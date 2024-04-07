/// Sample a quad light source.
/// \param[in,out] rng The random number generator state.
/// \param[in] state The state of the surface being shaded.
/// \param[in] light The light source to sample.
/// \param[out] normal The normal at the sampled point.
/// \param[out] emission The emitted radiance at the sampled point.
/// \param[out] dist The distance to the sampled point.
/// \param[out] pdf The probability density of the sampled direction.
/// \return The sampled direction.
vec3 quad_sample(inout RNGState rng, in State state, in Light light, out vec3 normal, out vec3 emission, out float dist, out float pdf) {
  const float r1 = rand(rng);
  const float r2 = rand(rng);

  const vec3 light_surface_pos = light.position + light.u * r1 + light.v * r2;
  vec3 light_dir = light_surface_pos - state.first_hit_position;

  normal = normalize(cross(light.v, light.u));
  const float cos_theta = dot(-light_dir, normal);
  // Hide back face.
  if (cos_theta < 0.0) {
    emission = vec3(0.0);
    dist = 0.0;
    pdf = 0.0;
    return vec3(0.0);
  }

  const float dist_sq = dot(light_dir, light_dir);
  dist = sqrt(dist_sq);
  light_dir /= dist;
  emission = light.intensity * g_main_ubo_inst.num_of_lights;
  pdf = dist_sq / (light.area * abs(cos_theta));

  return light_dir;
}

/// Intersect a quad light source.
/// \param[in] light The light source to intersect.
/// \param[in] Ray The ray to intersect with the light source.
/// \param[out] normal The normal at the intersection point.
/// \param[out] pdf The probability density of the intersection point.
/// \return The distance along the ray to the intersection point.
float quad_intersect(in Light light, in Ray ray, out vec3 normal, out float pdf) {
  normal = normalize(cross(light.v, light.u));

  const float cos_theta = dot(-ray.direction, normal);
  // Hide back face.
  if (cos_theta < 0.0)
    return INF;

  const vec4 plane = vec4(normal, dot(normal, light.position));
  const vec3 u = light.u / dot(light.u, light.u);
  const vec3 v = light.v / dot(light.v, light.v);

  const float t = rect_intersect(light.position, u, v, plane, ray);
  if (t < 0.0)
    return INF;

  pdf = (t * t) / (light.area * cos_theta);
  return t;
}