/* =====================================================================
   ARMDD 2026/27 - MoreRhythm Data Mart
   Script : 01_Data_Profiling.sql
   Owner  : Michal Binek
   Purpose: Data profiling of the operational database (MoreRhythm)
            before designing the staging area and the cleansing rules.
   Focus  : (1) customer tax IDs (taxpayer_number) - duplicates,
                placeholders, invalid Portuguese NIF check digits,
                near-duplicate customers;
            (2) invoice timestamps (invoice_date, create_*, last_update_*,
                payment_date) - ordering and consistency;
            (3) supporting checks used by the cleansing rules
                (amounts, signs, VAT, orphan keys, currency, shipping).
   ===================================================================== */
USE MoreRhythm;
GO
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   0. Volume overview
   --------------------------------------------------------------------- */
SELECT s.name + '.' + t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s     ON s.schema_id = t.schema_id
JOIN sys.partitions p  ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE t.name <> 'sysdiagrams'
GROUP BY s.name, t.name
ORDER BY table_name;
GO

/* =====================================================================
   1. CUSTOMERS - TAX NUMBER (taxpayer_number) PROFILING
   ===================================================================== */

/* 1.1 Column profile: nulls, blanks, lengths, numeric-only */
SELECT
    COUNT(*)                                                         AS total_rows,
    SUM(CASE WHEN taxpayer_number IS NULL THEN 1 ELSE 0 END)         AS null_tax,
    SUM(CASE WHEN LTRIM(RTRIM(taxpayer_number)) = '' THEN 1 ELSE 0 END) AS blank_tax,
    SUM(CASE WHEN LTRIM(RTRIM(taxpayer_number)) NOT LIKE '%[^0-9]%'
              AND LEN(LTRIM(RTRIM(taxpayer_number))) = 9 THEN 1 ELSE 0 END) AS nine_digit_numeric,
    COUNT(DISTINCT taxpayer_number)                                  AS distinct_tax,
    MIN(LEN(taxpayer_number))                                        AS min_len,
    MAX(LEN(taxpayer_number))                                        AS max_len
FROM dbo.customers;
GO

/* 1.2 Placeholder / dummy tax numbers (internal customers, cash sales) */
SELECT number, name, taxpayer_number, type, segment
FROM dbo.customers
WHERE LTRIM(RTRIM(taxpayer_number)) = ''
   OR LTRIM(RTRIM(taxpayer_number)) NOT LIKE '%[^0]%'          -- only zeros
   OR LEN(LTRIM(RTRIM(taxpayer_number))) <> 9
ORDER BY number;
GO

/* 1.3 Exact duplicate tax numbers (same NIF on different customer ids) */
SELECT c.taxpayer_number, COUNT(*) AS occurrences,
       STRING_AGG(CAST(c.number AS varchar(10)) + ':' + c.name, ' | ') AS customers
FROM dbo.customers c
WHERE LEN(LTRIM(RTRIM(c.taxpayer_number))) = 9
  AND c.taxpayer_number LIKE '%[^0]%'
GROUP BY c.taxpayer_number
HAVING COUNT(*) > 1;
GO

/* 1.4 Portuguese NIF check-digit validation (modulo 11)
       check = 11 - (sum(d_i * (9 - i)) mod 11), i = 1..8 ; if result >= 10 -> 0 */
