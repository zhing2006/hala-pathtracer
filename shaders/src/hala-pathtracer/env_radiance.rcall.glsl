#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/env_map.glsl"

layout(location = 1) callableDataInEXT GetEnvRadiance g_get_env_radiance;

void main() {
  if (g_main_ubo_inst.use_hdri) {
    vec3 dir = g_get_env_radiance.direction;
    const float theta = acos(dir.z);
    const vec2 uv = vec2(
      -(PI + atan(dir.y, dir.x)) * INV_TWO_PI - g_main_ubo_inst.env_rotation,
      theta * INV_PI
    );

    float mis_weight = 1.0;
    if (g_get_env_radiance.depth > 0 && (g_get_env_radiance.flags & RAY_FLAGS_SPECULAR) == 0) {
      const float pdf = env_pdf(uv, theta);
      mis_weight = power_heuristic(g_get_env_radiance.pdf, pdf);
    }

#if defined(USE_MEDIUM) && !defined(USE_VOL_MIS)
    if (!g_get_env_radiance.is_surface_scatter) {
      mis_weight = 1.0;
    }
#endif

    g_get_env_radiance.radiance = mis_weight * textureLod(g_env_map, uv, 0).rgb * g_main_ubo_inst.env_intensity;
  } else {
    const float a = max(g_get_env_radiance.direction.z, 0.0);
    g_get_env_radiance.radiance = mix(g_main_ubo_inst.ground_color.rgb, g_main_ubo_inst.sky_color.rgb, a) * g_main_ubo_inst.env_intensity;
  }
}