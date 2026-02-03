# app-gov-apis

Corporate climate risk assessment tool for Japanese companies, built with MoonBit.

## Overview

This system evaluates physical climate risk exposure by integrating multiple Japanese government APIs:

1. **EDINET** (Financial Services Agency) - Corporate financial disclosures (XBRL)
2. **gBizINFO** (METI) - Corporate registry and address normalization
3. **GSI** (Geospatial Information Authority) - Hazard map tiles (flood, landslide, storm surge, tsunami)
4. **e-Stat** (Statistics Bureau) - Regional statistical data (via mesh codes)

## Features

- Extract facility information from XBRL financial reports
- Geocode addresses and sample hazard pixels from GSI tiles
- Calculate risk-weighted asset values
- Generate reports in HTML, JSON, or CSV format

## Quick Start

```bash
just run
```

### With API Keys

```bash
COMPANY="Example Corp" \
EDINET_API_KEY="your-edinet-key" \
GBIZ_API_KEY="your-gbiz-key" \
just run
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `COMPANY` | Company name to analyze | `Example Corp` |
| `EDINET_API_KEY` | EDINET API v2 key | (empty) |
| `GBIZ_API_KEY` | gBizINFO API key | (empty) |
| `EDINET_DATE` | Start date for document search | `2024-01-01` |
| `EDINET_DAYS` | Days to search back | `7` |
| `HAZARD_MODE` | `max`, `avg`, or `weighted` | `max` |
| `HAZARD_WEIGHTS` | Comma-separated `dataset:weight` pairs | (empty) |
| `OUTPUT` | `html`, `json`, or `csv` | `html` |

## CLI Arguments

```bash
moon run src/main -- <company> <edinet_key> <gbiz_key> <date>
```

## Output Formats

### HTML (default)
Interactive report with facility table and risk scores

### JSON
```json
{
  "company_name": "...",
  "doc_id": "...",
  "total_score": 12345.67,
  "hazard_mode": "max",
  "facilities": [...]
}
```

### CSV
```csv
hazard_mode,hazard_weights,facility,address,lat,lon,hazard,risk_score,confidence
max,default,Factory A,Tokyo,35.6,139.7,01_flood_l2_shinsuishin_data,1000.0,0.8
```

## Hazard Datasets

| Dataset | Description |
|---------|-------------|
| `01_flood_l2_shinsuishin_data` | Flood (L2) |
| `04_td_dosekiryu` | Landslide |
| `04_td_kyukeisha` | Collapsed areas |
| `02_takashio_shinsuishin_data` | Storm surge |
| `03_tsunami_shinsui_data` | Tsunami |

## Development

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
just test-update  # update snapshot tests
just info      # generate type definition files
just release-check  # fmt + info + check + test
```

## API Keys

### EDINET API v2
- https://api.edinet-fsa.go.jp/api/v2/documents.json
- Requires free API key from EDINET

### gBizINFO API
- https://info.gbiz.go.jp/hojin/v1/hojin
- Requires free API key from gBizINFO

## License

MIT
