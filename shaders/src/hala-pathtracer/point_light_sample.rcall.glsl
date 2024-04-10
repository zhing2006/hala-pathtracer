#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/light/point.glsl"

layout(location = 5) callableDataInEXT SampleLight g_sample_light;

void main() {
  g_sample_light.direction = point_sample(
    g_sample_light.rng,
    g_sample_light.state,
    g_sample_light.light,
    g_sample_light.normal,
    g_sample_light.emission,
    g_sample_light.dist,
    g_sample_light.pdf);
}