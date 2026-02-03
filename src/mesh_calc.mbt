///|
/// Compute basic (third-level) mesh code for given lat/lon.
pub fn mesh_code_basic(lat : Float, lon : Float) -> String {
  let p = Float::floor(lat * 1.5)
  let u = Float::floor(lon - 100.0)
  let a = (lat * 1.5 - p) * 8.0
  let b = (lon - 100.0 - u) * 8.0
  let q = Float::floor(a)
  let v = Float::floor(b)
  let r = Float::floor((a - q) * 10.0)
  let w = Float::floor((b - v) * 10.0)
  p.to_int().to_string()
    .add(u.to_int().to_string())
    .add(q.to_int().to_string())
    .add(v.to_int().to_string())
    .add(r.to_int().to_string())
    .add(w.to_int().to_string())
}

///|
/// Compute half-mesh code by appending quadrant (1-4).
pub fn mesh_code_half(lat : Float, lon : Float) -> String {
  let base = mesh_code_basic(lat, lon)
  let p = Float::floor(lat * 1.5)
  let u = Float::floor(lon - 100.0)
  let a = (lat * 1.5 - p) * 8.0
  let b = (lon - 100.0 - u) * 8.0
  let q = Float::floor(a)
  let v = Float::floor(b)
  let r = Float::floor((a - q) * 10.0)
  let w = Float::floor((b - v) * 10.0)
  let sub_lat = Float::floor(((a - q) * 10.0 - r) * 2.0)
  let sub_lon = Float::floor(((b - v) * 10.0 - w) * 2.0)
  let quadrant = (sub_lat.to_int() * 2) + sub_lon.to_int() + 1
  base.add(quadrant.to_string())
}
