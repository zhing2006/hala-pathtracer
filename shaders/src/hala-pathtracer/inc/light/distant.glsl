/// Sample a distant light source.
/// \param[in,out] rng The random number generator state.
/// \param[in] state The state of the surface being shaded.
/// \param[in] light The light source to sample.
/// \param[out] normal The normal at the sampled point.
/// \param[out] emission The emitted radiance at the sampled point.
/// \param[out] dist The distance to the sampled point.
/// \param[out] pdf The probability density of the sampled direction.
/// \return The sampled direction.
vec3 distant_sample(inout RNGState rng, in State state, in Light light, out vec3 normal, out vec3 emission, out float dist, out float pdf) {
  vec3 direction = -light.u;

  const float cos_alpha = light.v.x;
  if (cos_alpha > EPS) {
    const vec3 N = direction;
    vec3 T, B;
    onb(N, T, B);

    const float r = rand(rng);
    const float phi = TWO_PI * rand(rng);
    const float z = (1 - r * (1 - cos_alpha));
    const float radius = sqrt(1 - z * z);
    const float x = radius * cos(phi);
    const float y = radius * sin(phi);

    direction = to_world(T, B, N, vec3(x, y, z));
  }

  normal = light.u;
  emission = light.intensity * g_main_ubo_inst.num_of_lights;
  dist = WORLD_SIZE;
  pdf = 1.0;

  return direction;
}