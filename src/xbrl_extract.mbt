///|
extern "js" fn unzip_first_xml(zip_bytes : Bytes) -> @core.Promise[String] =
  #| async (zipBytes) => {
  #|   try {
  #|     const { unzipSync, strFromU8 } = await import("https://cdn.jsdelivr.net/npm/fflate@0.8.2/esm/browser.js");
  #|     const data = zipBytes instanceof Uint8Array ? zipBytes : new Uint8Array(zipBytes);
  #|     const files = unzipSync(data);
  #|     const keys = Object.keys(files || {});
  #|     const key = keys.find((k) => k.endsWith(".xbrl") || k.endsWith(".xml")) || keys[0];
  #|     if (!key) return "";
  #|     return strFromU8(files[key]);
  #|   } catch (e) {
  #|     return "";
  #|   }
  #| }

///|
/// Extract facility list from XBRL ZIP archive (placeholder).
pub async fn extract_facilities_from_xbrl(archive : Bytes) -> Array[Facility] {
  let xml = unzip_first_xml(archive).wait()
  match extract_facility_table(xml) {
    None => []
    Some(table_html) => {
      let rows = extract_rows(table_html)
      if rows.length() == 0 {
        []
      } else {
        let normalized = normalize_rows(rows)
        if normalized.length() == 0 {
          []
        } else {
          let header_cells = merged_header_cells(normalized)
          let name_index = find_header_index(header_cells, "名称", 0)
          let address_index = find_header_index(header_cells, "所在地", 1)
          let amount_index = find_amount_index(header_cells, rows[0])
          let multiplier = detect_multiplier(table_html)
          let facilities : Array[Facility] = []
          for i = 0; i < normalized.length(); i = i + 1 {
            let cells = normalized[i]
            if is_header_row(cells) {
              continue
            }
            match
              parse_facility_cells(
                cells, name_index, address_index, amount_index, multiplier,
              ) {
              Some(facility) => facilities.push(facility)
              None => ()
            }
          }
          facilities
        }
      }
    }
  }
}

///|
/// Find the "主要な設備の状況" table and return HTML.
pub fn extract_facility_table(xbrl_xml : String) -> String? {
  let keyword = "主要な設備の状況"
  match xbrl_xml.find(keyword) {
    None => None
    Some(start) => {
      let tail = safe_slice(xbrl_xml, start, xbrl_xml.length())
      match tail.find("<table") {
        None => None
        Some(table_start) => {
          let table_tail = safe_slice(tail, table_start, tail.length())
          match table_tail.find("</table>") {
            None => None
            Some(table_end) => {
              let table_html = safe_slice(table_tail, 0, table_end)
              Some(table_html)
            }
          }
        }
      }
    }
  }
}

///|
fn extract_rows(table_html : String) -> Array[String] {
  let views = table_html.split("<tr").to_array()
  views.map(fn(v) { v.to_string() })
}

///|
pub fn parse_facility_row(
  row_html : String,
  name_index : Int,
  address_index : Int,
  amount_index : Int,
  multiplier : Float,
) -> Facility? {
  let cells = extract_cells(row_html)
  if cells.length() == 0 {
    None
  } else {
    parse_facility_cells(
      cells, name_index, address_index, amount_index, multiplier,
    )
  }
}

///|
pub fn parse_facility_cells(
  cells : Array[String],
  name_index : Int,
  address_index : Int,
  amount_index : Int,
  multiplier : Float,
) -> Facility? {
  if cells.length() == 0 {
    None
  } else {
    let equip_index = find_equipment_index(cells)
    let name = cell_at(cells, name_index, 0)
    let address = cell_at(cells, address_index, 1)
    let amount_text = cell_at(cells, amount_index, cells.length() - 1)
    if equip_index == name_index ||
      name.contains("設備") ||
      name.contains("区分") {
      None
    } else {
      let asset_value = parse_amount(amount_text, multiplier)
      Some(Facility::new(name, address, 0.0, 0.0, asset_value))
    }
  }
}

