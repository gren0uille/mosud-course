-- Практическая работа № 1. Контрольные проверки загрузки Olist
-- Камалов Т. А., группа ______
--
-- Файл выполняется одним запуском после schema.sql и ничего не изменяет.
-- Проверяются три свойства: число строк, отсутствие NULL в ключевых полях
-- и отсутствие «осиротевших» ссылок.

\echo '=== 1. Число строк в таблицах схемы olist ==='

-- Ожидаемые значения взяты из задания. Столбец diff показывает отклонение:
-- ноль означает, что таблица загружена полностью.
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

\echo ''
\echo '=== 2. NULL в ключевых полях (должны быть нули) ==='

-- Поля, объявленные NOT NULL, проверяются повторно: это контроль того, что
-- CSV не содержал пустых значений там, где они недопустимы.
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

\echo ''
\echo '=== 3. Осиротевшие ссылки (должны быть нули) ==='

-- Строки дочерней таблицы, для которых нет родительской записи. После
-- успешного создания внешних ключей такие строки существовать не могут,
-- однако проверка оставлена: она позволяет найти причину, если добавление
-- ключа завершилось ошибкой.
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

\echo ''
\echo '=== 4. Созданные ограничения ==='

-- Контроль того, что первичные и внешние ключи действительно созданы.
SELECT tc.constraint_type,
       tc.table_name,
       tc.constraint_name
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'olist'
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY tc.constraint_type, tc.table_name;
