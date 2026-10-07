-- Практическая работа № 2. Множества и мультимножества в SQL
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: штат X = MT, штат Y = MS

-- A — product_id товаров, которые покупали клиенты из MT
-- B — то же для MS
-- Учитываются только заказы со статусом delivered.
-- Представления создаю в схеме lab, olist не меняется.
-- В представлениях DISTINCT нет: это мультимножества (одна строка на позицию заказа).

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
-- count(*) > count(DISTINCT): один товар покупали несколько раз,
-- в том числе несколько штук в одном заказе.


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
-- UNION ALL просто склеивает строки: |A| + |B| с повторами.
-- UNION удаляет дубликаты и внутри A и B, и между ними,
-- поэтому даёт |A ∪ B| = |A| + |B| - |A ∩ B| по различным значениям.


-- 3. Пересечение A ∩ B
SELECT count(*) AS intersect_rows
FROM (SELECT product_id FROM lab.lab02_a
      INTERSECT
      SELECT product_id FROM lab.lab02_b) t;

-- первые 10 товаров пересечения
SELECT product_id FROM lab.lab02_a
INTERSECT
SELECT product_id FROM lab.lab02_b
ORDER BY product_id
LIMIT 10;


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
-- Проверка: |A - B| + |A ∩ B| = |A| (по различным), аналогично для B.


-- 5. Коммутативность объединения и пересечения.
-- Симметрическая разность двух результатов пуста => результаты совпадают.
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
-- Оба значения 0: A ∪ B = B ∪ A, A ∩ B = B ∩ A.


-- 6. Разность некоммутативна: A − B ≠ B − A.
-- Если бы они были равны, оба счётчика ниже были бы 0.
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
-- Более того, A − B и B − A вообще не пересекаются:
-- элемент A − B лежит в A, а элементы B − A в A не лежат.


-- 7. Пересечение без INTERSECT, через EXISTS
SELECT count(*) AS exists_rows
FROM (
    SELECT DISTINCT a.product_id
    FROM lab.lab02_a a
    WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id)
) t;
-- Совпадает с п. 3. DISTINCT обязателен: без него товар,
-- купленный в MT несколько раз, попадёт в результат несколько раз.

-- проверка, что результаты совпадают как множества (ожидается 0)
SELECT count(*) AS differences
FROM (
    (SELECT product_id FROM lab.lab02_a INTERSECT SELECT product_id FROM lab.lab02_b)
    EXCEPT
    SELECT a.product_id FROM lab.lab02_a a
    WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id)
) t;


-- 8. Дубликаты: тот же запрос с EXISTS, но без DISTINCT
SELECT count(*) AS rows, count(DISTINCT product_id) AS distinct_products
FROM lab.lab02_a a
WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id);

-- какие товары повторяются
SELECT a.product_id, count(*) AS times
FROM lab.lab02_a a
WHERE EXISTS (SELECT 1 FROM lab.lab02_b b WHERE b.product_id = a.product_id)
GROUP BY a.product_id
HAVING count(*) > 1
ORDER BY times DESC, a.product_id
LIMIT 10;

-- ALL-варианты тоже работают с мультимножествами
SELECT 'INTERSECT ALL' AS op, count(*) AS rows
FROM (SELECT product_id FROM lab.lab02_a INTERSECT ALL SELECT product_id FROM lab.lab02_b) t
UNION ALL
SELECT 'EXCEPT ALL (A - B)', count(*)
FROM (SELECT product_id FROM lab.lab02_a EXCEPT ALL SELECT product_id FROM lab.lab02_b) t;
-- INTERSECT ALL: товар входит min(m, n) раз, EXCEPT ALL: max(m - n, 0) раз,
-- где m и n — число его вхождений в A и B.


-- 9. Множество или мультимножество
-- Возвращают множество (без повторов):
--   UNION, INTERSECT, EXCEPT, SELECT DISTINCT.
--   Дубликаты удаляются даже если они были в одном аргументе.
-- Могут вернуть мультимножество:
--   UNION ALL, INTERSECT ALL, EXCEPT ALL, обычный SELECT, JOIN,
--   WHERE EXISTS / IN без DISTINCT.
--   Сами A и B здесь мультимножества: товар повторяется
--   столько раз, сколько раз его купили.
