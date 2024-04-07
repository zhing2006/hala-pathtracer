/// Compute the Oren-Nayar reflectance factor.
/// param[in] state The ray tracing state.
/// param[in] mat The material.
/// param[in] V The outgoing direction.
/// param[in] L The incident direction.
/// return The reflectance factor.
vec3 oren_nayar_f(in State state, in Material mat, in vec3 wo, in vec3 wi) {
  // Compute the sine of the angle of incidence and observation.
  const float sin_theta_i = sin_theta(wi);
  const float sin_theta_o = sin_theta(wo);

  // Computes cosine term of Oren-Nayar model.
  float max_cos = 0.0;
  // If both angles are greater than a small epsilon (avoiding division by zero)
  if (sin_theta_i > EPS && sin_theta_o > EPS) {
    // Calculate sin and cos phi for the incoming and outgoing directions
    const float sin_phi_i = sin_phi(wi), cos_phi_i = cos_phi(wi);
    const float sin_phi_o = sin_phi(wo), cos_phi_o = cos_phi(wo);
    // Compute the difference in azimuth angle between the light and view directions
    const float d_cos = cos_phi_i * cos_phi_o + sin_phi_i * sin_phi_o;
    // Take the maximum between 0 and the azimuthal angle difference (avoid negative values)
    max_cos = max(0.0, d_cos);
  }

  // Calculate sin of the alpha angle and tangent of the beta angle
  float sin_alpha, tan_beta;
  if (abs_cos_theta(wi) > abs_cos_theta(wo)) {
    sin_alpha = sin_theta_o;
    tan_beta = sin_theta_i / abs_cos_theta(wi);
  } else {
    sin_alpha = sin_theta_i;
    tan_beta = sin_theta_o / abs_cos_theta(wo);
  }

  // // Compute the roughness squared and Oren-Nayar coefficients A and B
  // // The roughness (sigma) is scaled by PI/2 for conversion
  // const float sigma = mat.roughness * FRAC_PI_2;
  // const float sigma2 = sigma * sigma;
  // // Coefficient A accounts for the flat Lambertian-like term but attenuated
  // // by the surface roughness
  // const float A = 1.0 - (sigma2 / (2.0 * (sigma2 + 0.33)));
  // // Coefficient B accounts for the surface roughness and viewing geometry
  // const float B = 0.45 * sigma2 / (sigma2 + 0.09);

  const float A = mat.ax;
  const float B = mat.ay;

  // Return the Oren-Nayar diffuse reflectance factoring in coefficients A and B,
  // the material base color, and the inverse of pi (since it's a diffuse model).
  return mat.base_color * INV_PI * (A + B * max_cos * sin_alpha * tan_beta);
}

vec3 oren_nayar_eval(in State state, in Material mat, in vec3 V, in vec3 N, in vec3 L, out float pdf);

/// Oren Nayar BRDF sampling and evaluation functions.
/// \param[in,out] rng The random number generator state.
/// \param[in,out] any_non_specular_bounce Set to true if any non-specular bounce is performed.
/// \param[in] state The ray tracing state.
/// \param[in] mat The material.
/// \param[in] V The view direction.
/// \param[in] N The surface normal.
/// \param[in] T The tangent vector.
/// \param[out] L The light direction.
/// \param[out] pdf The probability density function value.
/// \param[out] flags The sampling flags.
/// \return The BRDF value.
vec3 oren_nayar_sample(inout RNGState rng, inout bool any_non_specular_bounce, in State state, in Material mat, in vec3 V, in vec3 N, out vec3 L, out float pdf, out uint flags) {
  const float r1 = rand(rng);
  const float r2 = rand(rng);

  L = cosine_sample_hemisphere(r1, r2);
  L = to_world(state.tangent, state.bitangent, N, L);

  // Oren Nayar BRDF is always non-specular.
  any_non_specular_bounce = true;

  flags = RAY_FLAGS_REFLECTION;
  return oren_nayar_eval(state, mat, V, N, L, pdf);
}

/// Oren Nayar BRDF evaluation function.
/// \param[in] state The ray tracing state.
/// \param[in] mat The material.
/// \param[in] V The view direction.
/// \param[in] N The surface normal.
/// \param[in] L The light direction.
/// \param[out] pdf The probability density function value.
/// \return The BRDF value.
vec3 oren_nayar_eval(in State state, in Material mat, in vec3 V, in vec3 N, in vec3 L, out float pdf) {
  L = to_local(state.tangent, state.bitangent, N, L);
  V = to_local(state.tangent, state.bitangent, N, V);

  pdf = L.z * INV_PI;

  return oren_nayar_f(state, mat, V, L) * L.z;
}

/// Oren Nayar BRDF probability density function.
/// \param[in] V The view direction.
/// \param[in] N The surface normal.
/// \param[in] L The light direction.
/// \return The probability density function value.
float oren_nayar_pdf(in vec3 V, in vec3 N, in vec3 L) {
  return dot(N, L) * INV_PI;
}