WITH n AS (
    SELECT number, name, LTRIM(RTRIM(taxpayer_number)) AS nif
    FROM dbo.customers
    WHERE LEN(LTRIM(RTRIM(taxpayer_number))) = 9
      AND LTRIM(RTRIM(taxpayer_number)) NOT LIKE '%[^0-9]%'
), calc AS (
    SELECT number, name, nif,
        ( CAST(SUBSTRING(nif,1,1) AS int)*9 + CAST(SUBSTRING(nif,2,1) AS int)*8
        + CAST(SUBSTRING(nif,3,1) AS int)*7 + CAST(SUBSTRING(nif,4,1) AS int)*6
        + CAST(SUBSTRING(nif,5,1) AS int)*5 + CAST(SUBSTRING(nif,6,1) AS int)*4
        + CAST(SUBSTRING(nif,7,1) AS int)*3 + CAST(SUBSTRING(nif,8,1) AS int)*2 ) % 11 AS r,
        CAST(SUBSTRING(nif,9,1) AS int) AS given_check
    FROM n
)
SELECT number, name, nif, given_check,
       CASE WHEN r < 2 THEN 0 ELSE 11 - r END AS expected_check,
       CASE WHEN given_check = CASE WHEN r < 2 THEN 0 ELSE 11 - r END
                 AND nif NOT LIKE '0%' THEN 'VALID' ELSE 'INVALID' END AS nif_status
FROM calc
ORDER BY nif_status, number;
GO

/* 1.5 Near-duplicate customers: same zip code (or same phone digits)
       but different customer id. Names are compared accent/case-insensitive
       and with a SOUNDEX/DIFFERENCE score as a cheap similarity indicator.  */
WITH c AS (
    SELECT number, name, taxpayer_number, zip_code, address,
           REPLACE(REPLACE(REPLACE(phone,' ',''),'+',''),'-','') AS phone_digits,
           UPPER(name COLLATE Latin1_General_CI_AI)               AS name_norm
    FROM dbo.customers
    WHERE LTRIM(RTRIM(zip_code)) <> ''
)
SELECT a.number AS cust_a, a.name AS name_a, a.taxpayer_number AS nif_a,
       b.number AS cust_b, b.name AS name_b, b.taxpayer_number AS nif_b,
       a.zip_code,
       CASE WHEN a.phone_digits = b.phone_digits AND a.phone_digits <> '' THEN 'Y' ELSE 'N' END AS same_phone,
       CASE WHEN a.taxpayer_number = b.taxpayer_number THEN 'Y' ELSE 'N' END AS same_nif,
       DIFFERENCE(a.name_norm, b.name_norm) AS name_difference_0_4
FROM c a
JOIN c b ON a.number < b.number
        AND (a.zip_code = b.zip_code OR (a.phone_digits = b.phone_digits AND a.phone_digits <> ''))
ORDER BY a.zip_code;
GO

/* 1.6 Tax numbers that differ by one transposition / one digit
       (typing errors, e.g. 300455644 vs 300456544) */
WITH n AS (
    SELECT number, name, taxpayer_number AS nif FROM dbo.customers
    WHERE LEN(taxpayer_number) = 9 AND taxpayer_number NOT LIKE '%[^0-9]%' AND taxpayer_number LIKE '%[^0]%'
), pos AS (SELECT TOP (9) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS p FROM sys.objects)
SELECT a.number AS cust_a, a.name AS name_a, a.nif AS nif_a,
       b.number AS cust_b, b.name AS name_b, b.nif AS nif_b,
       SUM(CASE WHEN SUBSTRING(a.nif,p,1) <> SUBSTRING(b.nif,p,1) THEN 1 ELSE 0 END) AS differing_digits
FROM n a JOIN n b ON a.number < b.number CROSS JOIN pos
GROUP BY a.number, a.name, a.nif, b.number, b.name, b.nif
HAVING SUM(CASE WHEN SUBSTRING(a.nif,p,1) <> SUBSTRING(b.nif,p,1) THEN 1 ELSE 0 END) BETWEEN 1 AND 2
ORDER BY differing_digits, cust_a;
GO

/* 1.7 Other customer attribute quality */
SELECT
    SUM(CASE WHEN LTRIM(RTRIM(c.email)) <> '' AND c.email NOT LIKE '%_@_%._%' THEN 1 ELSE 0 END) AS invalid_email,
    SUM(CASE WHEN LTRIM(RTRIM(c.email)) = '' THEN 1 ELSE 0 END)                               AS missing_email,
    SUM(CASE WHEN LTRIM(RTRIM(clity)) = '' THEN 1 ELSE 0 END)                               AS missing_city,
    SUM(CASE WHEN zone IS NULL THEN 1 ELSE 0 END)                                           AS missing_zone,
    SUM(CASE WHEN LTRIM(RTRIM(zip_code)) <> '' AND zip_code NOT LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]%' THEN 1 ELSE 0 END) AS non_pt_zip,
    SUM(CASE WHEN e.number IS NULL THEN 1 ELSE 0 END)                                       AS seller_not_employee
