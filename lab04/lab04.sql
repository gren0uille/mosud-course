-- Практическая работа № 4. Соединения отношений и сложные JOIN
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: клиенты без отзывов

-- 2. Кратности
-- customers → orders: 1:1 по customer_id, 1:N по customer_unique_id
-- orders → order_reviews: 1:N
-- orders → order_items: 1:N
-- customers ↔ products: M:N через orders и order_items
SELECT 'заказов на customer_id, max' AS what,
       (SELECT max(c) FROM (SELECT count(*) c FROM olist.orders GROUP BY customer_id) t) AS value
UNION ALL
SELECT 'заказов на customer_unique_id, max',
       (SELECT max(c) FROM (SELECT count(*) c FROM olist.orders o
                            JOIN olist.customers cu ON cu.customer_id = o.customer_id
                            GROUP BY cu.customer_unique_id) t)
UNION ALL
SELECT 'заказов с 2+ отзывами',
       (SELECT count(*) FROM (SELECT order_id FROM olist.order_reviews
                              GROUP BY order_id HAVING count(*) > 1) t)
UNION ALL
SELECT 'отзывов на заказ, max',
       (SELECT max(c) FROM (SELECT count(*) c FROM olist.order_reviews GROUP BY order_id) t);
-- результат: заказов на customer_id, max 1; заказов на customer_unique_id, max 17; заказов с 2+ отзывами 547; отзывов на заказ, max 3


-- 1, 3. Заказы с отзывом и без по штатам
-- DISTINCT, т. к. у заказа бывает несколько отзывов
SELECT c.customer_state,
       count(DISTINCT o.order_id)                                         AS orders,
       count(DISTINCT o.order_id) FILTER (WHERE r.order_id IS NOT NULL)   AS with_review,
       count(DISTINCT o.order_id) FILTER (WHERE r.order_id IS NULL)       AS without_review,
       round(avg(r.review_score), 2)                                      AS avg_score
FROM olist.customers c
JOIN olist.orders o ON o.customer_id = c.customer_id
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY without_review DESC, c.customer_state;
-- результат: 27 строк

-- 7. γ_{state; count, avg}(σ_{delivered}(customers ⋈ orders) ⟕ order_reviews)


-- 4. Антисоединение: покупатели без единого отзыва
SELECT count(DISTINCT c.customer_unique_id) AS customers_without_reviews
FROM olist.customers c
WHERE EXISTS (SELECT 1 FROM olist.orders o
              WHERE o.customer_id = c.customer_id AND o.order_status = 'delivered')
  AND NOT EXISTS (SELECT 1
                  FROM olist.customers c2
                  JOIN olist.orders o2 ON o2.customer_id = c2.customer_id
                  JOIN olist.order_reviews r ON r.order_id = o2.order_id
                  WHERE c2.customer_unique_id = c.customer_unique_id);
-- результат: 603

-- заказы без отзыва через LEFT JOIN
SELECT c.customer_state, count(*) AS delivered_orders_without_review
FROM olist.customers c
JOIN olist.orders o ON o.customer_id = c.customer_id
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND r.order_id IS NULL
GROUP BY c.customer_state
ORDER BY 2 DESC
LIMIT 10;
-- результат: 10 строк

SELECT c.customer_unique_id, c.customer_city, c.customer_state,
       o.order_id, o.order_delivered_customer_date::date AS delivered
FROM olist.customers c
JOIN olist.orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM olist.order_reviews r WHERE r.order_id = o.order_id)
ORDER BY delivered DESC NULLS LAST, o.order_id
LIMIT 5;
-- результат: 5 строк


-- 5. Ошибка: items и reviews через один order_id, строки перемножаются
SELECT 'ошибочный' AS variant,
       round(sum(oi.price), 2) AS revenue,
       count(r.review_id)      AS reviews
FROM olist.orders o
JOIN olist.order_items oi ON oi.order_id = o.order_id
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
UNION ALL
-- контроль: каждая таблица отдельно
SELECT 'эталон',
       (SELECT round(sum(oi.price), 2)
        FROM olist.order_items oi JOIN olist.orders o ON o.order_id = oi.order_id
        WHERE o.order_status = 'delivered'),
       (SELECT count(*)
        FROM olist.order_reviews r JOIN olist.orders o ON o.order_id = r.order_id
        WHERE o.order_status = 'delivered');
-- результат: ошибочный 13279836.59 110013; эталон 13221498.11 96361

SELECT i.order_id, i.items, r.reviews, i.items * r.reviews AS joined_rows
FROM (SELECT order_id, count(*) AS items FROM olist.order_items GROUP BY order_id) i
JOIN (SELECT order_id, count(*) AS reviews FROM olist.order_reviews GROUP BY order_id) r
  ON r.order_id = i.order_id
ORDER BY joined_rows DESC, i.order_id
LIMIT 5;
-- результат: 5 строк


-- 6. Исправление: агрегирую до одной строки на заказ
WITH items AS (
    SELECT order_id, sum(price) AS revenue
    FROM olist.order_items
    GROUP BY order_id
),
reviews AS (
    SELECT order_id, count(*) AS reviews
    FROM olist.order_reviews
    GROUP BY order_id
)
SELECT 'исправленный' AS variant,
       round(sum(i.revenue), 2)       AS revenue,
       sum(coalesce(r.reviews, 0))    AS reviews
FROM olist.orders o
JOIN items i ON i.order_id = o.order_id
LEFT JOIN reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered';
-- результат: variant = исправленный, revenue = 13221498.11, reviews = 96361

-- по штатам
WITH items AS (
    SELECT order_id, sum(price) AS revenue
    FROM olist.order_items
    GROUP BY order_id
),
reviews AS (
    SELECT order_id, count(*) AS reviews
    FROM olist.order_reviews
    GROUP BY order_id
)
SELECT c.customer_state,
       round(sum(i.revenue), 2)      AS revenue,
       sum(coalesce(r.reviews, 0))   AS reviews,
       count(*) FILTER (WHERE r.order_id IS NULL) AS orders_without_review
FROM olist.customers c
JOIN olist.orders o ON o.customer_id = c.customer_id
JOIN items i ON i.order_id = o.order_id
LEFT JOIN reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;
-- результат: 10 строк
