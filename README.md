# THE-SIZWE-COFFEE-BUSINESS
# Sizwe Coffee – SQL Year-End Analysis

## Project overview

This project answers eight business questions raised by Nomsa Dlamini (Financial Director) and Bongani Twala (National Sales Manager) ahead of the Sizwe Coffee year-end review (financial year ended 30 June 2025).

Sizwe Coffee is a Johannesburg-based coffee roastery and wholesale supplier with a second distribution centre in Cape Town. It sells roasted coffee to approximately 1,400 business customers across Grocery Chains, Restaurant Groups, Independent Cafés, Hotel Groups and office/subscription accounts. Revenue reached R480 m in FY2025 (up from R441 m in FY2024). The business operates two channels: Wholesale (≈70 %) and Subscription (≈30 %).

The eight questions cover channel performance, product-line profitability, collections health, key accounts, trade-promotion gaps, sales-rep target attainment, seasonality and the drivers of the observed gross-margin decline.

## Dataset

Nine tables were used:

| Table              | Rows   | Description |
|--------------------|--------|-------------|
| customers          | 1 400  | One row per customer (channel, segment, province, credit limit, assigned rep) |
| products           | 23     | SKUs with product line, pack size, list price and unit cost |
| sales_orders       | 48 144 | Order header (customer, dates, channel, rep) |
| sales_lines        | 168 172| Order lines – **revenue and COGS live here** |
| ar_ledger          | 48 144 | Invoices, due dates, amounts settled |
| reps               | 18     | Sales representatives and monthly targets |
| rep_visits         | 9 400  | Field visits and outcomes |
| trade_promotions   | 640    | Promotional support given to customers |
| vendors            | 74     | Suppliers (not required for the eight tasks) |

Key relationships:
- `sales_orders.customer_id` → `customers.customer_id`
- `sales_orders.order_id` → `sales_lines.order_id`
- `sales_lines.sku` → `products.sku`
- `customers.rep_id` / `sales_orders.rep_id` → `reps.rep_id`
- `ar_ledger.customer_id` → `customers.customer_id`
- `trade_promotions.customer_id` → `customers.customer_id`

Revenue is taken exclusively from `sales_lines.line_revenue`. Financial years are defined on `sales_orders.order_date`:
- FY2024 = order_date ≤ 2024-06-30
- FY2025 = order_date > 2024-06-30

## Skills demonstrated

| Technique              | Tasks |
|------------------------|-------|
| Multi-table JOINs      | All   |
| Conditional aggregation (CASE + SUM) | 1, 3, 8 |
| Date filtering & DATE_TRUNC | 1, 4, 6, 7, 8 |
| Window functions (LAG, rolling AVG) | 7 |
| CTEs                   | 5, 6, 7, 8 |
| LEFT JOIN to preserve all rows | 4, 5, 6 |
| GROUP BY + ORDER BY + LIMIT | 2, 4, 5 |
| COALESCE / NULL handling | 3, 4, 6 |

## How to run

1. Place the nine CSV files in a folder (or use the provided DuckDB file).
2. Open a DuckDB session (CLI or Python):

```bash
duckdb sizwe.db
```

3. Load the CSVs (if not already loaded):

```sql
CREATE TABLE customers AS SELECT * FROM read_csv_auto('sizwe_customers.csv', header=true);
-- repeat for the other eight tables
```

4. Execute the statements in `queries.sql` in order. Each query is preceded by a comment indicating the task number and is followed (where required) by a short written answer.

All queries were developed and validated in DuckDB 2.0 (PostgreSQL-compatible dialect).

## Key insights

### For Nomsa (Finance)

- Channel growth is balanced. Both Wholesale and Subscription grew at 8.8 %. Wholesale remains the larger engine (R335 m vs R145 m).
- Collections risk is concentrated in Wholesale.Average days-to-settle is 68.7 days and R87.8 m is outstanding, versus 3.8 days and R0.75 m for Subscription. Immediate focus on the 3 454 open Wholesale invoices is warranted.
- Gross margin decline is mix-driven. Overall margin fell from 34.7 % to 33.0 %. Individual product-line margins were stable; the drop was caused by Bulk Commercial rising from 25 % to 33.6 % of revenue while carrying only a 19.9 % margin. Higher-margin lines (House Blend, Single Origin) lost share.

### For Bongani (Sales)

- Top account concentration. Halvane Retail Group alone delivered R38.4 m in FY2025 – an order of magnitude larger than the next customer.
- Trade-promotion white space. Fifteen high-revenue Wholesale customers (led by Umhlanga Fresh 108, Ridgeway Foods 308 and Kalahari Kitchen 42) have never received a trade promotion. A targeted programme for the top three would be a low-risk way to protect volume.
- Rep performance is strong overall.16 of 18 representatives exceeded 100 % of monthly target on a FY2025 average basis. The two under-performers (Sipho Steyn 98 %, Johan Naidoo 78 %) merit coaching conversations.
- Seasonality is predictable.December is consistently the quietest month (≈13 % MoM decline). Planning and cash-flow forecasts should explicitly allow for this pattern.



