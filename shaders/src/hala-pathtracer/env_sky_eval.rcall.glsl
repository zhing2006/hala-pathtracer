#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"

layout(location = 1) callableDataInEXT EvalEnv g_eval_env;

void main() {
  const float a = max(g_eval_env.direction.z, 0.0);
  g_eval_env.radiance = mix(g_main_ubo_inst.ground_color.rgb, g_main_ubo_inst.sky_color.rgb, a) * g_main_ubo_inst.env_intensity;
}