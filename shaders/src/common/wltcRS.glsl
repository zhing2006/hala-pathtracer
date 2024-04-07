// RNG fomr code by Moroz Mykhailo: https://www.shadertoy.com/view/wltcRS

// RNG state
struct RNGState {
  uvec4 s0, s1;
  ivec2 pixel;
};

RNGState rng_initialize(vec2 p, uint frame) {
  ivec2 pixel = ivec2(p);

  //white noise seed
  uvec4 s0 = uvec4(p, frame, uint(p.x) + uint(p.y));

  //blue noise seed
  uvec4 s1 = uvec4(frame, frame * 15843, frame * 31 + 4566, frame * 2345 + 58585);

  return RNGState(s0, s1, pixel);
}

// https://www.pcg-random.org/
void pcg4d(inout uvec4 v) {
  v = v * 1664525u + 1013904223u;
  v.x += v.y*v.w; v.y += v.z*v.x; v.z += v.x*v.y; v.w += v.y*v.z;
  v = v ^ (v >> 16u);
  v.x += v.y*v.w; v.y += v.z*v.x; v.z += v.x*v.y; v.w += v.y*v.z;
}

float rand(inout RNGState state) {
  pcg4d(state.s0); return float(state.s0.x) / float(0xffffffffu);
}

vec2 rand2(inout RNGState state) {
  pcg4d(state.s0); return vec2(state.s0.xy) / float(0xffffffffu);
}

vec3 rand3(inout RNGState state) {
  pcg4d(state.s0); return vec3(state.s0.xyz) / float(0xffffffffu);
}

vec4 rand4(inout RNGState state) {
  pcg4d(state.s0); return vec4(state.s0) / float(0xffffffffu);
}

//random blue noise sampling pos
ivec2 shift2(inout RNGState state) {
  pcg4d(state.s1);
  return (state.pixel + ivec2(state.s1.xy % 0x0fffffffu)) % 1024;
}

vec4 rand4blue(inout RNGState state, texture2D blue_noise) {
  return texelFetch(blue_noise, shift2(state), 0);
}
