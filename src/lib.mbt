///|
/// CorpHazard Audit core library entry (placeholder).
pub fn version() -> String {
  "0.1.0"
}

///|
pub struct Facility {
  name : String
  address : String
  lat : Float
  lon : Float
  asset_value : Float
} derive(Show, Eq)

///|
pub struct FacilityRisk {
  facility : Facility
  hazard : String
  risk_score : Float
  confidence : Float
} derive(Show, Eq)

///|
pub struct CompanyReport {
  company_name : String
  doc_id : String
  facilities : Array[FacilityRisk]
  total_score : Float
  hazard_mode : String
  hazard_weights : String
} derive(Show, Eq)

///|
pub struct HazardPixel {
  r : Int
  g : Int
  b : Int
  a : Int
} derive(Show, Eq)

///|
pub struct EdinetDocument {
  doc_id : String
  filer_name : String
  doc_type : String
  submit_date_time : String?
} derive(Show, Eq)

///|
pub struct GbizCompany {
  name : String
  corp_number : String
  address : String
} derive(Show, Eq)

///|
pub struct FacilityGeo {
  facility : Facility
  confidence : Float
} derive(Show, Eq)

///|
pub fn Facility::new(
  name : String,
  address : String,
  lat : Float,
  lon : Float,
  asset_value : Float,
) -> Facility {
  { name, address, lat, lon, asset_value }
}

///|
pub fn FacilityRisk::new(
  facility : Facility,
  hazard : String,
  risk_score : Float,
  confidence : Float,
) -> FacilityRisk {
  { facility, hazard, risk_score, confidence }
}

///|
pub fn CompanyReport::new(
  company_name : String,
  doc_id : String,
  facilities : Array[FacilityRisk],
  total_score : Float,
  hazard_mode : String,
  hazard_weights : String,
) -> CompanyReport {
  { company_name, doc_id, facilities, total_score, hazard_mode, hazard_weights }
}

///|
pub fn HazardPixel::new(r : Int, g : Int, b : Int, a : Int) -> HazardPixel {
  { r, g, b, a }
}

///|
pub fn EdinetDocument::new(
  doc_id : String,
  filer_name : String,
  doc_type : String,
  submit_date_time : String?,
) -> EdinetDocument {
  { doc_id, filer_name, doc_type, submit_date_time }
}

///|
pub fn GbizCompany::new(
  name : String,
  corp_number : String,
  address : String,
) -> GbizCompany {
  { name, corp_number, address }
}

///|
pub fn FacilityGeo::new(facility : Facility, confidence : Float) -> FacilityGeo {
  { facility, confidence }
}

///|
/// Map hazard pixel RGBA to risk factor.
pub fn risk_from_pixel(pixel : HazardPixel) -> Float {
  if pixel.a == 0 {
    0.0
  } else if pixel.r > 200 && pixel.g < 100 {
    0.8
  } else if pixel.r > 150 {
    0.5
  } else {
    0.1
  }
}

///|
/// Compute weighted facility risk score.
pub fn facility_score(facility : Facility, factor : Float) -> Float {
  facility.asset_value * factor
}

///|
pub fn render_report(report : CompanyReport) -> String {
  let header = "<h1>CorpHazard Audit</h1>"
  let subtitle = "<p>Company: ".add(report.company_name).add("</p>")
  let hazard_meta = "<p>Hazard mode: "
    .add(report.hazard_mode)
    .add(" (weights: ")
    .add(report.hazard_weights)
    .add(")</p>")
  let score = "<p>Total score: ".add(report.total_score.to_string()).add("</p>")
  let table_header = "<tr><th>Facility</th><th>Address</th><th>Hazard</th><th>Risk</th><th>Confidence</th></tr>"
  let table_rows = report.facilities
    .map(fn(f) {
      "<tr><td>"
      .add(f.facility.name)
      .add("</td><td>")
      .add(f.facility.address)
      .add("</td><td>")
      .add(f.hazard)
      .add("</td><td>")
      .add(f.risk_score.to_string())
      .add("</td><td>")
      .add(f.confidence.to_string())
      .add("</td></tr>")
    })
    .join("")
  let empty_note = if report.facilities.length() == 0 {
    "<p>No facilities found.</p>"
  } else {
    ""
  }
  "<div class=\"report\">"
  .add(header)
  .add(subtitle)
  .add(hazard_meta)
  .add(score)
  .add(empty_note)
  .add("<table>")
  .add(table_header)
  .add(table_rows)
  .add("</table></div>")
}

