-- Практическая работа № 1. Контрольные проверки загрузки Olist
-- Камалов Т. А. ИНБО-20-23

-- число строк в каждой таблице
SELECT table_name,
       actual_rows,
       expected_rows,
       actual_rows - expected_rows AS diff
FROM (
    SELECT 'customers' AS table_name, count(*) AS actual_rows, 99441 AS expected_rows
        FROM olist.customers
    UNION ALL SELECT 'orders', count(*), 99441 FROM olist.orders
    UNION ALL SELECT 'order_items', count(*), 112650 FROM olist.order_items
    UNION ALL SELECT 'order_payments', count(*), 103886 FROM olist.order_payments
    UNION ALL SELECT 'order_reviews', count(*), 99224 FROM olist.order_reviews
    UNION ALL SELECT 'products', count(*), 32951 FROM olist.products
    UNION ALL SELECT 'sellers', count(*), 3095 FROM olist.sellers
    UNION ALL SELECT 'geolocation', count(*), 1000163 FROM olist.geolocation
    UNION ALL SELECT 'product_category_name_translation', count(*), 71
        FROM olist.product_category_name_translation
) AS counts
ORDER BY table_name;

-- пустые значения в ключевых полях
SELECT 'customers.customer_id' AS column_name, count(*) AS null_count
    FROM olist.customers WHERE customer_id IS NULL
UNION ALL SELECT 'orders.order_id', count(*)
    FROM olist.orders WHERE order_id IS NULL
UNION ALL SELECT 'orders.customer_id', count(*)
    FROM olist.orders WHERE customer_id IS NULL
UNION ALL SELECT 'order_items.order_id', count(*)
    FROM olist.order_items WHERE order_id IS NULL
UNION ALL SELECT 'order_items.product_id', count(*)
    FROM olist.order_items WHERE product_id IS NULL
UNION ALL SELECT 'order_items.seller_id', count(*)
    FROM olist.order_items WHERE seller_id IS NULL
UNION ALL SELECT 'order_payments.order_id', count(*)
    FROM olist.order_payments WHERE order_id IS NULL
UNION ALL SELECT 'order_reviews.review_id', count(*)
    FROM olist.order_reviews WHERE review_id IS NULL
UNION ALL SELECT 'order_reviews.order_id', count(*)
    FROM olist.order_reviews WHERE order_id IS NULL
UNION ALL SELECT 'products.product_id', count(*)
    FROM olist.products WHERE product_id IS NULL
UNION ALL SELECT 'sellers.seller_id', count(*)
    FROM olist.sellers WHERE seller_id IS NULL
ORDER BY column_name;

-- строки, которые ссылаются на несуществующую запись
SELECT 'order_items -> orders' AS relation, count(*) AS orphan_rows
FROM olist.order_items oi
LEFT JOIN olist.orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_items -> products', count(*)
FROM olist.order_items oi
LEFT JOIN olist.products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'order_items -> sellers', count(*)
FROM olist.order_items oi
LEFT JOIN olist.sellers s ON s.seller_id = oi.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'order_payments -> orders', count(*)
FROM olist.order_payments op
LEFT JOIN olist.orders o ON o.order_id = op.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_reviews -> orders', count(*)
FROM olist.order_reviews r
LEFT JOIN olist.orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'orders -> customers', count(*)
FROM olist.orders o
LEFT JOIN olist.customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
ORDER BY relation;

-- какие ключи созданы
SELECT tc.constraint_type,
       tc.table_name,
       tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'olist'
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY tc.constraint_type, tc.table_name;