FROM dbo.customers c
LEFT JOIN dbo.employees e ON e.number = c.seller;

SELECT number, name, email, clity, zip_code, zone, seller
FROM dbo.customers
WHERE (LTRIM(RTRIM(email)) <> '' AND email NOT LIKE '%_@_%._%')
   OR LTRIM(RTRIM(clity)) = '' OR zone IS NULL
   OR (LTRIM(RTRIM(zip_code)) <> '' AND zip_code NOT LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]%');

SELECT type, segment, COUNT(*) AS n FROM dbo.customers GROUP BY type, segment ORDER BY type, segment;
GO

/* =====================================================================
   2. INVOICES - TIMESTAMP PROFILING
   ===================================================================== */

/* 2.1 Ranges of all date/time columns */
SELECT MIN(invoice_date) AS min_invoice_date, MAX(invoice_date) AS max_invoice_date,
       MIN(CAST(create_date AS datetime) + CAST(create_time AS datetime))           AS min_created_at,
       MAX(CAST(create_date AS datetime) + CAST(create_time AS datetime))           AS max_created_at,
       MIN(CAST(last_update_date AS datetime) + CAST(last_update_time AS datetime)) AS min_updated_at,
       MAX(CAST(last_update_date AS datetime) + CAST(last_update_time AS datetime)) AS max_updated_at,
       MIN(payment_date) AS min_payment_date, MAX(payment_date) AS max_payment_date
FROM dbo.invoices;
GO

/* 2.2 Distribution of invoices per day / weekday (invoice_date) */
SELECT invoice_date, DATENAME(weekday, invoice_date) AS weekday,
       CASE WHEN invoice_date = EOMONTH(invoice_date) THEN 'Y' ELSE 'N' END AS is_month_end,
       COUNT(*) AS n_invoices
FROM dbo.invoices
GROUP BY invoice_date
ORDER BY invoice_date;
GO

/* 2.3 Timestamp consistency rules
       R1 created_at must be <= updated_at
       R2 create_date should not be before invoice_date (record created before the sale)
       R3 payment_date must be >= invoice_date
       R4 invoice dates in the future / before company start                       */
WITH t AS (
    SELECT invoice_stamp_id, invoice_date, payment_date,
           CAST(create_date AS datetime) + CAST(create_time AS datetime)           AS created_at,
           CAST(last_update_date AS datetime) + CAST(last_update_time AS datetime) AS updated_at,
           create_date
    FROM dbo.invoices
)
SELECT invoice_stamp_id, invoice_date, create_date, created_at, updated_at, payment_date,
       CASE WHEN created_at > updated_at       THEN 'R1 created_after_updated; ' ELSE '' END +
       CASE WHEN create_date < invoice_date    THEN 'R2 created_before_invoice_date; ' ELSE '' END +
       CASE WHEN create_date > invoice_date    THEN 'R2b created_after_invoice_date; ' ELSE '' END +
       CASE WHEN payment_date < invoice_date   THEN 'R3 paid_before_invoice; ' ELSE '' END +
       CASE WHEN invoice_date > CAST(GETDATE() AS date) THEN 'R4 future_invoice; ' ELSE '' END AS issues
FROM t
WHERE created_at > updated_at OR create_date <> invoice_date
   OR payment_date < invoice_date OR invoice_date > CAST(GETDATE() AS date);
GO

