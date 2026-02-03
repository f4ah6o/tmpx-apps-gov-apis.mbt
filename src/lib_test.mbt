///|
test "risk scoring" {
  let facility = Facility::new("A", "Tokyo", 0.0, 0.0, 100.0)
  let pixel = HazardPixel::new(220, 80, 60, 255)
  let factor = risk_from_pixel(pixel)
  let score = facility_score(facility, factor)
  inspect(score, content="80")
}
