# cep-cli — Brazilian Postal Code (CEP) Lookup CLI (`cep.sh`)

🇺🇸 **English** | 🇧🇷 [Português (BR)](README-ptbr.md) | 🇪🇸 [Español](README-es.md)

[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/cep-cli/releases) [![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

![cep-cli Cover](cep-cli-cover.webp)

`cep.sh` is a lightweight Bash CLI for looking up Brazilian postal codes (CEPs) with an automatic multi-provider HTTPS fallback chain: **BrasilAPI v2** (with coordinates, IBGE & timezone) -> **OpenCEP** -> **ViaCEP**. Supports single and batch lookups (`--file`), strict 8-digit validation, and structured `table`, `json`, and `csv` outputs.

> **Historical Credits:** Refactored from the original 2012 `cep.sh` script by **Percio Andrade (Percio Castelo)** (which originally queried the now-defunct `cep.correiocontrol.com.br` endpoint).

## Key Features

- **Resilient 3-Provider Fallback Chain (`--provider auto`):** queries **BrasilAPI v2**, automatically falling back to **OpenCEP** and **ViaCEP** on timeouts or missing records (or pin a specific provider with `--provider brasilapi|opencep|viacep`).
- **Batch & File Support:** pass multiple CEPs on the CLI or load a list via `-f/--file ceps.txt` (ignoring blank lines and `#` comments).
- **Rich Metadata:** street, neighborhood, city, state (UF), IBGE code, timezone, coordinates, and OpenStreetMap link (when returned by BrasilAPI v2).
- **Structured Outputs:** `-o table|json|csv`, `-q/--quiet`, `--no-color`, `-V/--version`, `-h/--help`.

## Installation

```bash
git clone https://github.com/sr00t3d/cep-cli.git
cd cep-cli
chmod +x cep.sh
sudo install -m 0755 cep.sh /usr/local/bin/cep
```

## Usage

```bash
cep 01001-000
cep 01001000 90250210
cep --provider opencep -o json 01001-000
cep --provider viacep -o csv 01001000 90250210
cep --file ceps.txt -o json
```

## Real Output Example

### Table Output (`cep.sh --no-color 01001-000`)

```text
=====================================================================
 cep.sh v2.0.0 | Brazilian CEP Lookup | 2026-11-21T02:44:20Z
=====================================================================

[OK] CEP         : 01001-000 (provider: opencep)
     Logradouro  : Praça da Sé
     Bairro      : Sé
     Cidade/UF   : São Paulo / SP
     IBGE        : 3550308
```

### Batch CSV Output (`cep.sh --provider viacep -o csv 01001000 90250210`)

```csv
cep,status,provider,street,neighborhood,city,state,ibge,latitude,longitude,timezone
"01001-000","found","viacep","Praça da Sé","Sé","São Paulo","SP","3550308","","",""
"90250-210","found","viacep","Avenida Palmira Gobbi","Humaitá","Porto Alegre","RS","4314902","","",""
```

## License

Licensed under the [Apache License 2.0](LICENSE).

## Windows (PowerShell `cep.ps1`)

Zero external dependencies — works natively on **Windows PowerShell 5.1** and **PowerShell 7+**:

```powershell
.\cep.ps1 01001-000
.\cep.ps1 -Provider opencep 69042-500
.\cep.ps1 01001-000 90250-210 -Output csv
.\cep.ps1 -File ceps.txt -Output json
```
