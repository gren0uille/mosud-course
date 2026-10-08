-- Практическая работа № 7. NULL, трёхзначная логика и качество данных
-- Камалов Т. А. ИНБО-20-23


-- 1. NULL по столбцам: count(*) - count(col)

SELECT 'orders' AS tbl, count(*) AS total_rows,
       count(*) - count(order_status)                  AS order_status,
       count(*) - count(order_purchase_timestamp)      AS purchase_ts,
       count(*) - count(order_approved_at)             AS approved_at,
       count(*) - count(order_delivered_carrier_date)  AS delivered_carrier,
       count(*) - count(order_delivered_customer_date) AS delivered_customer,
       count(*) - count(order_estimated_delivery_date) AS estimated_delivery
FROM olist.orders;
-- результат: 99441 строк; NULL: approved_at 160, delivered_carrier 1783, delivered_customer 2965, остальные 0

SELECT 'products' AS tbl, count(*) AS total_rows,
       count(*) - count(product_category_name)      AS category,
       count(*) - count(product_name_lenght)        AS name_len,
       count(*) - count(product_description_lenght) AS descr_len,
       count(*) - count(product_photos_qty)         AS photos_qty,
       count(*) - count(product_weight_g)           AS weight_g,
       count(*) - count(product_length_cm)          AS length_cm,
       count(*) - count(product_height_cm)          AS height_cm,
       count(*) - count(product_width_cm)           AS width_cm
FROM olist.products;
-- результат: 32951 строк; NULL: category/name/descr/photos по 610, вес и размеры по 2

SELECT 'order_reviews' AS tbl, count(*) AS total_rows,
       count(*) - count(review_score)            AS score,
       count(*) - count(review_comment_title)    AS comment_title,
       count(*) - count(review_comment_message)  AS comment_message,
       count(*) - count(review_creation_date)    AS creation_date,
       count(*) - count(review_answer_timestamp) AS answer_ts
FROM olist.order_reviews;
-- результат: 99224 строк; NULL: comment_title 87656, comment_message 58247, остальные 0


-- 2. COUNT(*) vs COUNT(col)
SELECT count(*)                             AS all_orders,
       count(order_delivered_customer_date) AS with_delivery_date,
       count(*) - count(order_delivered_customer_date) AS without_date
FROM olist.orders;
-- результат: all_orders = 99441, with_delivery_date = 96476, without_date = 2965

-- по статусам
SELECT order_status, count(*) AS orders,
       count(*) - count(order_delivered_customer_date) AS no_delivery_date
FROM olist.orders
GROUP BY order_status
ORDER BY no_delivery_date DESC;
-- результат: 8 строк


-- 3. = NULL / <> NULL vs IS NULL
SELECT 'col = NULL'      AS predicate, count(*) AS rows
FROM olist.orders WHERE order_delivered_customer_date = NULL
UNION ALL
SELECT 'col <> NULL', count(*)
FROM olist.orders WHERE order_delivered_customer_date <> NULL
UNION ALL
SELECT 'col IS NULL', count(*)
FROM olist.orders WHERE order_delivered_customer_date IS NULL
UNION ALL
SELECT 'col IS NOT NULL', count(*)
FROM olist.orders WHERE order_delivered_customer_date IS NOT NULL;
-- результат: col = NULL 0; col <> NULL 0; col IS NULL 2965; col IS NOT NULL 96476

SELECT NULL = NULL          AS null_eq_null,
       NULL <> NULL         AS null_ne_null,
       1 = NULL             AS one_eq_null,
       NULL IS NULL         AS null_is_null,
       (NULL = 1) IS UNKNOWN AS is_unknown,
       TRUE OR NULL         AS true_or_null,
       FALSE AND NULL       AS false_and_null,
       TRUE AND NULL        AS true_and_null,
       NOT (NULL::boolean)  AS not_null;
-- результат: NULL = NULL → NULL, 1 = NULL → NULL, NULL IS NULL → t, TRUE OR NULL → t, FALSE AND NULL → f, TRUE AND NULL → NULL


-- 4. IS DISTINCT FROM
SELECT a, b,
       a = b                     AS eq,
       a <> b                    AS ne,
       a IS DISTINCT FROM b      AS distinct_from,
       a IS NOT DISTINCT FROM b  AS not_distinct_from
FROM (VALUES (1, 1), (1, 2), (1, NULL), (NULL::int, NULL::int)) v(a, b);
-- результат: 4 строки

-- факт vs план доставки
SELECT count(*) FILTER (WHERE order_delivered_customer_date::date <> order_estimated_delivery_date::date)
           AS ne_count,
       count(*) FILTER (WHERE order_delivered_customer_date::date IS DISTINCT FROM order_estimated_delivery_date::date)
           AS distinct_count
