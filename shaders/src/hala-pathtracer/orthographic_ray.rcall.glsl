#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"

layout(location = 0) callableDataInEXT GenCameraRay g_gen_cam_ray;

void main() {
  // Get the camera from the buffer.
  const Camera camera = g_cameras_buf_inst.cameras[g_gen_cam_ray.camera_index];
  const float xmag = camera.focal_distance_or_xmag;
  const float ymag = camera.aperture_or_ymag;

  vec4 r = rand4blue(g_gen_cam_ray.rng, g_blue_noise);

  // Generate two random numbers, each in the range [0.0, 2.0).
  float r1 = 2.0 * r.x;
  float r2 = 2.0 * r.y;

  // Map the random numbers to the range [-1.0, 1.0).
  // The square root is used to make a non-linear distribution,
  // which is more likely to sample points near the center of the pixel.
  vec2 jitter;
  jitter.x = r1 < 1.0 ? sqrt(r1) - 1.0 : 1.0 - sqrt(2.0 - r1);
  jitter.y = r2 < 1.0 ? sqrt(r2) - 1.0 : 1.0 - sqrt(2.0 - r2);

  // Because the jitter is in the range [-1.0, 1.0), we need to scale it to the pixel size.
  // jiter range: [-1.0, 1.0), length is 2.0, so we divide by half of the resolution.
  jitter /= (g_main_ubo_inst.resolution * 0.5);

  // Calculate screen space UV [(0, 0), (1, 1)].
  vec2 screen_uv = vec2(gl_LaunchIDEXT.x, g_main_ubo_inst.resolution.y - gl_LaunchIDEXT.y) / g_main_ubo_inst.resolution;
  // Mapping the screen UV to the range [-1.0, 1.0] and add the jitter.
  vec2 d = (2.0 * screen_uv - 1.0) + jitter;

  // Calculate the ray direction and origin.
  vec3 ray_dir = normalize(camera.forward);
  vec3 ray_origin = camera.position + camera.right * (d.x * xmag) + camera.up * (d.y * ymag);

  g_gen_cam_ray.ray.direction = ray_dir;
  g_gen_cam_ray.ray.origin = ray_origin;
}