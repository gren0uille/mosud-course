-- Практическая работа № 6. Подзапросы и логика предикатов
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: продавцы со средним freight_value выше общего среднего


-- 1, 2. Подзапросы: скалярный (общее среднее) и коррелированный (по продавцу)
SELECT s.seller_id, s.seller_city, s.seller_state,
       round((SELECT avg(oi.freight_value)
              FROM olist.order_items oi
              WHERE oi.seller_id = s.seller_id), 2)            AS seller_avg_freight,
       round((SELECT avg(freight_value) FROM olist.order_items), 2) AS overall_avg_freight
FROM olist.sellers s
WHERE (SELECT avg(oi.freight_value)
       FROM olist.order_items oi
       WHERE oi.seller_id = s.seller_id)
    > (SELECT avg(freight_value) FROM olist.order_items)
ORDER BY seller_avg_freight DESC, s.seller_id
LIMIT 10;
-- результат: 10 строк

SELECT count(*) AS sellers_above_avg
FROM olist.sellers s
WHERE (SELECT avg(oi.freight_value) FROM olist.order_items oi
       WHERE oi.seller_id = s.seller_id)
    > (SELECT avg(freight_value) FROM olist.order_items);
-- результат: 1221

-- продавцы с продажами, EXISTS
SELECT count(*) AS sellers_total,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM olist.order_items oi
                                      WHERE oi.seller_id = s.seller_id)) AS sellers_with_sales
FROM olist.sellers s;
-- результат: sellers_total = 3095, sellers_with_sales = 3095


-- 3. CTE с агрегацией. Подзапросы выше ~30 с (нет индекса по seller_id), CTE < 1 с
WITH seller_freight AS (
    SELECT seller_id, avg(freight_value) AS avg_freight
    FROM olist.order_items
    GROUP BY seller_id
),
overall AS (
    SELECT avg(freight_value) AS avg_freight
    FROM olist.order_items
)
SELECT count(*) AS sellers_above_avg
FROM seller_freight sf
CROSS JOIN overall o
WHERE sf.avg_freight > o.avg_freight;
-- результат: 1221


-- 4. Сверка
WITH sub AS (
    SELECT s.seller_id
    FROM olist.sellers s
    WHERE (SELECT avg(oi.freight_value) FROM olist.order_items oi
           WHERE oi.seller_id = s.seller_id)
        > (SELECT avg(freight_value) FROM olist.order_items)
),
cte AS (
    SELECT sf.seller_id
    FROM (SELECT seller_id, avg(freight_value) AS avg_freight
          FROM olist.order_items GROUP BY seller_id) sf
    CROSS JOIN (SELECT avg(freight_value) AS avg_freight FROM olist.order_items) o
    WHERE sf.avg_freight > o.avg_freight
)
SELECT 'подзапросы - CTE' AS check_name, count(*) AS rows
FROM (SELECT seller_id FROM sub EXCEPT SELECT seller_id FROM cte) d
UNION ALL
SELECT 'CTE - подзапросы', count(*)
FROM (SELECT seller_id FROM cte EXCEPT SELECT seller_id FROM sub) d;
-- результат: подзапросы - CTE 0; CTE - подзапросы 0


-- 5. ANY / ALL относительно средних по штатам продавцов
WITH seller_freight AS (
    SELECT oi.seller_id, se.seller_state, avg(oi.freight_value) AS avg_freight
    FROM olist.order_items oi
    JOIN olist.sellers se ON se.seller_id = oi.seller_id
    GROUP BY oi.seller_id, se.seller_state
),
state_freight AS (
    SELECT seller_state, avg(avg_freight) AS avg_freight
    FROM seller_freight
    GROUP BY seller_state
)
SELECT 'выше ALL штатов' AS condition, count(*) AS sellers
FROM seller_freight sf
WHERE sf.avg_freight > ALL (SELECT avg_freight FROM state_freight)
UNION ALL
SELECT 'выше ANY штата', count(*)
FROM seller_freight sf
WHERE sf.avg_freight > ANY (SELECT avg_freight FROM state_freight)
UNION ALL
SELECT 'всего продавцов с продажами', count(*)
FROM seller_freight;
-- результат: выше ALL штатов 149; выше ANY штата 1314; всего продавцов с продажами 3095

-- > ALL = > max, > ANY = > min
WITH seller_freight AS (
    SELECT oi.seller_id, se.seller_state, avg(oi.freight_value) AS avg_freight
    FROM olist.order_items oi
    JOIN olist.sellers se ON se.seller_id = oi.seller_id
    GROUP BY oi.seller_id, se.seller_state
),
state_freight AS (
    SELECT seller_state, avg(avg_freight) AS avg_freight
    FROM seller_freight
    GROUP BY seller_state
)
SELECT round(min(avg_freight), 2) AS min_state_avg,
       round(max(avg_freight), 2) AS max_state_avg,
       (SELECT count(*) FROM seller_freight
        WHERE avg_freight > (SELECT max(avg_freight) FROM state_freight)) AS gt_max,
       (SELECT count(*) FROM seller_freight
        WHERE avg_freight > (SELECT min(avg_freight) FROM state_freight)) AS gt_min
FROM state_freight;
-- результат: min_state_avg = 19.39, max_state_avg = 55.03, gt_max = 149, gt_min = 1314

-- = ANY (аналог IN): продавцы из штатов с доставкой выше средней
SELECT count(*) AS sellers_in_expensive_states
FROM olist.sellers s
WHERE s.seller_state = ANY (
    SELECT se.seller_state
    FROM olist.order_items oi
    JOIN olist.sellers se ON se.seller_id = oi.seller_id
    GROUP BY se.seller_state
    HAVING avg(oi.freight_value) > (SELECT avg(freight_value) FROM olist.order_items));
-- результат: 1074
