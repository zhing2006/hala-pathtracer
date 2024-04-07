/// Sample a sphere light source.
/// \param[in,out] rng The random number generator state.
/// \param[in] state The state of the surface being shaded.
/// \param[in] light The light source to sample.
/// \param[out] normal The normal at the sampled point.
/// \param[out] emission The emitted radiance at the sampled point.
/// \param[out] dist The distance to the sampled point.
/// \param[out] pdf The probability density of the sampled direction.
/// \return The sampled direction.
vec3 sphere_sample(inout RNGState rng, in State state, in Light light, out vec3 normal, out vec3 emission, out float dist, out float pdf) {
  const float r1 = rand(rng);
  const float r2 = rand(rng);

  vec3 sphere_center_to_surface = state.first_hit_position - light.position;
  const float dist_to_sphere_center = length(sphere_center_to_surface);
  sphere_center_to_surface /= dist_to_sphere_center;
  // No lighting inside the sphere.
  if (dist_to_sphere_center < light.radius) {
    normal = sphere_center_to_surface;
    emission = vec3(0.0);
    dist = dist_to_sphere_center;
    pdf = 0.0;
    return vec3(0.0);
  }

  vec3 sampled_dir = uniform_sample_hemisphere(r1, r2);

  vec3 T, B;
  onb(sphere_center_to_surface, T, B);
  sampled_dir = T * sampled_dir.x + B * sampled_dir.y + sphere_center_to_surface * sampled_dir.z;

  vec3 light_surface_pos = light.position + sampled_dir * light.radius;
  vec3 light_dir = light_surface_pos - state.first_hit_position;
  const float dist_sq = dot(light_dir, light_dir);
  dist = sqrt(dist_sq);
  light_dir = light_dir / dist;
  normal = normalize(light_surface_pos - light.position);
  emission = light.intensity * g_main_ubo_inst.num_of_lights;
  pdf = dist_sq / (light.area * 0.5 * abs(dot(normal, light_dir)));

  return light_dir;
}

/// Intersect a sphere light source.
/// \param[in] light The light source to intersect.
/// \param[in] Ray The ray to intersect with the light source.
/// \param[out] normal The normal at the intersection point.
/// \param[out] pdf The probability density of the intersection point.
/// \return The distance along the ray to the intersection point.
float sphere_intersect(in Light light, in Ray ray, out vec3 normal, out float pdf) {
  // No lighting inside the sphere.
  const float dist = length(light.position - ray.origin);
  if (dist < light.radius)
    return INF;

  const float t = sphere_intersect(light.radius, light.position, ray);
  if (t < 0.0)
    return INF;

  const vec3 hit_pt = ray.origin + t * ray.direction;
  const float cos_theta = dot(-ray.direction, normalize(hit_pt - light.position));

  pdf = (t * t) / (light.area * cos_theta * 0.5);

  return t;
}