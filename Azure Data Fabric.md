# Microsoft Fabric POC setup guide for SQL Server architects

**Microsoft Fabric provides a fully managed, SaaS-based analytics platform that fundamentally changes how data warehousing works — and several critical differences from SQL Server 2022 will trip up even experienced DBAs.** The most important things to know upfront: constraints are informational only (not enforced), there are no user-created indexes, the default semantic model was sunset in September 2025, and the web-based SQL editor resets session context on every execution. This guide covers trial activation, warehouse creation and DDL, data export via BCP, CSV loading into Fabric, and semantic model configuration — all reflecting the current (2024–2025) state of the platform.

---

## 1. Activating a Fabric trial and setting up your workspace

### Starting the trial

Navigate to **app.fabric.microsoft.com** and click your **profile icon** in the upper-right corner to open the Account Manager pane. Click **"Start trial"** and a dialog titled "Activate your 60-day free Fabric trial capacity" appears. Select your **trial capacity region** (defaults to your tenant's home region — choose carefully, as moving workspaces later requires deleting all Fabric items first), agree to terms, and click **"Activate."** You become the Capacity Administrator for the trial.

An alternative activation path: attempt to create any Fabric item (Warehouse, Lakehouse, Notebook) in a workspace you own, and Fabric prompts you to start a trial automatically.

### What the trial provides

The trial runs for **60 days** and provisions either an **F64 (64 CUs)** or **F4 (4 CUs)** capacity. Newer trials increasingly default to F4; an upgrade button ("Change size") exists in Admin Portal → Capacity Settings → Trial tab, but eligibility varies and is not guaranteed. The F64 tier is equivalent to Power BI Premium P1 and provides **1 TB of OneLake storage**, access to all Fabric workloads (Data Factory, Synapse Data Engineering, Data Science, Real-Time Intelligence, Power BI, Data Warehouse), and a complementary Power BI Individual Trial license if you don't already hold Pro or PPU.

Features **not available** on trial: Copilot (AI assistant), Private Link, Trusted Workspace Access, AI Experiences, and autoscale. You cannot burst beyond the fixed CU allocation, and there is no capacity overage billing.

Extension is possible but not self-service — contact your Microsoft sales representative near expiration. Community reports indicate a "Request to renew trial" link sometimes appears, granting another 60-day window at Microsoft's discretion.

### Prerequisites and enterprise blockers

You need a **work or school Microsoft Entra ID account** (personal Gmail/Outlook.com emails are not supported). No Azure subscription or credit card is required. A Fabric (Free) license — obtained simply by signing into the portal — is sufficient to start the trial; the complementary Power BI Individual Trial is granted automatically during activation.

Tenant admin consent is not required by default, but admins can block trials through two tenant settings: **"Users can create Fabric items"** and **"Users can try Microsoft Fabric paid features"** (both in Admin Portal → Tenant Settings). Other common blockers include exhausted tenant trial capacity limits (approximately 5 trials per tenant), Conditional Access policies, and self-service purchase restrictions in the M365 Admin Center.

### Creating and assigning workspaces

Click **Workspaces** in the left navigation → **"+ New workspace"** → enter a name → expand **Advanced** → set **Workspace type** to **"Fabric Trial"** → click **Apply**. Multiple workspaces can share the same trial capacity, and hundreds of users can collaborate on a single trial. To reassign an existing workspace, open Workspace Settings → Workspace type → Edit → select "Fabric Trial" → Apply.

### Trial limitations affecting a star schema POC

For an F64 trial, the **maximum semantic model memory is 25 GB** (per model), with a **10 GB hard limit per partition** during processing. Direct Lake guardrails cap tables at **1.5 billion rows** before falling back to DirectQuery. Capacity throttling uses 24-hour smoothing for background operations; sustained usage beyond the CU budget triggers background rejection, delaying or blocking operations. The absence of autoscale means you cannot dynamically handle burst workloads. After trial expiration, non-Power BI items (warehouses, lakehouses, pipelines) become inactive and are **permanently deleted after 7 days** if not migrated to paid capacity.

---

## 2. Creating a Fabric Warehouse and understanding its T-SQL surface area

### Creating the warehouse

Open your workspace → click **"+ New Item"** → select **"Warehouse"** under "Store data" → enter a name → click **Create**. An empty warehouse provisions in seconds. The only required input is the name — there are no options for compute, storage, indexing, or distribution. Collation defaults to `Latin1_General_100_BIN2_UTF8` (case-sensitive); to use case-insensitive collation, you must create the warehouse via REST API, and collation cannot be changed after creation.

### What T-SQL works — and what doesn't

Fabric Warehouse supports a broad but distinctly different T-SQL surface area compared to SQL Server 2022. The table below highlights the most impactful differences for a star schema POC:

| Feature | SQL Server 2022 | Fabric Warehouse | Notes |
|---|---|---|---|
| **Indexes (all types)** | ✅ | ❌ | No user-created indexes; data stored natively as V-Order Parquet |
| **Computed columns** | ✅ | ❌ | Use views or ETL logic instead |
| **Triggers** | ✅ | ❌ | Not supported |
| **DEFAULT constraints** | ✅ | ❌ | Handle defaults in ETL |
| **CHECK constraints** | ✅ | ❌ | Handle validation in ETL |
| **Stored procedures** | ✅ | ✅ | Fully supported with DDL/DML inside |
| **Views** | ✅ | ✅ | Standard CREATE VIEW works |
| **CTEs and window functions** | ✅ | ✅ | Including ROW_NUMBER, LAG, LEAD |
| **MERGE statement** | ✅ | ✅ | Generally available |
| **Temp tables (#)** | ✅ | ✅ | Session-scoped only; no global ##temp |
| **Cross-database queries** | ✅ | ✅ | Same workspace only, three-part naming |
| **IDENTITY columns** | ✅ | ✅ (limited) | **BIGINT only**, no custom SEED/INCREMENT, no IDENTITY_INSERT, gaps expected |
| **Sequences** | ✅ | ❌ | Not available |
| **PK/FK/UNIQUE constraints** | ✅ (enforced) | ✅ (informational) | Must use ALTER TABLE with NOT ENFORCED |
| **datetime, money, nvarchar** | ✅ | ❌ | Use datetime2, decimal, varchar (UTF-8 handles Unicode) |

### The critical DDL pattern: constraints via ALTER TABLE

The single biggest gotcha for SQL Server DBAs is that **you cannot define PK, FK, or UNIQUE constraints inline in CREATE TABLE**. You must use separate ALTER TABLE statements with the `NONCLUSTERED NOT ENFORCED` keywords:

```sql
CREATE TABLE dbo.DimProduct (
    ProductKey INT NOT NULL,
    ProductName VARCHAR(200),
    Category VARCHAR(100)
);

ALTER TABLE dbo.DimProduct
ADD CONSTRAINT PK_DimProduct
PRIMARY KEY NONCLUSTERED (ProductKey) NOT ENFORCED;

CREATE TABLE dbo.FactSales (
    SalesKey BIGINT IDENTITY,
    ProductKey INT NOT NULL,
    SalesAmount DECIMAL(18,2)
);

ALTER TABLE dbo.FactSales
ADD CONSTRAINT FK_FactSales_Product
FOREIGN KEY (ProductKey) REFERENCES dbo.DimProduct(ProductKey) NOT ENFORCED;
```

These constraints are **metadata hints only** — the engine does not validate uniqueness or referential integrity. They serve the query optimizer and help Power BI detect relationships, but you must enforce data quality in your ETL pipeline.

### The web SQL editor

The built-in editor provides **IntelliSense**, syntax highlighting, multiple query tabs, auto-save, and keyboard shortcuts (Ctrl+Enter to run, Ctrl+K,C to comment). Results display up to **10,000 rows** with search/filter. You can save queries as named items, export to Excel, or visualize results inline.

**Critical caveat: each Run creates a new session.** SET statements, transactions, and temporary tables do not persist across executions. Multi-statement transactions must be in a single batch. For session-persistent work, connect via **SSMS 19+** or **VS Code with the mssql extension**.

---

## 3. Exporting data from SQL Server 2022 with BCP and SQLCMD

### BCP fundamentals for CSV export

BCP with the `-T` flag uses Windows Authentication — any account with SELECT permission works, no DBA role required. The key switches for Fabric-compatible CSV output:

```cmd
bcp MyDatabase.dbo.DimProduct out "C:\Export\DimProduct.csv" ^
  -S MyServer\SQL2022 ^
  -T ^
  -c ^
  -t"," ^
  -r"\n" ^
  -C 65001
```

The flags: `-c` for character mode, `-t","` for comma delimiter, `-r"\n"` for Unix-style line endings (use `ROWTERMINATOR='0x0A'` in Fabric), and **`-C 65001` for UTF-8 encoding** (matching Fabric's default). Use `bcp queryout` instead of `bcp out` when you need WHERE clauses, column selection, or NULL handling via ISNULL().

### Chunking large tables

For fact tables exceeding 500MB, run multiple `bcp queryout` commands with non-overlapping WHERE predicates. ID-range chunking works best for tables with surrogate keys:

```cmd
bcp "SELECT * FROM MyDB.dbo.FactSales WITH (NOLOCK) WHERE SalesKey BETWEEN 1 AND 2000000" queryout "C:\Export\FactSales_001.csv" -S MyServer -T -c -t"," -r"\n" -C 65001 -a 65535
bcp "SELECT * FROM MyDB.dbo.FactSales WITH (NOLOCK) WHERE SalesKey BETWEEN 2000001 AND 4000000" queryout "C:\Export\FactSales_002.csv" -S MyServer -T -c -t"," -r"\n" -C 65001 -a 65535
```

Use `-a 65535` for maximum network packet size (significant throughput improvement on large exports), `WITH (NOLOCK)` to avoid blocking, and run BCP on the server itself to eliminate network overhead. Fabric's COPY INTO supports wildcard paths (`FactSales*.csv`), so multiple chunk files load seamlessly.

### The header problem and recommended workaround

BCP does not export column headers. The most reliable workaround is the **separate-file concatenation** method:

```cmd
bcp "SELECT 'ProductKey,ProductName,Category'" queryout "C:\Export\headers.csv" -S MyServer -T -c -C 65001
bcp MyDB.dbo.DimProduct out "C:\Export\data.csv" -S MyServer -T -c -t"," -r"\n" -C 65001
copy /b "C:\Export\headers.csv" + "C:\Export\data.csv" "C:\Export\DimProduct.csv"
```

However, **for Fabric loading, headers are optional** — simply use `FIRSTROW = 1` in COPY INTO for headerless files, or `FIRSTROW = 2` to skip a header row. Skipping headers entirely is the simplest path.

### NULL and special character handling

BCP exports NULLs as empty fields (nothing between delimiters) and empty strings as a **0x00 NUL byte** — a notorious behavior that can corrupt downstream parsing. The fix is to use `queryout` with explicit ISNULL() wrapping: `ISNULL(ColumnName, '')`.

BCP has **no built-in text qualification**. Commas, quotes, or newlines embedded in varchar data will break CSV structure. Workarounds: use a pipe (`|`) delimiter instead of comma (then configure `FIELDTERMINATOR='|'` in Fabric), or wrap fields in double quotes using `CHAR(34)` in the query, or strip problematic characters with REPLACE().

### When to use SQLCMD instead

SQLCMD includes headers by default (though it also inserts an annoying dashed separator line beneath them) and has simpler syntax for small, ad-hoc exports. Use it for quick dimension table exports under 100K rows. For large fact tables, BCP is significantly faster. SQLCMD syntax:

```cmd
sqlcmd -S MyServer -d MyDB -E -Q "SET NOCOUNT ON; SELECT * FROM dbo.DimProduct" -s"," -W -w 4096 -o "C:\Export\DimProduct.csv"
```

The `-W` flag removes trailing spaces, `-w 4096` prevents line wrapping, and `SET NOCOUNT ON` suppresses the row-count footer.

---

## 4. Loading CSV files into Fabric Warehouse

### COPY INTO: the primary loading mechanism

Fabric Warehouse's COPY INTO statement reads from **Azure Blob Storage, ADLS Gen2, or OneLake** — it cannot read local files. For a POC, the simplest path is uploading CSVs to a **Lakehouse Files section** and referencing them via OneLake URL.

```sql
COPY INTO dbo.DimProduct
FROM 'https://onelake.dfs.fabric.microsoft.com/<workspaceGUID>/<lakehouseGUID>/Files/csv-exports/DimProduct.csv'
WITH (
    FILE_TYPE = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0A',
    ENCODING = 'UTF8',
    MAXERRORS = 10
);
```

When sourcing from OneLake, **no CREDENTIAL clause is needed** — authentication uses your Entra ID passthrough. You need Contributor or higher permissions on both the Lakehouse workspace (source) and Warehouse workspace (target). For Azure Blob or ADLS sources, provide a SAS token or storage account key via the CREDENTIAL option.

Key options: `FIRSTROW = 2` skips headers, `FIELDQUOTE = '"'` handles quoted fields, `DATEFORMAT = 'ymd'` controls date parsing, `MAXERRORS` sets the reject threshold, and `ERRORFILE` captures rejected rows for debugging. Wildcard paths are supported for loading chunked exports: `FROM '.../FactSales*.csv'`.

### Uploading CSVs to a Lakehouse

You **cannot upload files directly to a Warehouse** — the Warehouse has no Files section. Instead, create a Lakehouse in your workspace and upload there:

1. Open the Lakehouse → expand the **Files** section in the explorer pane
2. Right-click Files → **"Upload" → "Upload files"** → browse and select your CSVs (or drag and drop)
3. Files land at `<lakehouse>/Files/<your-folder>/<filename>.csv`
4. To get the OneLake URL: right-click the uploaded file → **Properties** → copy the URL

For files larger than a few hundred MB, use **Azure Storage Explorer** (sign in with Entra ID, navigate OneLake → workspace → lakehouse → Files) or **AzCopy** from the command line with the `--trusted-microsoft-suffixes=onelake.blob.fabric.microsoft.com` flag. The **OneLake File Explorer** Windows app also works, integrating OneLake into Windows File Explorer for drag-and-drop operations.

### Pipeline Copy Activity: when orchestration matters

COPY INTO is sufficient for one-time or simple loads. Use a **Data Pipeline** when you need scheduling, monitoring dashboards, retry logic, or multi-step orchestration. Create a pipeline via workspace → "+ New Item" → "Data pipeline" → add a Copy Activity → configure Lakehouse source (Files folder) and Warehouse destination. The pipeline's Copy Activity uses the COPY command internally and adds pre-copy scripts (e.g., TRUNCATE TABLE), auto-create table capability, and built-in run history.

### Ingestion limits on trial capacity

There is **no documented hard limit on file size or row count** for COPY INTO. Best practice is to keep individual files at least **4 MB** for optimal parallelism and limit source files to roughly 5,000 per load operation. OneLake storage on trial is capped at **1 TB**. Warehouse ingestion operations are classified as background workloads with 24-hour smoothing — sustained heavy loading on an F4 trial may trigger throttling. Monitor consumption with the **Fabric Capacity Metrics app**.

---

## 5. Building and customizing semantic models

### The default semantic model is gone

As of **September 5, 2025**, Fabric no longer auto-generates a default semantic model when you create a warehouse. By November 30, 2025, all existing default models were decoupled into standalone items. Many older tutorials still reference the default model — this information is outdated. You must now **explicitly create every semantic model**.

### Creating a custom semantic model

Open your Warehouse → click **"New semantic model"** in the Home ribbon → enter a name → select the target workspace → **check the tables to include** (views are hidden by default; click "Show views" to reveal them, noting that view-backed items force DirectQuery fallback) → click **Confirm**. The model opens in the **web model editor** using **Direct Lake** storage mode by default, reading Parquet files directly from OneLake with near-real-time freshness.

You can create **multiple semantic models** on the same warehouse for different business domains. Custom models do **not inherit FK constraints or relationships** from the warehouse — even if you defined them via ALTER TABLE, you must recreate relationships manually in the model editor.

### Defining relationships between facts and dimensions

In the web model editor's diagram view, **drag a column from one table to the matching column in another** to create a relationship. Alternatively, click **"Manage relationships"** in the ribbon → "New relationship" → configure the From/To tables and columns, cardinality (Many-to-one for standard fact-to-dimension), and cross-filter direction (Single is the default and recommended for most star schemas). Relationships can also be edited via the Properties pane by clicking on a relationship line in the diagram.

### Adding DAX measures in the web portal

Switch the model editor to **Editing mode** (toggle in the top-right corner) → select the table where the measure should live → click **"New measure"** in the ribbon → type your DAX expression in the formula bar:

```dax
Total Sales = SUM(FactSales[SalesAmount])
Profit Margin = DIVIDE([Total Sales] - [Total Cost], [Total Sales])
YTD Sales = TOTALYTD([Total Sales], DimDate[FullDate])
```

The DAX editor provides **full IntelliSense and autocomplete**, identical to Power BI Desktop. All standard DAX functions are supported including time intelligence (TOTALYTD, SAMEPERIODLASTYEAR), CALCULATE, FILTER, RELATED, USERELATIONSHIP, and USERPRINCIPALNAME for RLS. Changes **auto-save** with no undo — use semantic model version history or Git integration for recovery.

### Creating hierarchies

In the web editor's Data Pane, right-click the top-level column (e.g., `Year` in DimDate) → **"Create hierarchy"** → rename it in the Properties pane (e.g., "Date Hierarchy") → add subordinate levels (Quarter, Month, Day) via drag-and-drop in the Data Pane or the hierarchy dropdown. Optionally hide the original flat columns to prevent user confusion. Hierarchies are supported **only in custom semantic models** — the now-defunct default model did not support them.

### Row-level security basics

In the web model editor, click **"Manage roles"** in the ribbon → **"New"** → name the role (e.g., "RegionFiltered") → select the filter table → define filter logic using the dropdown editor for simple conditions or switch to the **DAX editor** for dynamic rules:

```dax
[Email] = USERPRINCIPALNAME()
```

Click Save, then go to the **"Assign"** tab to add users or Azure AD security groups. Test via **"Test as role"** in the editor. With Direct Lake models, report recipients need ReadData permission on the underlying warehouse/lakehouse, or you must configure fixed-identity credentials instead of SSO. Note that SQL-level RLS defined on the warehouse's SQL analytics endpoint causes queries to **fall back from Direct Lake to DirectQuery**.

### Connecting Power BI Desktop via Live Connection

Open Power BI Desktop → Home → **Get Data** → **"Power BI semantic models"** → the OneLake Catalog displays all models you have Build permission for → select your model → click **Connect**. A live connection is established instantly; the Data pane populates with all tables, measures, and hierarchies. You cannot modify the model structure through this connection (it's read-only), but you can create **report-level measures** and visual calculations.

For XMLA endpoint access (SSMS, Tabular Editor), use the connection string `powerbi://api.powerbi.com/v1.0/myorg/<WorkspaceName>`, found in the semantic model's Settings → Server settings. This requires the tenant admin to enable "Allow XMLA endpoints." As of March 2025, Power BI Desktop also supports **live editing** of Direct Lake models — connect via OneLake Catalog → select the model → Connect dropdown → "Edit" — changes save directly to the workspace in real-time.

---

## Conclusion: the five things that will save you the most time

The Fabric POC workflow is straightforward once you internalize a few key differences from SQL Server. **Constraints are metadata-only** — define PK/FK via ALTER TABLE with NOT ENFORCED, but enforce data quality in your ETL. **There are no indexes** — the engine manages columnar Parquet storage automatically. **The default semantic model no longer exists** — create custom models explicitly and manually rebuild relationships even if you defined FKs in the warehouse. **BCP needs explicit NULL and encoding handling** — always use `-C 65001` for UTF-8 and ISNULL() wrappers to avoid 0x00 byte corruption. Finally, **upload CSVs to a Lakehouse first** since Warehouse has no file storage, then reference them in COPY INTO via the OneLake HTTPS path with no credential clause needed. An F64 trial capacity with 1 TB storage is more than sufficient for a star schema POC, but monitor CU consumption via the Capacity Metrics app to avoid throttling on sustained loads.