FROM olist.orders;
-- результат: ne_count = 95184, distinct_count = 98149


-- 5. NOT IN vs NOT EXISTS
DROP TABLE IF EXISTS temp_ids;
CREATE TEMP TABLE temp_ids (id text);
INSERT INTO temp_ids
SELECT order_id FROM olist.orders ORDER BY order_id LIMIT 1;
INSERT INTO temp_ids VALUES (NULL);

SELECT * FROM temp_ids;
-- результат: 2 строки: 00010242fe8c5a6d1ba2dd792cb16214 и NULL

SELECT 'NOT IN' AS method, count(*) AS orders
FROM olist.orders o
WHERE o.order_id NOT IN (SELECT id FROM temp_ids)
UNION ALL
SELECT 'NOT EXISTS', count(*)
FROM olist.orders o
WHERE NOT EXISTS (SELECT 1 FROM temp_ids t WHERE t.id = o.order_id)
UNION ALL
SELECT 'NOT IN без NULL', count(*)
FROM olist.orders o
WHERE o.order_id NOT IN (SELECT id FROM temp_ids WHERE id IS NOT NULL);
-- результат: NOT IN 0; NOT EXISTS 99440; NOT IN без NULL 99440
-- NOT IN = 0: x <> NULL даёт UNKNOWN для всех строк


-- 6. Фильтр в ON vs в WHERE
SELECT 'фильтр в ON' AS variant,
       count(DISTINCT o.order_id)                                       AS orders,
       count(DISTINCT o.order_id) FILTER (WHERE r.review_id IS NOT NULL) AS with_good_review
FROM olist.orders o
LEFT JOIN olist.order_reviews r
       ON r.order_id = o.order_id AND r.review_score >= 4
UNION ALL
-- в WHERE LEFT JOIN превращается в INNER
SELECT 'фильтр в WHERE',
       count(DISTINCT o.order_id),
       count(DISTINCT o.order_id) FILTER (WHERE r.review_id IS NOT NULL)
FROM olist.orders o
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE r.review_score >= 4;
-- результат: фильтр в WHERE 76120 76120; фильтр в ON 99441 76120


-- 7. COALESCE и NULLIF
SELECT review_id, review_score,
       coalesce(review_comment_message, '(без комментария)') AS comment
FROM olist.order_reviews
ORDER BY review_creation_date, review_id
LIMIT 5;
-- результат: 5 строк

-- доля фрахта в цене, NULLIF от деления на 0
SELECT count(*) AS items,
       round(avg(freight_value / NULLIF(price, 0)), 3) AS avg_freight_share
FROM olist.order_items;
-- результат: items = 112650, avg_freight_share = 0.321

SELECT 10 / NULLIF(0, 0) AS safe_division;
-- результат: NULL
-- SELECT 10 / 0;  -- ERROR: division by zero


-- 8. Профиль качества
SELECT 'заказы без фактической даты доставки' AS metric,
       count(*) - count(order_delivered_customer_date) AS null_rows,
       count(*) AS total,
       round(100.0 * (count(*) - count(order_delivered_customer_date)) / count(*), 2) AS pct
FROM olist.orders
UNION ALL
SELECT 'доставленные заказы без даты доставки',
       count(*) - count(order_delivered_customer_date), count(*),
       round(100.0 * (count(*) - count(order_delivered_customer_date)) / count(*), 2)
FROM olist.orders WHERE order_status = 'delivered'
UNION ALL
SELECT 'товары без категории',
       count(*) - count(product_category_name), count(*),
       round(100.0 * (count(*) - count(product_category_name)) / count(*), 2)
FROM olist.products
UNION ALL
SELECT 'отзывы без текста',
       count(*) - count(review_comment_message), count(*),
       round(100.0 * (count(*) - count(review_comment_message)) / count(*), 2)
FROM olist.order_reviews;
-- результат: без даты доставки 2.98%, delivered без даты 0.01%, товары без категории 1.85%, отзывы без текста 58.70%


-- 9. Естественный NULL: review_comment_message (комментарий необязателен),
--    order_delivered_customer_date у недоставленных заказов.
-- Проблема: delivered без даты доставки, товары без категории.
SELECT 'delivered без даты доставки' AS issue, count(*) AS rows
FROM olist.orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
UNION ALL
SELECT 'товар без категории, но с остальными полями', count(*)
FROM olist.products
WHERE product_category_name IS NULL AND product_weight_g IS NOT NULL;
-- результат: delivered без даты доставки 8; товар без категории, но с остальными полями 609

-- canceled с датой доставки
SELECT count(*) AS canceled_with_delivery_date
FROM olist.orders
WHERE order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL;
-- результат: 6
