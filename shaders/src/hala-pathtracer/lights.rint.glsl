#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "common/intersection.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/light/quad.glsl"
#include "hala-pathtracer/inc/light/sphere.glsl"

hitAttributeEXT LightHitAttribute g_light_hit_attribute;

void main() {
  Ray ray;
  ray.origin    = gl_WorldRayOriginEXT;
  ray.direction = gl_WorldRayDirectionEXT;

  int index = gl_PrimitiveID;
  Light light = g_lights_buf_inst.lights[index];

  float t = INF;
  vec3 normal = vec3(0.0);
  float pdf = 1.0;
  if (light.type == LIGHT_TYPE_QUAD) {
    t = quad_intersect(light, ray, normal, pdf);
  } else if (light.type == LIGHT_TYPE_SPHERE) {
    t = sphere_intersect(light, ray, normal, pdf);
  }

  if (t >= gl_RayTminEXT && t <= gl_RayTmaxEXT) {
    g_light_hit_attribute.normal = normal;
    g_light_hit_attribute.pdf = pdf;
    reportIntersectionEXT(t, index);
  }
}