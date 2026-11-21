# cep-cli — Consulta de CEP Brasileiro no Terminal (`cep.sh`)

🇺🇸 [English](README.md) | 🇧🇷 **Português (BR)** | 🇪🇸 [Español](README-es.md)

[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/cep-cli/releases) [![Shell](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

`cep.sh` é uma CLI leve em Bash para consultar CEPs brasileiros no terminal com cadeia automática de fallback HTTPS entre **BrasilAPI v2** (com coordenadas, IBGE e fuso horário) -> **OpenCEP** -> **ViaCEP**. Suporta consultas individuais ou em lote (`--file`), validação estrita de 8 dígitos e saídas em `table`, `json` e `csv`.

> **Créditos Históricos:** Refatorado do script `cep.sh` original de 2012 de **Percio Andrade (Percio Castelo)** (que consultava o antigo `cep.correiocontrol.com.br`).

## Principais Recursos

- **Fallback Automático em 3 Provedores (`--provider auto`):** consulta **BrasilAPI v2**, recorrendo automaticamente ao **OpenCEP** e **ViaCEP** em caso de timeout ou CEP ausente (ou escolha um provedor fixo via `--provider brasilapi|opencep|viacep`).
- **Suporte a Lote e Arquivo:** informe vários CEPs na linha de comando ou leia de um arquivo com `-f/--file ceps.txt`.
- **Metadados Completos:** logradouro, bairro, cidade, UF, código IBGE, fuso horário, coordenadas e link do OpenStreetMap.
- **Saídas Estruturadas:** `-o table|json|csv`, `-q/--quiet`, `--no-color`, `-V/--version`, `-h/--help`.

## Instalação

```bash
git clone https://github.com/sr00t3d/cep-cli.git
cd cep-cli
chmod +x cep.sh
sudo install -m 0755 cep.sh /usr/local/bin/cep
```

## Uso

```bash
cep 01001-000
cep 01001000 90250210
cep --provider opencep -o json 01001-000
cep --provider viacep -o csv 01001000 90250210
cep --file ceps.txt -o json
```

## Exemplo de Saída Real

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

## Licença

Licenciado sob a [Apache License 2.0](LICENSE).
