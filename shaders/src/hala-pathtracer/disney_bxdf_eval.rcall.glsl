#version 460
precision highp float;

#include "common/common.glsl"
#include "common/wltcRS.glsl"
#include "common/sampling.glsl"
#include "hala-pathtracer/inc/constants.glsl"
#include "hala-pathtracer/inc/types.glsl"
#include "hala-pathtracer/inc/global.glsl"
#include "hala-pathtracer/inc/bxdf/disney.glsl"

layout(location = 2) callableDataInEXT EvalBxDF g_eval_bxdf;

void main() {
  g_eval_bxdf.f = disney_eval(
    g_eval_bxdf.any_non_specular_bounce,
    g_eval_bxdf.state,
    g_eval_bxdf.mat,
    g_eval_bxdf.V,
    g_eval_bxdf.N,
    g_eval_bxdf.L,
    g_eval_bxdf.pdf);
}