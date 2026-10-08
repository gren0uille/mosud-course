-- Практическая работа № 5. Кванторы, EXISTS и реляционное деление
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: S = {MS, MT, GO}

-- продажи по категориям и штатам, delivered, без NULL-категорий
CREATE OR REPLACE VIEW lab.lab05_sales AS
SELECT p.product_category_name AS category,
       c.customer_state        AS state,
       o.order_id
FROM olist.orders o
JOIN olist.customers c   ON c.customer_id = o.customer_id
JOIN olist.order_items oi ON oi.order_id = o.order_id
JOIN olist.products p    ON p.product_id = oi.product_id
WHERE o.order_status = 'delivered'
  AND p.product_category_name IS NOT NULL;


-- 1, 2. Двойной NOT EXISTS
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO')),
categories AS (SELECT DISTINCT category FROM lab.lab05_sales)
SELECT k.category
FROM categories k
WHERE NOT EXISTS (
    SELECT 1 FROM target_states t
    WHERE NOT EXISTS (
        SELECT 1 FROM lab.lab05_sales s
        WHERE s.category = k.category AND s.state = t.state))
ORDER BY k.category;
-- результат: 47 строк


-- 3. HAVING COUNT(DISTINCT)
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO'))
SELECT s.category
FROM lab.lab05_sales s
JOIN target_states t ON t.state = s.state
GROUP BY s.category
HAVING count(DISTINCT s.state) = (SELECT count(*) FROM target_states)
ORDER BY s.category;
-- результат: 47 строк


-- 4. EXCEPT
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO')),
categories AS (SELECT DISTINCT category FROM lab.lab05_sales)
SELECT k.category
FROM categories k
WHERE NOT EXISTS (
    SELECT state FROM target_states
    EXCEPT
    SELECT s.state FROM lab.lab05_sales s WHERE s.category = k.category)
ORDER BY k.category;
-- результат: 47 строк


-- 5. Сверка решений
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO')),
categories AS (SELECT DISTINCT category FROM lab.lab05_sales),
r1 AS (
    SELECT k.category FROM categories k
    WHERE NOT EXISTS (
        SELECT 1 FROM target_states t
        WHERE NOT EXISTS (SELECT 1 FROM lab.lab05_sales s
                          WHERE s.category = k.category AND s.state = t.state))),
r2 AS (
    SELECT s.category FROM lab.lab05_sales s
    JOIN target_states t ON t.state = s.state
    GROUP BY s.category
    HAVING count(DISTINCT s.state) = (SELECT count(*) FROM target_states)),
r3 AS (
    SELECT k.category FROM categories k
    WHERE NOT EXISTS (
        SELECT state FROM target_states
        EXCEPT
        SELECT s.state FROM lab.lab05_sales s WHERE s.category = k.category))
SELECT 'r1 (NOT EXISTS)' AS solution, (SELECT count(*) FROM r1) AS categories,
       (SELECT count(*) FROM (SELECT * FROM r1 EXCEPT SELECT * FROM r2) d) AS minus_r2,
       (SELECT count(*) FROM (SELECT * FROM r2 EXCEPT SELECT * FROM r1) d) AS r2_minus,
       (SELECT count(*) FROM (SELECT * FROM r1 EXCEPT SELECT * FROM r3) d) AS minus_r3,
       (SELECT count(*) FROM (SELECT * FROM r3 EXCEPT SELECT * FROM r1) d) AS r3_minus
UNION ALL
SELECT 'r2 (HAVING)', (SELECT count(*) FROM r2), NULL, NULL,
       (SELECT count(*) FROM (SELECT * FROM r2 EXCEPT SELECT * FROM r3) d),
       (SELECT count(*) FROM (SELECT * FROM r3 EXCEPT SELECT * FROM r2) d)
UNION ALL
SELECT 'r3 (EXCEPT)', (SELECT count(*) FROM r3), NULL, NULL, NULL, NULL;
-- результат: r1, r2, r3 по 47 категорий, все разности 0
-- всего категорий
SELECT count(DISTINCT category) AS all_categories FROM lab.lab05_sales;
-- результат: 73


-- 6. Диагностика
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO'))
SELECT s.category, t.state, count(DISTINCT s.order_id) AS orders
FROM target_states t
LEFT JOIN lab.lab05_sales s ON s.state = t.state AND s.category = 'beleza_saude'
GROUP BY s.category, t.state
ORDER BY t.state;
-- результат: beleza_saude GO 206; beleza_saude MS 57; beleza_saude MT 83

-- нет в MS
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO'))
SELECT 'climatizacao' AS category, t.state, count(DISTINCT s.order_id) AS orders
FROM target_states t
LEFT JOIN lab.lab05_sales s ON s.state = t.state AND s.category = 'climatizacao'
GROUP BY t.state
ORDER BY t.state;
-- результат: climatizacao GO 6; climatizacao MS 0; climatizacao MT 3


-- 7. Пустой target_states
WITH target_states(state) AS (SELECT 'XX'::text WHERE false),
categories AS (SELECT DISTINCT category FROM lab.lab05_sales)
SELECT 'двойной NOT EXISTS' AS solution, count(*) AS categories
FROM categories k
WHERE NOT EXISTS (
    SELECT 1 FROM target_states t
    WHERE NOT EXISTS (SELECT 1 FROM lab.lab05_sales s
                      WHERE s.category = k.category AND s.state = t.state))
UNION ALL
SELECT 'HAVING COUNT', count(*)
FROM (SELECT s.category FROM lab.lab05_sales s
      JOIN target_states t ON t.state = s.state
      GROUP BY s.category
      HAVING count(DISTINCT s.state) = (SELECT count(*) FROM target_states)) x
UNION ALL
SELECT 'EXCEPT', count(*)
FROM categories k
WHERE NOT EXISTS (
    SELECT state FROM target_states
    EXCEPT
    SELECT s.state FROM lab.lab05_sales s WHERE s.category = k.category);
-- результат: двойной NOT EXISTS 73; HAVING COUNT 0; EXCEPT 73
-- NOT EXISTS и EXCEPT: все категории (условие "для всех" на пустом множестве истинно).
-- HAVING: 0, т. к. после JOIN с пустым S групп нет.


-- 8. Продавцы, продававшие во все штаты S
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO')),
seller_states AS (
    SELECT DISTINCT oi.seller_id, c.customer_state AS state
    FROM olist.orders o
    JOIN olist.customers c    ON c.customer_id = o.customer_id
    JOIN olist.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
)
SELECT count(*) AS sellers
FROM (SELECT DISTINCT seller_id FROM seller_states) sl
WHERE NOT EXISTS (
    SELECT 1 FROM target_states t
    WHERE NOT EXISTS (SELECT 1 FROM seller_states ss
                      WHERE ss.seller_id = sl.seller_id AND ss.state = t.state));
-- результат: 163

WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO')),
seller_states AS (
    SELECT DISTINCT oi.seller_id, c.customer_state AS state
    FROM olist.orders o
    JOIN olist.customers c    ON c.customer_id = o.customer_id
    JOIN olist.order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
)
SELECT se.seller_id, se.seller_city, se.seller_state
FROM olist.sellers se
WHERE NOT EXISTS (
    SELECT 1 FROM target_states t
    WHERE NOT EXISTS (SELECT 1 FROM seller_states ss
                      WHERE ss.seller_id = se.seller_id AND ss.state = t.state))
ORDER BY se.seller_id
LIMIT 10;
-- результат: 10 строк
