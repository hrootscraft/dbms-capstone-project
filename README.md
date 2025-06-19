# Real Estate Housing Management Database

## 1. Folder map

1. **create.sql** – schema DDL  
2. **load.sql** – bulk CSV → tables (~3000 rows each)  
3. **add_attributes.sql** – adds `neighborhood_id` FK to *properties*  
4. **test_queries.sql** – 14 example DML / analytics queries  
5. **stored_pgm_function / procedure** – reusable PL/pgSQL  
6. **transaction_trigger1/2*.sql** – trigger definitions + demos  
7. **indexed_performance.sql** – before/after `EXPLAIN ANALYZE` runs  

---

## 2. Quick‑start (bash)

```bash
# 0. create empty DB
psql -U $USER -c "CREATE DATABASE real_estate;"

# 1. schema & sample data
psql -U $USER -d real_estate -f create.sql
psql -U $USER -d real_estate -f load.sql

# 2. optional extra FK + demo sale
psql -U $USER -d real_estate -f add_attributes.sql
psql -U $USER -d real_estate -f transaction_trigger1.sql
psql -U $USER -d real_estate -f transaction_trigger1_demo.sql   # creates the sale

# 3. run examples
psql -U $USER -d real_estate -f test_queries.sql

# 4. business‑rule trigger
psql -U $USER -d real_estate -f transaction_trigger2.sql
psql -U $USER -d real_estate -f transaction_trigger2_demo.sql

# 5. stored programs (write output to ./output/)
mkdir -p output
psql -U $USER -d real_estate -v ON_ERROR_STOP=1 -f stored_pgm_function1.sql | tee output/stored_pgm_function1.txt
psql -U $USER -d real_estate -v ON_ERROR_STOP=1 -f stored_pgm_function2.sql | tee output/stored_pgm_function2.txt
psql -U $USER -d real_estate -v ON_ERROR_STOP=1 -f stored_pgm_function3.sql | tee output/stored_pgm_function3.txt
psql -U $USER -d real_estate -v ON_ERROR_STOP=1 -f stored_pgm_procedure1.sql | tee output/stored_pgm_procedure1.txt
psql -U $USER -d real_estate -v ON_ERROR_STOP=1 -f stored_pgm_procedure2.sql | tee output/stored_pgm_procedure2.txt
psql -U $USER -d real_estate -v ON_ERROR_STOP=1 -f stored_pgm_procedure3.sql | tee output/stored_pgm_procedure3.txt

# 6. performance study
psql -U $USER -d real_estate -f indexed_performance.sql | tee indexed_performance.txt
````

> **Log files**
> *transaction\_trigger1.txt* and *transaction\_trigger2.txt* show the trigger demos.
> *indexed\_performance.txt* captures baseline vs improved `EXPLAIN ANALYZE`.

---


## 3. Normalization

Every relation is in BCNF ([see report](BCNF_Justification_Report.md)). No decompositions required.


## 4. Database Testing (≥ 10 queries) & Stored Programs

### 4 .1  Manual test-suite (`test_queries.sql`)

* **14 mixed statements** (INSERT, UPDATE, DELETE, 10 different SELECT variants)  
* Executes with `\timing on` and auto-creates an `output/` folder, so every query
  result is saved for screenshots.  
* Covers `JOIN`, `GROUP BY … HAVING`, window functions, scalar & correlated
  sub-queries, `DISTINCT ON`, anti-join, `EXISTS / NOT EXISTS`, etc.

Run once:

```bash
psql -U $USER -d real_estate -f test_queries.sql
````

All results are written into the individual `output/query<n>.txt` files.

---

### 4 .2  Reusable stored programs

