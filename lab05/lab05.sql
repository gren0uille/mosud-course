-- Практическая работа № 5. Кванторы, EXISTS и реляционное деление
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: S = {MS, MT, GO}
-- Найти категории, которые покупали в доставленных заказах клиенты
-- каждого штата из S. Категории NULL исключены.

-- Продажи: категория, штат покупателя, заказ (только delivered).
-- Представление в схеме lab, чтобы не повторять соединение в каждом запросе.
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

-- Делимое: пары (category, state). Делитель: target_states.
-- Частное: категории c, для которых ∀ s ∈ S: (c, s) ∈ sales.


-- 1, 2. Двойной NOT EXISTS
-- ∀s P(c, s) ≡ ¬∃s ¬P(c, s):
-- нет такого штата из S, в котором категория не продавалась.
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


-- 3. GROUP BY / HAVING COUNT(DISTINCT state)
-- Число различных штатов из S, где была категория, равно |S|.
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO'))
SELECT s.category
FROM lab.lab05_sales s
JOIN target_states t ON t.state = s.state
GROUP BY s.category
HAVING count(DISTINCT s.state) = (SELECT count(*) FROM target_states)
ORDER BY s.category;


-- 4. EXCEPT и NOT EXISTS
-- S минус штаты категории пусто => категория есть во всех штатах S.
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO')),
categories AS (SELECT DISTINCT category FROM lab.lab05_sales)
SELECT k.category
FROM categories k
WHERE NOT EXISTS (
    SELECT state FROM target_states
    EXCEPT
    SELECT s.state FROM lab.lab05_sales s WHERE s.category = k.category)
ORDER BY k.category;


-- 5. Эквивалентность трёх решений: EXCEPT в обе стороны, ожидаются нули.
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
-- Все разности пусты => три решения дают одно и то же множество.
-- Для контроля: сколько всего категорий с продажами.
SELECT count(DISTINCT category) AS all_categories FROM lab.lab05_sales;


-- 6. Диагностика для одной найденной категории:
-- категория → штат → число заказов
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO'))
SELECT s.category, t.state, count(DISTINCT s.order_id) AS orders
FROM target_states t
LEFT JOIN lab.lab05_sales s ON s.state = t.state AND s.category = 'beleza_saude'
GROUP BY s.category, t.state
ORDER BY t.state;

-- для контраста категория, которой нет в MS, поэтому она не попала в частное
WITH target_states(state) AS (VALUES ('MS'), ('MT'), ('GO'))
SELECT 'climatizacao' AS category, t.state, count(DISTINCT s.order_id) AS orders
FROM target_states t
LEFT JOIN lab.lab05_sales s ON s.state = t.state AND s.category = 'climatizacao'
GROUP BY t.state
ORDER BY t.state;


-- 7. Пустой target_states
-- Логически: ∀s ∈ ∅ P(s) — истина (пустая истинность),
-- значит, в частное должны попасть ВСЕ категории.
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
-- NOT EXISTS и EXCEPT возвращают все категории: это соответствует логике,
-- нет ни одного обязательного штата, который бы не выполнялся.
-- HAVING возвращает 0: JOIN с пустым делителем не даёт ни одной строки,
-- групп нет, проверять HAVING не на чем. На пустом делителе это решение
-- расходится с математическим определением деления.


-- 8. Дополнительно: продавцы, которые продавали покупателям всех штатов S
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

-- первые 10 таких продавцов с городом
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
