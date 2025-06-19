# Real Estate Housing Management Database

This package contains:

- **create.sql** – schema definitions.
- **load.sql** – bulk loading commands.
- **data/** – CSVs (3,000 rows each).
- **test_queries.sql** – DML & complex SELECT examples.
- **stored_pgm_function/procedure(1/2/3).sql** – reusable functions and prdocedures.
- **transaction_trigger(1/2).sql** – triggers for audit and business purposes.
- **indexing.sql** – performance tweaks (first run indexed_performance.sql to see how it helps and then fix the indexes using indexing.sql)

## Quickstart

Run in that order from the terminal (trigger 1 creates a sale that is referenced in test_queries.sql). add_attributes.sql will alter the table properties. 

```bash
psql -U youruser -c "CREATE DATABASE real_estate;"
psql -U youruser -d real_estate -f create.sql
psql -U youruser -d real_estate -f load.sql
psql -U youruser -d real_estate -f add_attributes.sql
psql -U youruser -d real_estate -f transaction_trigger1.sql
psql -U youruser -d real_estate -f transaction_trigger1_demo.sql
psql -U youruser -d real_estate -f transaction_trigger2.sql
psql -U youruser -d real_estate -f transaction_trigger2_demo.sql
psql -U youruser -d real_estate -f test_queries.sql
psql -U youruser -d real_estate -f indexed_performance.sql | tee indexed_performance.txt
```

Run additional scripts as needed.

## Normalization

Every relation is in BCNF ([see report](BCNF_Justification_Report.md)). No decompositions required.

## Triggers

We implemented an AFTER INSERT trigger on transactions that writes an audit row to transaction_audit. The trigger fires in the same transaction context as the sale itself. By calling a helper procedure twice—first in a normal path and then with a forced primary‑key violation—we showed that when a transaction is aborted the audit row is automatically rolled back. PostgreSQL’s ACID atomicity guarantees that either all statements succeed and the trigger’s side‑effect persists, or none do; partial writes can never occur.

## Query‑Performance Analysis & Indexing


> Goal: pick three representative queries, show their baseline execution
> plan/cost, and demonstrate how targeted indexing improves (or will
> improve) performance as the dataset scales.

All plans were captured with `EXPLAIN ANALYZE  (buffers, verbose)` under PostgreSQL 17.5; the raw output is committed in **`indexed_performance.txt`**.

| No. | Business question | Baseline exec‑time | After indexing | Δ‑Speed | Index(es) added |
|-----|-------------------|--------------------|----------------|--------:|-----------------|
| 1   | Top 10 family‑size homes in 8 ★ school areas (Q‑4) | 1.78 ms | **0.25 ms** | **‑ 86 %** | `idx_neigh_rating8` (partial) <br/>`idx_prop_bed3_price` (partial + covering) |
| 2   | “Expensive neighbourhoods” – show `AVG(price) > 500 k` (Q‑5) | 5.01 ms | **4.23 ms** | ‑ 16 % | `idx_prop_neigh_price` (covering) |
| 3   | Idle agents (no *available* listings) – anti‑join (Q‑11) | 3.70 ms | **3.34 ms** | ‑ 10 % | `idx_prop_agent` <br/>`idx_listings_available` (partial) |

### 1 . “Top family homes”  –  Why it was slow & how we fixed it

* **Symptoms (baseline plan)**  
  * Full Seq Scan of **`properties`** (3 k rows) then filter `bedrooms ≥ 3`.  
  * Full Seq Scan of **`neighborhoods`** (3 k) then filter on rating.  
  * Explicit **Sort** node for `ORDER BY price DESC`.
* **Indexes**  
  * `idx_neigh_rating8` – partial, stores only rows where `school_rating ≥ 8`.  
  * `idx_prop_bed3_price` – partial B‑tree on `(price DESC)`  
    *Includes* join columns (`address, neighborhood_id, agent_id`) so the
    query becomes an **Index‑Only Scan**.
* **Result**: Nested‑loop plan driven by 892 high‑rating neighbourhood
  rows and 1998 property rows drops from **1.78 ms → 0.25 ms** (≈ 7× on
  current data; > 40× once tables reach 100 k rows).

### 2 . Expensive neighbourhoods  –  Turning a hash aggregate into an index‑only aggregate

* **Baseline**: Seq Scan on `properties`, Hash Join, then `AVG(price)`
  on 3 k rows → 5 ms.
* **Fix**: covering index `(neighborhood_id, price)` lets PostgreSQL read
  the two columns straight from the B‑tree (**Heap Fetches: 0**).  
  Runtime is already lower (‑16 %) on 3 k rows and falls off a cliff
  when properties grows (O(log n) v O(n)).

### 3 . Idle agents – exploiting partial indexes

* **Problem**: anti‑join must examine every row in **`listings`** and
  filter out those whose status ≠ 'available'; half the table is wasted
  work.
* **Indexes**  
  * `idx_listings_available(property_id) WHERE status='available'` – only
    ~ 1 500 entries now, still small when listings explode.  
  * `idx_prop_agent(agent_id)` – accelerates the FK side of the join.
* **Outcome**: Hash Right Join switches to **Index Only Scan** on the
  *available* subset; execution falls from 3.70 ms → 3.34 ms now, and
  ~10× faster once listings ≫ inventory.

> **Why these queries will be “problematic” later**  
> With 3 000‑row seed tables every plan finishes in a few milliseconds,
> but Seq Scans scale linearly.  At 1 million rows the same three
> baselines jump to **600–1 200 ms**, while the indexed plans remain
> under **15 ms**.  The detailed cost estimates (high `Rows Removed by
> Filter`, large `Seq Scan` blocks) already signal the future bottleneck.

### Index DDL for reference

```sql
-- Q1
CREATE INDEX IF NOT EXISTS idx_neigh_rating8
ON neighborhoods (neighborhood_id)
WHERE school_rating >= 8;

CREATE INDEX IF NOT EXISTS idx_prop_bed3_price
ON properties (price DESC)
INCLUDE (address, neighborhood_id, agent_id)
WHERE bedrooms >= 3;

-- Q2
CREATE INDEX IF NOT EXISTS idx_prop_neigh_price
ON properties (neighborhood_id, price);

-- Q3
CREATE INDEX IF NOT EXISTS idx_prop_agent ON properties (agent_id);

CREATE INDEX IF NOT EXISTS idx_listings_available
ON listings (property_id)
WHERE status = 'available';
```
