vec3 lambert_eval(in State state, in Material mat, in vec3 V, in vec3 N, in vec3 L, out float pdf);

/// Lambertian BRDF sampling and evaluation functions.
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
vec3 lambert_sample(inout RNGState rng, inout bool any_non_specular_bounce, in State state, in Material mat, in vec3 V, in vec3 N, out vec3 L, out float pdf, out uint flags) {
  const float r1 = rand(rng);
  const float r2 = rand(rng);

  L = cosine_sample_hemisphere(r1, r2);
  L = to_world(state.tangent, state.bitangent, N, L);

  // Lambertian BRDF is always non-specular.
  any_non_specular_bounce = true;

  flags = RAY_FLAGS_REFLECTION;
  return lambert_eval(state, mat, V, N, L, pdf);
}

/// Lambertian BRDF evaluation function.
/// \param[in] state The ray tracing state.
/// \param[in] mat The material.
/// \param[in] V The view direction.
/// \param[in] N The surface normal.
/// \param[in] L The light direction.
/// \param[out] pdf The probability density function value.
/// \return The BRDF value.
vec3 lambert_eval(in State state, in Material mat, in vec3 V, in vec3 N, in vec3 L, out float pdf) {
  const float n_dot_l = dot(N, L);
  pdf = n_dot_l * INV_PI;

  return mat.base_color * n_dot_l * INV_PI;
}

/// Lambertian BRDF probability density function.
/// \param[in] V The view direction.
/// \param[in] N The surface normal.
/// \param[in] L The light direction.
/// \return The probability density function value.
float lambert_pdf(in vec3 V, in vec3 N, in vec3 L) {
  return dot(N, L) * INV_PI;
}