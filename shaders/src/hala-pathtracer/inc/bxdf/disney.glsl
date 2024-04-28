/// Compute the tint colors for a material with a given index of refraction.
/// param[in] base_color The base color of the material.
/// param[in] specular_tint The specular tint factor.
/// param[in] sheen_tint The sheen tint factor.
/// param[in] eta The index of refraction.
/// param[out] F0 The Fresnel reflectance at normal incidence.
/// param[out] c_sheen The sheen color.
/// param[out] c_spec0 The specular color at normal incidence.
void tint_colors(
  vec3 base_color,
  float specular_tint,
  float sheen_tint,
  float eta,
  out float F0,
  out vec3 c_sheen,
  out vec3 c_spec0
) {
  // Calculate the luminance of the base color
  const float lum = luminance(base_color);
  // Compute the color tint based on luminance, or use white if luminance is zero
  const vec3 ctint = lum > 0.0 ? base_color / lum : vec3(1.0);

  // Calculate the Fresnel reflectance at normal incidence (F0)
  F0 = (1.0 - eta) / (1.0 + eta);
  F0 *= F0;

  // Compute the specular color at normal incidence, with an optional tint
  c_spec0 = F0 * mix(vec3(1.0), ctint, specular_tint);

  // Compute the sheen color, with an optional tint
  c_sheen = mix(vec3(1.0), ctint, sheen_tint);
}

/// Evaluate the Disney diffuse reflection based on material properties and lighting vectors.
/// param[in] base_color The base color of the material.
/// param[in] roughness The roughness of the material.
/// param[in] subsurface The subsurface scattering weight.
/// param[in] sheen The sheen weight.
/// param[in] c_sheen The sheen color.
/// param[in] V The outgoing vector.
/// param[in] L The indident vector.
/// param[in] H The half-angle vector.
/// param[out] pdf The probability density function for the sample.
/// return The reflected radiance.
vec3 eval_disney_diffuse(vec3 base_color, float roughness, float subsurface, float sheen, vec3 c_sheen, vec3 V, vec3 L, vec3 H, out float pdf) {
  // If the light direction is below the horizon, return black (no contribution)
  pdf = 0.0;
  if (L.z <= 0.0)
      return vec3(0.0);

  // Calculate the dot product between the light direction and the half-vector
  // Cosine of the angle between the normal and the half-vector
  const float L_dot_H = dot(L, H);

  // Compute the retro-reflection based on roughness and the dot product
  const float retro_reflection = 2.0 * roughness * L_dot_H * L_dot_H;

  // Calculate the diffuse fresnel reflectance using Schlick's approximation
  const float f_L = schlick_weight(L.z);
  const float f_V = schlick_weight(V.z);
  // Combine the terms to get the retro-reflection contribution
  const float f_retro = retro_reflection * (f_L + f_V + f_L * f_V * (retro_reflection - 1.0));
  // Calculate the diffuse contribution
  const float f_d = (1.0 - 0.5 * f_L) * (1.0 - 0.5 * f_V);

  // Calculate the fake subsurface scattering term
  const float f_ss90 = 0.5 * retro_reflection;
  // Interpolate based on the fresnel terms
  const float f_ss = mix(1.0, f_ss90, f_L) * mix(1.0, f_ss90, f_V);
  // Final subsurface scattering term
  const float ss = 1.25 * (f_ss * (1.0 / (L.z + V.z) - 0.5) + 0.5);

  // Calculate the sheen term using the fresnel weight and sheen properties
  const float f_H = schlick_weight(L_dot_H);
  const vec3 f_sheen = f_H * sheen * c_sheen;

  // Set the probability density function for the light direction
  pdf = L.z * INV_PI;
  // Combine all terms to compute the final diffuse color
  return INV_PI * base_color * mix(f_d + f_retro, ss, subsurface) + f_sheen;
}