///|
fn extract_cells(row_html : String) -> Array[String] {
  extract_cells_any(row_html).map(fn(c) { c.text })
}

///|
priv struct Cell {
  text : String
  colspan : Int
  rowspan : Int
}

///|
fn normalize_rows(rows : Array[String]) -> Array[Array[String]] {
  let normalized : Array[Array[String]] = []
  let span_values : Array[String] = []
  let span_counts : Array[Int] = []
  for row_html in rows {
    let cells = extract_cells_any(row_html)
    if cells.length() == 0 {
      continue
    }
    let row : Array[String] = []
    let mut col = 0
    let mut idx = 0
    while idx < cells.length() {
      while col < span_counts.length() && span_counts[col] > 0 {
        row.push(span_values[col])
        span_counts[col] = span_counts[col] - 1
        col = col + 1
      }
      let cell = cells[idx]
      let text = cell.text
      let colspan = if cell.colspan > 0 { cell.colspan } else { 1 }
      let rowspan = if cell.rowspan > 0 { cell.rowspan } else { 1 }
      for _i = 0; _i < colspan; _i = _i + 1 {
        while col >= span_counts.length() {
          span_counts.push(0)
          span_values.push("")
        }
        row.push(text)
        if rowspan > 1 {
          span_counts[col] = rowspan - 1
          span_values[col] = text
        }
        col = col + 1
      }
      idx = idx + 1
    }
    while col < span_counts.length() && span_counts[col] > 0 {
      row.push(span_values[col])
      span_counts[col] = span_counts[col] - 1
      col = col + 1
    }
    normalized.push(row)
  }
  normalized
}

///|
fn extract_cells_any(row_html : String) -> Array[Cell] {
  let cells : Array[Cell] = []
  let mut pos = 0
  while pos < row_html.length() {
    let td_pos = find_from(row_html, "<td", pos)
    let th_pos = find_from(row_html, "<th", pos)
    let (tag_pos, tag_name) = if td_pos >= 0 && (th_pos < 0 || td_pos < th_pos) {
      (td_pos, "td")
    } else if th_pos >= 0 {
      (th_pos, "th")
    } else {
      (-1, "")
    }
    if tag_pos < 0 {
      break
    }
    let tag_end = find_from(row_html, ">", tag_pos)
    if tag_end < 0 {
      break
    }
    let tag_text = safe_slice(row_html, tag_pos, tag_end + 1)
    let close_tag = "</".add(tag_name).add(">")
    let tail = safe_slice(row_html, tag_end + 1, row_html.length())
    let close_pos = match tail.find(close_tag) {
      Some(index) => index
      None => break
    }
    let cell_body = safe_slice(tail, 0, close_pos)
    let text = strip_tags(cell_body).trim().to_string()
    let colspan = parse_span(tag_text, "colspan")
    let rowspan = parse_span(tag_text, "rowspan")
    cells.push({ text, colspan, rowspan })
    pos = tag_end + close_pos + close_tag.length() + 1
  }
  cells
}

///|
fn strip_tags(input : String) -> String {
  let mut out = ""
  let mut in_tag = false
  for ch in input {
    if ch == '<' {
      in_tag = true
    } else if ch == '>' {
      in_tag = false
    } else if !in_tag {
      out = out.add(ch.to_string())
    }
  }
  out.replace_all(old="\u00a0", new=" ")
}

///|
fn parse_amount(text : String, multiplier : Float) -> Float {
  let cleaned = text.replace_all(old=",", new="").replace_all(old=" ", new="")
  let value : Result[Double, @strconv.StrConvError] = try? @strconv.parse_double(
    cleaned,
  )
  match value {
    Ok(v) => Float::from_double(v) * multiplier
    Err(_) => 0.0
  }
}

