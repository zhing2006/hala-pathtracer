#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/env_map.glsl"

layout(location = 2) callableDataInEXT SampleEnv g_sample_env;

void main() {
  g_sample_env.direction = sample_env_map(
    g_sample_env.rng,
    g_sample_env.emission,
    g_sample_env.pdf);
}