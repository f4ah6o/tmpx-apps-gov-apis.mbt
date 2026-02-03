# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**app-gov-apis** is a MoonBit application that evaluates physical climate risk exposure for Japanese companies by integrating multiple government APIs. The system:

1. Fetches corporate financial disclosures from EDINET (Financial Services Agency)
2. Extracts facility information from XBRL reports
3. Normalizes corporate addresses using gBizINFO (METI)
4. Geocodes addresses and samples hazard data from GSI map tiles
5. Calculates risk scores and generates reports (HTML/JSON/CSV)

## Quick Commands

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just test-update  # update snapshot tests
just run       # run main
just info      # generate type definition files
just release-check  # fmt + info + check + test (before commit)
```

## Code Navigation (IMPORTANT)

**Always use `moon ide` and `moon doc` instead of grep/Read for code exploration.**

```bash
# Show symbol definition with source code
moon ide peek-def symbol_name

# List symbols in a file
moon ide outline src/lib.mbt

# List standard library methods
moon doc 'String'
moon doc 'Array'
moon doc '@json'
```

## Coding Convention

- Each block is separated by `///|`
- MoonBit code uses snake_case for variables/functions (lowercase only)
- Struct definitions include `derive(Show, Eq)` where applicable

## Architecture

### Data Flow

1. **EDINET** (`fetch_documents`, `download_xbrl`) → Get company metadata and XBRL documents
2. **XBRL Extraction** (`extract_facilities_from_xbrl`) → Parse "主要な設備の状況" table from HTML
3. **gBizINFO** (`lookup_company`) → Normalize company names and addresses
4. **Geocoding** (`geocode`) → Convert addresses to lat/lon using GSI msearch
5. **GSI Tiles** (`hazard_pixel`) → Sample hazard pixels from tile servers
6. **Risk Scoring** (`facility_score`, `risk_from_pixel`) → Calculate weighted risk
7. **Report** (`render_report`, `report_to_json`, `report_to_csv`) → Output results

### Module Layout

- `src/lib.mbt` - Core domain types, API clients, risk scoring, report rendering
- `src/main/main.mbt` - CLI entry point, workflow orchestration
- `src/xbrl_extract.mbt` - XBRL/HTML parsing for facility table extraction
- `src/gsi_tiles.mbt` - Web Mercator tile math, pixel sampling from PNG tiles
- `src/mesh_calc.mbt` - Japanese mesh code calculations for regional statistics

### Key Types

- `Facility` - name, address, lat, lon, asset_value
- `FacilityRisk` - facility + hazard type + risk_score + confidence
- `CompanyReport` - company_name, doc_id, facilities, total_score, hazard_mode
- `HazardPixel` - RGBA values from GSI hazard tiles
- `EdinetDocument` - doc_id, filer_name, doc_type, submit_date_time
- `GbizCompany` - name, corp_number, address

### Hazard Datasets

GSI tile datasets used for risk assessment:
- `01_flood_l2_shinsuishin_data` - Flood (L2)
- `04_td_dosekiryu` - Landslide
- `04_td_kyukeisha` - Collapsed areas
- `02_takashio_shinsuishin_data` - Storm surge
- `03_tsunami_shinsui_data` - Tsunami

### CLI Usage

```bash
# Via environment variables
COMPANY="Example Corp" EDINET_API_KEY="xxx" GBIZ_API_KEY="yyy" just run

# Via arguments
moon run src/main -- -- "Company Name" EDINET_KEY GBIZ_KEY 2024-01-01

# Output formats (OUTPUT env var)
OUTPUT=html  # HTML report (default)
OUTPUT=json  # JSON export
OUTPUT=csv   # CSV export

# Hazard modes (HAZARD_MODE env var)
HAZARD_MODE=max       # Maximum hazard (default)
HAZARD_MODE=avg       # Average across all datasets
HAZARD_MODE=weighted  # Weighted average (use HAZARD_WEIGHTS)
```

## JavaScript Interop

This project targets JavaScript (`js`). Key extern patterns:

- `extern "js" fn name(...) -> ReturnType = #| (...) => { ... }` - Inline JS
- `@core.Promise[T]` for async operations, use `.wait()` to await
- `@hashmap.HashMap[K, V]` for mutable caching

## API Keys Required

- `EDINET_API_KEY` - EDINET API v2 (documents.json, document download)
- `GBIZ_API_KEY` - gBizINFO API (corporate number, address normalization)

## Development Guide

See also @docs/DEVELOPMENT_GUIDE.md
