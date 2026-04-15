# Microsoft Fabric Gold & Platinum layers: a complete setup guide for SQL Server architects

**Microsoft Fabric can host your star schema Gold layer as a full read-write Warehouse and your Platinum OLAP layer as a Direct Lake semantic model — but the migration path from on-prem SQL Server requires careful planning.** The most critical finding: Fabric Warehouse does **not** support .bacpac import natively. Instead, Microsoft's own Migration Assistant (using a .dacpac file) is the recommended schema migration tool, with COPY INTO or Data Pipelines handling data movement. This guide walks through every step from workspace creation to a working Power BI semantic model, using current Fabric terminology and documentation as of early 2026.

Your architecture — Bronze/Silver on-prem (MSSQL 2022 + SSIS) feeding a Gold Warehouse and Platinum semantic model in Fabric — aligns perfectly with Microsoft's documented "Pattern 2" medallion architecture. Below are the five parts, written for someone who thinks in T-SQL and SSAS tabular but has never opened the Fabric portal.

---

## Part 1: Understanding Fabric workspaces and capacity

### What a workspace actually is

A Fabric **workspace** is the top-level collaborative container where all your items live — warehouses, lakehouses, semantic models, reports, pipelines, notebooks, and dataflows. Think of it as a project folder backed by OneLake (Microsoft's unified data lake). Fabric workspaces are a direct evolution of Power BI workspaces, extended with new data engineering and warehousing capabilities. Every workspace maps to a single capacity, and role-based access (Admin, Member, Contributor, Viewer) controls who can do what.

Each workspace can hold up to **1,000 items** total (parent and child items combined). For your architecture, the items you'll create include a Fabric Warehouse (Gold), one or more semantic models (Platinum), and Power BI reports.

### How capacity and licensing work

Fabric runs on **capacity units (CUs)**. You purchase an F-SKU through Azure (F2, F4, F8… up to F2048), and that capacity backs one or more workspaces. Key F-SKU characteristics: pay-as-you-go billing (per-second), ability to pause/resume, and scale up/down at any time.

Your **Trial capacity** provides **64 CUs** — equivalent to an **F64 SKU** — for **60 days**, with up to **1 TB of OneLake storage**. This is substantial: F64 maps to 8 v-cores and is the threshold where viewers with a free Power BI license can consume reports without needing Pro licenses. The trial supports all Fabric workloads including Warehouse, Data Factory pipelines, semantic models, and notebooks.

**Trial limitations to watch for:**

- **Copilot and AI experiences** are not available on trial capacity
- **Private Link** is disabled
- **Trusted Workspace Access** is not supported
- When the trial ends, non-Power BI items become inactive; content persists in OneLake for **7 days** and can be reactivated by assigning a paid capacity
- Each user gets one trial; tenants have a limited total number of trial capacities

On F-SKUs below F64, every user creating or consuming content needs a **Power BI Pro** (or PPU/individual trial) license. Since your trial maps to F64, viewers with a free license can view reports — but confirm this behavior on trial capacity specifically, as some licensing nuances differ from paid F64.

### Recommended workspace organization

Microsoft documents three patterns for medallion architecture workspace layout. For your scenario (Bronze/Silver on-prem, Gold + Platinum in Fabric), the simplest approach is **one workspace containing both the Gold Warehouse and Platinum semantic models/reports**. This keeps everything under a single security boundary, enables cross-item references, and minimizes complexity on a trial account.

If you later separate responsibilities (e.g., a data engineering team managing Gold, a BI team managing Platinum), you can split into two workspaces — one for the Warehouse, one for semantic models and reports. Microsoft explicitly recommends this when different teams own different layers. For now, a single workspace is practical and sufficient.

**Key documentation:**
- Workspaces overview → `learn.microsoft.com/en-us/fabric/fundamentals/workspaces`
- Licensing & SKUs → `learn.microsoft.com/en-us/fabric/enterprise/licenses`
- Trial capacity → `learn.microsoft.com/en-us/fabric/fundamentals/fabric-trial`
- Medallion architecture patterns → `learn.microsoft.com/en-us/fabric/onelake/onelake-medallion-lakehouse-architecture`

---

## Part 2: Creating a Fabric Warehouse for your Gold star schema

### Why Warehouse and not Lakehouse

This is the most important architectural decision, and for a SQL-first star schema workload, **Warehouse is unambiguously the right choice**. Microsoft's own documentation states: *"The ideal use cases for Fabric Data Warehouse are star or snowflake schemas, curated corporate data marts, governed semantic models for business intelligence."*

The core differences:

| Capability | Fabric Warehouse | Lakehouse SQL analytics endpoint |
|---|---|---|
| **DML operations** | Full INSERT, UPDATE, DELETE, MERGE | Read-only (data changes via Spark only) |
| **DDL operations** | Full CREATE TABLE, ALTER TABLE, etc. | Views and functions only |
| **Transactions** | Full multi-table ACID | None through SQL endpoint |
| **Developer persona** | SQL developers, BI architects | Spark/data engineers |
| **Best for** | Star schema, data marts, curated BI | Unstructured data, Spark pipelines |

Both store data as **Delta Parquet** on OneLake and share the same underlying SQL engine. Both expose a TDS endpoint on port 1433. But only the Warehouse gives you full read-write T-SQL — essential for maintaining dimension tables, SCD patterns, and fact table loads via SQL.

### Step-by-step: creating the Warehouse

1. Open the Fabric portal (`app.fabric.microsoft.com`) and navigate to your workspace
2. Click **+ New item** in the workspace toolbar
3. Under the **"Store data"** section, select **Warehouse**
4. Enter a name (e.g., `GoldWarehouse`) and click **Create**
5. An empty warehouse opens in the web-based SQL editor, ready for DDL and data loading

The Warehouse immediately provisions a **TDS endpoint** (SQL connection string) you can use from SSMS, Azure Data Studio, or any ODBC/JDBC client. Find it under the Warehouse's **Settings → Connection strings** page. The format is: `<unique-id>.datawarehouse.fabric.microsoft.com`, using **TCP port 1433** with **Microsoft Entra ID authentication only** (no SQL auth).

### What the SQL analytics endpoint means for you

Every Warehouse and Lakehouse in Fabric automatically exposes a SQL analytics endpoint — a read-only TDS interface for querying. For your Warehouse, this matters less (you'll use the full read-write endpoint), but it's relevant because you can run **cross-database queries** between your Warehouse and any Lakehouse in the same workspace using three-part naming (`DatabaseName.SchemaName.TableName`). This is useful if you ever stage data through a Lakehouse.

**Key documentation:**
- Create a Warehouse → `learn.microsoft.com/en-us/fabric/data-warehouse/create-warehouse`
- Warehouse vs Lakehouse decision guide → `learn.microsoft.com/en-us/fabric/fundamentals/decision-guide-lakehouse-warehouse`
- Connectivity & TDS endpoint → `learn.microsoft.com/en-us/fabric/data-warehouse/connectivity`

---

## Part 3: Getting your on-prem data into Fabric — the .bacpac question

### The critical finding: .bacpac import is NOT supported

**Fabric Warehouse does not support .bacpac import.** This is confirmed by Microsoft's documentation and community responses. The Warehouse is architecturally different from SQL Server or Azure SQL Database — it stores data as Delta Parquet files, not MDF/LDF, and the SqlPackage `import` action does not work against the Warehouse TDS endpoint.

A separate product called **Fabric SQL Database** (a transactional OLTP database based on Azure SQL Database) does support .bacpac via SqlPackage, but that is not what you want for an analytical star schema.

### Recommended migration path: DACPAC + Migration Assistant for schema, then pipeline or COPY INTO for data

For a one-time migration from SQL Server 2022, the best approach splits into **schema migration** and **data migration** as separate steps.

#### Step 1 — Migrate the schema using Migration Assistant with a DACPAC

The **Fabric Migration Assistant** is a built-in tool specifically designed for SQL Server → Fabric Warehouse migrations. It accepts a **.dacpac** file (schema-only extract, unlike .bacpac which includes data) and automatically translates T-SQL to Fabric-compatible syntax.

**Extract the DACPAC from your on-prem database:**

```
sqlpackage /action:Extract ^
  /sourceconnectionstring:"Server=YourServer;Database=YourGoldDB;Trusted_Connection=True" ^
  /targetfile:"C:\Migration\GoldDB.dacpac"
```

**Import via Migration Assistant:**

1. Open your Fabric Warehouse in the portal
2. Click the **Migrate** button in the ribbon
3. Select **"Analytical T-SQL warehouse or database"**
4. Upload the `.dacpac` file
5. The Migration Assistant analyzes the schema and **automatically converts** unsupported constructs:
   - `datetime` → `datetime2`
   - `nvarchar` → `varchar` (UTF-8)
   - `money` → `decimal`
   - Removes indexes (not needed in Fabric)
   - Converts constraint syntax to `NOT ENFORCED`
6. Review the migration summary — fix any flagged issues (AI-powered Copilot can help on paid capacity)
7. Confirm to create all objects in the Warehouse

**Documentation:** `learn.microsoft.com/en-us/fabric/data-warehouse/migrate-with-migration-assistant`

#### Step 2 — Migrate the data

You have three practical options for the data itself, ranked by simplicity:

**Option A: COPY INTO from Parquet or CSV files (highest throughput, recommended for larger datasets)**

1. Export your on-prem tables to **Parquet** or **CSV** files (use BCP, SSIS, or Azure Data Studio on-prem)
2. Upload the files to **Azure Blob Storage** or **ADLS Gen2**
3. In the Fabric Warehouse SQL editor (or SSMS), run COPY INTO for each table:

```sql
COPY INTO dbo.DimCustomer
FROM 'https://yourstorage.blob.core.windows.net/container/DimCustomer.parquet'
WITH (FILE_TYPE = 'PARQUET');
```

Authentication options include SAS token, Storage Account Key, or Entra ID. Parquet format is preferred over CSV for type fidelity and performance.

**Option B: Fabric Data Pipeline with on-premises data gateway (most automated)**

1. Install the **on-premises data gateway** (v3000.214.2+) on a machine that can reach your SQL Server
2. Register the gateway in Fabric: **Settings → Manage connections and gateways**
3. Create a **Data Pipeline** or **Copy Job** in Fabric: Source = SQL Server (via gateway), Destination = Fabric Warehouse

⚠️ **Important caveat:** When the destination is a Fabric Warehouse, the pipeline uses COPY INTO internally, which requires **staging through Azure Blob Storage or ADLS Gen2**. You must configure an external Azure Storage account as the staging area. Alternatively, you can pipeline data into a **Lakehouse** first (no staging needed), then use a cross-database `INSERT INTO ... SELECT` to move it to the Warehouse.

**Option C: Use the Migration Assistant's built-in Copy Job**

After completing the schema migration (Step 1), the Migration Assistant can initiate a **Copy Job** in Fabric Data Factory to move data from your source SQL Server. This requires an on-premises data gateway. This is the most integrated option but requires gateway setup.

**Documentation:**
- COPY INTO → `learn.microsoft.com/en-us/fabric/data-warehouse/ingest-data-copy`
- Data pipelines → `learn.microsoft.com/en-us/fabric/data-warehouse/ingest-data-pipelines`
- On-prem gateway → `learn.microsoft.com/en-us/fabric/data-factory/how-to-access-on-premises-data`
- Data ingestion overview → `learn.microsoft.com/en-us/fabric/data-warehouse/ingest-data`

### Why not use the .bacpac at all?

For your scenario, the DACPAC (schema) + COPY INTO (data) path is cleaner than trying to route through a .bacpac. The .bacpac combines schema and data into a single file optimized for Azure SQL Database's architecture — it has no value in the Fabric Warehouse ecosystem. Extract schema separately (DACPAC), export data separately (Parquet/CSV), and load each using the right tool.

---

## Part 4: Building the Gold star schema in Fabric Warehouse

### Creating dimension and fact tables

The Fabric Warehouse SQL editor supports standard T-SQL DDL. If you used the Migration Assistant, your tables already exist. If building from scratch, here's the pattern:

```sql
-- Date dimension
CREATE TABLE dbo.DimDate (
    DateKey        INT          NOT NULL,
    FullDate       DATE         NOT NULL,
    CalendarYear   INT          NOT NULL,
    CalendarQuarter SMALLINT    NOT NULL,
    MonthNumber    SMALLINT     NOT NULL,
    MonthName      VARCHAR(20)  NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY NONCLUSTERED (DateKey) NOT ENFORCED
);

-- Product dimension with surrogate key
CREATE TABLE dbo.DimProduct (
    ProductSK      BIGINT IDENTITY,  -- surrogate key (BIGINT only)
    ProductCode    VARCHAR(50)  NOT NULL,
    ProductName    VARCHAR(200) NOT NULL,
    Category       VARCHAR(100),
    CONSTRAINT PK_DimProduct PRIMARY KEY NONCLUSTERED (ProductSK) NOT ENFORCED
);

-- Fact table
CREATE TABLE dbo.FactSales (
    DateKey        INT          NOT NULL,
    ProductSK      BIGINT       NOT NULL,
    Quantity       INT          NOT NULL,
    SalesAmount    DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_Sales_Date FOREIGN KEY (DateKey)
        REFERENCES dbo.DimDate (DateKey) NOT ENFORCED,
    CONSTRAINT FK_Sales_Product FOREIGN KEY (ProductSK)
        REFERENCES dbo.DimProduct (ProductSK) NOT ENFORCED
);
```

### Ten things a SQL Server architect must know

These are the most impactful differences from on-prem SQL Server:

1. **IDENTITY is BIGINT only** — no `INT IDENTITY`, no custom SEED or INCREMENT, no `IDENTITY_INSERT`. If your existing surrogate keys are `INT`, use `BIGINT` in Fabric and accept the wider data type, or manage key assignment in your ETL logic.

2. **All constraints are NOT ENFORCED** — PRIMARY KEY, FOREIGN KEY, and UNIQUE constraints exist as metadata hints for the query optimizer and Power BI relationship auto-detection. They do **not** reject invalid data. Your ETL must enforce referential integrity.

3. **No indexes exist or are needed** — Fabric uses automatic columnar storage, statistics, and a new `CLUSTER BY` clause (up to 4 columns) for performance tuning. There are no clustered or non-clustered indexes to create.

4. **Data type mapping required** — `datetime` → `datetime2`, `nvarchar` → `varchar` (UTF-8 handles Unicode), `money` → `decimal`, `tinyint` → `smallint`. No `xml`, `geography`, `geometry`, `sql_variant`, or `hierarchyid`.

5. **Case-sensitive collation by default** — The default collation is `Latin1_General_100_BIN2_UTF8`. Column name `CustomerID` and `customerid` are different. A case-insensitive option exists but must be set at warehouse creation via REST API.

6. **ALTER TABLE is severely limited** — You can only ADD nullable columns, DROP columns, or ADD/DROP constraints with NOT ENFORCED. No `ALTER COLUMN` to change types.

7. **Stored procedures and views are fully supported** — Use them freely for your transformation logic.

8. **Snapshot isolation only** — All transactions use snapshot isolation. You cannot change the isolation level. Multi-table ACID transactions work, but locking is at the table level.

9. **No triggers, no sequences, no computed columns, no partitioned tables** — Plan your ETL accordingly.

10. **No SQL Agent** — Use Fabric Data Factory pipelines for scheduling and orchestration instead of SQL Agent jobs.

### Connecting SSMS to the Fabric Warehouse

1. Open **SSMS 19.x or later** (required; SSMS 18.x may have issues)
2. Click **Connect → Database Engine**
3. **Server name:** paste the SQL connection string from Warehouse Settings (e.g., `abc123.datawarehouse.fabric.microsoft.com`)
4. **Authentication:** Select **Microsoft Entra ID – Universal with MFA** (or another Entra ID method)
5. **Database:** Enter your warehouse name as the Initial Catalog
6. Click **Connect**

Once connected, Object Explorer shows your databases, tables, views, and stored procedures. You can run full DDL and DML — CREATE TABLE, INSERT, UPDATE, DELETE, MERGE, COPY INTO — just as you would against SQL Server. The experience is familiar but remember: no SQL auth, no linked servers, and **MARS (Multiple Active Result Sets) is not supported** (remove it from connection strings if present).

**Key documentation:**
- T-SQL surface area → `learn.microsoft.com/en-us/fabric/data-warehouse/tsql-surface-area`
- Data types → `learn.microsoft.com/en-us/fabric/data-warehouse/data-types`
- Tables → `learn.microsoft.com/en-us/fabric/data-warehouse/tables`
- Dimensional modeling series → `learn.microsoft.com/en-us/fabric/data-warehouse/dimensional-modeling-dimension-tables`
- SSMS connectivity → `learn.microsoft.com/en-us/fabric/data-warehouse/how-to-connect`
- IDENTITY columns → `learn.microsoft.com/en-us/fabric/data-warehouse/tutorial-identity`

---

## Part 5: Building the Platinum semantic model for Power BI

### Default semantic models are no longer auto-created

An important change as of **September 2025**: Fabric no longer automatically creates a default semantic model when you provision a Warehouse or Lakehouse. Previously, every Warehouse came with a paired read-only semantic model that exposed all tables. That behavior is gone. You now explicitly create a **custom semantic model** — which is actually better, because the custom model editor supports hierarchies, calculation groups, rich DAX editing, and full formatting control.

### Creating a Direct Lake semantic model from your Warehouse

This is the Platinum layer. **Direct Lake** is Fabric's marquee storage mode: it reads Delta Parquet files directly from OneLake without importing data into memory, combining near-real-time freshness with in-memory query performance. It is the default mode when you create a semantic model from the Fabric portal.

**Step-by-step:**

1. Open your **Warehouse** in the Fabric portal
2. Click **"New semantic model"** in the ribbon toolbar
3. Enter a name (e.g., `SalesModel_Platinum`)
4. Select the target workspace
5. Expand the **dbo** schema → expand **Tables** → check the tables to include (e.g., DimDate, DimProduct, DimCustomer, FactSales)
6. Click **Confirm**
7. Fabric creates the model and opens the **model designer** (diagram view)

You're now in a visual modeling environment that will feel conceptually similar to SSAS tabular model design — but in a browser.

### Adding relationships, measures, and hierarchies

**Relationships:** In the diagram view, drag a column from a fact table to the matching column on a dimension table (e.g., `FactSales.DateKey` → `DimDate.DateKey`). Fabric auto-detects cardinality (typically Many-to-One). If you defined FOREIGN KEY constraints in the Warehouse, some relationships may auto-populate. You can also use **Manage relationships** in the ribbon for precise control over cardinality and cross-filter direction.

**DAX measures:** Select a table in the Data pane, click **New measure** in the ribbon, and write DAX in the formula bar:

```dax
Total Sales = SUM(FactSales[SalesAmount])
Average Order Value = DIVIDE([Total Sales], DISTINCTCOUNT(FactSales[OrderID]))
YTD Sales = TOTALYTD([Total Sales], DimDate[FullDate])
```

The DAX editing experience includes full IntelliSense and autocomplete — comparable to Power BI Desktop.

**Hierarchies:** In the Data pane, right-click a column (e.g., `CalendarYear`) and create a hierarchy, then drag subordinate columns (Quarter, MonthName, FullDate) into it. This enables drill-down in Power BI reports.

**Calculation groups and perspectives** are both supported. Calculation groups (for time intelligence patterns like YTD/QTD/MTD) can be created via Power BI Desktop's Model Explorer or Tabular Editor connected through the XMLA endpoint. Perspectives allow hiding tables or columns for specific user audiences.

### Connecting Power BI Desktop to the semantic model

You have two primary connection methods:

**Live Connection (for report authoring against the published model):**
1. Open Power BI Desktop → **Home → Power BI semantic models** (or OneLake catalog)
2. Browse to your workspace → select `SalesModel_Platinum`
3. Click **Connect**
4. Build visuals and reports — the model stays in Fabric; you're building a report layer only
5. **Publish** the report back to the Fabric workspace

This is analogous to connecting Power BI Desktop to an SSAS live connection. You cannot modify the model but can add report-level measures.

**Live Edit (for model development in Desktop — new as of March 2025):**
1. Open Power BI Desktop → OneLake catalog → select the semantic model
2. Choose **"Edit"** instead of Connect
3. Make changes (add measures, relationships, tables) directly — changes auto-save to the service in real-time
4. This is the closest experience to authoring an SSAS tabular model in Visual Studio

**XMLA endpoint (for advanced tooling):**
The XMLA endpoint is **enabled read/write by default** on all Fabric and Premium capacities since June 2025. The connection string format is `powerbi://api.powerbi.com/v1.0/myorg/<WorkspaceName>`. You can connect with:

- **SSMS 19.1+** — browse model metadata, script TMSL, process/refresh
- **Tabular Editor** (free or commercial) — full model development experience, closest to Visual Studio SSAS projects
- **DAX Studio** — query testing and performance analysis
- **Visual Studio** (Analysis Services projects) — deploy tabular model projects

For an SSAS architect, Tabular Editor via XMLA will be the most natural advanced development environment.

### How this compares to SSAS Tabular

**Fabric semantic models run on the same VertiPaq (Analysis Services) engine** that powers SSAS Tabular and Azure Analysis Services. The compatibility level for Direct Lake models is **1604**. Key differences from SSAS:

- **No Power Query in Direct Lake models** — data transformation must happen upstream in the Warehouse or pipelines, not in the model's M queries. This is a fundamental design shift: the Warehouse owns the data shape, the semantic model owns the business logic (DAX).
- **No explicit partitioning needed** — Direct Lake reads delta tables directly; the engine handles memory management automatically.
- **Memory limits are per model, not per server** — on F64/Trial, the limit is **25 GB per semantic model** (enable Large semantic model storage format in workspace settings to exceed the 1 GB default).
- **No MOLAP cubes** — only tabular models are supported. If you have legacy multidimensional SSAS workloads, they must be redesigned as tabular.
- **Security uses workspace roles** — no server-level admin concept. RLS and OLS are fully supported.
- **Deployment uses Publish or XMLA** — no Analysis Services server to deploy to; models live in workspaces.

Everything else transfers: DAX measures, calculated columns, calculation groups, perspectives, translations, row-level security, object-level security, and partitions (via XMLA) all work as expected.

**Key documentation:**
- Create semantic model → `learn.microsoft.com/en-us/fabric/data-warehouse/create-semantic-model`
- Edit data models in service → `learn.microsoft.com/en-us/power-bi/transform-model/service-edit-data-models`
- XMLA endpoint → `learn.microsoft.com/en-us/fabric/enterprise/powerbi/service-premium-connect-tools`
- Direct Lake in PBI Desktop → `learn.microsoft.com/en-us/fabric/fundamentals/direct-lake-power-bi-desktop`
- Migrate AAS → Power BI → `learn.microsoft.com/en-us/power-bi/guidance/migrate-azure-analysis-services-to-powerbi-premium`
- Semantic models overview → `learn.microsoft.com/en-us/fabric/data-warehouse/semantic-models`

---

## Conclusion: what makes this architecture work

The end-to-end flow — DACPAC for schema migration, COPY INTO or Data Pipeline for data movement, Fabric Warehouse for your Gold star schema, and a Direct Lake semantic model for your Platinum OLAP layer — is well-supported and aligns with Microsoft's documented patterns. Three insights stand out from this research:

**First, Fabric Warehouse is closer to SQL Server than you'd expect.** Stored procedures, views, CTEs, window functions, MERGE, and multi-table transactions all work. The main adjustments are data types (`varchar` not `nvarchar`, `datetime2` not `datetime`, `BIGINT` for IDENTITY), non-enforced constraints, and no indexes. Most existing T-SQL will port with modest changes.

**Second, the .bacpac dead end is worth knowing about early.** The Migration Assistant with a DACPAC file is the correct on-ramp — not .bacpac. Plan to export schema and data separately. For data, Parquet files via COPY INTO give the highest throughput; for convenience, the Migration Assistant's integrated Copy Job handles everything through a gateway.

**Third, Direct Lake changes how you think about semantic models.** Unlike SSAS where the model owns both data and logic, a Direct Lake model reads data directly from Warehouse tables on OneLake. There's no import step, no scheduled refresh for the model itself, and data freshness depends on when the Warehouse tables are updated. This cleanly separates the Warehouse team's responsibility (data shape and quality) from the BI team's responsibility (business logic in DAX). For an SSAS architect, this is the single biggest conceptual shift — and arguably the biggest improvement.