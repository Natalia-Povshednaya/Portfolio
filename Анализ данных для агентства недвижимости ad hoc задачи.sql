-- Анализ данных для агентства недвижимости

-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- распределение по регионам
region_category AS (
    SELECT 
        a.id,
        a.last_price,
        a.days_exposition,
        a.first_day_exposition,
        f.total_area,
        f.rooms,
        f.balcony,
        c.city,
        f.is_apartment,
        CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region
    FROM advertisement a
    JOIN filtered_id USING(id)
    JOIN flats f USING(id)
    JOIN city c USING (city_id)
    JOIN "type" t USING(type_id) 
    WHERE EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018 
    AND t.type = 'город'
),
--распределение по временным интервалам
duration_days_category AS (
    SELECT 
        *,
        CASE 
            WHEN days_exposition IS NULL THEN 'non category'
            WHEN days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            ELSE '181+ days'
        END AS duration_category
    FROM region_category
)
SELECT
    region,
    duration_category,
    COUNT(id) AS count_sale,
 	ROUND(AVG(last_price / NULLIF(total_area,0))::numeric, 2) AS avg_sale_meter2,
    ROUND(AVG(total_area)::numeric, 2) AS avg_area,
    ROUND(AVG(rooms)::numeric, 2) AS avg_rooms,
    ROUND(AVG(balcony)::numeric, 2) AS avg_balcony,
    SUM(is_apartment) apartament,
    SUM(is_apartment)/COUNT(id)::NUMERIC * 100 share_apartament
FROM duration_days_category
GROUP BY region, duration_category
ORDER BY region, count_sale DESC;

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- фильтруем данные по типу город и полные года 2015-2018
filters_date AS (
    SELECT 
        a.id,
        a.first_day_exposition,
        a.days_exposition,
        a.last_price,
        f.total_area,
        t.type
    FROM filtered_id fi
    JOIN advertisement a USING(id)
    JOIN flats f USING(id)
    JOIN "type" t USING(type_id)
    WHERE 
        t.type = 'город'
        AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
),
-- ищем месяц публикации и месяц снятия объявления
last_first_month AS (
SELECT *,
EXTRACT(MONTH FROM first_day_exposition ) AS first_month,
EXTRACT(MONTH FROM (first_day_exposition + days_exposition * INTERVAL '1 day')) AS last_month
FROM filters_date fd 
),
-- статистика по месяцу публикации объявления
info_first_month AS (
SELECT 
	first_month AS month,
	COUNT(*) AS amount_publication,
	ROUND(AVG(last_price / NULLIF(total_area,0))::numeric, 2) AS avg_sale_meter2,
    ROUND(AVG(total_area)::numeric, 2) AS avg_area
FROM last_first_month
GROUP BY first_month
),
info_last_month AS (
SELECT 
	last_month AS month,
	COUNT(*) AS amount_sale,
	ROUND(AVG(last_price / NULLIF(total_area,0))::numeric, 2) AS avg_sale_meter2,
    ROUND(AVG(total_area)::numeric, 2) AS avg_area
FROM last_first_month
WHERE last_month IS NOT NULL
GROUP BY last_month)
--объединяем полученные данные в одну таблицу
SELECT *
FROM info_first_month
JOIN info_last_month USING(month)
ORDER BY MONTH ;