/* 2.4 Is the last_update timestamp actually used? (incremental-load relevance) */
SELECT
    SUM(CASE WHEN create_date = last_update_date AND create_time = last_update_time THEN 1 ELSE 0 END) AS never_updated,
    SUM(CASE WHEN NOT (create_date = last_update_date AND create_time = last_update_time) THEN 1 ELSE 0 END) AS updated_after_insert,
    SUM(CASE WHEN last_update_date = payment_date THEN 1 ELSE 0 END) AS updated_on_payment_date
FROM dbo.invoices;
GO

/* 2.5 Invoice lines timestamps vs header */
SELECT l.invoice_line_stamp_id, l.invoice_stamp_id, i.invoice_date,
       l.create_date AS line_create_date, i.create_date AS header_create_date
FROM dbo.invoices_lines l
JOIN dbo.invoices i ON i.invoice_stamp_id = l.invoice_stamp_id
WHERE l.create_date < i.create_date
   OR CAST(l.create_date AS datetime) + CAST(l.create_time AS datetime)
    > CAST(l.last_update_date AS datetime) + CAST(l.last_update_time AS datetime);
GO

/* 2.6 Invoice key format (stamp ids are char(25) with trailing spaces) */
SELECT LEFT(invoice_stamp_id, 3) AS prefix, COUNT(*) AS n,
       MIN(LEN(invoice_stamp_id)) AS min_len, MAX(LEN(invoice_stamp_id)) AS max_len,
       SUM(CASE WHEN invoice_stamp_id <> LTRIM(invoice_stamp_id) THEN 1 ELSE 0 END) AS leading_spaces
FROM dbo.invoices GROUP BY LEFT(invoice_stamp_id, 3);
GO

/* =====================================================================
   3. INVOICE AMOUNTS / CURRENCY / SHIPPING
   ===================================================================== */

/* 3.1 Currency domain (EUR standardisation) */
SELECT currency, COUNT(*) AS n FROM dbo.invoices GROUP BY currency;
GO

/* 3.2 Header arithmetic: total_for_vat = products_total + shipping;
       final_total = total_for_vat + vat_value; header vs sum of lines */
WITH l AS (
    SELECT invoice_stamp_id, SUM(line_total) AS sum_lines, SUM(line_vat) AS sum_vat, COUNT(*) AS n_lines
    FROM dbo.invoices_lines GROUP BY invoice_stamp_id
)
SELECT i.invoice_stamp_id, i.products_total, l.sum_lines, i.shipping_cost, i.total_for_vat,
       i.vat_value, l.sum_vat, i.final_total, l.n_lines,
       CASE WHEN l.invoice_stamp_id IS NULL                              THEN 'NO_LINES; ' ELSE '' END +
       CASE WHEN i.products_total <> l.sum_lines                         THEN 'PRODUCTS_TOTAL<>SUM(LINES); ' ELSE '' END +
       CASE WHEN i.total_for_vat <> i.products_total + i.shipping_cost   THEN 'TOTAL_FOR_VAT_MISMATCH; ' ELSE '' END +
       CASE WHEN i.vat_value <> l.sum_vat                                THEN 'VAT<>SUM(LINE_VAT); ' ELSE '' END +
       CASE WHEN i.final_total <> i.total_for_vat + i.vat_value          THEN 'FINAL_TOTAL_MISMATCH; ' ELSE '' END AS issues
FROM dbo.invoices i
LEFT JOIN l ON l.invoice_stamp_id = i.invoice_stamp_id
WHERE l.invoice_stamp_id IS NULL
   OR i.products_total <> l.sum_lines
   OR i.total_for_vat <> i.products_total + i.shipping_cost
   OR i.vat_value <> l.sum_vat
   OR i.final_total <> i.total_for_vat + i.vat_value;
GO

/* 3.3 Shipping cost as % of products_total (policy appears to be 2.5%) */
SELECT CAST(shipping_cost / NULLIF(products_total,0) AS decimal(9,6)) AS shipping_ratio, COUNT(*) AS n
FROM dbo.invoices
GROUP BY CAST(shipping_cost / NULLIF(products_total,0) AS decimal(9,6))
ORDER BY n DESC;
GO

