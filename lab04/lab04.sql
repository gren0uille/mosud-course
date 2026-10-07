-- Практическая работа № 4. Соединения отношений и сложные JOIN
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: клиенты без отзывов.
-- Маршрут: customers → orders LEFT JOIN order_reviews, антисоединение.

-- Кратности связей
--   customers → orders по customer_id: 1:1 на данных Olist
--     (у каждого заказа свой customer_id), но человек определяется
--     customer_unique_id, и по нему связь 1:N — один покупатель, много заказов.
--   orders → order_reviews по order_id: 1:N, у части заказов несколько отзывов.
--   orders → order_items по order_id: 1:N.
--   customers → orders → order_items: товары и клиенты связаны M:N через заказы.

-- проверка кратностей на данных
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


-- 1, 3. Основной запрос: по штатам — доставленные заказы, сколько из них
-- с отзывом, без отзыва и средняя оценка.
-- LEFT JOIN сохраняет заказы, у которых отзыва нет (r.* = NULL).
-- count(DISTINCT o.order_id), потому что у заказа может быть 2+ отзыва.
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

-- 7. Реляционная алгебра основного запроса
-- γ_{customer_state; count(order_id), avg(review_score)} (
--   σ_{order_status = 'delivered'} (customers ⋈_{customer_id} orders)
--   ⟕_{orders.order_id = order_reviews.order_id} order_reviews )
-- ⋈ — эквисоединение, ⟕ — левое внешнее соединение, γ — группировка.


-- 4. Антисоединение: клиенты (люди, customer_unique_id), у которых
-- есть доставленные заказы, но ни на один заказ нет отзыва.
-- customers ▷ (orders ⋈ order_reviews)

-- через NOT EXISTS
SELECT count(DISTINCT c.customer_unique_id) AS customers_without_reviews
FROM olist.customers c
WHERE EXISTS (SELECT 1 FROM olist.orders o
              WHERE o.customer_id = c.customer_id AND o.order_status = 'delivered')
  AND NOT EXISTS (SELECT 1
                  FROM olist.customers c2
                  JOIN olist.orders o2 ON o2.customer_id = c2.customer_id
                  JOIN olist.order_reviews r ON r.order_id = o2.order_id
                  WHERE c2.customer_unique_id = c.customer_unique_id);

-- то же через LEFT JOIN ... IS NULL, на уровне заказов
SELECT c.customer_state, count(*) AS delivered_orders_without_review
FROM olist.customers c
JOIN olist.orders o ON o.customer_id = c.customer_id
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND r.order_id IS NULL
GROUP BY c.customer_state
ORDER BY 2 DESC
LIMIT 10;

-- примеры клиентов без отзывов
SELECT c.customer_unique_id, c.customer_city, c.customer_state,
       o.order_id, o.order_delivered_customer_date::date AS delivered
FROM olist.customers c
JOIN olist.orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM olist.order_reviews r WHERE r.order_id = o.order_id)
ORDER BY delivered DESC NULLS LAST, o.order_id
LIMIT 5;


-- 5. Ошибочный JOIN: размножение строк.
-- Хочу выручку по товарам и число отзывов по штатам.
-- Соединяю order_items и order_reviews по одному order_id.
-- Заказ с 3 позициями и 2 отзывами даст 3 × 2 = 6 строк:
-- каждая цена посчитается дважды, каждый отзыв — трижды.
SELECT 'ошибочный' AS variant,
       round(sum(oi.price), 2) AS revenue,
       count(r.review_id)      AS reviews
FROM olist.orders o
JOIN olist.order_items oi ON oi.order_id = o.order_id
LEFT JOIN olist.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
UNION ALL
-- эталон: каждую таблицу считаю отдельно
SELECT 'эталон',
       (SELECT round(sum(oi.price), 2)
        FROM olist.order_items oi JOIN olist.orders o ON o.order_id = oi.order_id
        WHERE o.order_status = 'delivered'),
       (SELECT count(*)
        FROM olist.order_reviews r JOIN olist.orders o ON o.order_id = r.order_id
        WHERE o.order_status = 'delivered');

-- заказы, на которых происходит размножение
SELECT i.order_id, i.items, r.reviews, i.items * r.reviews AS joined_rows
FROM (SELECT order_id, count(*) AS items FROM olist.order_items GROUP BY order_id) i
JOIN (SELECT order_id, count(*) AS reviews FROM olist.order_reviews GROUP BY order_id) r
  ON r.order_id = i.order_id
ORDER BY joined_rows DESC, i.order_id
LIMIT 5;


-- 6. Исправление: предварительная агрегация до одной строки на заказ.
-- После неё обе стороны имеют кратность 1:1 с orders, размножения нет.
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
-- Совпадает с эталоном.

-- то же по штатам
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
