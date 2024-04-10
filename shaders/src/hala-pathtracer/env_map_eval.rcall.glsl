#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/env_map.glsl"

layout(location = 1) callableDataInEXT EvalEnv g_eval_env;

void main() {
  vec3 dir = g_eval_env.direction;
  const float theta = acos(dir.z);
  const vec2 uv = vec2(
    -(PI + atan(dir.y, dir.x)) * INV_TWO_PI - g_main_ubo_inst.env_rotation,
    theta * INV_PI
  );

  float mis_weight = 1.0;
  if (g_eval_env.depth > 0 && (g_eval_env.flags & RAY_FLAGS_SPECULAR) == 0) {
    const float pdf = env_pdf(uv, theta);
    mis_weight = power_heuristic(g_eval_env.pdf, pdf);
  }

#if defined(USE_MEDIUM) && !defined(USE_VOL_MIS)
  if (!g_eval_env.is_surface_scatter) {
    mis_weight = 1.0;
  }
#endif

  g_eval_env.radiance = mis_weight * textureLod(g_env_map, uv, 0).rgb * g_main_ubo_inst.env_intensity;
}