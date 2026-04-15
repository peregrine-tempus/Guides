# OLAP vs. Data Lakes: Choosing the Right Azure Fabric Architecture
### A Decision Guide for Star Schema + SSAS Workloads in Microsoft Fabric

---

## Table of Contents

- [A Note on the Term "Semantic Model"](#a-note-on-the-term-semantic-model)

1. [Executive Summary](#1-executive-summary)
2. [What Your Business Has Actually Asked For](#2-what-your-business-has-actually-asked-for)
3. [The Two Paths](#3-the-two-paths)
   - [Path A: SQL-Native / OLAP-First](#path-a-sql-native--olap-first)
   - [Path B: Data Lake / Delta Lake with Notebooks](#path-b-data-lake--delta-lake-with-notebooks)
4. [How Power BI Connects to Each Path](#4-how-power-bi-connects-to-each-path)
5. [Honest Comparison: Which Path Fits You?](#5-honest-comparison-which-path-fits-you)
6. [My Recommendation](#6-my-recommendation)
7. [What About Your Azure Background?](#7-what-about-your-azure-background)
8. [Glossary of Microsoft Fabric Terms](#8-glossary-of-microsoft-fabric-terms)

---

## A Note on the Term "Semantic Model"

If you worked with SSAS and Power BI in earlier years, you will encounter this term constantly in Fabric documentation and it can be disorienting because Microsoft has used several different names for essentially the same concept over time. Here is the full lineage:

| Era | What It Was Called | What It Actually Was |
|---|---|---|
| SQL Server 2005–2016 | **SSAS Tabular model** | A compiled `.abf` / `.bim` project deployed to an Analysis Services instance; defined measures, KPIs, hierarchies, and relationships in DAX; Power BI connected via Live Connection |
| Power BI 2016–2021 | **Power BI Dataset** | The same Tabular engine embedded inside the Power BI service; you published a `.pbix` and its data model became a "dataset" others could connect to |
| Power BI / Fabric 2022–present | **Semantic Model** | Microsoft renamed "Dataset" to "Semantic Model" to better reflect its purpose — it is the *meaning layer* between raw data and reports |

**So a Semantic Model is not a new technology.** It is the modern name for what you already know as the SSAS Tabular model or Power BI Dataset. The engine underneath — VertiPaq (the columnar in-memory engine), the DAX language, the concept of measures, hierarchies, relationships, and row-level security — is identical. Only the name changed, and the hosting location moved from an on-premises SSAS server into the Fabric cloud service.

### What a Semantic Model Contains

Think of it as a translation layer that sits between your data store (Warehouse or Lakehouse) and your Power BI reports. It holds:

- **Tables and relationships** — which fact tables join to which dimension tables, and on what keys (this is your star schema expressed as a model, not just as SQL DDL)
- **Measures** — DAX calculations such as `Total Sales = SUM(FactSales[Amount])` or complex time-intelligence expressions like rolling 12-month averages
- **Hierarchies** — e.g., Year → Quarter → Month → Day, or Country → Region → Store, allowing drill-down in reports
- **KPIs** — measures with target values and status thresholds (green/yellow/red indicators)
- **Perspectives** — named subsets of the model exposed to specific user groups (e.g., a Finance perspective that hides Supply Chain tables)
- **Row-level security (RLS)** — DAX filter rules that restrict which rows a given user or role can see

### How It Relates to Your Platinum Layer

Your leadership asked for "OLAP cubes in SSAS consumed by Power BI." In the Fabric world, the **Semantic Model is the SSAS Tabular cube**. The workflow is:

```
Gold layer (Fabric Warehouse)     ← star schema tables live here, in T-SQL
          │
          ▼
   Semantic Model                  ← built on top of Gold; DAX measures, hierarchies, RLS
          │
          ▼
   Power BI Reports                ← connect via Live Connection; never touch the warehouse directly
```

Power BI report authors work entirely within the Semantic Model's vocabulary — they see friendly field names, pre-built measures, and drill-down hierarchies. They never write SQL or know what the underlying warehouse looks like. This separation of concerns — SQL for storage and loading, DAX for business logic, Power BI for visualization — is exactly the architecture your business has requested, and it maps 1:1 to what Fabric's Semantic Model delivers.

### One Semantic Model, Many Reports

A key design principle: you publish **one Semantic Model per subject area** (or one enterprise-wide model), and then many `.pbix` report files connect to it via **Live Connection**. The model is the single source of truth for business logic. If a measure definition changes, you update it in one place and every report that uses it reflects the change automatically. This is the same governance model you had with on-premises SSAS — it just lives in the cloud now.

---

## 1. Executive Summary

Your business leadership has requested:
- **Gold layer**: Star schema (relational dimensional model)
- **Platinum layer**: OLAP cubes built in SSAS, consumed by Power BI

Given those requirements, **Path A (SQL-Native / OLAP-First)** is the correct architectural choice. Microsoft Fabric is purpose-built for exactly this workload. The data lake / notebook path (Path B) is a valid alternative architecture, but it is optimized for different goals — large-scale data science, ML pipelines, and schema-flexible exploration — not for delivering structured star schemas and SSAS cubes to Power BI users.

That said, this document fully explains both paths so you can make an informed decision and anticipate questions from your team.

---

## 2. What Your Business Has Actually Asked For

Before comparing paths, it helps to name what each layer means in plain terms:

| Layer | What Leadership Asked For | What That Means Technically |
|---|---|---|
| **Bronze** | Raw ingestion | Unprocessed source data, minimal transformation |
| **Silver** | Cleansed / conformed | Standardized data types, deduplication, business keys resolved |
| **Gold** | Star schema | Fact and dimension tables in a relational model optimized for reporting |
| **Platinum** | OLAP cubes (SSAS) | Pre-aggregated, hierarchical measures built on top of Gold; consumed by Power BI via Live Connection or Direct Query |

The key insight: **Gold and Platinum are inherently relational and structured**. They are not schema-flexible workloads. This is the single most important factor in the architectural decision.

---

## 3. The Two Paths

### Path A: SQL-Native / OLAP-First

**Stack in Microsoft Fabric:**

```
On-Premises SQL 2022
        │
        ▼
  Data Factory (Fabric)          ← ETL / pipeline orchestration
        │
        ▼
  Fabric Lakehouse (Bronze/Silver) ← Optional: land raw files first
        │
        ▼
  Fabric Warehouse (Gold)         ← Dedicated SQL engine, T-SQL, star schema
        │
        ▼
  Analysis Services (SSAS)        ← Semantic model / OLAP cube
  or Fabric Semantic Model
        │
        ▼
  Power BI (Platinum consumers)   ← Live Connection / Direct Lake
```

**Key components:**

- **Microsoft Fabric Warehouse**: A fully managed, serverless T-SQL engine. You write DDL (`CREATE TABLE`, `ALTER TABLE`) and DML (`INSERT`, `MERGE`) exactly as you do in SQL Server today. This is where your star schema lives.
- **Fabric Data Factory**: The evolution of Azure Data Factory — same concepts, integrated directly into Fabric. Pipelines, data flows, copy activities. You will recognize it immediately.
- **Fabric Semantic Model (formerly Power BI Dataset / SSAS Tabular)**: This is Microsoft's current direction for "Platinum." It replaces the need for a separately deployed SSAS instance by embedding a Tabular model directly in Fabric. It supports DAX measures, hierarchies, perspectives, and relationships — everything SSAS Tabular offers.
- **Direct Lake Mode**: A Power BI connection mode unique to Fabric. Rather than importing data into a Power BI dataset or issuing SQL queries at report time, Direct Lake reads directly from the underlying Delta/Parquet files in the Lakehouse at near-import speed. This is the "streamlined Power BI" that makes Fabric compelling.

**What this path feels like day-to-day:**
You write T-SQL against the Fabric Warehouse to build and load your star schema. You then build a Semantic Model on top of it in Power BI Desktop or the Fabric portal, define your measures and hierarchies in DAX, and publish. Power BI reports connect via Live Connection. It is very close to the on-premises SSAS + Power BI workflow your business already understands.

---

### Path B: Data Lake / Delta Lake with Notebooks

**Stack in Microsoft Fabric:**

```
On-Premises SQL 2022
        │
        ▼
  Data Factory (Fabric)          ← Ingestion pipelines
        │
        ▼
  Fabric Lakehouse (OneLake)      ← All layers stored as Delta/Parquet
        │
        ▼
  Spark Notebooks / Dataflows     ← Transformations written in PySpark or SQL
        │
        ▼
  Delta Tables (Gold layer)       ← Queryable via SQL endpoint
        │
        ▼
  Semantic Model / Power BI       ← Connect via SQL endpoint or Direct Lake
```

**Key components:**

- **OneLake / Fabric Lakehouse**: A single unified storage layer. Every Fabric workspace has one OneLake backed by Azure Data Lake Storage Gen2 under the hood. Files are stored as Delta format (Parquet + transaction log). This is spiritually identical to your ADLSv2 + container experience — just abstracted.
- **Spark Notebooks**: PySpark or Spark SQL notebooks for transformation logic. This is the notebook-as-transformer pattern you know from Databricks.
- **Delta Tables**: Open-format tables registered in the Lakehouse metastore. They are queryable via a built-in SQL Analytics Endpoint (T-SQL, read-only) — no separate database needed.
- **Dataflows Gen2**: A low-code Power Query-based alternative to notebooks, suitable for simpler transformations without Spark overhead.

**What this path feels like day-to-day:**
You land data into the Lakehouse as Parquet/Delta files, transform it using Spark notebooks (PySpark or SQL), and register the results as Delta tables. Power BI then connects to those tables either via the SQL Analytics Endpoint or via Direct Lake mode. There is no dedicated SQL engine for write operations — the Warehouse is separate from the Lakehouse SQL endpoint.

---

## 4. How Power BI Connects to Each Path

This is frequently misunderstood, so it deserves its own section.

### Connection Modes (applies to both paths)

| Mode | How It Works | Best For |
|---|---|---|
| **Import** | Data is copied into Power BI's in-memory engine (VertiPaq) at refresh time | Small-to-medium datasets, fastest query performance |
| **DirectQuery** | Every visual issues a live SQL query to the source at render time | Large datasets, real-time requirements; slower than Import |
| **Live Connection** | Power BI connects to a Semantic Model (SSAS or Fabric Semantic Model); no data is stored in the .pbix file | Centralized semantic layer, enterprise-scale |
| **Direct Lake** | Fabric-exclusive; reads Delta/Parquet files directly without import or SQL translation | Large Fabric datasets; combines Import speed with DirectQuery freshness |

### Path A — How Power BI Connects

1. Power BI Desktop or the Fabric portal connects to the **Fabric Semantic Model** via **Live Connection**.
2. The Semantic Model reads from the **Fabric Warehouse** (Gold star schema) using an internal columnar cache.
3. Report users never write SQL — they drag fields from the model.
4. For your "Platinum = OLAP cubes" requirement: the Fabric Semantic Model is the direct replacement for SSAS Tabular in the cloud. If you specifically need SSAS Multidimensional (MDX cubes, not Tabular), that requires a separately hosted SSAS instance in Azure VM — Fabric does not natively host Multidimensional. Tabular is the modern equivalent and is fully supported.

### Path B — How Power BI Connects

Power BI has **three options** to reach Delta tables in a Fabric Lakehouse:

1. **Direct Lake** (recommended): Power BI reads the Delta Parquet files directly from OneLake. No data movement. Near-import speed. Requires the data to be registered as Delta tables in a Lakehouse, and requires a Fabric capacity (F-SKU or P-SKU). This is the "streamlined Power BI" story.

2. **SQL Analytics Endpoint** (DirectQuery fallback): Every Lakehouse automatically exposes a read-only T-SQL endpoint. Power BI can connect via DirectQuery to this endpoint. Performance is acceptable for moderate data sizes but slower than Direct Lake or Import.

3. **Import via Dataflow**: A Dataflow Gen2 or pipeline reads the Delta tables and pushes data into a Power BI Import dataset. This is the traditional approach and works fine but adds a refresh step.

> **Key takeaway for Path B and Power BI**: The connection works well — Direct Lake in particular is impressive — but you are still building a SQL-queryable layer on top of Delta files. For a star schema specifically, this means your Spark notebooks must produce well-structured, well-named Delta tables that mirror what you would have built in a relational warehouse anyway. The notebook approach does not eliminate the need for dimensional modeling discipline; it just changes *where* that modeling happens (Spark vs. T-SQL).

---

## 5. Honest Comparison: Which Path Fits You?

| Dimension | Path A: SQL-Native | Path B: Lake / Notebooks |
|---|---|---|
| **Matches business requirements** | ✅ Direct fit — star schema + SSAS = SQL-native workload | ⚠️ Achievable but indirect — requires discipline to produce star schema outputs from notebooks |
| **T-SQL familiarity** | ✅ Identical to SQL Server 2022 experience | ⚠️ Transformations in PySpark or Spark SQL; SQL endpoint is read-only |
| **Power BI integration** | ✅ Live Connection to Semantic Model is the standard enterprise pattern | ✅ Direct Lake is excellent; SQL endpoint is adequate |
| **SSAS / Semantic Model** | ✅ Fabric Semantic Model is the native replacement for SSAS Tabular | ⚠️ Same Semantic Model is used, but built on top of Lake tables vs. Warehouse tables |
| **Operational complexity** | ✅ Lower — no Spark cluster management, no notebook orchestration | ⚠️ Higher — Spark sessions, notebook dependencies, Delta table maintenance (OPTIMIZE, VACUUM) |
| **Governance / lineage** | ✅ Clear SQL DDL, schema-enforced tables | ⚠️ Schema-on-read; discipline required to avoid "swamp" drift |
| **Your team's skillset** | ✅ SQL Server DBAs and BI developers can adopt quickly | ⚠️ Requires Spark/Python familiarity; steeper learning curve for SQL-centric teams |
| **Scalability ceiling** | ⚠️ Fabric Warehouse scales well but has limits vs. Spark for massive raw data volumes | ✅ Spark / Delta handles very large data volumes natively |
| **Cost profile** | ✅ Predictable — Fabric capacity units (CUs) consumed by SQL workloads | ⚠️ Spark sessions consume CUs even when idle; can be higher for bursty workloads |
| **Relevant to your current approval** | ✅ Fully supported in a trial Fabric workspace with personal workspace access | ✅ Also supported in trial, but Spark pool warm-up adds friction to POC iteration speed |

---

## 6. My Recommendation

**Use Path A (SQL-Native) for this engagement.**

Here is the reasoning:

1. **Your requirements are explicitly relational.** Star schema in Gold and OLAP cubes in Platinum are not lake-native concepts — they are the output of a data modeling discipline that maps cleanly to SQL engines. There is no advantage to routing that work through Parquet files and Spark notebooks when a SQL Warehouse is available and purpose-built for it.

2. **Your team will adopt faster.** SQL Server 2022 skills transfer almost entirely to the Fabric Warehouse. DDL is T-SQL. Procedures, views, and merge patterns all work. The learning curve is Fabric concepts and tooling, not a new programming language.

3. **Power BI's ideal connection for this workload is Live Connection to a Semantic Model**, which is what Path A delivers. Semantic Models built on Warehouse tables have full access to DAX, calculation groups, hierarchies, and row-level security — all the features your Power BI report authors expect from an SSAS-backed model.

4. **The Fabric Semantic Model is the strategic replacement for SSAS Tabular.** Microsoft is investing heavily here. If your Platinum requirement is for Tabular-style cubes (measures, KPIs, hierarchies, MDX/DAX queries), the Fabric Semantic Model satisfies this natively in the cloud without a separately managed SSAS VM.

5. **Your POC will be faster and cleaner.** In a trial personal workspace, standing up a Fabric Warehouse, loading a simple star schema, and connecting Power BI is a matter of hours. A notebook-based pipeline requires Spark session management, Delta table registration, and schema coordination that adds days of setup before you can show meaningful results.

### One Important Caveat on "Platinum = SSAS Cubes"

If your leadership specifically means **SSAS Multidimensional** (the classic cube format using MDX, dimension hierarchies stored as `.cube` files, and cube browser in SQL Server Management Studio), that is **not natively supported in Microsoft Fabric**. Fabric supports only the **Tabular** model, which is the modern successor to Multidimensional.

If Multidimensional is a hard requirement, you would need an **Azure Analysis Services** instance or an **SSAS on Azure VM** to host it, with the Fabric Warehouse feeding it via a pipeline. Power BI still connects cleanly in that scenario — it has connected to SSAS Multidimensional for years.

**Recommendation**: In your POC, build the Platinum layer as a Fabric Semantic Model (Tabular). Present it to leadership as "SSAS Tabular in the cloud — same DAX measures, same hierarchies, same Power BI Live Connection." If they insist on Multidimensional MDX, the conversation shifts to Azure Analysis Services rather than Fabric-native components.

---

## 7. What About Your Azure Background?

Your existing experience in Synapse Analytics, Data Factory, Databricks, ADLSv2, Parquet, and Spark notebooks is not wasted — it is directly translatable to Fabric concepts. Here is the mapping:

| Your Experience | Microsoft Fabric Equivalent | Notes |
|---|---|---|
| Azure Data Lake Storage Gen2 | **OneLake** | Fabric's unified storage; same ABFS protocol underneath |
| ADLSv2 Containers | **Workspaces + Lakehouses** | Workspace ≈ container scope; Lakehouse ≈ filesystem within it |
| Parquet files | **Delta tables** | Delta = Parquet + transaction log; default format in Fabric Lakehouse |
| Databricks Spark Notebooks | **Fabric Notebooks** | Same PySpark runtime; slightly different UI and spark session management |
| Azure Data Factory | **Fabric Data Factory** | Pipelines, Copy Activity, Data Flows — same concepts, integrated into Fabric portal |
| Synapse Analytics SQL Pool | **Fabric Warehouse** | Dedicated T-SQL engine; similar DDL/DML patterns |
| Synapse Serverless SQL | **Lakehouse SQL Analytics Endpoint** | Read-only T-SQL over Delta files; auto-provisioned |
| Synapse Link / Live Data | **Direct Lake** | Fabric's version of zero-copy Power BI reads |

Your background is actually an asset in a hybrid POC — you can articulate *why* the SQL-native path is the right choice for the current requirements, while demonstrating that you understand the lake path if the organization's needs evolve toward data science or ML in the future.

---

## 8. Glossary of Microsoft Fabric Terms

For reference as you navigate the Fabric portal during your POC:

| Term | Definition |
|---|---|
| **Microsoft Fabric** | Microsoft's unified analytics platform combining Data Factory, Synapse, Power BI, and Data Science into a single SaaS product |
| **OneLake** | The single unified storage layer for all Fabric items; backed by ADLS Gen2; one per Fabric tenant |
| **Lakehouse** | A Fabric item combining a Delta/Parquet file store with an auto-provisioned SQL Analytics Endpoint |
| **Fabric Warehouse** | A dedicated, serverless T-SQL engine within Fabric; supports DDL/DML; separate from Lakehouse |
| **SQL Analytics Endpoint** | Auto-provisioned read-only T-SQL endpoint on every Lakehouse; no write operations |
| **Semantic Model** | The current Microsoft name for what was previously called a "Power BI Dataset" and before that an "SSAS Tabular model." It is the business logic and meaning layer between your data store and Power BI reports — contains DAX measures, relationships, hierarchies, KPIs, perspectives, and row-level security. The underlying engine (VertiPaq + DAX) is unchanged from SSAS Tabular. |
| **Direct Lake** | A Power BI connection mode that reads Delta Parquet files from OneLake directly, bypassing import and SQL translation |
| **Capacity Units (CUs)** | The billing and resource unit for Fabric; consumed by all workloads (SQL, Spark, pipelines, reports) |
| **F-SKU** | A Fabric-specific capacity SKU (F2, F4, F8... F2048); required for Direct Lake and most Fabric features |
| **Workspace** | A collaboration and governance boundary in Fabric; analogous to a project or team scope |
| **Medallion Architecture** | A layered data design pattern: Bronze (raw) → Silver (cleansed) → Gold (modeled) — and in your case, Platinum (semantic/OLAP) |

---

*Document prepared as a decision guide for Fabric POC planning. Intended audience: Data Warehouse Architect evaluating Gold/Platinum layer placement in Microsoft Fabric.*
