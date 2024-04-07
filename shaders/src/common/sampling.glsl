vec2 uniform_sample_disk(in float r1, in float r2);

/// Compute the GTR (Generalized Trowbridge-Reitz) microfacet distribution.
/// This measures the probability distribution of microfacets oriented along the half-vector h.
/// \param[in] n_dot_h The dot product of the normal and half-vector.
/// \param[in] a The roughness parameter of the surface which affects the spread of the microfacet orientation.
/// \return The GTR distribution value.
float gtr1(in float n_dot_h, in float a) {
  // If the roughness is close to 1, the surface is very rough, and we return an isotropic distribution.
  if (a >= 1.0)
      return INV_PI;
  // Square of the roughness parameter.
  const float a2 = a * a;
  // Intermediate term used in the distribution equation.
  const float t = 1.0 + (a2 - 1.0) * n_dot_h * n_dot_h;
  // The GTR distribution function scaled by the roughness and the cosine of the angle of incidence.
  return (a2 - 1.0) / (PI * log(a2) * t);
}

/// Sample a direction based on the GTR1 microfacet distribution,
/// \param[in] roughness The roughness parameter of the surface which affects the spread of the microfacet orientation.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
/// \return The sampled direction.
vec3 sample_gtr1(in float roughness, in float r1, in float r2) {
  // Clamp roughness to avoid a zero value which can cause issues in computation.
  const float a = max(0.001, roughness);
  // Roughness squared.
  const float a2 = a * a;

  // Azimuthal angle phi uniformly sampled around the hemisphere.
  const float phi = r1 * TWO_PI;

  // Elevation angle theta calculated based on the microfacet distribution.
  // Ensure the result is clamped to valid range.
  const float cos_theta = sqrt((1.0 - pow(a2, 1.0 - r2)) / (1.0 - a2));
  const float sin_theta = clamp(sqrt(1.0 - (cos_theta * cos_theta)), 0.0, 1.0);
  // Sine and cosine components of phi.
  const float sin_phi = sin(phi);
  const float cos_phi = cos(phi);

  // Return the microfacet normal in spherical coordinates.
  return vec3(sin_theta * cos_phi, sin_theta * sin_theta, cos_theta);
}

/// Compute the GTR2 (Generalized Trowbridge-Reitz) microfacet distribution.
/// This measures the probability distribution of microfacets oriented along the half-vector h.
/// \param[in] n_dot_h The dot product of the normal and half-vector.
/// \param[in] a The roughness parameter of the surface which affects the spread of the microfacet orientation.
/// \return The GTR2 distribution value.
float gtr2(in float n_dot_h, in float a) {
  // Roughness squared.
  const float a2 = a * a;
  // Intermediate term used in the GGX distribution equation.
  const float t = 1.0 + (a2 - 1.0) * n_dot_h * n_dot_h;
  // The GTR2 distribution function normalized by Pi and adjusted for the microfacet orientations.
  return a2 / (PI * t * t);
}

/// Sample a direction based on the GTR2 microfacet distribution.
/// \param[in] roughness The roughness parameter of the surface which affects the spread of the microfacet orientation.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
/// \return The sampled direction.
vec3 sample_gtr2(in float roughness, in float r1, in float r2) {
  // Ensure the roughness is above a small threshold to avoid degenerate cases.
  const float a = max(0.001, roughness);

  // Azimuthal angle phi uniformly sampled around the hemisphere.
  const float phi = r1 * TWO_PI;

  // Solve for the elevation angle theta based on the inverse CDF of GTR2.
  // Ensure theta is within valid bounds.
  const float cos_theta = sqrt((1.0 - r2) / (1.0 + (a * a - 1.0) * r2));
  const float sin_theta = clamp(sqrt(1.0 - (cos_theta * cos_theta)), 0.0, 1.0);
  // Sine and cosine components of phi.
  const float sin_phi = sin(phi);
  const float cos_phi = cos(phi);

  // Return the microfacet normal in spherical coordinates.
  return vec3(sin_theta * cos_phi, sin_theta * sin_phi, cos_theta);
}

