#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"

layout(location = 1) rayPayloadInEXT ShadowRayPayload g_shadow_ray_payload;

void main() {
  g_shadow_ray_payload.is_hit = false;
}
