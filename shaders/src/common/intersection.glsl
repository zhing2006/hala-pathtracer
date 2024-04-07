/// Check if a ray intersects a sphere.
/// \param[in] rad The radius of the sphere.
/// \param[in] pos The position of the sphere.
/// \param[in] r The ray.
/// \return The distance to the intersection point, or INF if no intersection.
float sphere_intersect(in float rad, in vec3 pos, in Ray r) {
  // Compute the vector from the ray's origin to the sphere's center.
  const vec3 op = pos - r.origin;
  // Calculate the dot product of the direction of the ray and the vector 'op'
  // This represents the length of the projection of 'op' onto the ray's direction.
  const float b = dot(op, r.direction);
  // Compute the discriminant (det) to determine the nature of the intersection.
  float det = b * b - dot(op, op) + rad * rad;
  // If the discriminant is negative, there are no real roots and thus no intersection.
  if (det < 0.0)
    return INF;

  // Calculate the square root of the discriminant for further calculations.
  det = sqrt(det);
  // Calculate the first potential intersection time 't1'.
  const float t1 = b - det;
  // If 't1' is greater than a small positive number (EPS), the intersection is in front of the ray.
  if (t1 > EPS)
    return t1;

  // Otherwise, calculate the second potential intersection time 't2'.
  const float t2 = b + det;
  // If 't2' is greater than EPS, the intersection is in front of the ray.
  if (t2 > EPS)
    return t2;

  // If neither intersection is in front of the ray, return infinity to indicate no intersection.
  return INF;
}

/// Check if a ray intersects a rect.
/// \param[in] pos The position of the rect.
/// \param[in] u The first edge of the rect.
/// \param[in] v The second edge of the rect.
/// \param[in] plane The plane of the rect.
/// \param[in] r The ray.
/// \return The distance to the intersection point, or INF if no intersection.
float rect_intersect(in vec3 pos, in vec3 u, in vec3 v, in vec4 plane, in Ray r) {
  // Extract the normal vector of the plane from the plane representation.
  const vec3 n = vec3(plane);
  // Calculate the dot product of the ray's direction and the plane's normal.
  const float dt = dot(r.direction, n);
  // Calculate the intersection time 't' of the ray with the plane.
  const float t = (plane.w - dot(n, r.origin)) / dt;

  // Check if the intersection time 't' is greater than a small positive number (EPS).
  if (t > EPS) {
    // Calculate the intersection point 'p' on the plane.
    const vec3 p = r.origin + r.direction * t;
    // Compute the vector from the rectangle's corner 'pos' to the intersection point 'p'.
    const vec3 vi = p - pos;
    // Project 'vi' onto the edge vector 'u' to find its component along 'u'.
    const float a1 = dot(u, vi);
    // Check if the projection is within the bounds of the rectangle's first edge.
    if (a1 >= 0.0 && a1 <= 1.0) {
      // Project 'vi' onto the edge vector 'v' to find its component along 'v'.
      const float a2 = dot(v, vi);
      // Check if the projection is within the bounds of the rectangle's second edge.
      if (a2 >= 0.0 && a2 <= 1.0) {
        // If both projections are within bounds, return the intersection time 't'.
        return t;
      }
    }
  }

  // If the intersection is not within the bounds of the rectangle, return infinity to indicate no intersection.
  return INF;
}