/// Sample a microfacet normal based on the GGX VNDF (Visible Normal Distribution Function).
/// \param[in] V The incident direction.
/// \param[in] ax The anisotropic roughness parameter in the x direction.
/// \param[in] ay The anisotropic roughness parameter in the y direction.
vec3 sample_ggx_vndf(in vec3 V, in float ax, in float ay, in float r1, in float r2) {
  // Stretch the view vector V by the anisotropic roughness parameters and normalize it.
  const vec3 Vh = normalize(vec3(ax * V.x, ay * V.y, V.z));

  // Compute the length squared of the projected view vector onto the surface plane.
  const float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
  // T1 and T2 form an orthonormal basis (tangent space) perpendicular to Vh.
  const vec3 T1 = lensq > 0 ? vec3(-Vh.y, Vh.x, 0) * inversesqrt(lensq) : vec3(1, 0, 0);
  const vec3 T2 = cross(Vh, T1);

  // Sample a point on the unit disk in the tangent space.
  vec2 t = uniform_sample_disk(r1, r2);
  // Blend between the disk sample and a sample in the hemisphere based on the z component of Vh.
  const float s = 0.5 * (1.0 + Vh.z);
  t.y = (1.0 - s) * sqrt(1.0 - t.x * t.x) + s * t.y;

  // Combine the sampled point with the stretched view vector to get the sampled half-vector.
  const vec3 Nh = t.x * T1 + t.y * T2 + sqrt(max(0.0, 1.0 - t.x * t.x - t.y * t.y)) * Vh;

  // Return the sampled microfacet normal, unstretched, ensuring it's above the surface plane.
  return normalize(vec3(ax * Nh.x, ay * Nh.y, max(0.0, Nh.z)));
}

/// Compute the GTR2Aniso (Generalized Trowbridge-Reitz) microfacet distribution with anisotropy.
/// This measures the probability distribution of microfacets oriented along the half-vector h.
/// \param[in] n_dot_h The dot product of the normal and half-vector.
/// \param[in] h_dot_x The dot product of the half-vector and the x axis.
/// \param[in] h_dot_y The dot product of the half-vector and the y axis.
/// \param[in] ax The anisotropic roughness parameter in the x direction.
/// \param[in] ay The anisotropic roughness parameter in the y direction.
/// \return The GTR2Aniso distribution value.
float gtr2_aniso(in float n_dot_h, in float h_dot_x, in float h_dot_y, in float ax, in float ay) {
  // Squares of anisotropic scaling factors.
  // Combined distribution term.
  const float a = h_dot_x / ax;
  const float b = h_dot_y / ay;
  const float c = a * a + b * b + n_dot_h * n_dot_h;
  // Return the microfacet distribution function for anisotropic surfaces.
  return 1.0 / (PI * ax * ay * c * c);
}

/// Sample a direction based on the GTR2Aniso microfacet distribution.
/// \param[in] ax The anisotropic roughness parameter in the x direction.
/// \param[in] ay The anisotropic roughness parameter in the y direction.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
/// \return The sampled direction.
vec3 sample_gtr2_aniso(in float ax, in float ay, in float r1, in float r2) {
  // Calculate the azimuthal angle phi for anisotropic sampling.
  const float phi = r1 * TWO_PI;

  // Apply anisotropy scaling to the azimuthal angle components.
  const float sin_phi = ay * sin(phi);
  const float cos_phi = ax * cos(phi);
  // Calculate the tangent of the polar angle theta based on random sample r2.
  const float tan_theta = sqrt(r2 / (1 - r2));

  // Construct microfacet normal in anisotropic tangent space and normalize.
  return vec3(tan_theta * cos_phi, tan_theta * sin_phi, 1.0);
}

/// Compute SmithG (Smith's Geometric Shadowing function) calculates the likelihood that
/// microfacets are visible from a given view direction. This function is isotropic.
/// \param[in] n_dot_v The dot product of the normal and view direction.
/// \param[in] alpha_g The roughness parameter of the surface which affects the spread of the microfacet orientation.
/// \return The SmithG value.
float smith_g(in float n_dot_v, in float alpha_g) {
  // Roughness squared.
  const float a = alpha_g * alpha_g;
  // Cosine of the incident angle squared.
  const float b = n_dot_v * n_dot_v;
  // Calculate and return the shadowing term considering only isotropy.
  return (2.0 * n_dot_v) / (n_dot_v + sqrt(a + b - a * b));
}

/// Compute SmithGAniso (Smith's Geometric Shadowing function) calculates the likelihood that
/// microfacets are visible from a given view direction. This function is anisotropic.
/// \param[in] n_dot_v The dot product of the normal and view direction.
float smith_g_aniso(in float n_dot_v, in float v_dot_x, in float v_dot_y, in float ax, in float ay) {
  // Anisotropic scaling along the tangent direction.
  const float a = v_dot_x * ax;
  // Anisotropic scaling along the bitangent direction.
  const float b = v_dot_y * ay;
  // Cosine of the incident angle.
  const float c = n_dot_v;
  // Calculate and return the geometric shadowing function considering anisotropy.
  return (2.0 * n_dot_v) / (n_dot_v + sqrt(a * a + b * b + c * c));
}

/// Compute the Fresnel reflectance for a conductor using the Schlick approximation.
/// \param[in] u The cosine of the angle between the incident and normal directions.
/// \param[in] f0 The reflectance at normal incidence.
float schlick_weight(in float u) {
  const float m = clamp(1.0 - u, 0.0, 1.0);
  const float m2 = m * m;
  return m2 * m2 * m;
}

