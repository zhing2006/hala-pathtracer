#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"

layout(location = 0) rayPayloadInEXT RayPayload g_ray_payload;
hitAttributeEXT LightHitAttribute g_light_hit_attribute;

void main() {
  Ray r = g_ray_payload.ray;

  // Fill the ray payload with the hit data.
  g_ray_payload.state.flags |= (RAY_FLAGS_HIT | RAY_FLAGS_IS_EMITTER);
  g_ray_payload.state.material_index = gl_HitKindEXT;
  g_ray_payload.state.hit_distance = gl_HitTEXT;
  g_ray_payload.state.first_hit_position = r.origin + r.direction * g_ray_payload.state.hit_distance;
  g_ray_payload.state.normal = g_light_hit_attribute.normal;
  g_ray_payload.state.ffnormal = dot(g_ray_payload.state.normal, r.direction) <= 0.0 ? g_ray_payload.state.normal : -g_ray_payload.state.normal;
  g_ray_payload.state.tangent = vec3(0);
  g_ray_payload.state.bitangent = vec3(0);
  g_ray_payload.state.tex_coord = vec2(g_light_hit_attribute.pdf, 0.0);
}
