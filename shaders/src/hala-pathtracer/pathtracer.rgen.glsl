#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "common/tonemap.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/rayload.glsl"

layout(location = 0) callableDataEXT GenCameraRay g_gen_cam_ray;
layout(location = 1) callableDataEXT EvalEnv g_eval_env;
layout(location = 2) callableDataEXT SampleEnv g_sample_env;
layout(location = 3) callableDataEXT EvalBxDF g_eval_bxdf;
layout(location = 4) callableDataEXT SampleBxDF g_sample_bxdf;
layout(location = 5) callableDataEXT SampleLight g_sample_light;

#include "hala-pathtracer/inc/lighting.glsl"

void main() {
  RNGState rng = rng_initialize(gl_LaunchIDEXT.xy, g_main_ubo_inst.frame_index);

  // Call the camera ray generation shader.
  g_gen_cam_ray.rng = rng;
  g_gen_cam_ray.camera_index = g_main_ubo_inst.camera_index;
  executeCallableEXT(CALLABLE_GEN_PERSPECTIVE_CAMERA_RAY, 0); // Call perspective camera ray generation shader.
  g_gen_cam_ray.ray;

  g_ray_payload.rng = g_gen_cam_ray.rng;
  g_ray_payload.ray = g_gen_cam_ray.ray;
  g_ray_payload.state.flags = 0;
  g_ray_payload.state.pdf = 1.0;
  g_ray_payload.state.eta = 1.0;
  g_ray_payload.state.material_index = INVALID_INDEX;
  g_ray_payload.state.medium.type = MEDIUM_NONE;
  g_ray_payload.state.medium.density = 0.0;
  g_ray_payload.state.medium.anisotropy = 1.0;

  // Trace the ray.
  vec3 radiance = vec3(0.0);
  vec3 throughput = vec3(1.0);
#ifdef USE_MEDIUM
  bool is_in_medium = false;
  bool is_medium_sampled = false;
#if !defined(USE_VOL_MIS)
  bool is_surface_scatter = false;
#endif
#endif
  bool any_non_specular_bounce = false;
  vec3 albedo = vec3(0.0);
  vec3 normal = vec3(0.0, 0.0, 1.0);
  for (g_ray_payload.state.depth = 0;; g_ray_payload.state.depth++) {
    traceRayEXT(
      g_tlas,                       // acceleration structure
      gl_RayFlagsOpaqueEXT,         // ray flags
      0xff,                         // cull mask
      0,                            // sbt record offset
      0,                            // sbt record stride
      0,                            // miss index
      g_ray_payload.ray.origin,     // ray origin
      0.0,                          // ray tmin
      g_ray_payload.ray.direction,  // ray direction
      WORLD_SIZE,                   // ray tmax
      0                             // payload (location = 0)
    );

    // If the ray missed, sample the environment map.
    if ((g_ray_payload.state.flags & RAY_FLAGS_HIT) == 0) {
      g_eval_env.flags = g_ray_payload.state.flags;
      g_eval_env.depth = g_ray_payload.state.depth;
      g_eval_env.pdf = g_ray_payload.state.pdf;
      g_eval_env.direction = g_ray_payload.ray.direction;
#if defined(USE_MEDIUM) && !defined(USE_VOL_MIS)
      g_eval_env.is_surface_scatter = is_surface_scatter;
#endif
      executeCallableEXT(CALLABLE_ENV_BEGIN + g_main_ubo_inst.env_type * 2, 1); // Call environment radiance shader.
      radiance += throughput * g_eval_env.radiance;

      // Store albedo and normal.
      if (g_ray_payload.state.depth == 0) {
        albedo = radiance;
        normal = -g_ray_payload.ray.direction;
      }
      break;
    }

    if ((g_ray_payload.state.flags & RAY_FLAGS_IS_EMITTER) != 0) {
      // If the ray hit a light source, the material index is the light index.
      Light light = g_lights_buf_inst.lights[g_ray_payload.state.material_index];
      // If the ray hit a light source, the pdf is in the state.tex_coord.x.
      const float light_pdf = g_ray_payload.state.tex_coord.x;

      float mis_weight = 1.0;
      if (g_ray_payload.state.depth > 0) {
        mis_weight = power_heuristic(g_ray_payload.state.pdf, light_pdf);
      }

#if defined(USE_MEDIUM) && !defined(USE_VOL_MIS)
      if (!is_surface_scatter) {
        mis_weight = 1.0;
      }
#endif

      radiance += mis_weight * light.intensity * throughput;
      break;
    }

    // If the ray hit a error material_index.
    if (g_ray_payload.state.material_index == INVALID_INDEX) {
      radiance = vec3(0.7, 0.0, 0.7);
      break;
    }

    // Get the material of the hit object.
    Material mat = g_materials_buf_inst.materials[g_ray_payload.state.material_index];
    g_ray_payload.state.eta = dot(g_ray_payload.ray.direction, g_ray_payload.state.normal) < 0.0 ? (1.0 / mat.ior) : mat.ior;

    // Build all color values.
    if (mat.base_color_map_index != INVALID_INDEX) {
      mat.base_color = textureLod(g_textures[mat.base_color_map_index], g_ray_payload.state.tex_coord, 0).rgb;
    }
    if (mat.metallic_roughness_map_index != INVALID_INDEX) {
      vec4 mr = textureLod(g_textures[mat.metallic_roughness_map_index], g_ray_payload.state.tex_coord, 0);
      mat.metallic = mr.b;
      mat.roughness = mr.g;
    }
    if (mat.emission_map_index != INVALID_INDEX) {
      mat.emission = textureLod(g_textures[mat.emission_map_index], g_ray_payload.state.tex_coord, 0).rgb;
    }

    // Build normal map.
    if (mat.normal_map_index != INVALID_INDEX) {
      vec3 normal_ts = textureLod(g_textures[mat.normal_map_index], g_ray_payload.state.tex_coord, 0).rgb;
      normal_ts.z *= 5.0;
      normal_ts = normalize(normal_ts * 2.0 - 1.0);
      vec3 original_normal = g_ray_payload.state.normal;
      g_ray_payload.state.normal = normalize(
        g_ray_payload.state.tangent * normal_ts.x +
        g_ray_payload.state.bitangent * normal_ts.y +
        g_ray_payload.state.normal * normal_ts.z);
      g_ray_payload.state.ffnormal = dot(original_normal, g_ray_payload.ray.direction) <= 0.0 ? g_ray_payload.state.normal : -g_ray_payload.state.normal;
      g_ray_payload.state.bitangent = cross(g_ray_payload.state.normal, g_ray_payload.state.tangent);
    }

    // Store albedo and normal.
    if (g_ray_payload.state.depth == 0) {
      albedo = mat.base_color;
      normal = g_ray_payload.state.normal;
    }

    // Add emission to the radiance.
    radiance += throughput * mat.emission;

#ifdef USE_MEDIUM
    // Process volume absorption, scattering and emission.
    is_medium_sampled = false;
#if !defined(USE_VOL_MIS)
    is_surface_scatter = false;
#endif

    if (is_in_medium) {
      if (g_ray_payload.state.medium.type == MEDIUM_ABSORB) {
        throughput *= exp(-(1.0 - g_ray_payload.state.medium.color) * g_ray_payload.state.hit_distance * g_ray_payload.state.medium.density);
      } else if (g_ray_payload.state.medium.type == MEDIUM_EMISSIVE) {
        radiance += g_ray_payload.state.medium.color * g_ray_payload.state.hit_distance * g_ray_payload.state.medium.density * throughput;
      } else {
        // Sample a distance in the medium.
        const float scatter_dist = min(-log(rand(g_ray_payload.rng)) / g_ray_payload.state.medium.density, g_ray_payload.state.hit_distance);
        is_medium_sampled = scatter_dist < g_ray_payload.state.hit_distance;

        // Sample the medium by Henyey-Greenstein method.
        if (is_medium_sampled) {
          throughput *= g_ray_payload.state.medium.color;

          // Move ray origin to scattering position.
          g_ray_payload.ray.origin += g_ray_payload.ray.direction * scatter_dist;
          g_ray_payload.state.first_hit_position = g_ray_payload.ray.origin;

          // Transmittance Evaluation.
          radiance += direct_lighting(mat, false, any_non_specular_bounce) * throughput;

          // Pick a new direction based on the phase function.
          const vec3 scatter_dir = sample_hg(-g_ray_payload.ray.direction, g_ray_payload.state.medium.anisotropy, rand(g_ray_payload.rng), rand(g_ray_payload.rng));
          g_ray_payload.state.pdf = phase_hg(dot(-g_ray_payload.ray.direction, scatter_dir), g_ray_payload.state.medium.anisotropy);
          g_ray_payload.ray.direction = scatter_dir;
        }
      }
    }

    // If medium was not sampled then proceed with surface BSDF evaluation.
    if (!is_medium_sampled) {
#endif
#ifdef USE_TRANSPARENT
      // Use opacity to determine if the material is transparent.
      if (mat.opacity == 0.0 || rand(g_ray_payload.rng) > mat.opacity) {
        g_ray_payload.state.depth--;
      } else
#endif
      {
#if defined(USE_MEDIUM) && !defined(USE_VOL_MIS)
        is_surface_scatter = true;
#endif
        // Next event estimation.
        radiance += throughput * direct_lighting(mat, true, any_non_specular_bounce);

        // Sample BSDF for color and outgoing direction.
        g_sample_bxdf.rng = g_ray_payload.rng;
        g_sample_bxdf.state = g_ray_payload.state;
        g_sample_bxdf.mat = mat;
        g_sample_bxdf.any_non_specular_bounce = any_non_specular_bounce;
        g_sample_bxdf.V = -g_ray_payload.ray.direction;
        g_sample_bxdf.N = g_ray_payload.state.ffnormal;
        executeCallableEXT(CALLABLE_MATERIAL_BXDF_BEGIN + mat.type * 2 + 1, 4);
        g_ray_payload.rng = g_sample_bxdf.rng;
        g_ray_payload.ray.direction = g_sample_bxdf.L;
        g_ray_payload.state.pdf = g_sample_bxdf.pdf;
        g_ray_payload.state.flags |= g_sample_bxdf.flags;
        any_non_specular_bounce = g_sample_bxdf.any_non_specular_bounce;
        vec3 f = g_sample_bxdf.f;
        if (g_ray_payload.state.pdf > 0.0) {
          throughput *= f / g_ray_payload.state.pdf;
        } else {
          break;
        }
      }

      // Move ray origin to hit point and set direction for next bounce.
      g_ray_payload.ray.origin = g_ray_payload.state.first_hit_position + g_ray_payload.ray.direction * EPS;

#ifdef USE_MEDIUM
      // Ray is in medium only if it is entering a surface containing a medium.
      if (dot(g_ray_payload.ray.direction, g_ray_payload.state.normal) < 0 && mat.medium.type != MEDIUM_NONE) {
        is_in_medium = true;
        // Get medium params from the intersected object.
        g_ray_payload.state.medium = mat.medium;
      } else {
        is_in_medium = false;
        g_ray_payload.state.medium.type = MEDIUM_NONE;
      }
    }
#endif

    // Stop tracing ray if maximum depth was reached.
    if (g_ray_payload.state.depth >= g_main_ubo_inst.max_depth)
      break;

    // Russian roulette.
    if (g_ray_payload.state.depth >= g_main_ubo_inst.rr_depth && g_main_ubo_inst.rr_depth > 0) {
      float q = min(max(throughput.x, max(throughput.y, throughput.z)) + 0.001, 0.95);
      if (rand(g_ray_payload.rng) > q)
        break;
      throughput /= q;
    }
  }

  // Get the current accumulated color.
  vec3 accum_radiance = imageLoad(g_accum_image, ivec2(gl_LaunchIDEXT.xy)).rgb;
  // Calculate the new accumulated color.
  vec3 new_accum_radiance = g_main_ubo_inst.frame_index == 0 ? radiance : mix(accum_radiance, radiance, 1.0 / (g_main_ubo_inst.frame_index + 1.0));
  // Store the new accumulated color.
  imageStore(g_accum_image, ivec2(gl_LaunchIDEXT.xy), vec4(new_accum_radiance, 1.0));

  // Get the current accumulated albedo.
  vec3 accum_albedo = imageLoad(g_albedo_image, ivec2(gl_LaunchIDEXT.xy)).rgb;
  // Calculate the new accumulated albedo.
  vec3 new_accum_albedo = g_main_ubo_inst.frame_index == 0 ? albedo : mix(accum_albedo, albedo, 1.0 / (g_main_ubo_inst.frame_index + 1.0));
  // Store the new accumulated albedo.
  imageStore(g_albedo_image, ivec2(gl_LaunchIDEXT.xy), vec4(new_accum_albedo, 1.0));

  // Get the current accumulated normal.
  vec3 accum_normal = imageLoad(g_normal_image, ivec2(gl_LaunchIDEXT.xy)).rgb;
  // Calculate the new accumulated normal.
  vec3 new_accum_normal = g_main_ubo_inst.frame_index == 0 ? normal : mix(accum_normal, normal, 1.0 / (g_main_ubo_inst.frame_index + 1.0));
  // Store the new accumulated normal.
  imageStore(g_normal_image, ivec2(gl_LaunchIDEXT.xy), vec4(new_accum_normal, 1.0));

  // Apply tonemapping.
  vec3 final_color;
  if (g_main_ubo_inst.enable_tonemap) {
    if (g_main_ubo_inst.enable_aces) {
      if (g_main_ubo_inst.use_simple_aces) {
        final_color = aces(new_accum_radiance);
      } else {
        final_color = aces_fitted(new_accum_radiance);
      }
    } else {
      final_color = tonemap(new_accum_radiance, 1.5);
    }
  } else {
    final_color = new_accum_radiance;
  }

  // Calculate the final color.
  final_color = linear_2_srgb(final_color);

  // Store the final image.
  imageStore(g_final_image, ivec2(gl_LaunchIDEXT.xy), vec4(final_color, 1.0));
}