/// Compute the Fresnel reflectance of a dielectric material given the
/// incident angle and the relative index of refraction using Fresnel's equations.
/// \param[in] cos_theta_i The cosine of the angle between the incident and normal directions.
/// \param[in] eta The relative index of refraction.
/// \return The Fresnel reflectance value.
float dielectric_fresnel(in float cos_theta_i, in float eta) {
  // Sin squared of transmitted angle.
  const float sin_theat_t_sq = eta * eta * (1.0f - cos_theta_i * cos_theta_i);

  // Total internal reflection check, for which reflectance becomes 1.
  if (sin_theat_t_sq > 1.0)
    return 1.0;

  // Cosine of the transmitted angle.
  const float cos_theta_t = sqrt(max(1.0 - sin_theat_t_sq, 0.0));

  // Perpendicular reflectance.
  const float rs = (eta * cos_theta_t - cos_theta_i) / (eta * cos_theta_t + cos_theta_i);
  // Parallel reflectance.
  const float rp = (eta * cos_theta_i - cos_theta_t) / (eta * cos_theta_i + cos_theta_t);

  // Average the two polarization reflectances to get total reflectance.
  return 0.5 * (rs * rs + rp * rp);
}

/// Uniform disk sampling.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
/// \return A point on the unit disk.
vec2 uniform_sample_disk(in float r1, in float r2) {
  const float r = sqrt(r1);
  const float phi = TWO_PI * r2;
  return vec2(r * cos(phi), r * sin(phi));
}

/// Cosine-weighted hemisphere sampling.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
/// \return A direction vector in the hemisphere.
vec3 cosine_sample_hemisphere(in float r1, in float r2) {
  vec3 dir;
  const float r = sqrt(r1);
  const float phi = TWO_PI * r2;
  dir.x = r * cos(phi);
  dir.y = r * sin(phi);
  dir.z = sqrt(max(0.0, 1.0 - dir.x * dir.x - dir.y * dir.y));
  return dir;
}

/// Uniform hemisphere sampling.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
/// \return A direction vector in the hemisphere.
vec3 uniform_sample_hemisphere(in float r1, in float r2) {
  const float r = sqrt(max(0.0, 1.0 - r1 * r1));
  const float phi = TWO_PI * r2;
  return vec3(r * cos(phi), r * sin(phi), r1);
}

/// Uniform sphere sampling.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
vec3 uniform_sample_sphere(in float r1, in float r2) {
  const float z = 1.0 - 2.0 * r1;
  const float r = sqrt(max(0.0, 1.0 - z * z));
  const float phi = TWO_PI * r2;
  return vec3(r * cos(phi), r * sin(phi), z);
}

/// Power heuristic.
/// \param[in] a A value.
/// \param[in] b A value.
/// \return The power heuristic.
float power_heuristic(in float a, in float b) {
  a *= a;
  b *= b;
  return a / (a + b);
}

/// Build an orthonormal basis from a normal vector.
/// \param[in] N The normal vector.
/// \param[out] T The tangent vector.
/// \param[out] B The bitangent vector.
void onb(in vec3 N, inout vec3 T, inout vec3 B) {
  vec3 up = abs(N.z) < 0.9999999 ? vec3(0, 0, 1) : vec3(1, 0, 0);
  T = normalize(cross(up, N));
  B = cross(N, T);
}

/// Henyey-Greenstein sampling.
/// \param[in] V The incident direction.
/// \param[in] g The anisotropy factor.
/// \param[in] r1 A random number in [0, 1].
/// \param[in] r2 A random number in [0, 1].
/// \return The sampled outgoing direction.
vec3 sample_hg(in vec3 V, in float g, in float r1, in float r2) {
  float cos_theta;

  if (abs(g) < 0.001)
    cos_theta = 1 - 2 * r2;
  else {
    const float sqr_term = (1 - g * g) / (1 + g - 2 * g * r2);
    cos_theta = -(1 + g * g - sqr_term * sqr_term) / (2 * g);
  }

  const float phi = r1 * TWO_PI;
  const float sin_theta = clamp(sqrt(1.0 - (cos_theta * cos_theta)), 0.0, 1.0);
  const float sin_phi = sin(phi);
  const float cos_phi = cos(phi);

  vec3 v1, v2;
  onb(V, v1, v2);

  return sin_theta * cos_phi * v1 + sin_theta * sin_phi * v2 + cos_theta * V;
}

/// Henyey-Greenstein phase function.
/// \param[in] cos_theta The cosine of the angle between the incident and outgoing directions.
/// \param[in] g The anisotropy factor.
/// \return The phase function value.
float phase_hg(in float cos_theta, in float g) {
  const float denom = max(1 + g * g + 2 * g * cos_theta, EPS);
  return INV_FOUR_PI * (1 - g * g) / (denom * sqrt(denom));
}