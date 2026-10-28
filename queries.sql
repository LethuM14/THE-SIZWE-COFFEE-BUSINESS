-- Task 1: Channel performance
SELECT
    so.channel,
    ROUND(SUM(CASE WHEN so.order_date <= '2024-06-30' THEN sl.line_revenue ELSE 0 END), 2) AS fy2024_revenue,
    ROUND(SUM(CASE WHEN so.order_date >  '2024-06-30' THEN sl.line_revenue ELSE 0 END), 2) AS fy2025_revenue,
    ROUND(
        (SUM(CASE WHEN so.order_date >  '2024-06-30' THEN sl.line_revenue ELSE 0 END)
       - SUM(CASE WHEN so.order_date <= '2024-06-30' THEN sl.line_revenue ELSE 0 END)) * 100.0
        / NULLIF(SUM(CASE WHEN so.order_date <= '2024-06-30' THEN sl.line_revenue ELSE 0 END), 0)
    , 1) AS growth_pct
FROM sizwe_sales_orders so
JOIN sizwe_sales_lines sl ON so.order_id = sl.order_id
GROUP BY so.channel
ORDER BY so.channel;

-- Answer: Both channels grew at the same rate of 8.8%. Wholesale remains the
-- larger channel (R308m to R335m) while Subscription grew from R133m to R145m.
-- The identical growth rate shows balanced expansion rather than a channel mix shift.


-- Task 2: Where the profit actually comes from
SELECT
    p.product_line,
    ROUND(SUM(sl.line_revenue), 2) AS revenue,
    ROUND(SUM(sl.cogs), 2) AS cogs,
    ROUND(SUM(sl.line_revenue) - SUM(sl.cogs), 2) AS gross_profit,
    ROUND((SUM(sl.line_revenue) - SUM(sl.cogs)) * 100.0 / NULLIF(SUM(sl.line_revenue), 0), 1) AS gross_margin_pct
FROM sizwe_sales_lines sl
JOIN sizwe_products p ON sl.sku = p.sku
GROUP BY p.product_line
ORDER BY gross_profit DESC;

-- Answer: House Blend earns the most absolute profit (R107m). It is not the
-- highest-margin line; Single Origin leads on margin at 44.3% while House Blend
-- sits at 38.3%. Bulk Commercial is the lowest-margin line at 19.9%.


-- Task 3: The collections problem
SELECT
    c.channel,
    COUNT(*) AS num_invoices,
    SUM(CASE WHEN ar.amount_settled >= ar.invoice_amount THEN 1 ELSE 0 END) AS settled,
    SUM(CASE WHEN ar.amount_settled < ar.invoice_amount OR ar.settlement_date IS NULL THEN 1 ELSE 0 END) AS open_invoices,
    ROUND(AVG(CASE WHEN ar.settlement_date IS NOT NULL
                   THEN DATE_DIFF(DAY, ar.invoice_date, ar.settlement_date) END), 1) AS avg_days_to_settle,
    ROUND(SUM(ar.invoice_amount - ar.amount_settled), 2) AS outstanding_value
FROM sizwe_ar_ledger ar
JOIN sizwe_customers c ON ar.customer_id = c.customer_id
GROUP BY c.channel
ORDER BY c.channel;

-- Answer: Wholesale is the collections problem. Average days to settle is 68.7
-- versus only 3.8 for Subscription, and R87.8m remains outstanding against
-- R0.75m for Subscription. Investigate Wholesale first, focusing on the 3,454
-- open invoices and the longer payment terms that dominate that channel.


-- Task 4: The ten accounts that matter most
SELECT
    c.trading_name,
    c.segment,
    c.province,
    COALESCE(r.rep_name, 'Unassigned') AS sales_rep,
    ROUND(SUM(sl.line_revenue), 2) AS fy2025_revenue
FROM sizwe_sales_orders so
JOIN sizwe_sales_lines sl ON so.order_id = sl.order_id
JOIN sizwe_customers c ON so.customer_id = c.customer_id
LEFT JOIN sizwe_reps r ON c.rep_id = r.rep_id
WHERE so.order_date > '2024-06-30'
GROUP BY c.trading_name, c.segment, c.province, r.rep_name
ORDER BY fy2025_revenue DESC
LIMIT 10;


