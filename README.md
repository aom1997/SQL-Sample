# SQL Sample – Healthcare Analytics

A collection of T-SQL scripts demonstrating production-level query writing, stored procedure design, and reusable function development in a healthcare data environment. All scripts are anonymized samples from real operational and analytical workloads.

---

## Files Overview

| File | Type | Purpose |
|---|---|---|
| `Medicare Claim Analysis-Oncology Cost.sql` | Analytical Query | Cost analysis of radiation therapy treatment courses for cancer patients |
| `Query for Dashboard-App Report.sql` | Dashboard Query | Provider alert responsiveness and engagement metrics for a clinical alerting platform |
| `Stored_Procedure-ActionCompleted.sql` | Stored Procedure | Role-based care tracking action completion statistics for reporting dashboards |
| `Function-Spilit Parameter.sql` | User-Defined Function | Reusable string-splitting utility for multi-value filter parameters |

---

## Script Details

### 1. Medicare Claim Analysis – Oncology Cost
**File:** `Medicare Claim Analysis-Oncology Cost.sql`

Analyzes radiation therapy treatment courses and associated costs for oncology patients using Medicare Part A and Part B claims data.

**Key techniques:**
- Joins across multiple CMS claims tables (`CCLF_PartA`, `CCLF5_PartB`, `CCLF4`) and ICD-10 lookup tables
- Uses CPT code ranges (77xxx series) to identify radiation therapy services
- Groups claims into treatment courses using simulation claims as anchors
- Classifies treatment modality (IMRT, SBRT, 3D radiotherapy) and body site (breast, lung, prostate, skin)

**Business questions answered:**
- What is the total treatment cost per cancer type and radiation modality?
- How many sessions does each treatment course contain?
- How are costs distributed across planning vs. delivery phases?

---

### 2. Query for Dashboard – App Report
**File:** `Query for Dashboard-App Report.sql`

Generates a provider-level performance report tracking responsiveness to clinical alerts within a care management platform.

**Key techniques:**
- Multi-database joins across 4 data sources (messaging, reporting, provider master, quality metrics)
- `ROW_NUMBER()` window function to deduplicate multi-user alert responses by priority
- Time-bucket categorization: response within 24 hrs / 1–3 business days / beyond 3 days
- Aggregation of alert lifecycle metrics (received, read, unread, actioned) per provider and patient

**Business questions answered:**
- How responsive is each provider to clinical alerts?
- What percentage of alerts receive action within 24 hours vs. delayed?
- How does alert engagement correlate with quality metrics (readmission rates, preventable diagnostic variation)?

---

### 3. Stored Procedure – Action Completed Statistics
**File:** `Stored_Procedure-ActionCompleted.sql`

A parameterized stored procedure that powers care tracking dashboards by computing action completion rates across various filters.

**Key techniques:**
- Role-based access control logic (Supervisor → Provider → User hierarchy) determining data scope
- Dynamic filtering by payer, practice, physician, NPI, and date range via input parameters
- Temporary table pipeline for eligible beneficiary ID staging
- Percentage calculation of completed vs. available actions, grouped by status category

**Output:** Category-level summary with action counts, completion percentages, and aggregated totals — consumed directly by dashboard reports.

---

### 4. Function – Split Parameter
**File:** `Function-Spilit Parameter.sql`

A reusable scalar-valued table function that parses a delimited string into individual rows, enabling multi-value filter support in stored procedures and queries.

**Key techniques:**
- Iterative string parsing using `CHARINDEX`, `LEFT`, and `RIGHT`
- Configurable delimiter (defaults to comma)
- Returns a single-column table for use in `JOIN` or `WHERE ... IN` clauses

**Example use case:** Passing a comma-separated list of provider IDs as a single parameter and joining the result set against a data table.

---

## Technical Environment

| Item | Detail |
|---|---|
| Database | Microsoft SQL Server (T-SQL) |
| Data Domain | Healthcare – Medicare claims, clinical alerting, care management |
| Query Complexity | Multi-table joins, CTEs, window functions, dynamic filtering, role-based logic |
| Integrations | Azure SQL, multi-database cross joins, CMS claims data (CCLF format) |
