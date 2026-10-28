# Snowflake SQL Style Guide v2.0

*A comprehensive, AI-optimized guide for readable, maintainable, and performant SQL development*

## Document Metadata

- **Target Database:** Snowflake
- **Scope:** DML for analytics, dbt models, and SQL transformations
- **Excluded:** DDL, Snowflake-specific features (clustering, time travel, cloning, caching, transactions, MERGE)
- **Version:** 2.0
- **Last Updated:** 2025-12-16
- **RFC-2119 Compliance:** This guide uses MUST, MUST NOT, SHOULD, SHOULD NOT, MAY per RFC-2119

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Principles](#core-principles)
3. [Naming Conventions](#naming-conventions)
4. [Formatting Standards](#formatting-standards)
5. [Common Table Expressions (CTEs)](#common-table-expressions-ctes)
6. [Query Components](#query-components)
7. [Advanced Patterns](#advanced-patterns)
8. [Performance Guidelines](#performance-guidelines)
9. [Code Review Checklist](#code-review-checklist)
10. [AI-Specific Guidance](#ai-specific-guidance)

---

## Quick Start

### The Golden Rules

1. **MUST** use lowercase with underscores in final SELECT; **SHOULD** normalize in first CTE (new code)
2. **MUST** prefix CTEs with `c_`
3. **MUST** use 4-space indentation (never tabs)
4. **MUST** qualify all columns with table/CTE aliases
5. **MUST** use trailing commas in SELECT lists
6. **SHOULD** prefix derived columns with `v_` only when collision risk exists
7. **SHOULD** avoid DISTINCT unless necessary with documentation

### Minimal Working Example

```sql
-- Rule-compliant query structure
with
    c_customer_base as (
        select
            c.customer_id,
            c.customer_name,
            c.registration_date
        from
            raw.customers as c
        where
            c.is_active = true
    )
select
    cb.customer_id,
    cb.customer_name
from
    c_customer_base as cb
order by
    cb.customer_id;
```

---

## Core Principles

### P-001: Consistency Over Personal Preference

**Rule:** Team standards MUST override individual coding preferences.

**Rationale:** Consistent code reduces cognitive load and enables efficient collaboration. When all code follows the same patterns, developers can focus on business logic rather than decoding different styles.

### P-002: Readability as First-Class Concern

**Rule:** Code MUST be optimized for reading and understanding, not minimal line count.

**Rationale:** SQL queries encode business logic that stakeholders need to understand. Code is read 10x more often than it's written.

### P-003: DRY (Don't Repeat Yourself)

**Rule:** Calculated values SHOULD be derived once and referenced multiple times.

**Rationale:** Repeated code increases maintenance burden and creates inconsistency risks. Use CTEs or column references to derive values once.

**Example:**
```sql
-- GOOD: Derive once, reference multiple times
select
    o.order_date,
    o.order_date + interval '30 days' as v_payment_due_date,
    case
        when v_payment_due_date < current_date then 'OVERDUE'
        else 'CURRENT'
    end as payment_status
from
    orders as o;

-- BAD: Repeated calculation
select
    o.order_date,
    o.order_date + interval '30 days' as payment_due_date,
    case
        when o.order_date + interval '30 days' < current_date then 'OVERDUE'
        else 'CURRENT'
    end as payment_status
from
    orders as o;
```

### P-004: Immutability When Possible

**Rule:** Transform data through stages rather than updating in place.

**Rationale:** Immutable transformations make data flow traceable and debuggable. Each CTE represents a clear transformation step.

### P-005: Explicit Over Implicit

**Rule:** Explicit naming and projections MUST be used over implicit references.

**Rationale:** Clear, verbose naming makes code self-documenting and reduces ambiguity. Avoid SELECT * in final queries.

---

## Naming Conventions

### N-001: Case Style and Source Column Normalization

**Priority:** P0 (Critical for final output), P1 (Recommended for internal)

**Rule:**

**Final Projection (MUST - Non-negotiable):**
- The final `SELECT` statement **MUST** use `lowercase_with_underscores` for all column aliases
- This applies to all columns in the output, regardless of source naming

**Internal CTEs (SHOULD - Preferred for new code):**
- Source columns **SHOULD** be normalized to `lowercase_with_underscores` in the first CTE that references them
- All derived columns **SHOULD** use compliant naming even in intermediate steps
- Subsequent CTEs **SHOULD** reference only normalized names

**Legacy Code (MAY - Acceptable for existing transforms):**
- Existing transforms **MAY** preserve source column casing in intermediate CTEs if:
  - Only the final projection is being modified
  - Full refactoring would be disproportionately risky/costly
  - The code is scheduled for future refactoring

**Rationale:** Lowercase is universally supported and readable. Avoids case-sensitivity issues across platforms. Final projection enforcement ensures consistent outputs. Early normalization improves internal readability while allowing pragmatic handling of legacy code.

**Decision Tree:**
```
Is this NEW code or a MAJOR refactor?
├─ YES → Use Option 2 (normalize in first CTE)
└─ NO → Is this a minor change to existing code?
    ├─ YES → Option 1 acceptable (normalize in final SELECT only)
    └─ NO → Prefer Option 2, but Option 1 allowed if justified
```

**Examples:**

**✅ GOOD: Option 2 - Normalize Early (Preferred for new code)**
```sql
with
    c_source_customers as (
        select
            CustomerID as customer_id,      -- Normalize immediately
            FirstName as first_name,
            ACCOUNT_STATUS as account_status
        from
            legacy_db.customers
    ),
    c_enriched as (
        select
            sc.customer_id,                 -- Consistent throughout
            sc.first_name,
            sc.account_status,
            upper(sc.first_name) as first_name_upper
        from
            c_source_customers as sc
    )
select
    e.customer_id,
    e.first_name,
    e.account_status
from
    c_enriched as e;
```

**✅ ACCEPTABLE: Option 1 - Legacy Pattern (For existing code)**
```sql
with
    c_source_customers as (
        select
            CustomerID,                     -- Preserve source casing
            FirstName,
            ACCOUNT_STATUS
        from
            legacy_db.customers
    ),
    c_enriched as (
        select
            sc.CustomerID,
            sc.FirstName,
            sc.ACCOUNT_STATUS,
            upper(sc.FirstName) as FirstNameUpper
        from
            c_source_customers as sc
    )
-- MUST normalize in final projection
select
    e.CustomerID as customer_id,
    e.FirstName as first_name,
    e.ACCOUNT_STATUS as account_status,
    e.FirstNameUpper as first_name_upper
from
    c_enriched as e;
```

**❌ BAD: Non-compliant final projection**
```sql
select
    e.CustomerID,          -- VIOLATION: Final projection not normalized
    e.FirstName,
    e.ACCOUNT_STATUS
from
    c_enriched as e;
```

### N-002: Descriptive Names

**Rule:** Identifiers MUST be descriptive and reveal intent.

**Rationale:** Self-documenting names reduce need for comments and speed up code reviews.

**Examples:**
- ✓ `total_sales_revenue`
- ✓ `customer_acquisition_count`
- ✗ `total_val`
- ✗ `count`

### N-003: Abbreviations

**Rule:** Abbreviations SHOULD only be used for widely understood industry terms.

**Acceptable abbreviations:**
- `id` (identifier)
- `url` (uniform resource locator)
- `api` (application programming interface)
- `roi` (return on investment)

**Examples:**
- ✗ `cust_acq_dt` → ✓ `customer_acquisition_date`
- ✗ `rev_amt` → ✓ `revenue_amount`
- ✗ `prod_cat` → ✓ `product_category`

### N-004: Magic Numbers

**Rule:** Magic numbers and constants MAY be used inline in SQL.

**Rationale:** SQL lacks constant definition capabilities. Document meaning via comments when value significance isn't obvious.

**Example:**
```sql
where
    o.order_date >= '2024-01-01' and  -- Fiscal year start
    o.order_amount > 1000              -- Minimum qualifying order
```

### N-005: Derived Column Prefix (v_) - Optional

**Rule:** Calculated columns MAY be prefixed with `v_` to avoid naming collisions, particularly when using SELECT *.

**Rationale:**
- **Primary purpose:** Prevents namespace collisions with source columns when using SELECT *
- **Not required:** If you explicitly list columns, collisions are unlikely
- **Practical:** No need to remove prefixes at the end - only use when collision risk exists
- **Optional pattern:** Use when it adds clarity or prevents conflicts, skip when unnecessary

**When to use v_ prefix:**
- Using SELECT * to carry forward columns and adding derived columns
- Risk of derived column name matching a source column name
- Debugging complex transformations where derived vs. source distinction helps

**When NOT to use v_ prefix:**
- Final output queries (explicitly list columns)
- No risk of name collision
- Would create unnecessary overhead

**Example with v_ (useful with SELECT *):**
```sql
with
    c_base as (
        select
            o.*,
            o.quantity * o.unit_price as v_line_total,  -- v_ prevents collision if "line_total" exists
            o.tax_rate
        from
            orders as o
    )
select
    cb.order_id,
    cb.v_line_total,
    cb.v_line_total * (1 + cb.tax_rate) as final_total
from
    c_base as cb;
```

**Example without v_ (explicit columns, no collision risk):**
```sql
with
    c_base as (
        select
            o.order_id,
            o.quantity,
            o.unit_price,
            o.quantity * o.unit_price as line_total,  -- No v_ needed
            o.tax_rate
        from
            orders as o
    )
select
    cb.order_id,
    cb.line_total,
    cb.line_total * (1 + cb.tax_rate) as total_with_tax
from
    c_base as cb;
```

### N-006: Aggregation Suffixes - Advisory

**Rule:** Aggregated columns SHOULD use standard suffixes for clarity and consistency.

**Rationale:** Standard suffixes provide immediate understanding of column content and data type expectations. This is advisory guidance to help with naming, not a strict requirement. Avoid overly generic suffixes like `_data` or `_info`, which do not convey the type of aggregation.

**Recommended suffixes:**
- `_cnt` for counts (more concise than `_count`)
- `_sum` for summations (more concise than `_total`)
- `_avg` for averages (more concise than `_average`)
- `_max` / `_min` for extremes
- `_rank` for ranking functions

**When to use:**
- When column name alone doesn't clearly indicate aggregation
- When consistency across similar metrics is important
- When concise naming is valued

**When descriptive names are acceptable:**
- `total_revenue` is fine (clearly a sum)
- `latest_order_date` is fine (clearly a max)
- `customer_count` is acceptable (though `customer_cnt` is more concise)

**Example:**
```sql
select
    o.product_category,
    count(*) as order_cnt,
    sum(o.revenue) as revenue_sum,
    avg(o.order_value) as order_value_avg,
    max(o.order_date) as latest_order_date,
    row_number() over (order by sum(o.revenue) desc) as revenue_rank
from
    orders as o
group by
    o.product_category;
```

### N-007: CTE Prefix (c_)

**Rule:** All CTE names MUST be prefixed with `c_`.

**Rationale:**
- Instantly signals derived dataset within current query
- Prevents naming conflicts with actual tables/views
- Makes data lineage clear

**Example:**
```sql
-- GOOD
with
    c_customer_data as (...)

-- BAD
with
    customer_data as (...)
```

### N-008: Pipeline Suffix (_step_XX)

**Rule:** Sequential transformation CTEs SHOULD use `_step_XX` suffix with increments of 10 or 20.

**Rationale:**
- Shows logical progression clearly
- Enables quick debugging of specific transformation points
- Spacing allows insertion of intermediate steps without renumbering

**Example:**
```sql
with
    c_sales_pipeline_step_10 as (
        -- Initial data selection
        ...
    ),
    c_sales_pipeline_step_20 as (
        -- Enrich with product details
        ...
    ),
    c_sales_pipeline_step_30 as (
        -- Calculate final metrics
        ...
    )
```

**When NOT to use `_step_XX`:**

Use descriptive names for lookup tables or reference CTEs used by multiple other CTEs.

```sql
with
    c_active_customers as (  -- Reference data, not pipeline step
        ...
    ),
    c_sales_pipeline_step_10 as (
        ...
    )
```

---

## Formatting Standards

### F-001: Indentation

**Rule:** MUST use 4-space indentation consistently. MUST NOT use tabs.

**Rationale:** Spaces ensure consistent rendering across all editors and systems. 4 spaces provide clear visual hierarchy.

### F-002: Clause Alignment

**Rule:** Major SQL clauses MUST align at the same indentation level with whitespace on either side.

**Major clauses:** `WITH`, `SELECT`, `FROM`, `WHERE`, `JOIN`, `ON`, `GROUP BY`, `HAVING`, `ORDER BY`, `QUALIFY`

**Example:**
```sql
with
    c_customer_summary as (
        select
            c.customer_id,
            c.customer_name
        from
            customers as c
        where
            c.is_active = true and
            c.registration_date >= '2024-01-01'
    )
select
    cs.customer_id
from
    c_customer_summary as cs;
```

### F-003: Column Alignment

**Rule:** Column names within SELECT blocks SHOULD be vertically aligned.

**Rationale:** Improves scannability and makes column relationships clear.

**Example:**
```sql
select
    ct.transaction_id,         -- Unique transaction identifier
    ct.customer_id,            -- Foreign key to customer
    ct.transaction_date,       -- When transaction occurred
    ct.amount,                 -- Transaction amount in base currency
    ct.currency_code           -- Currency denomination
from
    customer_transactions as ct;
```

### F-004: Column Qualification

**Rule:** All source columns MUST be fully qualified with table or CTE alias. Alias names (after AS keyword) are never qualified.

**What must be qualified:**
- Source columns from tables/CTEs: `c.customer_id`, `o.order_date`
- Source columns in WHERE, JOIN, GROUP BY, ORDER BY clauses
- Source columns within expressions: `sum(o.amount)`, `o.price * o.quantity`

**What is NOT qualified:**
- Alias names themselves: `as customer_name` (not `as c.customer_name`)
- Derived columns when referenced in same SELECT or WHERE/QUALIFY: `v_next_day` (already defined in SELECT)

**Rationale:**
- Prevents ambiguity in multi-table queries
- Makes data lineage explicit
- Simplifies debugging and maintenance
- Alias names are new identifiers, not source references

**Example:**
```sql
-- GOOD: Source columns qualified, alias names are not
select
    c.customer_id,                                    -- ✓ Source column qualified
    c.customer_name as full_name,                     -- ✓ Source qualified, alias is not
    o.order_date + interval '1 day' as v_next_day,    -- ✓ Source qualified, alias is not
    case
        when v_next_day > current_date then 'FUTURE'  -- ✓ Derived column reference, not qualified
        else 'PAST'
    end as date_status                                -- ✓ Alias name is not qualified
from
    customers as c
join
    orders as o
    on c.customer_id = o.customer_id                  -- ✓ Source columns qualified in JOIN
where
    c.is_active = true;                               -- ✓ Source column qualified in WHERE

-- BAD: Source columns not qualified
select
    customer_id,           -- ✗ Source column unqualified
    customer_name,         -- ✗ Source column unqualified
    order_date            -- ✗ Source column unqualified
from
    customers as c
join
    orders as o
    on customer_id = customer_id;  -- ✗ Ambiguous! Which table's customer_id?
```

### F-005: Table Aliases

**Rule:** Table aliases SHOULD use 2-character codes for external tables. CTE aliases in pipelines SHOULD use simple codes like `aa`, `bb`, `cc`.

**Rationale:**
- External table aliases need meaningful names for long-term maintenance
- CTE aliases can be minimal since CTE name provides context
- Consistent length improves visual alignment

**Example:**
```sql
with
    c_sales_data as (
        select
            s.order_id,        -- 's' maps to 'sales'
            s.product_id
        from
            raw.sales as s
    ),
    c_enriched_step_10 as (
        select
            aa.order_id,       -- Simple 'aa' for CTE
            bb.product_name    -- Simple 'bb' for external table
        from
            c_sales_data as aa
        join
            dim.products as bb
            on aa.product_id = bb.product_id
    )
```

### F-006: Trailing Commas

**Rule:** MUST always use trailing commas in SELECT lists.

**Rationale:** Easier to reorder columns, comment out lines, and produces cleaner version control diffs.

**Example:**
```sql
-- GOOD
select
    column_1,
    column_2,
    column_3,    -- Easy to comment out or reorder

-- BAD
select
    column_1
    , column_2   -- Harder to read and maintain
    , column_3
```

### F-007: Boolean Conjunctions

**Rule:** MUST treat `AND` as trailing conjunction. MUST place `OR` on its own line between parenthesized groups.

**Rationale:**
- **AND is common:** Can be treated as trailing conjunction (end of line)
- **OR is critical:** Significantly alters boolean logic and MUST stand out to prevent errors
- **Visual emphasis:** OR on its own line makes the logical split immediately obvious in code review

**Pattern for AND (trailing):**
```sql
where
    condition_1 and
    condition_2 and
    condition_3
```

**Pattern for OR (standalone line):**
```sql
where
    (
        condition_1 and
        condition_2
    )
    or
    (
        condition_3 and
        condition_4
    )
```

**CRITICAL:** The OR operator MUST be on its own line because:
- OR in the wrong place can completely change query logic
- Makes boolean groups visually distinct
- Easier to spot in code review
- Reduces risk of logic errors

**Complete Example:**
```sql
-- GOOD: AND trailing, OR standalone
select
    o.order_id,
    o.customer_id
from
    orders as o
where
    o.order_date >= '2024-01-01' and
    o.status = 'COMPLETED' and
    o.total_amount > 100
    or
    (
        o.customer_segment = 'PREMIUM' and
        o.order_date >= '2023-01-01'
    )

-- GOOD: Complex OR with multiple groups
where
    (
        order_date >= '2024-01-01' and
        status = 'COMPLETED'
    )
    or
    (
        total_amount > 1000 and
        customer_tier = 'GOLD'
    )
    or
    (
        customer_segment = 'PREMIUM'
    )

-- BAD: OR at end of line (hard to spot)
where
    order_date >= '2024-01-01' and status = 'COMPLETED' or
    total_amount > 100

-- BAD: OR trailing like AND (not emphasized)
where
    order_date >= '2024-01-01' and
    status = 'COMPLETED' or
    total_amount > 100
```

### F-008: Empty Lines

**Rule:** MUST NOT use unnecessary blank lines within queries. MUST use blank lines around set operators (`UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT`).

**Rationale:** SQL clauses provide sufficient visual separation. Blank lines reduce information density without adding clarity.

**Example:**
```sql
-- GOOD
select
    count(*)
from
    orders as o
where
    o.order_date >= '2024-01-01'

-- GOOD: Set operators
select customer_id from active_customers

union all

select customer_id from inactive_customers

-- BAD
select
    count(*)

from
    orders as o

where
    o.order_date >= '2024-01-01'
```

### F-009: Simple Functions

**Rule:** Simple function calls SHOULD remain on single lines when they fit within line length (120 chars).

**Example:**
```sql
select
    upper(customer_name) as customer_name_upper,
    coalesce(phone, email, 'No contact') as primary_contact,
    date_trunc('month', order_date) as order_month
from
    customers;
```

### F-010: Complex Function Breakdown

**Rule:** Functions with multiple arguments or exceeding line length MUST be broken down with proper indentation.

**Pattern:**
- Function name and opening parenthesis stay together
- Each argument on its own line, indented 4 spaces
- Closing parenthesis aligned with function name
- Trailing commas on arguments

**Example:**
```sql
select
    customer_id,
    sum(
        coalesce(
            case
                when o.order_status = 'COMPLETED' then o.order_value
                else 0
            end,
            0
        )
    ) as total_completed_revenue
from
    orders as o
group by
    customer_id;
```

### F-011: CASE Statement Formatting

**Rule:** `CASE`, `WHEN`, `ELSE`, and `END` MUST be vertically aligned. Simple cases MAY be inline.

**Example:**
```sql
-- Multi-line
case
    when condition_1 then result_1
    when condition_2 then result_2
    else default_result
end as column_name

-- Inline for simple cases
case when single_condition then result else default end as column_name
```

### F-012: Data Type Casting

**Rule:** MUST use `::` syntax for simple casts. MUST wrap complex expressions in parentheses before casting.

**Example:**
```sql
-- Simple
column_name::varchar as string_column
column_name::date as date_column

-- Complex expression
(aa.sales_amount + 10)::number(20, 2)
(coalesce(base, 0) + coalesce(tax, 0))::number(10, 2)
```

### F-013: Complex Mathematical Expressions

**Rule:** Multi-line mathematical expressions MUST be wrapped in parentheses with trailing operators.

**Pattern:**
- Wrap entire expression in parentheses
- Opening parenthesis on same line as alias
- Indent content 4 spaces
- Use trailing operators (+, -, *, /)
- Closing parenthesis aligns with opening

**Example:**
```sql
select
    customer_id,
    (
        coalesce(base_amount, 0) +
        coalesce(tax_amount, 0) -
        coalesce(discount_amount, 0) +
        coalesce(shipping_amount, 0)
    ) as total_amount
from
    orders;

-- Exception: Simple two-term expressions don't need parentheses
select
    quantity * unit_price as line_total,
    order_date + interval '7 days' as delivery_date
from
    order_items;
```

### F-014: Window Functions

**Rule:** Simple window functions MAY be inline. Complex window functions MUST be broken out.

**Example:**
```sql
-- Simple: inline
row_number() over (partition by customer_id order by order_date) as rn

-- Complex: broken out
row_number() over (
    partition by
        customer_id,
        product_category
    order by
        order_date desc,
        order_value desc
) as rn
```

### F-015: Subquery Formatting

**Rule:** SHOULD prefer CTEs over subqueries. When subqueries are necessary, indent 4 spaces from surrounding context.

**Use subqueries only for:**
- Simple scalar subqueries
- Correlated subqueries where CTE would be inefficient

**Example:**
```sql
select
    o.order_id,
    (
        select
            count(*)
        from
            order_items as oi
        where
            oi.order_id = o.order_id
    ) as item_count
from
    orders as o;

-- Inline for simple scalar
select
    o.order_id
from
    orders as o
where
    o.create_date >= (select max(dt) from control_table);
```

### F-016: Semi-Structured Data (Snowflake VARIANT)

**Rule:** MUST use double-quoted identifiers in JSON attribute names. MUST explicitly cast values.

**Rationale:** Double quotes preserve casing when source is reformatted. Explicit casting ensures correct data types.

**Example:**
```sql
-- Dot notation for known keys
select
    json_column:"customer"."name"::varchar as customer_name,
    json_column:"price"::number(10,2) as price
from
    orders;

-- FLATTEN for arrays
select
    aa.id,
    bb.value:"product_id"::varchar as product_id,
    bb.value:"quantity"::number as quantity
from
    orders as aa
join lateral
    flatten(input => aa.line_items) as bb;
```

### F-017: VALUES Constructor

**Rule:** MUST use VALUES for small inline datasets. MUST align value tuples vertically.

**Example:**
```sql
-- Option 1: Explicit column names
select
    tt.customer_id,
    tt.status,
    tt.balance
from
    values
        (1, 'ACTIVE', 100.00),
        (2, 'INACTIVE', 50.00),
        (3, 'PENDING', 75.00)
    as tt(customer_id, status, balance);

-- Option 2: Column indexes
select
    $1 as customer_id,
    $2 as status,
    $3 as balance
from
    values
        (1, 'ACTIVE', 100.00),
        (2, 'INACTIVE', 50.00),
        (3, 'PENDING', 75.00)
    as tt;
```

### F-018: ORDER BY

**Rule:** MUST use ORDER BY when result order matters. Without it, order is not guaranteed.

**Example:**
```sql
-- BAD: Assumes natural order
select * from customers limit 10;

-- GOOD: Explicit ordering
select *
from customers
order by customer_id
limit 10;
```

### F-019: QUALIFY Clause (Snowflake)

**Rule:** MUST place QUALIFY after WHERE/GROUP BY/HAVING, before ORDER BY. MUST repeat window function in QUALIFY.

**Clause order:** SELECT → FROM → WHERE → GROUP BY → HAVING → QUALIFY → ORDER BY

**Example:**
```sql
select
    customer_id,
    order_date,
    order_value,
    row_number() over (
        partition by customer_id
        order by order_date desc
    ) as rn
from
    orders
where
    order_date >= '2024-01-01'
qualify
    row_number() over (
        partition by customer_id
        order by order_date desc
    ) = 1
order by
    order_value desc;
```

### F-020: String Literals and Identifiers

**Rule:** MUST use single quotes for string literals. SHOULD avoid double-quoted identifiers unless absolutely necessary.

**Rationale:** Single quotes are SQL standard. Double-quoted identifiers create case-sensitive dependencies.

**Example:**
```sql
-- GOOD
where status = 'ACTIVE'

-- BAD (creates case-sensitive identifier)
select "customerId" from customers
```

### F-021: Function Pipelines

**Rule:** For chained function calls, SHOULD use compact formatting.

**Rationale:** Avoids excessive vertical space while maintaining transformation clarity.

**Example:**
```sql
-- GOOD
select
    account_id,
    function_a(function_b(function_c(
        aa.event_name
    ))) as normalized_name
from
    raw.events as aa;

-- NOT IDEAL (too much vertical space)
select
    account_id,
    function_a(
        function_b(
            function_c(
                aa.event_name
            )
        )
    ) as normalized_name
from
    raw.events as aa;
```

### F-022: NULL Handling

**Rule:** MUST explicitly handle NULLs in business-critical logic. MUST document NULL expectations.

**Anti-patterns to avoid:**
- Comparing NULL with = (use IS NULL / IS NOT NULL)
- Using NOT IN with potential NULLs (use NOT EXISTS)
- Missing NULL handling in aggregations

**Example:**
```sql
-- BAD
where customer_name = null  -- Always false

-- GOOD
where customer_name is null

-- Document NULL strategy
coalesce(discount_amount, 0) as discount_amount  -- NULL = no discount applied
```

### F-023: IS DISTINCT FROM

**Rule:** SHOULD use `IS DISTINCT FROM` when comparing values that treats NULL as a value.

**Example:**
```sql
-- GOOD: Compares for absolute equality
where aa.base_value is distinct from bb.base_value

-- BAD: Verbose NULL handling
where coalesce(aa.base_value, 0) != coalesce(bb.base_value, 0)
```

### F-024: JOIN Style

**Rule:** ON clause MUST be inline with join type. Join predicates MUST be on new line indented from ON.

**Example:**
```sql
-- Standard joins (INNER, LEFT, RIGHT, FULL)
select
    aa.id,
    bb.name
from
    header as aa
join
    child as bb
    on
        aa.id = bb.id and
        aa.type = bb.type

-- LATERAL joins
select
    aa.id,
    bb.value::string as name
from
    header as aa
join lateral
    flatten(aa.json_doc) as bb

-- ASOF joins
select
    aa.id,
    bb.value::string as name
from
    header as aa
asof join
    child as bb
    match_condition (
        aa.date >= bb.date
    )
    on
        aa.id = bb.id and
        aa.type = bb.type
```

### F-025: Set Operations

**Rule:** MUST place blank line before and after set operator keywords. Each SELECT MUST have identical column structure.

**Example:**
```sql
select
    customer_id,
    'ACTIVE' as status
from
    active_customers

union all

select
    customer_id,
    'INACTIVE' as status
from
    inactive_customers
```

**Note:** MUST document why UNION (with de-duplication) is chosen over UNION ALL.

---

## Common Table Expressions (CTEs)

### CTE-001: General Structure

**Rule:** CTEs MUST start on new line. First CTE MUST NOT be on same line as WITH clause. Each CTE MUST be indented and aligned.

**Example:**
```sql
-- GOOD
with
    c_cte_1 as (
        select
            c.customer_id
        from
            raw.customers as c
    ),
    c_cte_2 as (
        select
            o.order_id
        from
            raw.orders as o
    )
select
    c1.customer_id
from
    c_cte_1 as c1;

-- BAD
with c_cte_1 as (  -- On same line as WITH
    select customer_id from raw.customers
)
select * from c_cte_1;
```

### CTE-002: CTE Comments

**Rule:** Each CTE SHOULD contain inline comment describing its function, with detail matching code complexity.

**Example:**
```sql
with
    -- Read active customers from last 90 days with valid email addresses
    c_active_customers as (
        ...
    ),
    -- Calculate customer lifetime value including pending orders and refunds
    c_customer_metrics_step_10 as (
        ...
    )
```

### CTE-003: CTE Performance

**Rule:** If CTE is referenced 3+ times in complex query, SHOULD consider temp table or add comment explaining design decision.

**Rationale:** In Snowflake, CTEs referenced multiple times may be executed multiple times (not materialized).

**Example:**
```sql
with
    -- Referenced 4 times below; considered temp table but query completes in <1s
    c_customer_base as (
        ...
    )
```

### CTE-004: Pipeline Pattern

**Rule:** For complex transformations, SHOULD use base → step_XX → final naming pattern.

**Example:**
```sql
with
    c_customer_base as (
        -- Initial data load with basic filters
        select ...
    ),
    c_customer_step_10 as (
        -- Enrich with demographic data
        select
            aa.*,
            bb.segment
        from
            c_customer_base as aa
        join
            dim.demographics as bb
            on aa.customer_id = bb.customer_id
    ),
    c_customer_step_20 as (
        -- Calculate derived metrics
        select
            aa.*,
            aa.total_orders / aa.months_active as v_orders_per_month
        from
            c_customer_step_10 as aa
    ),
    c_customer as (
        -- Final selection and filtering
        select
            aa.customer_id,
            aa.segment,
            aa.v_orders_per_month as orders_per_month
        from
            c_customer_step_20 as aa
        where
            aa.v_orders_per_month > 1
    )
select * from c_customer;
```

---

## Query Components

### QC-001: GROUP BY

**Rule:** MUST list all non-aggregated columns in GROUP BY. SHOULD use column names, not positions.

**Rationale:** Column names are clearer than positions. Snowflake doesn't infer functional dependencies like some databases.

**Example:**
```sql
-- GOOD
select
    product_id,
    sum(sale_amount) as total_sales
from
    sales
group by
    product_id

-- BAD: Using positions
select
    product_id,
    sum(sale_amount) as total_sales
from
    sales
group by
    1  -- Unclear what column 1 is
```

### QC-002: Separate Aggregation from Presentation

**Rule:** SHOULD separate aggregation logic from presentation logic using CTEs.

**Rationale:** Makes complex queries more readable and maintainable.

**Example:**
```sql
-- GOOD
with
    c_sales_aggregates as (
        select
            product_id,
            sum(sale_amount) as total_sales,
            count(*) as sale_count
        from
            sales
        group by
            product_id
    )
select
    p.product_name,
    sa.total_sales,
    sa.sale_count
from
    products as p
join
    c_sales_aggregates as sa
    on p.product_id = sa.product_id;
```

### QC-003: DISTINCT Usage

**Rule:** SHOULD avoid SELECT DISTINCT unless necessary. MUST include comment explaining why when used.

**Rationale:**
- Performance impact on large datasets
- Often indicates misunderstood query logic
- Duplicates should be addressed at source

**Better approaches:**
- Proper joins
- WHERE filters
- GROUP BY aggregations
- Window functions (ROW_NUMBER)
- EXISTS/NOT EXISTS

**Example:**
```sql
-- BAD: Masking duplicate issue
select distinct customer_id from orders;

-- GOOD: Using QUALIFY and ROW_NUMBER
select
    customer_id,
    customer_name,
    row_number() over (partition by customer_id order by registration_date desc) as rn
from
    customer_audit
qualify
    row_number() over (partition by customer_id order by registration_date desc) = 1;
```

**When DISTINCT is acceptable:**
- Legacy system where duplicates can't be prevented
- Business requirement explicitly calls for unique values
- No other deduplication method is appropriate
- MUST include comment explaining rationale

---

## Advanced Patterns

### AP-001: Immutability and Data Flow

**Rule:** SHOULD transform data through stages rather than updating in place.

**Rationale:** Immutable transformations improve debugging, testing, and data lineage tracking.

**Example:**
```sql
with
    c_base as (
        select
            order_id,
            customer_id,
            total_amount
        from
            orders
        where
            order_date >= '2024-01-01'
    ),
    c_enriched as (
        select
            b.*,
            c.customer_tier
        from
            c_base as b
        join
            customers as c
            on b.customer_id = c.customer_id
    )
select * from c_enriched;
```

### AP-002: Strategic SELECT *

**Rule:** SELECT * MAY be used in intermediate CTE steps when schema is well-defined. MUST NOT be used in final query output.

**Rationale:** In CTE pipelines, previous steps define exact columns. SELECT * reduces repetition for intermediate transforms.

**Example:**
```sql
with
    c_base as (
        select
            order_id,
            customer_id,
            order_amount
        from
            orders
    ),
    c_enriched as (
        select
            b.*,                    -- Acceptable: we know exactly what b contains
            c.customer_name
        from
            c_base as b
        join
            customers as c
            on b.customer_id = c.customer_id
    )
select
    order_id,               -- Final SELECT must be explicit
    customer_name,
    order_amount
from
    c_enriched;
```

### AP-003: Column References in Snowflake

**Rule:** MAY reference columns defined earlier in SELECT projection within same query (WHERE, QUALIFY, subsequent column calculations).

**Rationale:** Snowflake-specific feature that reduces code repetition and improves maintainability.

**Example:**
```sql
select
    customer_id,
    upper(regexp_replace(surname, '\\s', '')) as surname_cleaned,
    upper(regexp_replace(postcode, '\\s', '')) as postcode_compressed
from
    customers
where
    postcode_compressed not in ('HP24YL', 'HP24YJ') and
    surname_cleaned != '';
```

---

## Performance Guidelines

### PG-001: Write for Readability First

**Rule:** MUST write for readability first, optimize for performance when testing shows issues.

**Rationale:** Modern databases (Snowflake, BigQuery) have sophisticated optimizers. Premature optimization reduces maintainability.

### PG-002: Document Performance Decisions

**Rule:** MUST document performance-critical sections and optimization decisions.

**Example:**
```sql
-- Pre-filter large table to reduce join overhead
-- Expected to reduce dataset from 100M to ~1M rows
with
    c_large_table_filtered as (
        select
            customer_id,
            transaction_date,
            amount
        from
            large_transaction_table
        where
            transaction_date >= current_date - interval '90 days'  -- Critical filter
            and amount > 0
    )
```

### PG-003: Snowflake Query Optimization

**Rule:** SHOULD optimize for Snowflake's architecture.

**Best practices:**
- Filter early to leverage micro-partition pruning
- Avoid SELECT * in production to reduce data transfer
- Use appropriate join types
- Leverage QUALIFY for window function filtering

---

## Code Review Checklist

### Quick Review Checklist

**Naming (N-001 to N-008):**
- [ ] All identifiers lowercase with underscores
- [ ] CTEs prefixed with `c_`
- [ ] Pipeline CTEs use `_step_XX` with 10/20 increments
- [ ] Derived columns use `v_` in intermediate steps
- [ ] Aggregations use standard suffixes (_cnt, _sum, etc.)

**Formatting (F-001 to F-025):**
- [ ] 4-space indentation throughout
- [ ] Trailing commas in SELECT lists
- [ ] Major clauses aligned at same level
- [ ] All source columns qualified with alias
- [ ] AND trailing, OR wrapped in parentheses
- [ ] No unnecessary blank lines
- [ ] Table aliases: 2-char for external, aa/bb for CTEs

**Logic (QC-001 to QC-003):**
- [ ] No SELECT * in final query
- [ ] DISTINCT usage justified with comment
- [ ] NULL handling explicit in business logic
- [ ] JOIN conditions complete and correct
- [ ] WHERE filters applied early

**Snowflake-Specific:**
- [ ] QUALIFY used for window function filtering
- [ ] :: casting for simple types
- [ ] String literals use single quotes
- [ ] No double-quoted identifiers unless justified

**Documentation:**
- [ ] Complex CTEs have descriptive comments
- [ ] Performance-critical sections documented
- [ ] Business rules explained
- [ ] Magic numbers have explanatory comments

### Decision Trees for Reviewers

**CTE Naming:**
```
Has WITH clause?
├─ Yes: CTEs start with c_?
│  ├─ Yes: ✓ PASS
│  └─ No: ✗ FAIL (Rule N-007)
└─ No: Skip
```

**Pipeline Naming:**
```
CTE is sequential pipeline?
├─ Yes: Uses _step_XX with 10/20 increments?
│  ├─ Yes: ✓ PASS
│  └─ No: ✗ FAIL (Rule N-008)
└─ No: Uses descriptive name?
   ├─ Yes: ✓ PASS
   └─ No: ⚠ WARNING
```

**DISTINCT Usage:**
```
Uses DISTINCT?
├─ Yes: Has comment explaining why?
│  ├─ Yes: ✓ PASS (review justification)
│  └─ No: ✗ FAIL (Rule QC-003)
└─ No: ✓ PASS
```

---

## AI-Specific Guidance

### For AI Code Generation

When generating SQL code, AI systems MUST:

1. **Apply all MUST rules automatically** without asking for confirmation
2. **Apply SHOULD rules by default** unless context indicates otherwise
3. **Explain MAY rules** when multiple valid approaches exist
4. **Reference rule IDs** when explaining decisions (e.g., "Applied N-007 for CTE naming")
5. **Generate compliant code** even when given non-compliant examples

### Rule Priority for AI

**P0 (Critical - Never violate):**
- N-001 (lowercase with underscores)
- N-007 (CTE c_ prefix)
- F-001 (4-space indentation)
- F-004 (column qualification)
- F-006 (trailing commas)
- F-007 (AND trailing, OR wrapped)

**P1 (High - Violate only with explicit justification):**
- N-008 (pipeline _step_XX)
- F-010 (complex function breakdown)
- QC-003 (avoid DISTINCT)

**P2 (Medium - Apply by default, flexible in edge cases):**
- N-005 (v_ prefix for collision avoidance - optional)
- N-006 (aggregation suffixes - advisory)
- F-003 (column alignment)
- F-015 (prefer CTEs over subqueries)
- AP-002 (strategic SELECT *)

### Pattern Matching for AI Validation

**Identifier validation:**
```regex
# Valid identifier
^[a-z][a-z0-9_]*$

# Valid CTE name
^c_[a-z][a-z0-9_]*$

# Valid pipeline CTE
^c_[a-z][a-z0-9_]*_step_[0-9]{2,}$

# Valid derived column
^v_[a-z][a-z0-9_]*$

# Valid aggregation column
^[a-z][a-z0-9_]*_(cnt|sum|avg|max|min|rank)$
```

### Structured Rule Reference

Each rule has:
- **ID:** Unique identifier (e.g., N-007, F-004)
- **RFC-2119 Level:** MUST, MUST NOT, SHOULD, SHOULD NOT, MAY
- **Category:** Naming, Formatting, CTE, Query Component, Advanced Pattern, Performance
- **Description:** Clear statement of rule
- **Rationale:** Why rule exists
- **Example:** Code demonstrating rule
- **AI Priority:** P0, P1, or P2

---

## Complete Examples

### Example 1: Simple Aggregation Query

```sql
-- Customer order summary for Q4 2024
-- Purpose: Calculate customer order metrics for quarterly reporting
with
    -- Filter to Q4 2024 completed orders only
    c_q4_orders as (
        select
            o.customer_id,
            o.order_id,
            o.order_date,
            o.total_amount
        from
            raw.orders as o
        where
            o.order_date between '2024-10-01' and '2024-12-31' and
            o.status = 'COMPLETED'
    )
select
    c.customer_id,
    c.customer_name,
    c.customer_email,
    count(qo.order_id) as order_cnt,
    sum(qo.total_amount) as total_spent_sum,
    avg(qo.total_amount) as avg_order_value,
    max(qo.order_date) as last_order_date
from
    customers as c
left join
    c_q4_orders as qo
    on c.customer_id = qo.customer_id
where
    c.is_active = true
group by
    c.customer_id,
    c.customer_name,
    c.customer_email
order by
    total_spent_sum desc nulls last;
```

### Example 2: Complex Pipeline with Transformations

```sql
-- Sales performance analysis with customer segmentation
-- Purpose: Calculate sales metrics by customer segment and product category
-- Business Rules:
--   - Premium customers get 5% discount
--   - Gold customers get 3% discount
--   - Minimum order threshold: $100
with
    -- Step 1: Load base sales data from last 90 days
    c_sales_pipeline_step_10 as (
        select
            s.sale_id,
            s.customer_id,
            s.product_id,
            s.sale_date,
            s.quantity,
            s.unit_price,
            s.total_amount
        from
            raw.sales as s
        where
            s.sale_date >= current_date - interval '90 days' and
            s.status = 'COMPLETED'
    ),
    -- Step 2: Enrich with customer segment data
    c_sales_pipeline_step_20 as (
        select
            sp.*,
            c.customer_segment,
            c.customer_tier,
            c.registration_date
        from
            c_sales_pipeline_step_10 as sp
        join
            dim.customers as c
            on sp.customer_id = c.customer_id
    ),
    -- Step 3: Add product hierarchy information
    c_sales_pipeline_step_30 as (
        select
            sp.*,
            p.product_name,
            p.product_category,
            p.product_subcategory
        from
            c_sales_pipeline_step_20 as sp
        join
            dim.products as p
            on sp.product_id = p.product_id
    ),
    -- Step 4: Calculate derived metrics with business rules
    c_sales_pipeline_step_40 as (
        select
            sp.*,
            sp.quantity * sp.unit_price as v_calculated_total,
            case
                when sp.customer_tier = 'PREMIUM' then sp.total_amount * 0.95
                when sp.customer_tier = 'GOLD' then sp.total_amount * 0.97
                else sp.total_amount
            end as v_discounted_amount,
            date_trunc('month', sp.sale_date) as v_sale_month
        from
            c_sales_pipeline_step_30 as sp
    ),
    -- Step 5: Filter to qualifying orders only
    c_sales_final as (
        select
            sp.customer_segment,
            sp.product_category,
            sp.v_sale_month,
            sp.v_discounted_amount,
            sp.customer_id
        from
            c_sales_pipeline_step_40 as sp
        where
            sp.v_discounted_amount >= 100  -- Minimum order threshold
    )
select
    sf.customer_segment,
    sf.product_category,
    sf.v_sale_month as sale_month,
    count(*) as transaction_cnt,
    sum(sf.v_discounted_amount) as total_revenue_sum,
    avg(sf.v_discounted_amount) as avg_transaction_value,
    count(distinct sf.customer_id) as unique_customer_cnt
from
    c_sales_final as sf
group by
    sf.customer_segment,
    sf.product_category,
    sf.v_sale_month
order by
    sale_month,
    total_revenue_sum desc;
```

### Example 3: Window Functions with QUALIFY

```sql
-- Most recent order per customer with ranking
-- Purpose: Identify each customer's latest order and rank by value
with
    -- Get all completed orders with customer info
    c_customer_orders as (
        select
            o.customer_id,
            c.customer_name,
            o.order_id,
            o.order_date,
            o.order_value,
            row_number() over (
                partition by o.customer_id
                order by o.order_date desc
            ) as rn
        from
            orders as o
        join
            customers as c
            on o.customer_id = c.customer_id
        where
            o.status = 'COMPLETED' and
            o.order_date >= '2024-01-01'
        qualify
            row_number() over (
                partition by o.customer_id
                order by o.order_date desc
            ) = 1
    )
select
    co.customer_id,
    co.customer_name,
    co.order_id as latest_order_id,
    co.order_date as latest_order_date,
    co.order_value,
    rank() over (order by co.order_value desc) as value_rank
from
    c_customer_orders as co
order by
    value_rank;
```

---

## Glossary

- **CTE (Common Table Expression):** Temporary named result set within SQL statement
- **ETL (Extract, Transform, Load):** Process for moving data from source to destination
- **Immutability:** Pattern of transforming data through stages rather than updating in place
- **LATERAL Join:** Join type allowing right-side to reference left-side columns
- **Micro-partition:** Snowflake's automatic data partitioning unit (50-500 MB compressed)
- **Pipeline:** Series of sequential data transformations
- **QUALIFY:** Snowflake clause for filtering rows based on window function results
- **VARIANT:** Snowflake data type for semi-structured data (JSON, XML, Avro, Parquet)
- **Window Function:** Function that performs calculation across set of rows related to current row

---

## References

- Snowflake Documentation: https://docs.snowflake.com/
- dbt Best Practices: https://docs.getdbt.com/guides/best-practices
- RFC-2119 Key words: https://www.ietf.org/rfc/rfc2119.txt
- SQL Style Guide Community Standards

---

## Version History

- **v2.0 (2025-12-16):** Complete restructure with rule IDs, RFC-2119 compliance, AI-specific guidance
- **v1.0:** Initial comprehensive guide

---

**Remember:** *Write SQL for the next developer who will read it, including your future self.*
