#extension GL_EXT_ray_tracing : enable
#extension GL_EXT_samplerless_texture_functions : enable
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_buffer_reference : require

#define PI          3.14159265358979323846264338327950288
#define FRAC_PI_2   (PI * 0.5)
#define FRAC_PI_4   (PI * 0.25)
#define INV_PI      (1.0 / PI)
#define TWO_PI      (2.0 * PI)
#define INV_TWO_PI  (1.0 / TWO_PI)
#define FOUR_PI     (4.0 * PI)
#define INV_FOUR_PI (1.0 / FOUR_PI)
#define EPS         0.0003
#define INF         1000000.0

/// The ray struct.
struct Ray {
  vec3 origin;
  vec3 direction;
};

/// Converts a linear value to sRGB color space.
/// param[in] x The linear value.
/// return The sRGB value.
float linear_2_srgb(float x) {
  if (x <= 0.0031308) {
    return 12.92 * x;
  } else {
    return 1.055 * pow(x, 1.0 / 2.4) - 0.055;
  }
}

/// Converts a linear color to sRGB color space.
/// param[in] x The linear color.
/// return The sRGB color.
vec3 linear_2_srgb(vec3 x) {
  return vec3(linear_2_srgb(x.r), linear_2_srgb(x.g), linear_2_srgb(x.b));
}

/// Converts an sRGB value to linear color space.
/// param[in] x The sRGB value.
/// return The linear value.
float srgb_2_linear(float x) {
  if (x <= 0.04045) {
    return x / 12.92;
  } else {
    return pow((x + 0.055) / 1.055, 2.4);
  }
}

/// Converts an sRGB color to linear color space.
/// param[in] x The sRGB color.
/// return The linear color.
vec3 srgb_2_linear(vec3 x) {
  return vec3(srgb_2_linear(x.r), srgb_2_linear(x.g), srgb_2_linear(x.b));
}

/// TV BT.601 for SDR.
/// param[in] c The color.
/// return The luminance.
// float luminance(vec3 c) {
//   return sqrt(0.299 * c.r * c.r + 0.587 * c.g * c.g + 0.114 * c.b * c.b);
// }

/// TV BT.709 for HDR.
/// param[in] c The color.
/// return The luminance.
float luminance(vec3 c) {
  return 0.212671 * c.r + 0.715160 * c.g + 0.072169 * c.b;
}

/// Transforms a direction from local space to world space.
/// param[in] X The local x-axis.
/// param[in] Y The local y-axis.
/// param[in] Z The local z-axis.
/// param[in] v The direction in local space.
/// return The direction in world space.
vec3 to_world(vec3 X, vec3 Y, vec3 Z, vec3 v) {
  return v.x * X + v.y * Y + v.z * Z;
}

/// Transforms a direction from world space to local space.
/// param[in] X The local x-axis.
/// param[in] Y The local y-axis.
/// param[in] Z The local z-axis.
/// param[in] v The direction in world space.
/// return The direction in local space.
vec3 to_local(vec3 X, vec3 Y, vec3 Z, vec3 v) {
  return vec3(dot(v, X), dot(v, Y), dot(v, Z));
}

/// Compute the cosine of the theta angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The cosine of the theta angle.
float cos_theta(vec3 w) { return w.z; }

/// Compute the cosine squared of the theta angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The cosine squared of the theta angle.
float cos2_theta(vec3 w) { return w.z * w.z; }

/// Compute the absolute value of the cosine of the theta angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The absolute value of the cosine of the theta angle.
float abs_cos_theta(vec3 w) { return abs(w.z); }

/// Compute the sine squared of the theta angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The sine squared of the theta angle.
float sin2_theta(vec3 w) { return max(0.f, 1.f - cos2_theta(w)); }

/// Compute the sine of the theta angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The sine of the theta angle.
float sin_theta(vec3 w) { return sqrt(sin2_theta(w)); }

/// Compute the tangent of the theta angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The tangent of the theta angle.
float tan_theta(vec3 w) { return sin_theta(w) / cos_theta(w); }

/// Compute the tangent squared of the theta angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The tangent squared of the theta angle.
float tan2_theta(vec3 w) { return sin2_theta(w) / cos2_theta(w); }

/// Compute the cosine of the phi angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The cosine of the phi angle.
float cos_phi(vec3 w) {
  const float sin_theta_ = sin_theta(w);
  return (sin_theta_ == 0.f) ? 1.f : clamp(w.x / sin_theta_, -1.f, 1.f);
}

/// Compute the sine of the phi angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The sine of the phi angle.
float sin_phi(vec3 w) {
  const float sin_theta_ = sin_theta(w);
  return (sin_theta_ == 0.f) ? 0.f : clamp(w.y / sin_theta_, -1.f, 1.f);
}

/// Compute the cosine squared of the phi angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The cosine squared of the phi angle.
float cos2_phi(vec3 w) {
  return cos_phi(w) * cos_phi(w);
}

/// Compute the sine squared of the phi angle in tangent space.
/// param[in] w The direction in tangent space.
/// return The sine squared of the phi angle.
float sin2_phi(vec3 w) {
  return sin_phi(w) * sin_phi(w);
}

/// Compute the cosine of the delta angle between two directions in tangent space.
/// param[in] wa The first direction in tangent space.
/// param[in] wb The second direction in tangent space.
/// return The cosine of the delta angle.
float cos_delta_phi(vec3 wa, vec3 wb) {
  return clamp(
    (wa.x * wb.x + wa.y * wb.y) / sqrt((wa.x * wa.x + wa.y * wa.y) * (wb.x * wb.x + wb.y * wb.y)),
    -1, 1);
}

/// Whether the direction is entering the surface.
/// param[in] v The direction in tangent space.
/// return Whether the direction is entering the surface.
bool is_entering(vec3 v) {
  return cos_theta(v) > 0;
}

/// Whether the two directions are on the same side.
/// param[in] wa The first direction in tangent space.
/// param[in] wb The second direction in tangent space.
/// return Whether the two directions are on the same side.
bool is_same_side(vec3 wa, vec3 wb) {
  return cos_theta(wa) * cos_theta(wb) > 0.f;
}