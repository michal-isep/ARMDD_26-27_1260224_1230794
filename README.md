# ARMDD 2026/27 – MoreRhythm Data Mart

Practical work for **Armazéns de Dados** (MSc in Informatics Engineering, ISEP).
Data mart for the sales (billing) of MoreRhythm, SA, built with SQL Server 2025, Integration Services and Power BI.

| Student | Number | GitHub |
|---|---|---|
| Person A | 1260224 | @michal-isep |
| Person B | 1230794 | @afsg13 |

## Repository structure

| Folder | Content | Owner |
|---|---|---|
| `SQL_Scripts/` | `01_Data_Profiling.sql`, `02_Create_Staging_Tables.sql`, `03_Create_DataMart_Tables.sql` | A: 01, 02 · B: 03 |
| `Design_Diagrams/` | 3-tier architecture diagram, star schema diagram (`.drawio` + `.png`) | A: architecture · B: star schema |
| `Documentation/` | report sections, data dictionary, mapping matrix, final report (PDF) | both |
| `SSIS/` | Integration Services project `MoreRhythm_ETL` (parameters, connection managers, packages) | A (setup), both (Part 2) |

## Databases (one SQL Server instance)

| Database | Role |
|---|---|
| `MoreRhythm` | operational system (source) |
| `MoreRhythm_StagingArea` | staging area: `stg_*`, `stg_*DQP`, `*_Lookup`, `etl_*` tables |
| `MoreRhythm_DataMart` | data mart: `FactSales`, `FactCurrencyRate`, dimensions |

Run the SQL scripts in numeric order in SSMS.

## Workflow

* `main` holds the reviewed version. Nobody commits to it directly.
* Each issue on the **PART1** board has its own branch: `feature/<issue-code>-<short-name>` (e.g. `feature/A1-data-profiling`).
* Work is merged through a pull request that references the issue (`Closes #n`) and is reviewed by the other member.

## Deadlines

* Part 1 (report PDF `1260224_1230794.pdf`): **15 Nov 2026, 23:59**
* Part 2 (final report + Integration Services + Analysis Services projects, ZIP): **13 Dec 2026, 23:59**
