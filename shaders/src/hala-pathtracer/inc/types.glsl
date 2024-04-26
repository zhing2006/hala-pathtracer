/// The camera struct.
struct Camera {
  vec3 position;  // camera position
  vec3 right;     // camera right vector
  vec3 up;        // camera up vector
  vec3 forward;   // camera forward vector
  float yfov;     // vertical field of view
  float focal_distance_or_xmag; // focal distance for perspective camera and xmag for orthographic camera
  float aperture_or_ymag; // aperture size for perspective camera and ymag for orthographic camera
  uint type;      // 0 - perspective camera, 1 - orthographic camera
};

/// The light struct.
struct Light {
  vec3 intensity;
  // For point light, position is the position.
  // For directional light, position is unused.
  // For spot light, quad light and sphere light, position is the position.
  vec3 position;
  // For point light, u is unused.
  // For directional light and spot light, u is the direction.
  // For quad light, u is the right direction and length.
  // For sphere light, u is unused.
  vec3 u;
  // For point light, v is unused.
  // For directional light, v.x is the cosine of the cone angle.
  // For spot light, v.x is the cosine of the inner cone angle, v.y is the cosine of the outer cone angle.
  // For quad light, v is the up direction and length.
  // For sphere light, v is unused.
  vec3 v;
  // For point light, directional light, spot light and quad light, radius is unused.
  // For sphere light, radius is the radius.
  float radius;
  // For point light, directional light and spot light, area is unused.
  // For quad light and sphere light, area is the area.
  float area;
  // light type: 0 - point, 1 - directional, 2 - spot, 3 - quad, 4 - sphere
  int type;
};

/// The medium struct.
struct Medium {
  vec3 color;
  float density;
  float anisotropy;
  uint type;
  float _padding0;
  float _padding1;
};

/// The material struct.
struct Material {
  Medium medium;

  vec3 base_color;
  float opacity;

  vec3 emission;
  float anisotropic;

  float metallic;
  float roughness;
  float subsurface;
  float specular_tint;

  float sheen;
  float sheen_tint;
  float clearcoat;
  float clearcoat_roughness;

  vec3 clearcoat_tint;
  float specular_transmission;

  float ior;
  float ax;
  float ay;
  uint base_color_map_index;

  uint normal_map_index;
  uint metallic_roughness_map_index;
  uint emission_map_index;
  uint type;
};

/// The vertex struct.
struct Vertex {
  vec3 position;
  vec3 normal;
  vec3 tangent;
  vec2 tex_coord;
};

layout(std430, buffer_reference, buffer_reference_align = 16) readonly buffer Vertices {
  Vertex data[];
};

layout(std430, buffer_reference, buffer_reference_align = 4) readonly buffer Indices {
  uint data[];
};

/// The primitive struct.
struct Primitive {
  mat4 transform;
  uint material_index;
  Vertices vertices;
  Indices indices;
};

/// The argument struct for generating a camera ray callable program.
struct GenCameraRay {
  // input & output
  RNGState rng;

  // input
  uint camera_index;

  // output
  Ray ray;
};

/// The path tracing state struct.
struct State {
  vec3 first_hit_position;
  vec3 ffnormal;
  vec3 normal;
  vec3 tangent;
  vec3 bitangent;
  vec2 tex_coord;
  float hit_distance;
  float pdf;
  float eta;

  uint flags;
  uint depth;

  uint material_index;
  Medium medium;
};

/// The argument struct for environment evaluation callable program.
struct EvalEnv {
  // input
  uint flags;
  uint depth;
  float pdf;
  vec3 direction;
#if defined(USE_MEDIUM) && !defined(USE_VOL_MIS)
  bool is_surface_scatter;
#endif

  // output
  vec3 radiance;
};

/// The argument struct for sampling the environment callable program.
struct SampleEnv {
  // input & output
  RNGState rng;

  // input
  State state;

  // output
  vec3 emission;
  vec3 direction;
  float pdf;
};

/// The argument struct for BxDF evaluation callable program.
struct EvalBxDF {
  // input
  bool any_non_specular_bounce;
  State state;
  Material mat;
  vec3 V;
  vec3 N;
  vec3 L;

  // output
  vec3 f;
  float pdf;
};

/// The argument struct for sampling a BxDF callable program.
struct SampleBxDF {
  // input & output
  RNGState rng;
  bool any_non_specular_bounce;

  // input
  State state;
  Material mat;
  vec3 V;
  vec3 N;

  // output
  vec3 f;
  vec3 L;
  float pdf;
  uint flags;
};

/// The argument struct for sampling a light source callable program.
struct SampleLight {
  // input & output
  RNGState rng;

  // input
  State state;
  Light light;

  // output
  vec3 normal;
  vec3 emission;
  vec3 direction;
  float dist;
  float pdf;
};

/// The ray payload struct for normal path tracing.
struct RayPayload {
  RNGState rng;
  State state;
  Ray ray;
};

/// The ray payload struct for shadow ray tracing.
struct ShadowRayPayload {
  bool is_hit;
};

/// The light hit attribute struct.
struct LightHitAttribute {
  vec3 normal;
  float pdf;
};