/// Evaluate the microfacet reflection based on material properties and lighting vectors.
/// param[in] ax The anisotropic roughness in the x direction.
/// param[in] ay The anisotropic roughness in the y direction.
/// param[in] V The outgoing vector.
/// param[in] L The indident vector.
/// param[in] H The half-angle vector.
/// param[in] F The Fresnel reflectance at normal incidence.
/// param[out] pdf The probability density function for the sample.
/// return The reflected radiance.
vec3 eval_microfacet_reflection(float ax, float ay, vec3 V, vec3 L, vec3 H, vec3 F, out float pdf) {
  // If the light direction is below the horizon, return black (no contribution)
  pdf = 0.0;
  if (L.z <= 0.0)
    return vec3(0.0);

  // Calculate the normal distribution function (D) using an anisotropic GGX distribution.
  const float D = gtr2_aniso(H.z, H.x, H.y, ax, ay);
  // Calculate the shadowing function (G1) for the outgoing vector V.
  const float G1 = smith_g_aniso(abs(V.z), V.x, V.y, ax, ay);
  // Calculate the combined shadowing function (G2) for both V and L.
  const float G2 = G1 * smith_g_aniso(abs(L.z), L.x, L.y, ax, ay);

  // Compute the probability density function for the microfacet reflection.
  pdf = G1 * D / (4.0 * V.z);
  // Return the reflected radiance which is the product of the Fresnel term (F),
  // the normal distribution function (D), and the shadowing function (G2),
  // divided by the geometric attenuation factor (4 * L.z * V.z).
  return F * D * G2 / (4.0 * L.z * V.z);
}

float directional_albedo(float alpha, float cosTheta) {
  return 1.0 -
         1.45940 * alpha * (-0.20276 + alpha * (2.77203 + (-2.61748 + 0.73343 * alpha) * alpha)) * cosTheta *
             (3.09507 + cosTheta * (-9.11368 + cosTheta * (15.88844 + cosTheta * (-13.70343 + 4.51786 * cosTheta))));
}

float average_albedo(float alpha) {
  return 1.0 + alpha * (-0.11304 + alpha * (-1.86947 + (2.22682 - 0.83397 * alpha) * alpha));
}

vec3 average_fresnel(vec3 f0, vec3 f90) {
  return 20.0 / 21.0 * f0 + 1.0 / 21.0 * f90;
}

/// Evaluate the microfacet energy compensation term based on material properties and lighting vectors.
/// param[in] ax The anisotropic roughness in the x direction.
/// param[in] ay The anisotropic roughness in the y direction.
/// param[in] V The outgoing vector.
/// param[in] L The indident vector.
/// param[in] H The half-angle vector.
/// param[in] F The Fresnel reflectance at normal incidence.
/// param[out] pdf The probability density function for the sample.
/// return The energy compensation term.
vec3 eval_microfacet_ms(float ax, float ay, vec3 V, vec3 L, vec3 H, vec3 F0) {
  return vec3(0.0);
  // float alpha = sqrt(ax * ay);
  // float Ewi = directional_albedo(alpha, abs(V.z));
  // float Ewo = directional_albedo(alpha, abs(L.z));
  // float Eavg = average_albedo(alpha);
  // float ms = (1.0 - Ewo) * (1.0 - Ewi) / (PI * (1.0 - Eavg));
  // vec3 Favg = average_fresnel(F0, vec3(1.0));
  // vec3 f = (Favg * Favg * Eavg) / (1.0 - Favg * (1.0 - Eavg));
  // return ms * f;
}