///|
pub fn report_to_json(report : CompanyReport) -> String {
  let obj : Map[String, Json] = Map::new()
  obj["company_name"] = report.company_name.to_json()
  obj["doc_id"] = report.doc_id.to_json()
  obj["total_score"] = report.total_score.to_json()
  obj["hazard_mode"] = report.hazard_mode.to_json()
  obj["hazard_weights"] = report.hazard_weights.to_json()
  obj["facility_count"] = report.facilities.length().to_json()
  let items : Array[Json] = []
  for item in report.facilities {
    let row : Map[String, Json] = Map::new()
    row["facility"] = item.facility.name.to_json()
    row["address"] = item.facility.address.to_json()
    row["lat"] = item.facility.lat.to_json()
    row["lon"] = item.facility.lon.to_json()
    row["hazard"] = item.hazard.to_json()
    row["risk_score"] = item.risk_score.to_json()
    row["confidence"] = item.confidence.to_json()
    items.push(Json::object(row))
  }
  obj["facilities"] = Json::array(items)
  Json::object(obj).to_string()
}

///|
pub fn report_to_csv(report : CompanyReport) -> String {
  let header = "hazard_mode,hazard_weights,facility,address,lat,lon,hazard,risk_score,confidence\n"
  let mut rows = ""
  for item in report.facilities {
    rows = rows
      .add(csv_cell(report.hazard_mode))
      .add(",")
      .add(csv_cell(report.hazard_weights))
      .add(",")
      .add(csv_cell(item.facility.name))
      .add(",")
      .add(csv_cell(item.facility.address))
      .add(",")
      .add(item.facility.lat.to_string())
      .add(",")
      .add(item.facility.lon.to_string())
      .add(",")
      .add(csv_cell(item.hazard))
      .add(",")
      .add(item.risk_score.to_string())
      .add(",")
      .add(item.confidence.to_string())
      .add("\n")
  }
  header.add(rows)
}

///|
fn csv_cell(value : String) -> String {
  if value.contains(",") || value.contains("\"") || value.contains("\n") {
    "\"".add(value.replace_all(old="\"", new="\"\"")).add("\"")
  } else {
    value
  }
}

///|
extern "js" fn fetch_text(url : String) -> @core.Promise[String] =
  #| async (url) => {
  #|   try {
  #|     const response = await fetch(url);
  #|     if (!response.ok) return "";
  #|     return await response.text();
  #|   } catch (e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn fetch_bytes(url : String) -> @core.Promise[Bytes] =
  #| async (url) => {
  #|   try {
  #|     const response = await fetch(url);
  #|     if (!response.ok) return new Uint8Array();
  #|     const buffer = await response.arrayBuffer();
  #|     return new Uint8Array(buffer);
  #|   } catch (e) {
  #|     return new Uint8Array();
  #|   }
  #| }

///|
pub async fn get_text(url : String) -> String {
  match text_cache.get(url) {
    Some(value) => value
    None => {
      let value = fetch_text(url).wait()
      text_cache[url] = value
      value
    }
  }
}

///|
pub async fn get_bytes(url : String) -> Bytes {
  match bytes_cache.get(url) {
    Some(value) => value
    None => {
      let value = fetch_bytes(url).wait()
      bytes_cache[url] = value
      value
    }
  }
}

///|
let text_cache : @hashmap.HashMap[String, String] = @hashmap.new()

///|
let bytes_cache : @hashmap.HashMap[String, Bytes] = @hashmap.new()

///|
pub fn edinet_documents_url(
  date : String,
  doc_type : Int,
  api_key : String,
) -> String {
  "https://api.edinet-fsa.go.jp/api/v2/documents.json?date="
  .add(date)
  .add("&type=")
  .add(doc_type.to_string())
  .add("&Subscription-Key=")
  .add(api_key)
}

///|
pub fn edinet_xbrl_url(
  doc_id : String,
  api_key : String,
  download_type? : Int = 1,
) -> String {
  "https://api.edinet-fsa.go.jp/api/v2/documents/"
  .add(doc_id)
  .add("?type=")
  .add(download_type.to_string())
  .add("&Subscription-Key=")
  .add(api_key)
}

///|
struct EdinetResult {
  docID : String
  filerName : String
  docTypeCode : String
  submitDateTime : String?
} derive(FromJson)

///|
struct EdinetResponse {
  results : Array[EdinetResult]
} derive(FromJson)

///|
pub fn parse_edinet_documents(json_text : String) -> Array[EdinetDocument] {
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(json_text)
  match parsed {
    Ok(json) => {
      let response_result : Result[EdinetResponse, @json.JsonDecodeError] = try? @json.from_json(
        json,
      )
      match response_result {
        Ok(response) =>
          response.results.map(fn(item) {
            EdinetDocument::new(
              item.docID,
              item.filerName,
              item.docTypeCode,
              item.submitDateTime,
            )
          })
        Err(_) => []
      }
    }
    Err(_) => []
  }
}

