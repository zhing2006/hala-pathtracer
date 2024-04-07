/// Sample a point light source.
/// \param[in,out] rng The random number generator state.
/// \param[in] state The state of the surface being shaded.
/// \param[in] light The light source to sample.
/// \param[out] normal The normal at the sampled point.
/// \param[out] emission The emitted radiance at the sampled point.
/// \param[out] dist The distance to the sampled point.
/// \param[out] pdf The probability density of the sampled direction.
/// \return The sampled direction.
vec3 point_sample(inout RNGState rng, in State state, in Light light, out vec3 normal, out vec3 emission, out float dist, out float pdf) {
  vec3 light_dir = light.position - state.first_hit_position;
  const float dist_sq = dot(light_dir, light_dir);
  dist = sqrt(dist_sq);
  light_dir = light_dir / dist;

  normal = -light_dir;
  emission = light.intensity * g_main_ubo_inst.num_of_lights / dist_sq;
  pdf = 1.0;

  return light_dir;
}