| File                            | Object                                              | Purpose / business value                                                                                                       | Demo call in log                                 |
| ------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| **stored\_pgm\_function1.sql**  | `get_neighborhood_stats()` *set-returning function* | One-row KPI snapshot for any neighbourhood (count, min/max/avg price, avg school rating).                                      | `SELECT * FROM get_neighborhood_stats(12);`      |
| **stored\_pgm\_function2.sql**  | `fn_agent_kpis()`                                   | KPI dashboard per agent (active vs sold listings, total sales, last sale date).                                                | `SELECT * FROM fn_agent_kpis(42);`               |
| **stored\_pgm\_function3.sql**  | `fn_buyer_activity_summary()`                       | Single-row summary of a buyer’s favourites, inspections and total spend.                                                       | `SELECT * FROM fn_buyer_activity_summary(1883);` |
| **stored\_pgm\_procedure1.sql** | `create_sale()`                                     | **Atomic sale** → inserts `transactions`, closes the listing, autogenerates a matching `mortgages` row.                        | `CALL create_sale(135, 2, 402000);`              |
| **stored\_pgm\_procedure2.sql** | `add_property_with_listing()`                       | Inserts a new property, optionally auto-detects the neighbourhood from the address, and creates its first *available* listing. | see two example `CALL`s inside the file          |
| **stored\_pgm\_procedure3.sql** | `reassign_and_remove_agent()`                       | Moves every property from a departing agent to a replacement; deletes the old agent *only* if no active listings remain.       | `CALL reassign_and_remove_agent(17, 42);`        |

> **How we captured evidence**
> Each script is executed with `tee` so its console output lands in
> `output/stored_pgm_<name>.txt`, e.g.

```bash
mkdir -p output 

psql -U $USER -d real_estate -v ON_ERROR_STOP=1 -f stored_pgm_function1.sql | tee output/stored_pgm_function1.txt
# …repeat for the other five files
```

The text files show:

* `CREATE FUNCTION / PROCEDURE` confirmation
* The `CALL`/`SELECT` used for demonstration
* Result rows or `NOTICE` messages proving success
* (For the procedures) follow-up verification queries

---


## 5. Transaction Handling with Failure-Aware Triggers

---

### 5 .1  Why do we need failure-aware triggers?

Real-estate workflows span several tables (`transactions`, `mortgages`, `listings`).
If one statement inside a multi-step sale fails, we must be sure that **no
partial state** survives (atomicity) *and* that business rules are still enforced.

We implemented **two independent trigger systems** to demonstrate both sides of the coin:

| Trigger set                                           | Business value                                          | What fails?                                   | What the trigger does                                                                    |
| ----------------------------------------------------- | ------------------------------------------------------- | --------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **T-1 Audit** (`trg_trans_audit`)                     | Keep an immutable audit row *only* when a sale commits. | Any subsequent error in the same transaction. | Because it is **`AFTER INSERT`**, its insert is rolled back automatically on failure.    |
| **T-2 One-active-listing** (`trg_one_active_listing`) | Enforce “≤ 1 *available* listing per property”.         | Second attempt to add an `'available'` row.   | **`BEFORE INSERT/UPDATE`** raises an exception; the entire outer transaction is aborted. |

---

### 5 .2  Schema objects (see `transaction_trigger1.sql` / `transaction_trigger2.sql`)

```sql
-- T-1  audit table + trigger
CREATE TABLE IF NOT EXISTS transaction_audit ( … );
CREATE FUNCTION  trg_log_transaction() RETURNS TRIGGER …  -- inserts audit row
CREATE TRIGGER   trg_trans_audit 
AFTER INSERT ON transactions 
FOR EACH ROW EXECUTE FUNCTION trg_log_transaction();

-- T-2  business-rule trigger
CREATE FUNCTION trg_one_active_listing() RETURNS TRIGGER …  -- checks duplicates
CREATE TRIGGER  trg_one_active_listing
BEFORE INSERT OR UPDATE ON listings
FOR EACH ROW EXECUTE FUNCTION trg_one_active_listing();
```

Both scripts write their progress banners to `transaction_trigger1.txt` and `transaction_trigger2.txt`.

---

### 5 .3  Demo run (success + failure)

#### 5 .3. 1  Sale audit (`transaction_trigger1_demo.sql`)

| Step                   | What the demo does                                                            | Outcome in the log                                                        |
| ---------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| *truncate*             | Clears `transaction_audit`                                                    | `-- audit table truncated --`                                             |
| **Happy path**         | `CALL demo_sale_maybe_fail(…, FALSE)`                                         | Trigger fires → 1 audit row committed                                     |
| **Deliberate failure** | Same call with `_make_it_fail = TRUE` – inserts duplicate PK into `mortgages` | Duplicate-key error raised → transaction aborts → **no second audit row** |
| Verify                 | `SELECT * FROM transaction_audit`                                             | Still exactly **1** row                                                   |

