#!/usr/bin/env bash
# ==============================================================================
#  cep.sh — Brazilian Postal Code (CEP) Lookup CLI (BrasilAPI / OpenCEP / ViaCEP)
# ==============================================================================
#  Author  : Percio Castelo (Percio Andrade) <percio@perciocastelo.com.br>
#  Website : https://perciocastelo.com.br
#  Project : https://perciocastelo.com.br/projetos/en/cep-cli.html
#  Repo    : https://github.com/sr00t3d/cep-cli
#  License : Apache-2.0
#  Version : 2.0.0
# ==============================================================================

set -uo pipefail

readonly SCRIPT_NAME="cep.sh"
readonly SCRIPT_VERSION="2.0.0"

# Runtime options
PROVIDER="auto"           # auto | brasilapi | opencep | viacep
INPUT_FILE=""
FORMAT="table"
QUIET=0
NO_COLOR=0
declare -a TARGETS=()

# Detected tools
HAVE_JQ=0
HAVE_PY3=0
TIMESTAMP_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Results (0x1f-delimited rows: cep_fmt|status|provider|street|neighborhood|city|state|ibge|lat|lon|tz)
declare -a ROWS=()

# Colors
RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
OK="[OK]" ATT="[!]" FAIL="[ERR]"

init_colors() {
  if [[ "$NO_COLOR" -eq 0 && -t 1 && -z "${NO_COLOR:-}" && "$FORMAT" == "table" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
    OK="${GREEN}[OK]${RESET}"
    ATT="${YELLOW}[!]${RESET}"
    FAIL="${RED}[ERR]${RESET}"
  else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
    OK="[OK]" ATT="[!]" FAIL="[ERR]"
  fi
}

show_help() {
  cat <<'USAGE'
cep.sh v2.0.0 — Brazilian Postal Code (CEP) Lookup CLI

Usage:
  cep.sh [options] <cep> [cep2 ...]
  cep.sh --file <ceps.txt> [-o table|json|csv]

Options:
  -f, --file <path>          Read CEPs from a file (one per line; # comments ignored)
  -p, --provider <name>      API provider: auto (default: brasilapi->opencep->viacep), brasilapi, opencep, viacep
  -o, --output <fmt>         Output format: table (default), json, csv
  -q, --quiet                Suppress banner header
  --no-color                 Disable ANSI colors
  -V, --version              Show version and exit
  -h, --help                 Show this help and exit

Examples:
  cep.sh 01001-000
  cep.sh 01001000 90250210
  cep.sh --provider opencep -o json 01001-000
  cep.sh --file ceps.txt -o csv
USAGE
}

need_cmd() {
  local missing=0 cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf '[ERR] Missing required command: %s\n' "$cmd" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
}

normalize_cep() {
  printf '%s' "$1" | tr -cd '0-9'
}

format_cep() {
  local c="$1"
  printf '%s-%s' "${c:0:5}" "${c:5:3}"
}

query_brasilapi() {
  local cep="$1" body="" parsed=""
  body="$(curl -fsS --connect-timeout 4 --max-time 8 "https://brasilapi.com.br/api/cep/v2/${cep}" 2>/dev/null || true)"
  [[ -z "$body" ]] && return 1
  printf '%s' "$body" | grep -q '"cep"' || return 1

  if [[ "$HAVE_JQ" -eq 1 ]]; then
    parsed="$(jq -r '[(.street // ""), (.neighborhood // ""), (.city // ""), (.state // ""), ((.ibge.city // .ibge // "") | tostring), ((.location.coordinates.latitude // "") | tostring), ((.location.coordinates.longitude // "") | tostring), (.timezoneName // "")] | join("\u001f")' 2>/dev/null <<<"$body" || true)"
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    parsed="$(python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
ib = d.get("ibge")
ib_val = ib.get("city", "") if isinstance(ib, dict) else (ib or "")
coords = (d.get("location") or {}).get("coordinates") or {}
vals = [d.get("street",""), d.get("neighborhood",""), d.get("city",""), d.get("state",""), ib_val, coords.get("latitude",""), coords.get("longitude",""), d.get("timezoneName","")]
print("\x1f".join(str(v or "") for v in vals))
' 2>/dev/null <<<"$body" || true)"
  fi
  [[ -n "$parsed" ]] && { printf '%s' "$parsed"; return 0; }
  return 1
}

query_opencep() {
  local cep="$1" body="" parsed=""
  body="$(curl -fsS --connect-timeout 4 --max-time 8 "https://opencep.com/v1/${cep}" 2>/dev/null || true)"
  [[ -z "$body" ]] && return 1
  printf '%s' "$body" | grep -q '"cep"' || return 1

  if [[ "$HAVE_JQ" -eq 1 ]]; then
    parsed="$(jq -r '[(.logradouro // ""), (.bairro // ""), (.localidade // ""), (.uf // ""), (.ibge // ""), "", "", ""] | join("\u001f")' 2>/dev/null <<<"$body" || true)"
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    parsed="$(python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
vals = [d.get("logradouro",""), d.get("bairro",""), d.get("localidade",""), d.get("uf",""), d.get("ibge",""), "", "", ""]
print("\x1f".join(str(v or "") for v in vals))
' 2>/dev/null <<<"$body" || true)"
  fi
  [[ -n "$parsed" ]] && { printf '%s' "$parsed"; return 0; }
  return 1
}

query_viacep() {
  local cep="$1" body="" parsed=""
  body="$(curl -fsS --connect-timeout 4 --max-time 8 "https://viacep.com.br/ws/${cep}/json/" 2>/dev/null || true)"
  [[ -z "$body" ]] && return 1
  if printf '%s' "$body" | grep -q '"erro"'; then
    return 1
  fi
  printf '%s' "$body" | grep -q '"cep"' || return 1

  if [[ "$HAVE_JQ" -eq 1 ]]; then
    parsed="$(jq -r '[(.logradouro // ""), (.bairro // ""), (.localidade // ""), (.uf // ""), (.ibge // ""), "", "", ""] | join("\u001f")' 2>/dev/null <<<"$body" || true)"
  elif [[ "$HAVE_PY3" -eq 1 ]]; then
    parsed="$(python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
vals = [d.get("logradouro",""), d.get("bairro",""), d.get("localidade",""), d.get("uf",""), d.get("ibge",""), "", "", ""]
print("\x1f".join(str(v or "") for v in vals))
' 2>/dev/null <<<"$body" || true)"
  fi
  [[ -n "$parsed" ]] && { printf '%s' "$parsed"; return 0; }
  return 1
}

lookup_one() {
  local raw="$1"
  local cep cep_fmt
  cep="$(normalize_cep "$raw")"
  if [[ "${#cep}" -ne 8 ]]; then
    ROWS+=("${raw}"$'\x1f'"invalid"$'\x1f'"none"$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'"")
    return 0
  fi
  cep_fmt="$(format_cep "$cep")"

  local res="" used=""
  local -a chain=()
  case "$PROVIDER" in
    auto)      chain=(brasilapi opencep viacep) ;;
    brasilapi) chain=(brasilapi) ;;
    opencep)   chain=(opencep) ;;
    viacep)    chain=(viacep) ;;
  esac

  local p
  for p in "${chain[@]}"; do
    case "$p" in
      brasilapi) res="$(query_brasilapi "$cep" || true)" ;;
      opencep)   res="$(query_opencep "$cep" || true)" ;;
      viacep)    res="$(query_viacep "$cep" || true)" ;;
    esac
    if [[ -n "$res" ]]; then
      used="$p"
      break
    fi
  done

  if [[ -n "$res" ]]; then
    ROWS+=("${cep_fmt}"$'\x1f'"found"$'\x1f'"${used}"$'\x1f'"${res}")
  else
    ROWS+=("${cep_fmt}"$'\x1f'"not_found"$'\x1f'"${PROVIDER}"$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'""$'\x1f'"")
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

csv_escape() {
  local s="$1"
  s="${s//$'\n'/ ; }"
  s="${s//$'\r'/}"
  s="${s//\"/\"\"}"
  printf '"%s"' "$s"
}

render_output() {
  local row cep st prov street neigh city uf ibge lat lon tz
  case "$FORMAT" in
    json)
      local items="" first=1
      for row in "${ROWS[@]}"; do
        IFS=$'\x1f' read -r cep st prov street neigh city uf ibge lat lon tz <<<"$row"
        [[ "$first" -eq 0 ]] && items+=","
        first=0
        items+="{\"cep\":\"$(json_escape "$cep")\",\"status\":\"$(json_escape "$st")\",\"provider\":\"$(json_escape "$prov")\",\"street\":\"$(json_escape "$street")\",\"neighborhood\":\"$(json_escape "$neigh")\",\"city\":\"$(json_escape "$city")\",\"state\":\"$(json_escape "$uf")\",\"ibge\":\"$(json_escape "$ibge")\",\"latitude\":\"$(json_escape "$lat")\",\"longitude\":\"$(json_escape "$lon")\",\"timezone\":\"$(json_escape "$tz")\"}"
      done
      cat <<EOF
{
  "tool": "${SCRIPT_NAME}",
  "version": "${SCRIPT_VERSION}",
  "timestamp": "$(json_escape "$TIMESTAMP_UTC")",
  "count": ${#ROWS[@]},
  "results": [${items}]
}
EOF
      ;;
    csv)
      printf 'cep,status,provider,street,neighborhood,city,state,ibge,latitude,longitude,timezone\n'
      for row in "${ROWS[@]}"; do
        IFS=$'\x1f' read -r cep st prov street neigh city uf ibge lat lon tz <<<"$row"
        printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
          "$(csv_escape "$cep")" "$(csv_escape "$st")" "$(csv_escape "$prov")" \
          "$(csv_escape "$street")" "$(csv_escape "$neigh")" "$(csv_escape "$city")" \
          "$(csv_escape "$uf")" "$(csv_escape "$ibge")" "$(csv_escape "$lat")" \
          "$(csv_escape "$lon")" "$(csv_escape "$tz")"
      done
      ;;
    table)
      if [[ "$QUIET" -eq 0 ]]; then
        printf '%s=====================================================================%s\n' "$CYAN" "$RESET"
        printf ' %s%s v%s%s | Brazilian CEP Lookup | %s\n' "$BOLD" "$SCRIPT_NAME" "$SCRIPT_VERSION" "$RESET" "$TIMESTAMP_UTC"
        printf '%s=====================================================================%s\n' "$CYAN" "$RESET"
      fi
      for row in "${ROWS[@]}"; do
        IFS=$'\x1f' read -r cep st prov street neigh city uf ibge lat lon tz <<<"$row"
        printf '\n'
        if [[ "$st" == "found" ]]; then
          printf '%s %-11s : %s (provider: %s)\n' "$OK" "CEP" "$cep" "$prov"
          printf '     %-11s : %s\n' "Logradouro" "${street:-n/a}"
          printf '     %-11s : %s\n' "Bairro" "${neigh:-n/a}"
          printf '     %-11s : %s / %s\n' "Cidade/UF" "${city:-?}" "${uf:-?}"
          [[ -n "$ibge" ]] && printf '     %-11s : %s\n' "IBGE" "$ibge"
          [[ -n "$tz" ]]   && printf '     %-11s : %s\n' "Timezone" "$tz"
          if [[ -n "$lat" && -n "$lon" ]]; then
            printf '     %-11s : %s, %s\n' "Coords" "$lat" "$lon"
            printf '     %-11s : https://www.openstreetmap.org/?mlat=%s&mlon=%s#map=15/%s/%s\n' "Map (OSM)" "$lat" "$lon" "$lat" "$lon"
          fi
        elif [[ "$st" == "invalid" ]]; then
          printf '%s CEP inválido : %s (esperado 8 dígitos)\n' "$FAIL" "$cep"
        else
          printf '%s CEP não encontrado: %s (provider: %s)\n' "$ATT" "$cep" "$prov"
        fi
      done
      ;;
  esac
}