/// Evaluate the microfacet refraction based on material properties, lighting vectors, and the index of refraction.
/// param[in] ax The anisotropic roughness in the x direction.
/// param[in] ay The anisotropic roughness in the y direction.
/// param[in] base_color The base color of the material.
/// param[in] eta The relative index of refraction.
/// param[in] V The outgoing vector.
/// param[in] L The incident vector.
/// param[in] H The half-angle vector.
/// param[in] F The Fresnel reflectance at normal incidence.
/// param[out] pdf The probability density function for the sample.
/// return The refracted radiance.
vec3 eval_microfacet_refraction(float ax, float ay, vec3 base_color, float eta, vec3 V, vec3 L, vec3 H, vec3 F, out float pdf) {
  // If the light direction is below the horizon, return black (no contribution)
  pdf = 0.0;
  if (L.z >= 0.0)
    return vec3(0.0);

  // Calculate the dot product between L and H, and between V and H
  const float l_dot_h = dot(L, H);
  const float v_dot_h = dot(V, H);

  // Calculate the normal distribution function (D) using an anisotropic GGX distribution.
  const float D = gtr2_aniso(H.z, H.x, H.y, ax, ay);
  // Calculate the shadowing function (G1) for the outgoing vector V.
  const float G1 = smith_g_aniso(abs(V.z), V.x, V.y, ax, ay);
  // Calculate the combined shadowing function (G2) for both V and L.
  const float G2 = G1 * smith_g_aniso(abs(L.z), L.x, L.y, ax, ay);
  // Calculate the denominator of the refraction jacobian, which is part of the change of variables.
  float denom = l_dot_h + v_dot_h * eta;
  denom *= denom;
  // Calculate the squared relative index of refraction.
  const float eta2 = eta * eta;
  // Calculate the jacobian of the refraction, which accounts for the solid angle compression.
  const float jacobian = abs(l_dot_h) / denom;

  // Compute the probability density function for the microfacet refraction.
  pdf = G1 * max(0.0, v_dot_h) * D * jacobian / V.z;
  // Return the refracted radiance, which includes the base color, Fresnel term, normal distribution function,
  // shadowing function, jacobian, and the relative index of refraction, all divided by the geometric attenuation.
  return pow(base_color, vec3(0.5)) * (1.0 - F) * D * G2 * abs(v_dot_h) * jacobian * eta2 / abs(L.z * V.z);
}

/// Evaluate the clearcoat reflection based on material properties and lighting vectors.
/// Clearcoat is an additional specular layer on top of a material, often used to simulate a varnished surface.
/// param[in] clearcoat_roughness The roughness of the clearcoat layer.
/// param[in] V The normalized outgoing/view vector.
/// param[in] L The normalized incident/light vector.
/// param[in] H The normalized half-angle vector, which is the half-way direction between V and L.
/// param[out] pdf The probability density function for the sample, which is used for importance sampling.
/// return The clearcoat reflection contribution to the final color.
vec3 eval_clearcoat(float clearcoat_roughness, vec3 V, vec3 L, vec3 H, out float pdf) {
  // If the light direction is below the horizon, return black (no contribution).
  pdf = 0.0;
  if (L.z <= 0.0)
    return vec3(0.0);

  // Calculate the dot product between V and H.
  const float v_dot_h = dot(V, H);

  // Calculate the Fresnel term using Schlick's approximation.
  const float F = mix(0.04, 1.0, schlick_weight(v_dot_h));
  // Calculate the normal distribution function (D) using a GGX distribution tailored for clearcoat.
  const float D = gtr1(H.z, clearcoat_roughness);
  // Calculate the geometric attenuation (G) using the Smith's method for clearcoat.
  const float G = smith_g(L.z, 0.25) * smith_g(V.z, 0.25);
  // Calculate the jacobian of the reflection, which accounts for the solid angle compression.
  const float jacobian = 1.0 / (4.0 * v_dot_h);

  // Compute the probability density function for the clearcoat reflection.
  pdf = D * H.z * jacobian;
  // Return the clearcoat reflection contribution, which includes the Fresnel term, normal distribution function,
  // and the geometric attenuation.
  return vec3(F) * D * G;
}

