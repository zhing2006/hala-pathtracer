#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"

layout(location = 0) rayPayloadInEXT RayPayload g_ray_payload;
hitAttributeEXT vec2 attribs; // barycentric coordinates of the triangle hit by a ray

void main() {
  const Ray r = g_ray_payload.ray;

  // Get the primitive data.
  const uint primitive_index = gl_InstanceCustomIndexEXT;
  Primitive prim = g_primitives[primitive_index].data;

  // Get the inverse transpose of the primitive's transform matrix.
  const mat3 transform_it = transpose(inverse(mat3(prim.transform)));

  // Get the three vertices of the triangle.
  const uint i0 = prim.indices.data[gl_PrimitiveID * 3 + 0];
  const uint i1 = prim.indices.data[gl_PrimitiveID * 3 + 1];
  const uint i2 = prim.indices.data[gl_PrimitiveID * 3 + 2];
  const Vertex v0 = prim.vertices.data[i0];
  const Vertex v1 = prim.vertices.data[i1];
  const Vertex v2 = prim.vertices.data[i2];
  const vec3 v0_position = vec3(v0.position_x, v0.position_y, v0.position_z);
  const vec3 v1_position = vec3(v1.position_x, v1.position_y, v1.position_z);
  const vec3 v2_position = vec3(v2.position_x, v2.position_y, v2.position_z);
  const vec3 v0_normal = vec3(v0.normal_x, v0.normal_y, v0.normal_z);
  const vec3 v1_normal = vec3(v1.normal_x, v1.normal_y, v1.normal_z);
  const vec3 v2_normal = vec3(v2.normal_x, v2.normal_y, v2.normal_z);
  const vec3 v0_tangent = vec3(v0.tangent_x, v0.tangent_y, v0.tangent_z);
  const vec3 v1_tangent = vec3(v1.tangent_x, v1.tangent_y, v1.tangent_z);
  const vec3 v2_tangent = vec3(v2.tangent_x, v2.tangent_y, v2.tangent_z);
  const vec2 v0_tex_coord = vec2(v0.tex_coord_x, v0.tex_coord_y);
  const vec2 v1_tex_coord = vec2(v1.tex_coord_x, v1.tex_coord_y);
  const vec2 v2_tex_coord = vec2(v2.tex_coord_x, v2.tex_coord_y);

  // // Calculate tangent and bitangent
  // vec3 delta_pos1 = v1_position - v0_position;
  // vec3 delta_pos2 = v2_position - v0_position;

  // vec2 delta_uv1 = v1_tex_coord - v0_tex_coord;
  // vec2 delta_uv2 = v2_tex_coord - v0_tex_coord;

  // float invdet = 1.0f / (delta_uv1.x * delta_uv2.y - delta_uv1.y * delta_uv2.x);

  // vec3 tangent = (delta_pos1 * delta_uv2.y - delta_pos2 * delta_uv1.y) * invdet;
  // tangent = normalize(transform_it * tangent);
  // vec3 bitangent = (delta_pos2 * delta_uv1.x - delta_pos1 * delta_uv2.x) * invdet;
  // bitangent = normalize(transform_it * bitangent);

  // Transform the vertices to world space.
  const vec3 barycentric = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);
  vec3 normal = v0_normal * barycentric.x + v1_normal * barycentric.y + v2_normal * barycentric.z;
  normal = normalize(transform_it * normal);
  vec3 tangent = v0_tangent * barycentric.x + v1_tangent * barycentric.y + v2_tangent * barycentric.z;
  tangent = normalize(transform_it * tangent);
  const vec3 bitangent = cross(normal, tangent);
  const vec2 tex_coord = v0_tex_coord * barycentric.x + v1_tex_coord * barycentric.y + v2_tex_coord * barycentric.z;

  // Fill the ray payload with the hit data.
  g_ray_payload.state.flags |= RAY_FLAGS_HIT;
  g_ray_payload.state.material_index = prim.material_index;
  g_ray_payload.state.hit_distance = gl_HitTEXT;
  g_ray_payload.state.first_hit_position = r.origin + r.direction * g_ray_payload.state.hit_distance;
  g_ray_payload.state.normal = normal;
  g_ray_payload.state.ffnormal = dot(normal, r.direction) <= 0.0 ? normal : -normal;
  g_ray_payload.state.tangent = tangent;
  g_ray_payload.state.bitangent = bitangent;
  g_ray_payload.state.tex_coord = tex_coord;
}
