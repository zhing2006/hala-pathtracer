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
  Ray r = g_ray_payload.ray;

  // Get the primitive data.
  uint primitive_index = gl_InstanceCustomIndexEXT;
  Primitive prim = g_primitives_buf_inst.primitives[primitive_index];

  // Get the inverse transpose of the primitive's transform matrix.
  mat3 transform_it = transpose(inverse(mat3(prim.transform)));

  // Get the three vertices of the triangle.
  uint i0 = prim.indices.data[gl_PrimitiveID * 3 + 0];
  uint i1 = prim.indices.data[gl_PrimitiveID * 3 + 1];
  uint i2 = prim.indices.data[gl_PrimitiveID * 3 + 2];
  Vertex v0 = prim.vertices.data[i0];
  Vertex v1 = prim.vertices.data[i1];
  Vertex v2 = prim.vertices.data[i2];

  // // Calculate tangent and bitangent
  // vec3 delta_pos1 = v1.position - v0.position;
  // vec3 delta_pos2 = v2.position - v0.position;

  // vec2 delta_uv1 = v1.tex_coord - v0.tex_coord;
  // vec2 delta_uv2 = v2.tex_coord - v0.tex_coord;

  // float invdet = 1.0f / (delta_uv1.x * delta_uv2.y - delta_uv1.y * delta_uv2.x);

  // vec3 tangent = (delta_pos1 * delta_uv2.y - delta_pos2 * delta_uv1.y) * invdet;
  // tangent = normalize(transform_it * tangent);
  // vec3 bitangent = (delta_pos2 * delta_uv1.x - delta_pos1 * delta_uv2.x) * invdet;
  // bitangent = normalize(transform_it * bitangent);

  // Transform the vertices to world space.
  const vec3 barycentric = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);
  vec3 normal = v0.normal * barycentric.x + v1.normal * barycentric.y + v2.normal * barycentric.z;
  normal = normalize(transform_it * normal);
  vec3 tangent = v0.tangent * barycentric.x + v1.tangent * barycentric.y + v2.tangent * barycentric.z;
  tangent = normalize(transform_it * tangent);
  vec3 bitangent = cross(normal, tangent);
  vec2 tex_coord = v0.tex_coord * barycentric.x + v1.tex_coord * barycentric.y + v2.tex_coord * barycentric.z;

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
