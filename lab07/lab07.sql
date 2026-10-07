-- Практическая работа № 7. NULL, трёхзначная логика и качество данных
-- Камалов Т. А. ИНБО-20-23
-- Работа общая, без вариантов.


-- 1. Число NULL по необязательным столбцам.
-- count(col) считает только не-NULL, поэтому NULL = count(*) - count(col).

SELECT 'orders' AS tbl, count(*) AS total_rows,
       count(*) - count(order_status)                  AS order_status,
       count(*) - count(order_purchase_timestamp)      AS purchase_ts,
       count(*) - count(order_approved_at)             AS approved_at,
       count(*) - count(order_delivered_carrier_date)  AS delivered_carrier,
       count(*) - count(order_delivered_customer_date) AS delivered_customer,
       count(*) - count(order_estimated_delivery_date) AS estimated_delivery
FROM olist.orders;

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

SELECT 'order_reviews' AS tbl, count(*) AS total_rows,
       count(*) - count(review_score)            AS score,
       count(*) - count(review_comment_title)    AS comment_title,
       count(*) - count(review_comment_message)  AS comment_message,
       count(*) - count(review_creation_date)    AS creation_date,
       count(*) - count(review_answer_timestamp) AS answer_ts
FROM olist.order_reviews;


-- 2. COUNT(*) и COUNT(столбец)
-- count(*) считает строки, count(col) — строки, где col не NULL.
-- Разница — заказы, которые ещё не доставлены (или отменены).
SELECT count(*)                             AS all_orders,
       count(order_delivered_customer_date) AS with_delivery_date,
       count(*) - count(order_delivered_customer_date) AS without_date
FROM olist.orders;

-- откуда берутся пропуски: разбивка по статусу
SELECT order_status, count(*) AS orders,
       count(*) - count(order_delivered_customer_date) AS no_delivery_date
FROM olist.orders
GROUP BY order_status
ORDER BY no_delivery_date DESC;


-- 3. = NULL и <> NULL не работают.
-- Сравнение с NULL даёт UNKNOWN, а WHERE пропускает только TRUE.
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

-- значения логических выражений с NULL
SELECT NULL = NULL          AS null_eq_null,
       NULL <> NULL         AS null_ne_null,
       1 = NULL             AS one_eq_null,
       NULL IS NULL         AS null_is_null,
       (NULL = 1) IS UNKNOWN AS is_unknown,
       TRUE OR NULL         AS true_or_null,
       FALSE AND NULL       AS false_and_null,
       TRUE AND NULL        AS true_and_null,
       NOT (NULL::boolean)  AS not_null;
-- psql показывает UNKNOWN как пустое значение.


-- 4. IS DISTINCT FROM — сравнение, в котором NULL ведёт себя как обычное значение.
SELECT a, b,
       a = b                     AS eq,
       a <> b                    AS ne,
       a IS DISTINCT FROM b      AS distinct_from,
       a IS NOT DISTINCT FROM b  AS not_distinct_from
FROM (VALUES (1, 1), (1, 2), (1, NULL), (NULL::int, NULL::int)) v(a, b);

-- на данных: заказы, где дата доставки клиенту отличается от плановой даты.
-- <> пропускает заказы без доставки, IS DISTINCT FROM их учитывает.
SELECT count(*) FILTER (WHERE order_delivered_customer_date::date <> order_estimated_delivery_date::date)
           AS ne_count,
       count(*) FILTER (WHERE order_delivered_customer_date::date IS DISTINCT FROM order_estimated_delivery_date::date)
           AS distinct_count
FROM olist.orders;


-- 5. NOT IN и NOT EXISTS при NULL
DROP TABLE IF EXISTS temp_ids;
CREATE TEMP TABLE temp_ids (id text);
INSERT INTO temp_ids
SELECT order_id FROM olist.orders ORDER BY order_id LIMIT 1;
INSERT INTO temp_ids VALUES (NULL);

SELECT * FROM temp_ids;

-- заказы, которых нет в temp_ids
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
-- NOT IN вернул 0: x NOT IN (a, NULL) = x <> a AND x <> NULL
-- = TRUE AND UNKNOWN = UNKNOWN для всех строк.
-- NOT EXISTS вернул 99440: строка с NULL просто ни с чем не совпадает.


-- 6. LEFT JOIN: фильтр в ON и в WHERE
-- В ON: условие участвует в поиске пары. Заказ без подходящего
-- отзыва остаётся, справа NULL. Это все заказы.
SELECT 'фильтр в ON' AS variant,
       count(DISTINCT o.order_id)                                       AS orders,
       count(DISTINCT o.order_id) FILTER (WHERE r.review_id IS NOT NULL) AS with_good_review
FROM olist.orders o
LEFT JOIN olist.order_reviews r
       ON r.order_id = o.order_id AND r.review_score >= 4
UNION ALL
-- В WHERE: фильтр применяется после соединения. У строк без пары
-- review_score = NULL, NULL >= 4 — UNKNOWN, строки отбрасываются.
-- LEFT JOIN фактически стал INNER JOIN.
SELECT 'фильтр в WHERE',
       count(DISTINCT o.order_id),
       count(DISTINCT o.order_id) FILTER (WHERE r.review_id IS NOT NULL)
FROM olist.orders o
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE r.review_score >= 4;


-- 7. COALESCE и NULLIF
-- COALESCE — первое не-NULL значение из списка: подставляю текст по умолчанию.
SELECT review_id, review_score,
       coalesce(review_comment_message, '(без комментария)') AS comment
FROM olist.order_reviews
ORDER BY review_creation_date, review_id
LIMIT 5;

-- NULLIF(a, b) = NULL, если a = b, иначе a. Защита от деления на ноль:
-- x / NULLIF(y, 0) вернёт NULL вместо ошибки.
-- Доля фрахта в цене позиции; у бесплатных позиций (price = 0) была бы ошибка.
SELECT count(*) AS items,
       round(avg(freight_value / NULLIF(price, 0)), 3) AS avg_freight_share
FROM olist.order_items;

-- демонстрация: без NULLIF — ошибка, с NULLIF — NULL
SELECT 10 / NULLIF(0, 0) AS safe_division;
-- SELECT 10 / 0;  -- ERROR: division by zero


-- 8. Мини-профиль качества данных
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


-- 9. Естественный NULL и NULL как проблема качества
-- Естественный: review_comment_message — комментарий необязателен,
--   большинство покупателей просто ставят оценку.
--   Также order_delivered_customer_date у заказов в пути или отменённых.
-- Проблема качества: order_delivered_customer_date у заказов
--   со статусом delivered — заказ доставлен, а даты нет.
--   И product_category_name: у товара на маркетплейсе категория должна быть.
SELECT 'delivered без даты доставки' AS issue, count(*) AS rows
FROM olist.orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
UNION ALL
SELECT 'товар без категории, но с остальными полями', count(*)
FROM olist.products
WHERE product_category_name IS NULL AND product_weight_g IS NOT NULL;

-- ещё одна аномалия: заказ отменён, но дата доставки клиенту есть
SELECT count(*) AS canceled_with_delivery_date
FROM olist.orders
WHERE order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL;
