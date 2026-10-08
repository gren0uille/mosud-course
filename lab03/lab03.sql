-- Практическая работа № 3. Выборка, проекция, переименование и реляционная алгебра
-- Камалов Т. А. ИНБО-20-23
-- Вариант 8: geolocation, state = RJ, lat от -23.1 до -22.7 (Рио)

-- 1. G = geolocation(zip_code_prefix, lat, lng, city, state)
-- 2. ρ(π_{zip_code_prefix, lat, lng, city}(σ_{state = 'RJ' ∧ -23.1 ≤ lat ≤ -22.7}(G)))


-- 3. SQL
SELECT geolocation_zip_code_prefix AS zip_prefix,
       geolocation_lat             AS lat,
       geolocation_lng             AS lng,
       geolocation_city            AS city
FROM olist.geolocation
WHERE geolocation_state = 'RJ'
  AND geolocation_lat BETWEEN -23.1 AND -22.7
ORDER BY zip_prefix, lat, lng
LIMIT 10;
-- результат: 10 строк

SELECT count(*) AS q1_rows
FROM olist.geolocation
WHERE geolocation_state = 'RJ'
  AND geolocation_lat BETWEEN -23.1 AND -22.7;
-- результат: 93279


-- 4. Две выборки: σ_{lat}(σ_{state}(G))
SELECT count(*) AS q2_rows
FROM (SELECT *
      FROM olist.geolocation
      WHERE geolocation_state = 'RJ') t
WHERE geolocation_lat BETWEEN -23.1 AND -22.7;
-- результат: 93279

-- сверка Q1 и Q2, EXCEPT ALL чтобы учесть повторы
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
-- результат: Q1 - Q2 0; Q2 - Q1 0


-- 5. Ранняя проекция: state убираю сразу после фильтра по штату
-- ρ(σ_{lat}(π_{zip, lat, lng, city}(σ_{state}(G))))
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
-- результат: 10 строк

-- сверка Q1 и Q3
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
-- результат: Q1 - Q3 0; Q3 - Q1 0


-- 6. Дубликаты: в geolocation нет ключа, точки повторяются
SELECT 'SELECT' AS variant, count(*) AS rows
FROM olist.geolocation
WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
UNION ALL
SELECT 'SELECT DISTINCT', count(*)
FROM (SELECT DISTINCT geolocation_zip_code_prefix, geolocation_lat,
                      geolocation_lng, geolocation_city
      FROM olist.geolocation
      WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7) t;
-- результат: SELECT 93279; SELECT DISTINCT 57599

SELECT geolocation_zip_code_prefix AS zip_prefix, geolocation_lat AS lat,
       geolocation_lng AS lng, geolocation_city AS city, count(*) AS times
FROM olist.geolocation
WHERE geolocation_state = 'RJ' AND geolocation_lat BETWEEN -23.1 AND -22.7
GROUP BY 1, 2, 3, 4
HAVING count(*) > 1
ORDER BY times DESC, zip_prefix
LIMIT 5;
-- результат: 5 строк
