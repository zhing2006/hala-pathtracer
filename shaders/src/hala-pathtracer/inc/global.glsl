layout(set = 0, binding = 0) uniform accelerationStructureEXT g_tlas;
layout(set = 0, binding = 1, rgba8) uniform image2D g_final_image;
layout(set = 0, binding = 2, rgba32f) uniform image2D g_accum_image;
layout(set = 0, binding = 3, rgba32f) uniform image2D g_albedo_image;
layout(set = 0, binding = 4, rgba32f) uniform image2D g_normal_image;
layout(set = 0, binding = 5) uniform texture2D g_blue_noise;
layout(set = 0, binding = 6) uniform sampler2D g_env_map;
layout(set = 0, binding = 7) uniform texture2D g_env_map_dist[2]; // 0: marginal distribution, 1: conditional distribution
layout(set = 0, binding = 8) uniform sampler g_env_map_dist_sampler;

layout(set = 1, binding = 0, std140) uniform MainUBO {
  vec4 ground_color;
  vec4 sky_color;
  vec2 resolution;
  uint max_depth;
  uint rr_depth;
  uint frame_index;
  uint camera_index;
  uint env_type;
  uint env_map_width;
  uint env_map_height;
  float env_total_sum;
  float env_rotation;
  float env_intensity;
  float exposure_value;
  bool enable_tonemap;
  bool enable_aces;
  bool use_simple_aces;
  uint num_of_lights;
} g_main_ubo_inst;

layout(set = 1, binding = 1) uniform CamerasBuffer {
  Camera cameras[MAX_CAMERAS];
} g_cameras_buf_inst;

layout(set = 1, binding = 2) uniform LightsBuffer {
  Light lights[MAX_LIGHTS];
} g_lights_buf_inst;

layout(set = 1, binding = 3) buffer MaterialsBuffer {
  Material materials[];
} g_materials_buf_inst;

layout(set = 1, binding = 4) buffer PrimitivesBuffer {
  Primitive primitives[];
} g_primitives_buf_inst;

layout(set = 2, binding = 0) uniform sampler2D g_textures[];
