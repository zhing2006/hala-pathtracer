/// Sample the environment map.
/// \param[in, out] rng The random number generator state.
/// \param[out] color The color of the environment map at the sampled direction.
/// \param[out] pdf The probability density of the sample.
/// \return The sampled direction.
vec3 sample_env_map(inout RNGState rng, out vec3 color, out float pdf) {
  const vec2 s = rand2(rng);

  const float v = textureLod(sampler2D(g_env_map_dist[0], g_env_map_dist_sampler), vec2(0.0, s.x), 0).x;
  const float u = textureLod(sampler2D(g_env_map_dist[1], g_env_map_dist_sampler), vec2(s.y, v), 0).x;

  color = textureLod(g_env_map, vec2(u, v), 0).rgb;
  pdf = luminance(color) / g_main_ubo_inst.env_total_sum;

  const float phi = (u + g_main_ubo_inst.env_rotation) * TWO_PI;
  const float theta = v * PI;
  const float sin_theta = sin(theta);

  if (sin_theta <= EPS)
    pdf = 0.0;

  const vec3 direction = normalize(vec3(
    -sin_theta * cos(phi),
    sin_theta * sin(phi),
    cos(theta)
  ));

  // convert the probability density for sampling (u,v)
  // to one expressed in terms of solid angle on the sphere.
  // Consider the function g that maps from (u,v) to (θ,φ),
  // g(u,v) = (πu/nu,2πv/nv). The absolute value of the determinant
  // of the Jacobian |Jg| is 2π^2/(nu*nv). p(θ,φ) = p(u,v)*nu*nv/2π^2.
  // divide sin_theta for uv warp deformation.
  pdf = (pdf * g_main_ubo_inst.env_map_width * g_main_ubo_inst.env_map_height) / (TWO_PI * PI * sin_theta);

  return direction;
}

/// Get the probability density function of the environment map at the given uv and theta.
/// \param uv The uv coordinate to sample the environment map at.
/// \param theta The angle between the direction and the z-axis.
/// \return The probability density function of the environment map at the given uv and theta.
float env_pdf(in vec2 uv, in float theta) {
  const float sin_theta = sin(theta);
  if (sin_theta > EPS) {
    const vec3 color = textureLod(g_env_map, uv, 0).rgb;
    const float pdf = luminance(color) / g_main_ubo_inst.env_total_sum;
    if (pdf > EPS)
      return (pdf * g_main_ubo_inst.env_map_width * g_main_ubo_inst.env_map_height) / (TWO_PI * PI * sin_theta);
    else
      return 0.0;
  } else {
    return 0.0;
  }
}
