-- Практическая работа № 6. Подзапросы и логика предикатов
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: продавцы, средняя стоимость доставки которых
-- выше общей средней стоимости доставки.
-- Стоимость доставки — order_items.freight_value, считаю по всем позициям.
-- Общая средняя — среднее freight_value по всем позициям всех продавцов.


-- 1, 2. Основное решение через подзапросы.
-- Скалярный подзапрос: общая средняя (одно значение).
-- Коррелированный подзапрос: средняя конкретного продавца,
-- зависит от строки внешнего запроса (s.seller_id).
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

SELECT count(*) AS sellers_above_avg
FROM olist.sellers s
WHERE (SELECT avg(oi.freight_value) FROM olist.order_items oi
       WHERE oi.seller_id = s.seller_id)
    > (SELECT avg(freight_value) FROM olist.order_items);

-- Для контекста: сколько продавцов вообще что-то продавали.
-- EXISTS — коррелированный: есть ли у продавца хотя бы одна позиция.
SELECT count(*) AS sellers_total,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM olist.order_items oi
                                      WHERE oi.seller_id = s.seller_id)) AS sellers_with_sales
FROM olist.sellers s;
-- Продавцы без продаж в основном запросе отсеиваются сами:
-- avg по пустому набору = NULL, а NULL > x даёт UNKNOWN, и WHERE строку не пропускает.


-- 3. Альтернатива: CTE с предварительной агрегацией и JOIN.
-- Средние по продавцам считаются за один проход по order_items,
-- а не отдельным подзапросом для каждого продавца.
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


-- 4. Сравнение результатов: EXCEPT в обе стороны, ожидаются 0 и 0.
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


-- 5. ANY и ALL (демонстрация).
-- x > ALL (набор)  — x больше каждого значения набора (больше максимума).
-- x > ANY (набор)  — x больше хотя бы одного значения (больше минимума).

-- Продавцы, чья средняя доставка выше средней доставки
-- КАЖДОГО штата продавцов (то есть выше самого «дорогого» штата).
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

-- проверка: > ALL равносильно > max, > ANY — > min (если в наборе нет NULL)
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

-- IN — то же, что = ANY. Продавцы из штатов, где средняя доставка
-- продавца выше общей средней.
SELECT count(*) AS sellers_in_expensive_states
FROM olist.sellers s
WHERE s.seller_state = ANY (
    SELECT se.seller_state
    FROM olist.order_items oi
    JOIN olist.sellers se ON se.seller_id = oi.seller_id
    GROUP BY se.seller_state
    HAVING avg(oi.freight_value) > (SELECT avg(freight_value) FROM olist.order_items));
