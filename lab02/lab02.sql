-- Практическая работа № 2. Множества и мультимножества в SQL
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: штат X = MT, штат Y = MS

-- A: товары, купленные клиентами из MT, B: из MS. Только delivered.
-- Без DISTINCT, одна строка = одна позиция заказа.

CREATE OR REPLACE VIEW lab.lab02_a AS
SELECT oi.product_id
FROM olist.orders o
JOIN olist.customers c ON c.customer_id = o.customer_id
JOIN olist.order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND c.customer_state = 'MT';

CREATE OR REPLACE VIEW lab.lab02_b AS
SELECT oi.product_id
FROM olist.orders o
JOIN olist.customers c ON c.customer_id = o.customer_id
JOIN olist.order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND c.customer_state = 'MS';


-- 1. Мощности A и B: всего строк и различных product_id
SELECT 'A (MT)' AS set_name, count(*) AS rows, count(DISTINCT product_id) AS distinct_products
FROM lab.lab02_a
UNION ALL
SELECT 'B (MS)', count(*), count(DISTINCT product_id)
FROM lab.lab02_b;
-- результат: A (MT) 1037 841; B (MS) 811 647


-- 2. Объединение A ∪ B
SELECT 'UNION' AS op, count(*) AS rows
FROM (SELECT product_id FROM lab.lab02_a
      UNION
      SELECT product_id FROM lab.lab02_b) t
UNION ALL
SELECT 'UNION ALL', count(*)
FROM (SELECT product_id FROM lab.lab02_a
      UNION ALL
      SELECT product_id FROM lab.lab02_b) t;
-- результат: UNION 1395; UNION ALL 1848
-- UNION ALL = |A| + |B|, UNION = |A| + |B| - |A ∩ B| по различным


-- 3. Пересечение A ∩ B
SELECT count(*) AS intersect_rows
FROM (SELECT product_id FROM lab.lab02_a
      INTERSECT
      SELECT product_id FROM lab.lab02_b) t;
-- результат: 93

SELECT product_id FROM lab.lab02_a
INTERSECT
SELECT product_id FROM lab.lab02_b
ORDER BY product_id
LIMIT 10;
-- результат: 10 строк


-- 4. Разности A − B и B − A
SELECT 'A - B' AS op, count(*) AS rows
FROM (SELECT product_id FROM lab.lab02_a
      EXCEPT
      SELECT product_id FROM lab.lab02_b) t
UNION ALL
SELECT 'B - A', count(*)
FROM (SELECT product_id FROM lab.lab02_b
      EXCEPT
      SELECT product_id FROM lab.lab02_a) t;
-- результат: A - B 748; B - A 554


-- 5. Коммутативность: симметрическая разность должна быть пустой
SELECT 'A ∪ B vs B ∪ A' AS check_name, count(*) AS differences
FROM (
    ((SELECT product_id FROM lab.lab02_a UNION SELECT product_id FROM lab.lab02_b)
     EXCEPT
     (SELECT product_id FROM lab.lab02_b UNION SELECT product_id FROM lab.lab02_a))
    UNION ALL
    ((SELECT product_id FROM lab.lab02_b UNION SELECT product_id FROM lab.lab02_a)
     EXCEPT
     (SELECT product_id FROM lab.lab02_a UNION SELECT product_id FROM lab.lab02_b))
) t
UNION ALL
SELECT 'A ∩ B vs B ∩ A', count(*)
FROM (
    ((SELECT product_id FROM lab.lab02_a INTERSECT SELECT product_id FROM lab.lab02_b)
     EXCEPT
     (SELECT product_id FROM lab.lab02_b INTERSECT SELECT product_id FROM lab.lab02_a))
    UNION ALL
    ((SELECT product_id FROM lab.lab02_b INTERSECT SELECT product_id FROM lab.lab02_a)
     EXCEPT
     (SELECT product_id FROM lab.lab02_a INTERSECT SELECT product_id FROM lab.lab02_b))
) t;
-- результат: A ∪ B vs B ∪ A 0; A ∩ B vs B ∩ A 0


-- 6. Разность некоммутативна
SELECT 'в A - B, но не в B - A' AS check_name, count(*) AS rows
FROM (
    (SELECT product_id FROM lab.lab02_a EXCEPT SELECT product_id FROM lab.lab02_b)
    EXCEPT
    (SELECT product_id FROM lab.lab02_b EXCEPT SELECT product_id FROM lab.lab02_a)
) t
UNION ALL
SELECT 'в B - A, но не в A - B', count(*)
FROM (
    (SELECT product_id FROM lab.lab02_b EXCEPT SELECT product_id FROM lab.lab02_a)
    EXCEPT
    (SELECT product_id FROM lab.lab02_a EXCEPT SELECT product_id FROM lab.lab02_b)
) t;
-- результат: в A - B, но не в B - A 748; в B - A, но не в A - B 554


-- 7. Пересечение без INTERSECT, через EXISTS
SELECT count(*) AS exists_rows
FROM (
    SELECT DISTINCT a.product_id
    FROM lab.lab02_a a
    WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id)
) t;
-- результат: 93

-- сверка с INTERSECT
SELECT count(*) AS differences
FROM (
    (SELECT product_id FROM lab.lab02_a INTERSECT SELECT product_id FROM lab.lab02_b)
    EXCEPT
    SELECT a.product_id FROM lab.lab02_a a
    WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id)
) t;
-- результат: 0


-- 8. Дубликаты: тот же запрос с EXISTS, но без DISTINCT
SELECT count(*) AS rows, count(DISTINCT product_id) AS distinct_products
FROM lab.lab02_a a
WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id);
-- результат: rows = 149, distinct_products = 93

SELECT a.product_id, count(*) AS times
FROM lab.lab02_a a
WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id)
GROUP BY a.product_id
HAVING count(*) > 1
ORDER BY times DESC, a.product_id
LIMIT 10;
-- результат: 10 строк

SELECT 'INTERSECT ALL' AS op, count(*) AS rows
FROM (SELECT product_id FROM lab.lab02_a INTERSECT ALL SELECT product_id FROM lab.lab02_b) t
UNION ALL
SELECT 'EXCEPT ALL (A - B)', count(*)
FROM (SELECT product_id FROM lab.lab02_a EXCEPT ALL SELECT product_id FROM lab.lab02_b) t;
-- результат: INTERSECT ALL 120; EXCEPT ALL (A - B) 917
-- 9. Множество: UNION, INTERSECT, EXCEPT, SELECT DISTINCT.
-- Мультимножество: UNION ALL, INTERSECT ALL, EXCEPT ALL, SELECT, JOIN, EXISTS без DISTINCT.
