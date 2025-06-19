
# Real Estate Capstone — Formal BCNF Proof  

**Boyce‑Codd Normal Form (BCNF)**  
A relation R(A₁…Aₙ) is in BCNF iff for **every non‑trivial functional dependency**  
&nbsp;&nbsp;`X → Y` (where Y ⊄ X)  
the determinant **X** is a *super‑key* of R (i.e., X’s attribute closure contains all attributes of R).  
Equivalently, no dependency exists in which a **proper subset** of a key functionally determines another non‑key attribute.

To prove each table is in BCNF we will:  

1. **List the schema** and the primary / candidate keys we declared.  
2. **Enumerate all FDs** that hold by design (PK → non‑keys and FK‑derived).  
3. **Compute the closure** of every determinant X to show that X is a super‑key.  
4. **Check composite keys** for partial or transitive dependencies.  

---

## Agents

**Attributes:** agent_id (PK), name, email, phone
**Candidate keys:** agent_id

**Functional dependencies:**
* `agent_id → name, email, phone`

**Proof:**
`agent_id` is the primary key.  Closure:  `{agent_id}⁺ = {agent_id, name, email, phone}`  (by the FD). Since the closure contains **all** attributes, `agent_id` is a super‑key and the only determinant. Therefore every FD satisfies BCNF.

---

## Buyers

**Attributes:** buyer_id (PK), name, email, phone
**Candidate keys:** buyer_id

**Functional dependencies:**
* `buyer_id → name, email, phone`

**Proof:**
Same reasoning as **Agents**: `buyer_id` functionally determines the remaining
attributes and is itself the primary key; thus the sole determinant is a super‑key.

---

## Sellers

**Attributes:** seller_id (PK), name, email, phone
**Candidate keys:** seller_id

**Functional dependencies:**
* `seller_id → name, email, phone`

**Proof:**
Identical proof: `seller_id` → other columns, and `seller_id` is the primary key ⇒ BCNF.

---

## Neighborhoods

**Attributes:** neighborhood_id (PK), name, city, state, school_rating
**Candidate keys:** neighborhood_id

**Functional dependencies:**
* `neighborhood_id → name, city, state, school_rating`

**Proof:**
`neighborhood_id` is declared PK.  Closure `{neighborhood_id}⁺` contains all attributes, so the only FD has a super‑key on the left.  
No other determinant exists (names are not unique across cities), hence BCNF.

---

## Schools

**Attributes:** school_id (PK), name, neighborhood_id (FK), rating
**Candidate keys:** school_id

**Functional dependencies:**
* `school_id → name, neighborhood_id, rating`

**Proof:**
Primary key `school_id` determines every non‑key attribute.  
Even though `neighborhood_id` is a foreign key, it **does not** functionally determine the school,
because multiple schools may reside in one neighborhood.  
Therefore the only determinant is `school_id` (super‑key) ⇒ BCNF.

---

## Properties

**Attributes:** property_id (PK), address, price, square_feet, year_built, neighborhood_id (FK), seller_id (FK)
**Candidate keys:** property_id

**Functional dependencies:**
* `property_id → address, price, square_feet, year_built, neighborhood_id, seller_id`

**Proof:**
Primary key `property_id` determines all other columns.  
Neither `address` nor `(address, neighborhood_id)` is guaranteed unique (e.g., condos), so no
other determinant holds.  Thus every FD has a super‑key on the left ⇒ BCNF.

---

## Listings

**Attributes:** listing_id (PK), property_id (FK), agent_id (FK), status, list_price, listing_date
**Candidate keys:** listing_id; property_id, listing_date

**Functional dependencies:**
* `listing_id → property_id, agent_id, status, list_price, listing_date`
* `property_id, listing_date → listing_id, agent_id, status, list_price`

**Proof:**
There are two candidate keys:

* `listing_id` (surrogate primary key)  
* `(property_id, listing_date)` (a property can appear at most once per day)

**Check FD 1:** `listing_id` is a candidate key ⇒ super‑key.  
**Check FD 2:** `(property_id, listing_date)` is also a candidate key ⇒ super‑key.

Because *all* determinants are super‑keys, no FD violates BCNF.  
No partial dependency exists on `(property_id, listing_date)` because it is *minimal*—dropping either attribute breaks uniqueness.  
No transitive dependency appears because non‑key attributes (`status`, `list_price`, `agent_id`) do not determine other columns.

---

## Inspections

**Attributes:** inspection_id (PK), property_id (FK), inspection_date, result
**Candidate keys:** inspection_id

**Functional dependencies:**
* `inspection_id → property_id, inspection_date, result`

**Proof:**
`inspection_id` is the only determinant; closure equals the full attribute set ⇒ BCNF.

---

## Transactions

**Attributes:** transaction_id (PK), property_id (FK), buyer_id (FK), sale_date, sale_price
**Candidate keys:** transaction_id

**Functional dependencies:**
* `transaction_id → property_id, buyer_id, sale_date, sale_price`

**Proof:**
`transaction_id` determines all other attributes and is itself the primary key ⇒ BCNF.  
`property_id` alone cannot determine `buyer_id` (a property may be resold), and `(property_id, sale_date)` is not unique across repossessions ⇒ no violating FDs.

---

## Mortgages

**Attributes:** transaction_id (PK & FK), lender, principal, interest_rate, term_years
**Candidate keys:** transaction_id

**Functional dependencies:**
* `transaction_id → lender, principal, interest_rate, term_years`

**Proof:**
One‑to‑one extension of **Transactions**.  
`transaction_id` is both the primary key and foreign key and fully determines every other attribute.  
No other determinant exists ⇒ BCNF.

---

## Favorites

**Attributes:** buyer_id (PK part & FK), property_id (PK part & FK), saved_at
**Candidate keys:** buyer_id, property_id

**Functional dependencies:**
* `buyer_id, property_id → saved_at`

**Proof:**
Composite primary key `(buyer_id, property_id)` is the only determinant:

* **Super‑key test:** its closure contains all columns.  
* **Partial dependency test:** Neither `buyer_id` nor `property_id` alone uniquely identifies a favorite row.  

Therefore the relation meets BCNF; no additional attributes induce transitive dependencies.

---