main() {
  need_cmd curl tr grep
  command -v jq >/dev/null 2>&1 && HAVE_JQ=1
  command -v python3 >/dev/null 2>&1 && HAVE_PY3=1

  [[ "$#" -eq 0 ]] && { show_help; exit 1; }

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)      show_help; exit 0 ;;
      -V|--version)   printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      -f|--file)      INPUT_FILE="${2:-}"; shift 2 ;;
      -p|--provider)  PROVIDER="${2:-auto}"; shift 2 ;;
      -q|--quiet)     QUIET=1; shift ;;
      --no-color)     NO_COLOR=1; shift ;;
      -o|--output)    FORMAT="${2:-table}"; shift 2 ;;
      --output=*)     FORMAT="${1#*=}"; shift ;;
      --*)            printf '[ERR] Unknown option: %s (use -h for help)\n' "$1" >&2; exit 1 ;;
      *)              TARGETS+=("$1"); shift ;;
    esac
  done

  case "$FORMAT" in
    table|json|csv) ;;
    *) printf '[ERR] Invalid output format: %s (expected table, json, or csv)\n' "$FORMAT" >&2; exit 1 ;;
  esac

  case "$PROVIDER" in
    auto|brasilapi|opencep|viacep) ;;
    *) printf '[ERR] Invalid --provider: %s (expected auto, brasilapi, opencep, or viacep)\n' "$PROVIDER" >&2; exit 1 ;;
  esac

  init_colors

  if [[ -n "$INPUT_FILE" ]]; then
    [[ -r "$INPUT_FILE" ]] || { printf '%s Cannot read file: %s\n' "$FAIL" "$INPUT_FILE" >&2; exit 1; }
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      line="${line%%#*}"
      line="$(printf '%s' "$line" | tr -d '[:space:]')"
      [[ -z "$line" ]] && continue
      TARGETS+=("$line")
    done < "$INPUT_FILE"
  fi

  [[ "${#TARGETS[@]}" -gt 0 ]] || { printf '%s No CEPs provided.\n' "$FAIL" >&2; exit 1; }

  local t
  for t in "${TARGETS[@]}"; do
    lookup_one "$t"
  done

  render_output
}

main "$@"
