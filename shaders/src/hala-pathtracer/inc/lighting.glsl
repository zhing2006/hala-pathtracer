#include "env_map.glsl"

#if defined(USE_MEDIUM) && defined(USE_VOL_MIS)
/// Evaluate the transmittance along the ray.
/// \param[in] ray The ray.
/// \return The transmittance.
vec3 eval_transmittance(in Ray ray) {
  g_trans_ray_payload.ray = ray;
  g_trans_ray_payload.state.flags = 0;
  g_trans_ray_payload.state.pdf = 1.0;
  g_trans_ray_payload.state.eta = 1.0;
  g_trans_ray_payload.state.material_index = INVALID_INDEX;
  g_trans_ray_payload.state.medium.type = MEDIUM_NONE;
  g_trans_ray_payload.state.medium.density = 0.0;
  g_trans_ray_payload.state.medium.anisotropy = 1.0;

  vec3 transmittance = vec3(1.0);

  for (int depth = 0; depth < g_main_ubo_inst.max_depth; depth++) {
    traceRayEXT(
      g_tlas,                             // acceleration structure
      gl_RayFlagsOpaqueEXT,               // ray flags
      0xff,                               // cull mask
      0,                                  // sbt record offset
      0,                                  // sbt record stride
      0,                                  // miss index
      g_trans_ray_payload.ray.origin,     // ray origin
      0.0,                                // ray tmin
      g_trans_ray_payload.ray.direction,  // ray direction
      WORLD_SIZE,                         // ray tmax
      2                                   // payload (location = 2)
    );

    // If no hit (environment map) or if ray hit a light source then return transmittance.
    if ((g_trans_ray_payload.state.flags & RAY_FLAGS_HIT) == 0 || (g_trans_ray_payload.state.flags & RAY_FLAGS_IS_EMITTER) != 0)
      break;

    // Get hit material.
    Material mat = g_materials_buf_inst.materials[g_trans_ray_payload.state.material_index];

#ifdef USE_TRANSPARENT
    bool is_transparent = mat.opacity == 0.0 || rand(g_ray_payload.rng) > mat.opacity;
#else
    bool is_transparent = false;
#endif
    bool is_refractive = (1.0 - mat.metallic) * mat.specular_transmission > 0.0;
    if (!(is_transparent || is_refractive))
      return vec3(0.0);

    // Evaluate transmittance.
    if (dot(g_trans_ray_payload.ray.direction, g_trans_ray_payload.state.normal) > 0 && mat.medium.type != MEDIUM_NONE) {
      vec3 color = mat.medium.type == MEDIUM_ABSORB ? vec3(1.0) - mat.medium.color : vec3(1.0);
      transmittance *= exp(-color * mat.medium.density * g_trans_ray_payload.state.hit_distance);
    }

    // Move ray origin to hit point.
    g_trans_ray_payload.ray.origin = g_trans_ray_payload.state.first_hit_position + g_trans_ray_payload.ray.direction * EPS;
  }

  return transmittance;
}
#endif