-- Task 5: A commercial gap
WITH wholesale_rev AS (
    SELECT
        c.customer_id,
        c.trading_name,
        c.segment,
        c.province,
        SUM(sl.line_revenue) AS total_revenue
    FROM sizwe_customers c
    JOIN sizwe_sales_orders so ON c.customer_id = so.customer_id
    JOIN sizwe_sales_lines sl ON so.order_id = sl.order_id
    WHERE c.channel = 'Wholesale'
    GROUP BY c.customer_id, c.trading_name, c.segment, c.province
),
promoted AS (
    SELECT DISTINCT customer_id FROM sizwe_trade_promotions
)
SELECT
    wr.trading_name,
    wr.segment,
    wr.province,
    ROUND(wr.total_revenue, 2) AS revenue
FROM wholesale_rev wr
LEFT JOIN promoted p ON wr.customer_id = p.customer_id
WHERE p.customer_id IS NULL
ORDER BY wr.total_revenue DESC
LIMIT 15;

-- Answer: Prioritise promotional support for the top three a targeted volume rebate or
-- new-listing package could protect or grow the relationship.


-- Task 6: Are the sales representatives hitting target?
WITH fy2025_rev AS (
    SELECT
        so.rep_id,
        SUM(sl.line_revenue) AS total_rev
    FROM sizwe_sales_orders so
    JOIN sizwe_sales_lines sl ON so.order_id = sl.order_id
    WHERE so.order_date > '2024-06-30'
    GROUP BY so.rep_id
)
SELECT
    r.rep_name,
    r.territory,
    r.target_monthly,
    ROUND(COALESCE(f.total_rev, 0) / 12.0, 2) AS avg_monthly_actual,
    ROUND((COALESCE(f.total_rev, 0) / 12.0) * 100.0 / r.target_monthly, 1) AS pct_of_target
FROM sizwe_reps r
LEFT JOIN fy2025_rev f ON r.rep_id = f.rep_id
ORDER BY pct_of_target DESC;


-- Task 7: The shape of the year
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', so.order_date) AS month,
        SUM(sl.line_revenue) AS revenue
    FROM sizwe_sales_orders so
    JOIN sizwe_sales_lines sl ON so.order_id = sl.order_id
    GROUP BY 1
)
SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
          / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS pct_change,
    ROUND(AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_3m_avg
FROM monthly
ORDER BY month;

-- Answer: There is a clear seasonal pattern. Revenue dips sharply every December
-- (around 13% month-on-month) and recovers through the first half of the calendar
-- year, peaking around June/July. December is consistently Sizwe’s quietest month.


-- Task 8: Why has the margin moved?
WITH by_year AS (
    SELECT
        p.product_line,
        CASE WHEN so.order_date <= '2024-06-30' THEN 'FY2024' ELSE 'FY2025' END AS fy,
        SUM(sl.line_revenue) AS revenue,
        SUM(sl.line_revenue) - SUM(sl.cogs) AS gp
    FROM sizwe_sales_lines sl
    JOIN sizwe_sales_orders so ON sl.order_id = so.order_id
    JOIN sizwe_products p ON sl.sku = p.sku
    GROUP BY 1, 2
),
totals AS (
    SELECT fy, SUM(revenue) AS total_rev FROM by_year GROUP BY fy
)
SELECT
    b.product_line,
    ROUND(MAX(CASE WHEN b.fy = 'FY2024' THEN b.revenue END), 2) AS rev_fy2024,
    ROUND(MAX(CASE WHEN b.fy = 'FY2024' THEN b.gp * 100.0 / NULLIF(b.revenue, 0) END), 1) AS margin_fy2024,
    ROUND(MAX(CASE WHEN b.fy = 'FY2024' THEN b.revenue * 100.0 / t24.total_rev END), 1) AS share_fy2024,
    ROUND(MAX(CASE WHEN b.fy = 'FY2025' THEN b.revenue END), 2) AS rev_fy2025,
    ROUND(MAX(CASE WHEN b.fy = 'FY2025' THEN b.gp * 100.0 / NULLIF(b.revenue, 0) END), 1) AS margin_fy2025,
    ROUND(MAX(CASE WHEN b.fy = 'FY2025' THEN b.revenue * 100.0 / t25.total_rev END), 1) AS share_fy2025
FROM by_year b
CROSS JOIN (SELECT total_rev FROM totals WHERE fy = 'FY2024') t24
CROSS JOIN (SELECT total_rev FROM totals WHERE fy = 'FY2025') t25
GROUP BY b.product_line
ORDER BY product_line;

-- Answer: The overall gross margin fell from 34.7% to 33.0% because of a mix
-- shift toward Bulk Commercial. That line’s revenue share rose from 25.0% to
-- 33.6% while its margin stayed low at 19.9%. Higher-margin lines (House Blend,
-- Single Origin, Capsules) all lost share. Individual product-line margins were
-- essentially stable; the decline is almost entirely mix-driven.