///|
pub async fn fetch_documents(
  date : String,
  doc_type : Int,
  api_key : String,
) -> Array[EdinetDocument] {
  if api_key.length() == 0 {
    return []
  }
  let url = edinet_documents_url(date, doc_type, api_key)
  let body = get_text(url)
  parse_edinet_documents(body)
}

///|
pub async fn download_xbrl(
  doc_id : String,
  api_key : String,
  download_type? : Int = 1,
) -> Bytes {
  if api_key.length() == 0 || doc_id.length() == 0 {
    return []
  }
  let url = edinet_xbrl_url(doc_id, api_key, download_type~)
  get_bytes(url)
}

///|
pub fn gbiz_search_url(name : String, api_key : String) -> String {
  "https://info.gbiz.go.jp/hojin/v1/hojin?name="
  .add(name.replace_all(old=" ", new="%20"))
  .add("&limit=20&offset=0&apikey=")
  .add(api_key)
}

///|
struct GbizResult {
  corporate_number : String
  name : String
  location : String
} derive(FromJson)

///|
struct GbizResponse {
  results : Array[GbizResult]
} derive(FromJson)

///|
pub fn parse_gbiz_companies(json_text : String) -> Array[GbizCompany] {
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(json_text)
  match parsed {
    Ok(json) => {
      let response_result : Result[GbizResponse, @json.JsonDecodeError] = try? @json.from_json(
        json,
      )
      match response_result {
        Ok(response) =>
          response.results.map(fn(item) {
            GbizCompany::new(item.name, item.corporate_number, item.location)
          })
        Err(_) => []
      }
    }
    Err(_) => []
  }
}

///|
pub async fn lookup_company(name : String, api_key : String) -> GbizCompany? {
  lookup_company_with_hint(name, "", api_key)
}

///|
pub async fn lookup_company_with_hint(
  name : String,
  address_hint : String,
  api_key : String,
) -> GbizCompany? {
  if api_key.length() == 0 || name.length() == 0 {
    return None
  }
  let url = gbiz_search_url(name, api_key)
  let body = get_text(url)
  let companies = parse_gbiz_companies(body)
  select_best_company(companies, name, address_hint)
}

///|
pub fn gsi_geocode_url(address : String) -> String {
  "https://msearch.gsi.go.jp/address-search/AddressSearch?q=".add(
    address.replace_all(old=" ", new="%20"),
  )
}

///|
struct GsiGeometry {
  coordinates : Array[Double]
} derive(FromJson)

///|
struct GsiResult {
  geometry : GsiGeometry
} derive(FromJson)

///|
pub fn parse_gsi_geocode(json_text : String) -> (Float, Float)? {
  let parsed : Result[Json, @json.ParseError] = try? @json.parse(json_text)
  match parsed {
    Ok(json) => {
      let results_result : Result[Array[GsiResult], @json.JsonDecodeError] = try? @json.from_json(
        json,
      )
      match results_result {
        Ok(results) =>
          if results.length() == 0 {
            None
          } else {
            let coords = results[0].geometry.coordinates
            if coords.length() < 2 {
              None
            } else {
              let lon = Float::from_double(coords[0])
              let lat = Float::from_double(coords[1])
              Some((lat, lon))
            }
          }
        Err(_) => None
      }
    }
    Err(_) => None
  }
}

///|
pub async fn geocode(address : String) -> (Float, Float)? {
  if address.length() == 0 {
    return None
  }
  let url = gsi_geocode_url(address)
  let body = get_text(url)
  parse_gsi_geocode(body)
}

///|
pub async fn enrich_facilities_with_confidence(
  company_name : String,
  facilities : Array[Facility],
  gbiz_api_key : String,
) -> Array[FacilityGeo] {
  let address_hint = find_address_hint(facilities)
  let normalized_address = match
    lookup_company_with_hint(company_name, address_hint, gbiz_api_key) {
    Some(company) => normalize_address(company.address)
    None => ""
  }
  let enriched : Array[FacilityGeo] = []
  for facility in facilities {
    let raw_address = if facility.address.length() == 0 {
      normalized_address
    } else {
      normalize_address(facility.address)
    }
    let address = raw_address
    let base_confidence : Float = if facility.address.length() == 0 {
      0.6
    } else {
      0.8
    }
    let coords = if address.length() == 0 { None } else { geocode(address) }
    match coords {
      Some((lat, lon)) =>
        enriched.push(
          FacilityGeo::new(
            Facility::new(
              facility.name,
              address,
              lat,
              lon,
              facility.asset_value,
            ),
            1.0,
          ),
        )
      None =>
        enriched.push(
          FacilityGeo::new(
            Facility::new(
              facility.name,
              address,
              facility.lat,
              facility.lon,
              facility.asset_value,
            ),
            if address.length() == 0 {
              0.2
            } else {
              base_confidence
            },
          ),
        )
    }
  }
  enriched
}