/// Evaluate the Disney principled BSDF for a given material and lighting scenario.
/// This function combines multiple components, including diffuse, specular, metallic, and clearcoat reflections, as well as glass refractions.
/// param[in] any_non_specular_bounce Whether any non-specular bounces have occurred so far.
/// param[in] state The geometric state containing surface normal, tangent, and bitangent.
/// param[in] mat The material properties.
/// param[in] V The normalized outgoing/view vector.
/// param[in] N The normalized surface normal vector.
/// param[in] L The normalized incident/light vector.
/// param[out] pdf The probability density function for the sample, which is used for importance sampling.
/// return The combined BSDF contribution to the final radiance.
vec3 disney_eval(bool any_non_specular_bounce, State state, Material mat, vec3 V, vec3 N, vec3 L, out float pdf) {
  float ax = mat.ax;
  float ay = mat.ay;
#ifdef ROUGHNESS_REGULARIZE_EVAL
  // Regularize the anisotropic roughness to avoid artifacts.
  if (state.depth > 0 && any_non_specular_bounce) {
#ifdef ROUGHNESS_REGULARIZE_2EXP_WITH_DEPTH
    if (ax < 0.3) ax = clamp(2 * state.depth * ax, 0.1, 0.3);
    if (ay < 0.3) ay = clamp(2 * state.depth * ay, 0.1, 0.3);
#else
    if (ax < 0.3) ax = clamp(2 * ax, 0.1, 0.3);
    if (ay < 0.3) ay = clamp(2 * ay, 0.1, 0.3);
#endif
  }
#endif

  // Initialize the pdf to 0.0, which will be changed if the light direction is valid.
  pdf = 0.0;
  // Initialize the BSDF contribution to black.
  vec3 f = vec3(0.0);

  // Transform to tangent space to simplify operations (N dot L = L.z; N dot V = V.z; N dot H = H.z)
  V = to_local(state.tangent, state.bitangent, N, V);
  L = to_local(state.tangent, state.bitangent, N, L);

  // Calculate the half-angle vector based on whether we're reflecting or refracting.
  vec3 H;
  if (L.z > 0.0)
    H = normalize(L + V);
  else
    H = normalize(L + V * state.eta);

  // Ensure the half-angle vector is in the same hemisphere as the normal.
  if (H.z < 0.0)
    H = -H;

  // Compute tint colors and Fresnel reflectance at normal incidence.
  vec3 c_sheen, c_spec0;
  float F0;
  tint_colors(
    mat.base_color,
    mat.specular_tint,
    mat.sheen_tint,
    state.eta,
    F0,
    c_sheen,
    c_spec0);

  // Calculate weights for different material components.
  const float dielectric_wt = (1.0 - mat.metallic) * (1.0 - mat.specular_transmission);
  const float metal_wt = mat.metallic;
  const float glass_wt = (1.0 - mat.metallic) * mat.specular_transmission;

  // Compute probabilities for each BSDF lobe.
  const float schlick_wt = schlick_weight(V.z);
  float diffuse_pr = dielectric_wt * luminance(mat.base_color);
  float dielectric_pr = dielectric_wt * luminance(mix(c_spec0, vec3(1.0), schlick_wt));
  float metal_pr = metal_wt * luminance(mix(mat.base_color, vec3(1.0), schlick_wt));
  float glass_pr = glass_wt;
  float clearcoat_pr = 0.25 * mat.clearcoat;

  // Normalize probabilities to sum to 1.
  const float inv_total_wt = 1.0 / (diffuse_pr + dielectric_pr + metal_pr + glass_pr + clearcoat_pr);
  diffuse_pr *= inv_total_wt;
  dielectric_pr *= inv_total_wt;
  metal_pr *= inv_total_wt;
  glass_pr *= inv_total_wt;
  clearcoat_pr *= inv_total_wt;

  // Determine if we're dealing with reflection or refraction.
  const bool reflect = L.z * V.z > 0;

  // Temporary variable to store pdf for each component.
  float tmp_pdf = 0.0;
  // Calculate the absolute value of the dot product between V and H.
  const float v_dot_h = abs(dot(V, H));

  // Evaluate diffuse component if applicable.
  if (diffuse_pr > 0.0 && reflect) {
    f += eval_disney_diffuse(mat.base_color, mat.roughness, mat.subsurface, mat.sheen, c_sheen, V, L, H, tmp_pdf) * dielectric_wt;
    pdf += tmp_pdf * diffuse_pr;
  }

  // Evaluate dielectric specular reflection if applicable.
  if (dielectric_pr > 0.0 && reflect) {
    // Normalize for interpolating based on c_spec0
    const float F = (dielectric_fresnel(v_dot_h, state.eta) - F0) / (1.0 - F0);

    f += eval_microfacet_reflection(ax, ay, V, L, H, mix(c_spec0, vec3(1.0), F), tmp_pdf) * dielectric_wt;
    f += eval_microfacet_ms(ax, ay, V, L, H, c_spec0) * dielectric_wt;
    pdf += tmp_pdf * dielectric_pr;
  }

  // Evaluate metallic reflection if applicable.
  if (metal_pr > 0.0 && reflect) {
    // Tinted to base color
    const vec3 F = mix(mat.base_color, vec3(1.0), schlick_weight(v_dot_h));

    f += eval_microfacet_reflection(ax, ay, V, L, H, F, tmp_pdf) * metal_wt;
    f += eval_microfacet_ms(ax, ay, V, L, H, mat.base_color) * metal_wt;
    pdf += tmp_pdf * metal_pr;
  }

  // Evaluate glass/specular BSDF if applicable.
  if (glass_pr > 0.0) {
    // Dielectric fresnel (achromatic)
    const float F = dielectric_fresnel(v_dot_h, state.eta);

    if (reflect) {
      f += eval_microfacet_reflection(ax, ay, V, L, H, vec3(F), tmp_pdf) * glass_wt;
      f += eval_microfacet_ms(ax, ay, V, L, H, c_spec0) * glass_wt;
      pdf += tmp_pdf * glass_pr * F;
    } else {
      f += eval_microfacet_refraction(ax, ay, mat.base_color, state.eta, V, L, H, vec3(F), tmp_pdf) * glass_wt;
      pdf += tmp_pdf * glass_pr * (1.0 - F);
    }
  }

  // Evaluate clearcoat reflection if applicable.
  if (clearcoat_pr > 0.0 && reflect) {
    f += eval_clearcoat(mat.clearcoat_roughness, V, L, H, tmp_pdf) * mat.clearcoat_tint.xyz * 0.25 * mat.clearcoat;
    pdf += tmp_pdf * clearcoat_pr;
  }

  // Return the combined BSDF contribution multiplied by the cosine of the angle between L and N.
  return f * abs(L.z);
}

