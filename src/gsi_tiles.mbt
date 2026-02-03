///|
/// Convert lat/lon to slippy tile (x, y) at zoom level.
pub fn tile_coords(lat : Float, lon : Float, zoom : Int) -> (Int, Int) {
  let n = Double::from_int(1 << zoom)
  let lon_d = lon.to_double()
  let lat_d = lat.to_double()
  let lon_ratio = (lon_d + 180.0) / 360.0
  let lat_rad = @math.PI * lat_d / 180.0
  let y_ratio = (1.0 - @math.ln(@math.tan(lat_rad) + (1.0 / @math.cos(lat_rad))) / @math.PI) / 2.0
  let x = Double::floor(lon_ratio * n).to_int()
  let y = Double::floor(y_ratio * n).to_int()
  (x, y)
}

///|
/// Convert lat/lon to pixel coords within a tile (0..255).
pub fn tile_pixel(lat : Float, lon : Float, zoom : Int) -> (Int, Int) {
  let n = Double::from_int(1 << zoom)
  let lon_d = lon.to_double()
  let lat_d = lat.to_double()
  let lon_ratio = (lon_d + 180.0) / 360.0
  let lat_rad = @math.PI * lat_d / 180.0
  let y_ratio = (1.0 - @math.ln(@math.tan(lat_rad) + (1.0 / @math.cos(lat_rad))) / @math.PI) / 2.0
  let x = Double::floor(lon_ratio * n)
  let y = Double::floor(y_ratio * n)
  let px = Double::floor((lon_ratio * n - x) * 256.0).to_int()
  let py = Double::floor((y_ratio * n - y) * 256.0).to_int()
  (px, py)
}

///|
extern "js" fn sample_pixel_js(url : String, px : Int, py : Int) -> @core.Promise[String] =
  #| async (url, px, py) => {
  #|   try {
  #|     const response = await fetch(url);
  #|     if (!response.ok) return "0,0,0,0";
  #|     if (typeof createImageBitmap !== "function") return "0,0,0,0";
  #|     const blob = await response.blob();
  #|     const bitmap = await createImageBitmap(blob);
  #|     if (typeof OffscreenCanvas === "undefined") return "0,0,0,0";
  #|     const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
  #|     const ctx = canvas.getContext("2d");
  #|     ctx.drawImage(bitmap, 0, 0);
  #|     const data = ctx.getImageData(px, py, 1, 1).data;
  #|     return `${data[0]},${data[1]},${data[2]},${data[3]}`;
  #|   } catch (e) {
  #|     return "0,0,0,0";
  #|   }
  #| }

///|
pub fn hazard_tile_url(dataset : String, zoom : Int, x : Int, y : Int) -> String {
  "https://cyberjapandata.gsi.go.jp/xyz/"
    .add(dataset)
    .add("/")
    .add(zoom.to_string())
    .add("/")
    .add(x.to_string())
    .add("/")
    .add(y.to_string())
    .add(".png")
}

///|
pub async fn hazard_pixel(
  dataset : String,
  lat : Float,
  lon : Float,
  zoom : Int,
) -> HazardPixel {
  let (x, y) = tile_coords(lat, lon, zoom)
  let (px, py) = tile_pixel(lat, lon, zoom)
  let url = hazard_tile_url(dataset, zoom, x, y)
  let text = sample_pixel_js(url, px, py).wait()
  parse_pixel(text)
}

fn parse_pixel(text : String) -> HazardPixel {
  let parts = text.split(",").to_array()
  if parts.length() < 4 {
    HazardPixel::new(0, 0, 0, 0)
  } else {
    let r = parse_int(parts[0])
    let g = parse_int(parts[1])
    let b = parse_int(parts[2])
    let a = parse_int(parts[3])
    HazardPixel::new(r, g, b, a)
  }
}

fn parse_int(view : StringView) -> Int {
  let value : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(view)
  match value {
    Ok(v) => v
    Err(_) => 0
  }
}
