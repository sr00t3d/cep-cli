# cep-cli — Consulta de Código Postal Brasileño CEP (`cep.sh`)

🇺🇸 [English](README.md) | 🇧🇷 [Português (BR)](README-ptbr.md) | 🇪🇸 **Español**

[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/cep-cli/releases) [![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

![Portada cep-cli](cep-cli-cover.webp)

`cep.sh` es una CLI en Bash para consultar códigos postales brasileños (CEP) con cadena automática de respaldo HTTPS entre **BrasilAPI v2** -> **OpenCEP** -> **ViaCEP**, soporte por lotes (`--file`) y salidas en `table`, `json` y `csv`.

> **Créditos Históricos:** Refactorizado del script original `cep.sh` de 2012 de **Percio Andrade (Percio Castelo)**.

## Uso

```bash
cep 01001-000
cep 01001000 90250210
cep --provider opencep -o json 01001-000
cep --file ceps.txt -o csv
```

## Licencia

Licenciado bajo la [Apache License 2.0](LICENSE).

## Windows (PowerShell `cep.ps1`)

Cero dependencias externas — funciona de forma nativa en **Windows PowerShell 5.1** y **PowerShell 7+**:

```powershell
.\cep.ps1 01001-000
.\cep.ps1 -Provider opencep 69042-500
.\cep.ps1 01001-000 90250-210 -Output csv
.\cep.ps1 -File ceps.txt -Output json
```
