#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/bxdf/lambert.glsl"
#include "hala-pathtracer/inc/bxdf/oren_nayar.glsl"

layout(location = 3) callableDataInEXT SampleBxDF g_sample_bxdf;

void main() {
  if (g_sample_bxdf.mat.roughness > EPS) {
    g_sample_bxdf.f = oren_nayar_sample(
      g_sample_bxdf.rng,
      g_sample_bxdf.any_non_specular_bounce,
      g_sample_bxdf.state,
      g_sample_bxdf.mat,
      g_sample_bxdf.V,
      g_sample_bxdf.N,
      g_sample_bxdf.L,
      g_sample_bxdf.pdf,
      g_sample_bxdf.flags);
  } else {
    g_sample_bxdf.f = lambert_sample(
      g_sample_bxdf.rng,
      g_sample_bxdf.any_non_specular_bounce,
      g_sample_bxdf.state,
      g_sample_bxdf.mat,
      g_sample_bxdf.V,
      g_sample_bxdf.N,
      g_sample_bxdf.L,
      g_sample_bxdf.pdf,
      g_sample_bxdf.flags);
  }
}