///|
fn cell_at(cells : Array[String], index : Int, fallback_index : Int) -> String {
  if index >= 0 && index < cells.length() {
    cells[index]
  } else if fallback_index >= 0 && fallback_index < cells.length() {
    cells[fallback_index]
  } else {
    ""
  }
}

///|
fn find_header_index(
  cells : Array[String],
  keyword : String,
  fallback : Int,
) -> Int {
  for i = 0; i < cells.length(); i = i + 1 {
    if cells[i].contains(keyword) {
      return i
    }
  }
  fallback
}

///|
fn find_amount_index(cells : Array[String], header_row : String) -> Int {
  for i = 0; i < cells.length(); i = i + 1 {
    if cells[i].contains("帳簿") ||
      cells[i].contains("価額") ||
      cells[i].contains("金額") {
      return i
    }
  }
  if header_row.contains("帳簿") || header_row.contains("価額") {
    cells.length() - 1
  } else {
    cells.length() - 1
  }
}

///|
fn find_equipment_index(cells : Array[String]) -> Int {
  for i = 0; i < cells.length(); i = i + 1 {
    if cells[i].contains("設備") || cells[i].contains("区分") {
      return i
    }
  }
  -1
}

///|
fn is_header_row(cells : Array[String]) -> Bool {
  for cell in cells {
    if cell.contains("名称") ||
      cell.contains("所在地") ||
      cell.contains("帳簿") ||
      cell.contains("価額") {
      return true
    }
  }
  false
}

///|
fn detect_multiplier(table_html : String) -> Float {
  if table_html.contains("百万円") {
    1000000.0
  } else if table_html.contains("千円") {
    1000.0
  } else {
    1.0
  }
}

///|
fn merged_header_cells(rows : Array[Array[String]]) -> Array[String] {
  if rows.length() == 0 {
    []
  } else if rows.length() == 1 {
    rows[0]
  } else {
    let first = rows[0]
    let second = rows[1]
    let merged : Array[String] = []
    let len = if first.length() > second.length() {
      first.length()
    } else {
      second.length()
    }
    for i = 0; i < len; i = i + 1 {
      let left = if i < first.length() { first[i] } else { "" }
      let right = if i < second.length() { second[i] } else { "" }
      let text = if left.length() == 0 {
        right
      } else if right.length() == 0 {
        left
      } else {
        left.add(" ").add(right)
      }
      merged.push(text)
    }
    merged
  }
}

///|
fn safe_slice(input : String, start : Int, end : Int) -> String {
  let len = input.length()
  if start < 0 || end < start || start >= len {
    ""
  } else {
    let end_pos = if end > len { len } else { end }
    input.unsafe_substring(start~, end=end_pos)
  }
}

///|
fn find_from(s : String, needle : String, start : Int) -> Int {
  let tail = safe_slice(s, start, s.length())
  match tail.find(needle) {
    Some(pos) => start + pos
    None => -1
  }
}

///|
fn parse_span(tag : String, name : String) -> Int {
  let key = name.add("=")
  match tag.find(key) {
    None => 1
    Some(pos) => {
      let rest = safe_slice(tag, pos + key.length(), tag.length())
      let trimmed = rest.trim().to_string()
      let value = if trimmed.has_prefix("\"") {
        let t = safe_slice(trimmed, 1, trimmed.length())
        let end_index = t.find("\"")
        match end_index {
          Some(i) => safe_slice(t, 0, i)
          None => ""
        }
      } else if trimmed.has_prefix("'") {
        let t = safe_slice(trimmed, 1, trimmed.length())
        let end_index = t.find("'")
        match end_index {
          Some(i) => safe_slice(t, 0, i)
          None => ""
        }
      } else {
        let end_index = trimmed.find(" ")
        match end_index {
          Some(i) => safe_slice(trimmed, 0, i)
          None => trimmed
        }
      }
      let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(
        value.to_string(),
      )
      match parsed {
        Ok(v) => v
        Err(_) => 1
      }
    }
  }
}