///|
fn normalize_name(name : String) -> String {
  name
  .replace_all(old=" ", new="")
  .replace_all(old="　", new="")
  .replace_all(old="・", new="")
  .replace_all(old="株式会社", new="")
  .replace_all(old="(株)", new="")
}

///|
fn normalize_address(address : String) -> String {
  let mut value = address
  value = value.replace_all(old="　", new=" ")
  value = value.replace_all(old="－", new="-")
  value = value.replace_all(old="ー", new="-")
  value = value.replace_all(old="−", new="-")
  value = value.replace_all(old="丁目", new="-")
  value = value.replace_all(old="番地", new="-")
  value = value.replace_all(old="番", new="-")
  value = value.replace_all(old="号", new="")
  value = value.replace_all(old="０", new="0")
  value = value.replace_all(old="１", new="1")
  value = value.replace_all(old="２", new="2")
  value = value.replace_all(old="３", new="3")
  value = value.replace_all(old="４", new="4")
  value = value.replace_all(old="５", new="5")
  value = value.replace_all(old="６", new="6")
  value = value.replace_all(old="７", new="7")
  value = value.replace_all(old="８", new="8")
  value = value.replace_all(old="９", new="9")
  value = value.replace_all(old="  ", new=" ")
  value.trim().to_string()
}

///|
fn extract_prefecture(address : String) -> String {
  if address.length() < 2 {
    ""
  } else {
    let suffixes = ["都", "道", "府", "県"]
    for suf in suffixes {
      let pos = address.find(suf)
      if pos is Some(pos) {
        let end = pos + suf.length()
        return safe_prefix(address, end)
      }
    }
    ""
  }
}

///|
fn safe_prefix(value : String, end : Int) -> String {
  if end <= 0 {
    ""
  } else if end >= value.length() {
    value
  } else {
    value.unsafe_substring(start=0, end~)
  }
}

///|
fn select_best_company(
  companies : Array[GbizCompany],
  target_name : String,
  address_hint : String,
) -> GbizCompany? {
  if companies.length() == 0 {
    return None
  }
  let target_key = normalize_name(target_name)
  let address_key = normalize_address(address_hint)
  let mut best : GbizCompany? = None
  let mut best_score = -1
  for company in companies {
    let name_key = normalize_name(company.name)
    let mut score = if name_key == target_key {
      3
    } else if name_key.contains(target_key) || target_key.contains(name_key) {
      2
    } else if name_key.has_prefix(target_key) || target_key.has_prefix(name_key) {
      1
    } else {
      0
    }
    if address_key.length() > 0 {
      let comp_addr = normalize_address(company.address)
      let pref_hint = extract_prefecture(address_key)
      let pref_comp = extract_prefecture(comp_addr)
      if comp_addr == address_key {
        score = score + 2
      } else if comp_addr.contains(address_key) ||
        address_key.contains(comp_addr) {
        score = score + 1
      }
      if pref_hint.length() > 0 && pref_hint == pref_comp {
        score = score + 1
      }
    }
    if score > best_score {
      best_score = score
      best = Some(company)
    }
  }
  best
}

///|
fn find_address_hint(facilities : Array[Facility]) -> String {
  for facility in facilities {
    if facility.address.length() > 0 {
      return facility.address
    }
  }
  ""
}

///|
pub async fn enrich_facilities(
  company_name : String,
  facilities : Array[Facility],
  gbiz_api_key : String,
) -> Array[Facility] {
  let normalized_address = match lookup_company(company_name, gbiz_api_key) {
    Some(company) => company.address
    None => ""
  }
  let enriched : Array[Facility] = []
  for facility in facilities {
    let address = if facility.address.length() == 0 {
      normalized_address
    } else {
      facility.address
    }
    let coords = if address.length() == 0 { None } else { geocode(address) }
    match coords {
      Some((lat, lon)) =>
        enriched.push(
          Facility::new(facility.name, address, lat, lon, facility.asset_value),
        )
      None =>
        enriched.push(
          Facility::new(
            facility.name,
            address,
            facility.lat,
            facility.lon,
            facility.asset_value,
          ),
        )
    }
  }
  enriched
}
