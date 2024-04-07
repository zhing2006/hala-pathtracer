#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"

layout(location = 0) rayPayloadInEXT RayPayload g_ray_payload;

void main() {
  g_ray_payload.state.flags &= ~RAY_FLAGS_HIT;
}
