// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
mat3 ACES_INPUT_MATRIX = mat3(
  vec3(0.59719, 0.35458, 0.04823),
  vec3(0.07600, 0.90834, 0.01566),
  vec3(0.02840, 0.13383, 0.83777)
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
mat3 ACES_OUTPUT_MATRIX = mat3(
  vec3(1.60475, -0.53108, -0.07367),
  vec3(-0.10208, 1.10813, -0.00605),
  vec3(-0.00327, -0.07276, 1.07602)
);

vec3 rrt_odt_fit(vec3 v) {
  vec3 a = v * (v + 0.0245786f) - 0.000090537f;
  vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
  return a / b;
}

vec3 aces_fitted(vec3 color) {
  color = color * ACES_INPUT_MATRIX;

  // Apply RRT and ODT
  color = rrt_odt_fit(color);

  color = color * ACES_OUTPUT_MATRIX;

  // Clamp to [0, 1]
  color = clamp(color, 0.0, 1.0);

  return color;
}

vec3 aces(in vec3 c) {
  float a = 2.51f;
  float b = 0.03f;
  float y = 2.43f;
  float d = 0.59f;
  float e = 0.14f;

  return clamp((c * (a * c + b)) / (c * (y * c + d) + e), 0.0, 1.0);
}

vec3 tonemap(in vec3 c, float limit) {
  return c * 1.0 / (1.0 + luminance(c) / limit);
}