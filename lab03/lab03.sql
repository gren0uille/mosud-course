-- Практическая работа № 3. Выборка, проекция, переименование и реляционная алгебра
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: geolocation, state = RJ и широта в диапазоне [-23.1; -22.7]
--            (примерно Рио-де-Жанейро с пригородами)
-- Проекция: zip_prefix, lat, lng, city

-- 1. Исходное отношение
-- G = olist.geolocation(geolocation_zip_code_prefix, geolocation_lat,
--                       geolocation_lng, geolocation_city, geolocation_state)
-- Используемые атрибуты: все пять; state и lat — в предикате,
-- zip_prefix, lat, lng, city — в проекции.

-- 2. Выражение реляционной алгебры
-- ρ_{zip_prefix←geolocation_zip_code_prefix, lat←geolocation_lat,
--   lng←geolocation_lng, city←geolocation_city} (
--   π_{geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city} (
--     σ_{geolocation_state = 'RJ' ∧ -23.1 ≤ geolocation_lat ≤ -22.7} (G)))


-- 3. Реализация в SQL: σ → WHERE, π → список SELECT, ρ → AS
SELECT geolocation_zip_code_prefix AS zip_prefix,
       geolocation_lat             AS lat,
       geolocation_lng             AS lng,
       geolocation_city            AS city
FROM olist.geolocation
WHERE geolocation_state = 'RJ'
  AND geolocation_lat BETWEEN -23.1 AND -22.7
ORDER BY zip_prefix, lat, lng
LIMIT 10;

SELECT count(*) AS q1_rows
FROM olist.geolocation
WHERE geolocation_state = 'RJ'
  AND geolocation_lat BETWEEN -23.1 AND -22.7;


-- 4. Разбиение предиката на две выборки
-- σ_{p1 ∧ p2}(G) = σ_{p2}(σ_{p1}(G)) = σ_{p1}(σ_{p2}(G))
-- p1: state = 'RJ', p2: -23.1 ≤ lat ≤ -22.7
SELECT count(*) AS q2_rows
FROM (SELECT *
      FROM olist.geolocation
      WHERE geolocation_state = 'RJ') t
WHERE geolocation_lat BETWEEN -23.1 AND -22.7;

-- Эквивалентность: разность в обе стороны пуста.
-- Использую EXCEPT ALL, чтобы совпало и число повторов, а не только множество.
SELECT 'Q1 - Q2' AS check_name, count(*) AS rows
FROM (
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city
    FROM olist.geolocation
    WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
    EXCEPT ALL
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city
    FROM (SELECT * FROM olist.geolocation WHERE geolocation_state = 'RJ') t
    WHERE geolocation_lat BETWEEN -23.1 AND -22.7
) d
UNION ALL
SELECT 'Q2 - Q1', count(*)
FROM (
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city
    FROM (SELECT * FROM olist.geolocation WHERE geolocation_state = 'RJ') t
    WHERE geolocation_lat BETWEEN -23.1 AND -22.7
    EXCEPT ALL
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city
    FROM olist.geolocation
    WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
) d;


-- 5. Ранняя проекция
-- Сначала фильтр по штату, сразу отбрасываю ненужный дальше state,
-- потом фильтр по широте и переименование:
-- ρ(σ_{p2}(π_{zip, lat, lng, city}(σ_{p1}(G))))
-- Так можно, потому что p2 использует только lat, а он в проекции остался.
SELECT zip_prefix, lat, lng, city
FROM (SELECT geolocation_zip_code_prefix AS zip_prefix,
             geolocation_lat             AS lat,
             geolocation_lng             AS lng,
             geolocation_city            AS city
      FROM olist.geolocation
      WHERE geolocation_state = 'RJ') t
WHERE lat BETWEEN -23.1 AND -22.7
ORDER BY zip_prefix, lat, lng
LIMIT 10;

-- эквивалентность с Q1 (ожидается 0 и 0)
SELECT 'Q1 - Q3' AS check_name, count(*) AS rows
FROM (
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city
    FROM olist.geolocation
    WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
    EXCEPT ALL
    SELECT zip_prefix, lat, lng, city
    FROM (SELECT geolocation_zip_code_prefix AS zip_prefix, geolocation_lat AS lat,
                 geolocation_lng AS lng, geolocation_city AS city
          FROM olist.geolocation WHERE geolocation_state = 'RJ') t
    WHERE lat BETWEEN -23.1 AND -22.7
) d
UNION ALL
SELECT 'Q3 - Q1', count(*)
FROM (
    SELECT zip_prefix, lat, lng, city
    FROM (SELECT geolocation_zip_code_prefix AS zip_prefix, geolocation_lat AS lat,
                 geolocation_lng AS lng, geolocation_city AS city
          FROM olist.geolocation WHERE geolocation_state = 'RJ') t
    WHERE lat BETWEEN -23.1 AND -22.7
    EXCEPT ALL
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city
    FROM olist.geolocation
    WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
) d;


-- 6. Дубликаты в проекции
-- В geolocation нет ключа, одна и та же точка повторяется.
-- После отбрасывания state повторов может стать ещё больше.
SELECT 'SELECT' AS variant, count(*) AS rows
FROM olist.geolocation
WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
UNION ALL
SELECT 'SELECT DISTINCT', count(*)
FROM (SELECT DISTINCT geolocation_zip_code_prefix, geolocation_lat,
                      geolocation_lng, geolocation_city
      FROM olist.geolocation
      WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7) t;

-- примеры повторяющихся кортежей
SELECT geolocation_zip_code_prefix AS zip_prefix, geolocation_lat AS lat,
       geolocation_lng AS lng, geolocation_city AS city, count(*) AS times
FROM olist.geolocation
WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
GROUP BY 1, 2, 3, 4
HAVING count(*) > 1
ORDER BY times DESC, zip_prefix
LIMIT 5;
-- Математическая проекция π дала бы результат как в SELECT DISTINCT.