/// Compute direct lighting.
/// \param[in] mat The material.
/// \param[in] is_surface True if the ray hit a surface, false otherwise.
/// \param[in] any_non_specular_bounce True if there was any non-specular bounce, false otherwise.
/// \return The direct lighting radiance.
vec3 direct_lighting(in Material mat, bool is_surface, bool any_non_specular_bounce) {
  vec3 Ld = vec3(0.0);
  vec3 Li = vec3(0.0);
  const vec3 scatter_pos = g_ray_payload.state.first_hit_position + g_ray_payload.state.ffnormal * EPS;

  // Sample environment map.
  if (g_main_ubo_inst.env_type != ENV_TYPE_SKY) {
    g_sample_env.rng = g_ray_payload.rng;
    g_sample_env.state = g_ray_payload.state;
    executeCallableEXT(CALLABLE_ENV_BEGIN + g_main_ubo_inst.env_type * 2 + 1, 2);
    g_ray_payload.rng = g_sample_env.rng;

    Li = g_sample_env.emission;
    const float light_pdf = g_sample_env.pdf;
    const vec3 light_dir = g_sample_env.direction;
    const Ray shadow_ray = Ray(scatter_pos, light_dir);

    if (light_pdf > 0.0) {
#if defined(USE_MEDIUM) && defined(USE_VOL_MIS)
      // If there are volumes in the scene then evaluate transmittance rather than a binary anyhit test.
      const vec3 transmittance =  eval_transmittance(shadow_ray);
      if (luminance(transmittance) > 0.0) {
        Li *= transmittance;

        float pdf = 0.0;
        vec3 f = vec3(0.0);
        if (is_surface) {
          g_eval_bxdf.state = g_ray_payload.state;
          g_eval_bxdf.mat = mat;
          g_eval_bxdf.any_non_specular_bounce = any_non_specular_bounce;
          g_eval_bxdf.V = -g_ray_payload.ray.direction;
          g_eval_bxdf.N = g_ray_payload.state.ffnormal;
          g_eval_bxdf.L = light_dir;
          executeCallableEXT(CALLABLE_MATERIAL_BXDF_BEGIN + mat.type * 2, 3);
          pdf = g_eval_bxdf.pdf;
          f = g_eval_bxdf.f;
        } else {
          pdf = phase_hg(dot(-g_ray_payload.ray.direction, light_dir), g_ray_payload.state.medium.anisotropy);
          f = vec3(pdf);
        }

        if (pdf > 0.0) {
          const float mis_weight = power_heuristic(light_pdf, pdf);
          if (mis_weight > 0.0)
            Ld += mis_weight * Li * f / light_pdf;
        }
      }
#else
      // Create shadow ray.
      g_shadow_ray_payload.is_hit = true;
      traceRayEXT(
        g_tlas,
        gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT,
        0xff,
        0,
        0,
        1,
        shadow_ray.origin,
        0.0,
        shadow_ray.direction,
        WORLD_SIZE,
        1);

      // Evaluate the BRDF and shadow.
      if (!g_shadow_ray_payload.is_hit) {
        g_eval_bxdf.state = g_ray_payload.state;
        g_eval_bxdf.mat = mat;
        g_eval_bxdf.any_non_specular_bounce = any_non_specular_bounce;
        g_eval_bxdf.V = -g_ray_payload.ray.direction;
        g_eval_bxdf.N = g_ray_payload.state.ffnormal;
        g_eval_bxdf.L = light_dir;
        executeCallableEXT(CALLABLE_MATERIAL_BXDF_BEGIN + mat.type * 2, 3);
        const float pdf = g_eval_bxdf.pdf;
        const vec3 f = g_eval_bxdf.f;

        if (pdf > 0.0) {
          const float mis_weight = power_heuristic(light_pdf, pdf);
          if (mis_weight > 0.0)
            Ld += mis_weight * Li * f / light_pdf;
        }
      }
#endif
    }
  }

  // Sample analytic lights.
  if (g_main_ubo_inst.num_of_lights > 0) {
    const int light_index = int(rand(g_ray_payload.rng) * float(g_main_ubo_inst.num_of_lights));
    const Light light = g_lights_buf_inst.lights[light_index];

    // Sample light.
    g_sample_light.rng = g_ray_payload.rng;
    g_sample_light.state = g_ray_payload.state;
    g_sample_light.light = light;
    executeCallableEXT(CALLABLE_LIGHT_BEGIN + light.type, 5);
    g_ray_payload.rng = g_sample_light.rng;
    const vec3 light_dir = g_sample_light.direction;
    const Ray shadow_ray = Ray(scatter_pos, light_dir);
    const float light_pdf = g_sample_light.pdf;
    Li = g_sample_light.emission;

    if (light_pdf > 0.0 && dot(light_dir, g_sample_light.normal) < 0.0) {
#if defined(USE_MEDIUM) && defined(USE_VOL_MIS)
      const vec3 transmittance =  eval_transmittance(shadow_ray);
      if (luminance(transmittance) > 0.0) {
        Li *= transmittance;

        float pdf = 0.0;
        vec3 f = vec3(0.0);
        if (is_surface) {
          g_eval_bxdf.state = g_ray_payload.state;
          g_eval_bxdf.mat = mat;
          g_eval_bxdf.any_non_specular_bounce = any_non_specular_bounce;
          g_eval_bxdf.V = -g_ray_payload.ray.direction;
          g_eval_bxdf.N = g_ray_payload.state.ffnormal;
          g_eval_bxdf.L = light_dir;
          executeCallableEXT(CALLABLE_MATERIAL_BXDF_BEGIN + mat.type * 2, 3);
          pdf = g_eval_bxdf.pdf;
          f = g_eval_bxdf.f;
        } else {
          pdf = phase_hg(dot(-g_ray_payload.ray.direction, light_dir), g_ray_payload.state.medium.anisotropy);
          f = vec3(pdf);
        }

        if (pdf > 0.0) {
          float mis_weight = 1.0;
          if (light.area > 0.0) // No MIS for distant light.
            mis_weight = power_heuristic(light_pdf, pdf);

          if (mis_weight > 0.0)
            Ld += mis_weight * Li * f / light_pdf;
        }
      }
#else
      // Create shadow ray.
      g_shadow_ray_payload.is_hit = true;
      traceRayEXT(
        g_tlas,
        gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsOpaqueEXT | gl_RayFlagsSkipClosestHitShaderEXT,
        0xff,
        0,
        0,
        1,
        shadow_ray.origin,
        0.0,
        shadow_ray.direction,
        g_sample_light.dist - 2.0 * EPS,
        1);

      // Evaluate the BRDF and shadow.
      if (!g_shadow_ray_payload.is_hit) {
        g_eval_bxdf.state = g_ray_payload.state;
        g_eval_bxdf.mat = mat;
        g_eval_bxdf.any_non_specular_bounce = any_non_specular_bounce;
        g_eval_bxdf.V = -g_ray_payload.ray.direction;
        g_eval_bxdf.N = g_ray_payload.state.ffnormal;
        g_eval_bxdf.L = light_dir;
        executeCallableEXT(CALLABLE_MATERIAL_BXDF_BEGIN + mat.type * 2, 3);
        const float pdf = g_eval_bxdf.pdf;
        const vec3 f = g_eval_bxdf.f;

        if (pdf > 0.0) {
          float mis_weight = 1.0;
          if (light.area > 0.0) // No MIS for delta light.
            mis_weight = power_heuristic(light_pdf, pdf);

          if (mis_weight > 0.0)
            Ld += mis_weight * Li * f / light_pdf;
        }
      }
#endif
    }
  }

  return Ld;
}