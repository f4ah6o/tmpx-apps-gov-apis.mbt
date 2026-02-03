///|
async fn main {
  @async.sleep(16)
  let args = js_get_args()
  let has_cli = args.length() > 1
  let company = if has_cli { args[1] } else { env_or("COMPANY", "Example Corp") }
  let edinet_key = if args.length() > 2 { args[2] } else { env_or("EDINET_API_KEY", "") }
  let gbiz_key = if args.length() > 3 { args[3] } else { env_or("GBIZ_API_KEY", "") }
  let date = if args.length() > 4 { args[4] } else { env_or("EDINET_DATE", "2024-01-01") }
  let days = parse_int(env_or("EDINET_DAYS", "7"), 7)
  let hazard_mode = env_or("HAZARD_MODE", "max")
  let hazard_weights = env_or("HAZARD_WEIGHTS", "")
  let doc_id = select_doc_id_range(date, days, edinet_key)
  let xbrl = @core.download_xbrl(doc_id, edinet_key)
  let facilities = if xbrl.length() == 0 {
    []
  } else {
    @core.extract_facilities_from_xbrl(xbrl)
  }
  let enriched = @core.enrich_facilities_with_confidence(company, facilities, gbiz_key)
  let facility_risks : Array[@core.FacilityRisk] = []
  let mut total_score : Float = 0.0
  let datasets = [
    "01_flood_l2_shinsuishin_data",
    "04_td_dosekiryu",
    "04_td_kyukeisha",
    "02_takashio_shinsuishin_data",
    "03_tsunami_shinsui_data",
  ]
  for item in enriched {
    let facility = item.facility
    let mut best_hazard = "unknown"
    let mut best_factor : Float = 0.0
    let mut factor_sum : Float = 0.0
    let mut weight_sum : Float = 0.0
    for dataset in datasets {
      let factor : Float = if facility.lat == 0.0 && facility.lon == 0.0 {
        0.0
      } else {
        let pixel = @core.hazard_pixel(dataset, facility.lat, facility.lon, 15)
        @core.risk_from_pixel(pixel)
      }
      let weight = parse_weight(hazard_weights, dataset)
      factor_sum = factor_sum + (factor * weight)
      weight_sum = weight_sum + weight
      if factor > best_factor {
        best_factor = factor
        best_hazard = dataset
      }
    }
    let effective_factor : Float = if hazard_mode == "avg" {
      if datasets.length() == 0 {
        0.0
      } else {
        factor_sum / Float::from_int(datasets.length())
      }
    } else if hazard_mode == "weighted" {
      if weight_sum == 0.0 { 0.0 } else { factor_sum / weight_sum }
    } else {
      best_factor
    }
    let risk_score = @core.facility_score(facility, effective_factor) * item.confidence
    total_score = total_score + risk_score
    facility_risks.push(
      @core.FacilityRisk::new(facility, best_hazard, risk_score, item.confidence),
    )
  }
  let report = @core.CompanyReport::new(
    company,
    doc_id,
    facility_risks,
    total_score,
    hazard_mode,
    if hazard_weights.length() == 0 { "default" } else { hazard_weights },
  )
  let output = env_or("OUTPUT", "html")
  match output {
    "json" => {
      let json = @core.report_to_json(report)
      println(json)
    }
    "csv" => {
      let csv = @core.report_to_csv(report)
      println(csv)
    }
    _ => {
      let html = @core.render_report(report)
      println(html)
    }
  }
}

///|
extern "js" fn js_get_args() -> Array[String] =
  #| () => {
  #|   if (typeof process !== "undefined" && process.argv) return process.argv;
  #|   if (typeof Deno !== "undefined" && Deno.args) return Deno.args;
  #|   return [];
  #| }

///|
extern "js" fn js_get_env(name : String) -> String =
  #| (name) => {
  #|   if (typeof process !== "undefined" && process.env && process.env[name]) return process.env[name];
  #|   if (typeof Deno !== "undefined" && Deno.env) {
  #|     try { return Deno.env.get(name) || ""; } catch (e) {}
  #|   }
  #|   return "";
  #| }

fn env_or(name : String, fallback : String) -> String {
  let value = js_get_env(name)
  if value.length() == 0 { fallback } else { value }
}

fn parse_int(value : String, fallback : Int) -> Int {
  let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(value)
  match parsed {
    Ok(v) => v
    Err(_) => fallback
  }
}

fn parse_weight(spec : String, dataset : String) -> Float {
  if spec.length() == 0 {
    1.0
  } else {
    let parts = spec.split(",").to_array()
    for part in parts {
      let pair = part.to_string().split(":").to_array()
      if pair.length() == 2 {
        let key = pair[0].to_string().trim().to_string()
        if key == dataset {
          let value = pair[1].to_string().trim().to_string()
          let parsed : Result[Double, @strconv.StrConvError] = try? @strconv.parse_double(value)
          return match parsed {
            Ok(v) => Float::from_double(v)
            Err(_) => 1.0
          }
        }
      }
    }
    1.0
  }
}

let doc_id_cache : @hashmap.HashMap[String, String] = @hashmap.new()

///|
// removed unused select_doc_id

///|
async fn select_doc_id_range(start_date : String, days : Int, api_key : String) -> String {
  if api_key.length() == 0 {
    return "DOC-000"
  }
  let cache_key = start_date.add("/").add(days.to_string())
  match doc_id_cache.get(cache_key) {
    Some(value) => return value
    None => ()
  }
  let mut best_doc_id = ""
  let mut best_time = ""
  for i = 0; i < days; i = i + 1 {
    let date = js_shift_date(start_date, -i)
    let documents = @core.fetch_documents(date, 2, api_key)
    for doc in documents {
      if doc.doc_type != "2" {
        continue
      }
      let time = match doc.submit_date_time {
        Some(t) => t
        None => ""
      }
      if time != "" && (best_time == "" || time > best_time) {
        best_time = time
        best_doc_id = doc.doc_id
      }
    }
  }
  let result = if best_doc_id != "" { best_doc_id } else { "DOC-000" }
  doc_id_cache[cache_key] = result
  result
}

extern "js" fn js_shift_date(date : String, offset_days : Int) -> String =
  #| (date, offset) => {
  #|   const d = new Date(date);
  #|   if (Number.isNaN(d.getTime())) return date;
  #|   d.setUTCDate(d.getUTCDate() + offset);
  #|   const yyyy = d.getUTCFullYear();
  #|   const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  #|   const dd = String(d.getUTCDate()).padStart(2, "0");
  #|   return `${yyyy}-${mm}-${dd}`;
  #| }