/// Sample the Disney principled BSDF for a given material and lighting scenario.
/// This function combines multiple components, including diffuse, specular, metallic, and clearcoat reflections, as well as glass refractions.
/// It uses importance sampling to choose one of these components based on their relative contribution to the material's appearance.
/// param[in, out] rng A random number generator state for sampling.
/// param[in, out] any_non_specular_bounce Set to true if any non-specular bounce is performed.
/// param[in] state The geometric state containing surface normal, tangent, and bitangent.
/// param[in] mat The material properties.
/// param[in] V The normalized outgoing/view vector.
/// param[in] N The normalized surface normal vector.
/// param[out] L The normalized incident/light vector that is sampled.
/// param[out] pdf The probability density function for the sample, which is used for importance sampling.
/// \param[out] flags The sampling flags.
/// return The combined BSDF contribution to the final radiance.
vec3 disney_sample(inout RNGState rng, inout bool any_non_specular_bounce, in State state, Material mat, vec3 V, vec3 N, out vec3 L, out float pdf, out uint flags) {
  float ax = mat.ax;
  float ay = mat.ay;
#ifdef ROUGHNESS_REGULARIZE_SAMPLE
  // Regularize the anisotropic roughness to avoid artifacts.
  if (state.depth > 0 && any_non_specular_bounce) {
#ifdef ROUGHNESS_REGULARIZE_2EXP_WITH_DEPTH
    if (ax < 0.3) ax = clamp(2 * state.depth * ax, 0.1, 0.3);
    if (ay < 0.3) ay = clamp(2 * state.depth * ay, 0.1, 0.3);
#else
    if (ax < 0.3) ax = clamp(2 * ax, 0.1, 0.3);
    if (ay < 0.3) ay = clamp(2 * ay, 0.1, 0.3);
#endif
  }
#endif
  // Our disney BSDF only have non-specular bounces. Because alpha x and y clamp to 0.001 in material.rs file.
  any_non_specular_bounce = true;

  // Initialize the pdf to 0.0, which will be changed if the light direction is valid.
  pdf = 0.0;

  // Generate two random numbers for sampling the BSDF.
  const float r1 = rand(rng);
  const float r2 = rand(rng);

  // Transform to tangent space to simplify operations (N dot L = L.z; N dot V = V.z; N dot H = H.z)
  V = to_local(state.tangent, state.bitangent, N, V);

  // Compute tint colors and Fresnel reflectance at normal incidence.
  vec3 c_sheen, c_spec0;
  float F0;
  tint_colors(
    mat.base_color,
    mat.specular_tint,
    mat.sheen_tint,
    state.eta,
    F0,
    c_sheen,
    c_spec0);

  // Calculate weights for different material components.
  const float dielectric_wt = (1.0 - mat.metallic) * (1.0 - mat.specular_transmission);
  const float metal_wt = mat.metallic;
  const float glass_wt = (1.0 - mat.metallic) * mat.specular_transmission;

  // Compute probabilities for each BSDF lobe.
  const float schlick_wt = schlick_weight(V.z);
  float diffuse_pr = dielectric_wt * luminance(mat.base_color);
  float dielectric_pr = dielectric_wt * luminance(mix(c_spec0, vec3(1.0), schlick_wt));
  float metal_pr = metal_wt * luminance(mix(mat.base_color, vec3(1.0), schlick_wt));
  float glass_pr = glass_wt;
  float clearcoat_pr = 0.25 * mat.clearcoat;

  // Normalize probabilities to sum to 1.
  const float inv_total_wt = 1.0 / (diffuse_pr + dielectric_pr + metal_pr + glass_pr + clearcoat_pr);
  diffuse_pr *= inv_total_wt;
  dielectric_pr *= inv_total_wt;
  metal_pr *= inv_total_wt;
  glass_pr *= inv_total_wt;
  clearcoat_pr *= inv_total_wt;

  // CDF of the sampling probabilities
  float cdf[5];
  cdf[0] = diffuse_pr;
  cdf[1] = cdf[0] + dielectric_pr;
  cdf[2] = cdf[1] + metal_pr;
  cdf[3] = cdf[2] + glass_pr;
  cdf[4] = cdf[3] + clearcoat_pr;

  // Sample a lobe based on its importance.
  float r3 = rand(rng);

  // Sample diffuse reflection with cosine-weighted hemisphere sampling.
  if (r3 < cdf[0]) {
    L = cosine_sample_hemisphere(r1, r2);
    flags = RAY_FLAGS_REFLECTION;
  }
  // Sample dielectric & metallic reflection with GGX VND sampling.
  else if (r3 < cdf[2]) {
    vec3 H = sample_ggx_vndf(V, ax, ay, r1, r2);

    if (H.z < 0.0)
      H = -H;

    L = normalize(reflect(-V, H));
    flags = RAY_FLAGS_REFLECTION;
  }
  // Sample glass reflection or refraction with GGX VND sampling.
  else if (r3 < cdf[3]) {
    vec3 H = sample_ggx_vndf(V, ax, ay, r1, r2);
    const float F = dielectric_fresnel(abs(dot(V, H)), state.eta);

    if (H.z < 0.0)
      H = -H;

    // Rescale random number.
    r3 = (r3 - cdf[2]) / (cdf[3] - cdf[2]);

    // Reflection
    if (r3 < F) {
      L = normalize(reflect(-V, H));
      flags = RAY_FLAGS_REFLECTION;
    }
    // Transmission
    else {
      L = normalize(refract(-V, H, state.eta));
      flags = RAY_FLAGS_TRANSMISSION;
    }
  }
  // Sample clearcoat reflection with GTR1 sampling.
  else {
    vec3 H = sample_gtr1(mat.clearcoat_roughness, r1, r2);

    if (H.z < 0.0)
      H = -H;

    L = normalize(reflect(-V, H));
    flags = RAY_FLAGS_REFLECTION;
  }

  // Transform the sampled direction back to world space.
  L = to_world(state.tangent, state.bitangent, N, L);
  V = to_world(state.tangent, state.bitangent, N, V);

  // Evaluate the BSDF for the sampled direction.
  return disney_eval(any_non_specular_bounce, state, mat, V, N, L, pdf);
}