> **Justification:** When PostgreSQL aborts a transaction, *all*
> statements, including side-effects executed by triggers, are rolled
> back.  This proves atomicity.

#### 5 .3. 2  One-active-listing (`transaction_trigger2_demo.sql`)

| Step            | What happens                                                 | Evidence                           |
| --------------- | ------------------------------------------------------------ | ---------------------------------- |
| Choose property | Picks one with zero active listings                          | `-- Property chosen --`            |
| **1st insert**  | Adds an `'available'` listing                                | `INSERT 0 1`                       |
| **2nd insert**  | Trigger detects duplicate active listing ⇒ `RAISE EXCEPTION` | Error message in log               |
| Verify          | Row-count query shows **active\_cnt = 1**                    | Confirms second insert rolled back |

> **What happens when a txn is aborted?**
> *All* DML inside that transaction is undone, locks are released, and
> other sessions never see the partial state.  The error is propagated to
> the client so the application can react.

---

### 5 .4  Files included

| File                            | Purpose                                     |
| ------------------------------- | ------------------------------------------- |
| `transaction_trigger1.sql`      | Builds audit table + trigger                |
| `transaction_trigger1_demo.sql` | Runs success + failure demo, appends to log |
| `transaction_trigger1.txt`      | Console + query output (proof)              |
| `transaction_trigger2.sql`      | Builds one-active-listing trigger           |
| `transaction_trigger2_demo.sql` | Success + failure demo for T-2              |
| `transaction_trigger2.txt`      | Console + query output                      |

---

### 5 .5  How to reproduce

```bash
# create objects
psql -U <user> -d real_estate -f transaction_trigger1.sql
psql -U <user> -d real_estate -f transaction_trigger2.sql

# run demos (append output to .txt files)
psql -U <user> -d real_estate -f transaction_trigger1_demo.sql
psql -U <user> -d real_estate -f transaction_trigger2_demo.sql
```

Open `transaction_trigger1.txt` and `transaction_trigger2.txt` to see:

* Trigger creation banners
* Successful operation
* Controlled failure + rollback
* Post-failure verification queries


## 6. Query‑Performance Analysis & Indexing


> Goal: pick three representative queries, show their baseline execution
> plan/cost, and demonstrate how targeted indexing improves (or will
> improve) performance as the dataset scales.

All plans were captured with `EXPLAIN ANALYZE  (buffers, verbose)` under PostgreSQL 17.5; the raw output is committed in **`indexed_performance.txt`**.

| No. | Business question | Baseline exec‑time | After indexing | Δ‑Speed | Index(es) added |
|-----|-------------------|--------------------|----------------|--------:|-----------------|
| 1   | Top 10 family‑size homes in 8 ★ school areas (Q‑4) | 1.78 ms | **0.25 ms** | **‑ 86 %** | `idx_neigh_rating8` (partial) <br/>`idx_prop_bed3_price` (partial + covering) |
| 2   | “Expensive neighbourhoods” – show `AVG(price) > 500 k` (Q‑5) | 5.01 ms | **4.23 ms** | ‑ 16 % | `idx_prop_neigh_price` (covering) |
| 3   | Idle agents (no *available* listings) – anti‑join (Q‑11) | 3.70 ms | **3.34 ms** | ‑ 10 % | `idx_prop_agent` <br/>`idx_listings_available` (partial) |

### 6 .1  “Top family homes”  –  Why it was slow & how we fixed it

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

### 6 .2  Expensive neighbourhoods  –  Turning a hash aggregate into an index‑only aggregate

* **Baseline**: Seq Scan on `properties`, Hash Join, then `AVG(price)`
  on 3 k rows → 5 ms.
* **Fix**: covering index `(neighborhood_id, price)` lets PostgreSQL read
  the two columns straight from the B‑tree (**Heap Fetches: 0**).  
  Runtime is already lower (‑16 %) on 3 k rows and falls off a cliff
  when properties grows (O(log n) v O(n)).

### 6 .3  Idle agents – exploiting partial indexes

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
