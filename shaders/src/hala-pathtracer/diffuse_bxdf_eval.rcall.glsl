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

layout(location = 2) callableDataInEXT EvalBxDF g_eval_bxdf;

void main() {
  if (g_eval_bxdf.mat.roughness > EPS) {
    g_eval_bxdf.f = oren_nayar_eval(g_eval_bxdf.state, g_eval_bxdf.mat, g_eval_bxdf.V, g_eval_bxdf.N, g_eval_bxdf.L, g_eval_bxdf.pdf);
  } else {
    g_eval_bxdf.f = lambert_eval(g_eval_bxdf.state, g_eval_bxdf.mat, g_eval_bxdf.V, g_eval_bxdf.N, g_eval_bxdf.L, g_eval_bxdf.pdf);
  }
}