/* =====================================================================
   4. INVOICE LINES
   ===================================================================== */

/* 4.1 Sign errors and arithmetic: line_total = quantity * unit_price */
SELECT invoice_line_stamp_id, invoice_stamp_id, product, quantity, unit_price, line_total, line_vat,
       quantity * unit_price AS qty_x_price,
       CASE WHEN quantity   <= 0 THEN 'NON_POSITIVE_QTY; '   ELSE '' END +
       CASE WHEN unit_price <= 0 THEN 'NON_POSITIVE_PRICE; ' ELSE '' END +
       CASE WHEN ABS(quantity * unit_price) <> line_total THEN 'LINE_TOTAL_MISMATCH; ' ELSE '' END +
       CASE WHEN line_vat IS NULL THEN 'NULL_VAT; ' ELSE '' END AS issues
FROM dbo.invoices_lines
WHERE quantity <= 0 OR unit_price <= 0 OR ABS(quantity * unit_price) <> line_total OR line_vat IS NULL;
GO

/* 4.2 Implied VAT rate per line vs product vat_rate */
SELECT CAST(l.line_vat / NULLIF(l.line_total,0) * 100 AS decimal(6,2)) AS implied_vat_pct,
       p.vat_rate, COUNT(*) AS n
FROM dbo.invoices_lines l LEFT JOIN dbo.products p ON p.reference = l.product
GROUP BY CAST(l.line_vat / NULLIF(l.line_total,0) * 100 AS decimal(6,2)), p.vat_rate;
GO

/* 4.3 Unit price on the line vs product current_sell_price (scale check) */
SELECT TOP (20) l.product, l.unit_price, p.current_sell_price,
       p.current_sell_price / NULLIF(ABS(l.unit_price),0) AS ratio
FROM dbo.invoices_lines l JOIN dbo.products p ON p.reference = l.product
ORDER BY ratio;
GO

/* =====================================================================
   5. PRODUCTS / REFERENTIAL INTEGRITY
   ===================================================================== */

/* 5.1 Products with missing mandatory descriptive attributes */
SELECT reference, designation, family, category, supplyer, vat_rate, current_sell_price
FROM dbo.products
WHERE designation IS NULL OR family IS NULL OR category IS NULL OR supplyer IS NULL
   OR vat_rate IS NULL OR current_sell_price IS NULL;
GO

/* 5.2 Price magnitude (current_sell_price appears stored x 1,000,000) */
SELECT MIN(current_sell_price) AS min_price, MAX(current_sell_price) AS max_price,
       AVG(current_sell_price) AS avg_price FROM dbo.products;
GO

/* 5.3 Are the "ghost" products (no attributes) ever sold? */
SELECT p.reference, COUNT(l.invoice_line_stamp_id) AS times_sold
FROM dbo.products p LEFT JOIN dbo.invoices_lines l ON l.product = p.reference
WHERE p.designation IS NULL GROUP BY p.reference;
GO

/* 5.4 Suppliers: duplicated tax numbers / placeholders (DimSupplier) */
SELECT taxpayer_number, COUNT(*) AS n, STRING_AGG(CAST(number AS varchar(10)) + ':' + name, ' | ') AS suppliers
FROM dbo.suplliers GROUP BY taxpayer_number HAVING COUNT(*) > 1;
SELECT number, name, taxpayer_number, zone, type FROM dbo.suplliers WHERE zone IS NULL OR LTRIM(RTRIM(city)) = '';
GO

/* 5.5 Customers / employees referenced by invoices */
SELECT i.customer, c.name, c.type, COUNT(*) AS n_invoices
FROM dbo.invoices i JOIN dbo.customers c ON c.number = i.customer
GROUP BY i.customer, c.name, c.type ORDER BY i.customer;
SELECT i.employee, e.name, e.[group], COUNT(*) AS n_invoices
FROM dbo.invoices i JOIN dbo.employees e ON e.number = i.employee
GROUP BY i.employee, e.name, e.[group];
GO
