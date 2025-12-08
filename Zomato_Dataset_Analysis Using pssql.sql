SELECT * FROM zomato_data LIMIT 10;

--1️⃣ Which are the top 5 most popular restaurants in each city based on total votes?
WITH pop AS (
    SELECT "Restaurant_Name", "City",
           SUM("Votes") AS total_votes,
           ROW_NUMBER() OVER (PARTITION BY "City" ORDER BY SUM("Votes") DESC) AS rn
    FROM zomato_data
    GROUP BY "Restaurant_Name", "City"
)
SELECT "Restaurant_Name", "City", total_votes
FROM pop
WHERE rn <= 5;
--2️⃣ Which cuisine delivers the highest revenue potential by comparing average price and average dining rating in each city?

SELECT 
    city,
    cuisine,
    ROUND(AVG(prices), 2) AS avg_price,
    ROUND(AVG(dining_rating), 2) AS avg_dining_rating,
    ROUND(AVG(prices) * AVG(dining_rating), 2) AS revenue_potential
FROM zomato_data
GROUP BY city, cuisine
ORDER BY revenue_potential DESC
LIMIT 15;


--3️⃣ Which items contribute the most to their restaurant’s popularity score (Restaurant_Popularity)?
WITH item_pop AS (
    SELECT
        restaurant_name,
        city,
        item_name,
        SUM(votes) AS item_votes,
        MAX(restaurant_popularity) AS restaurant_popularity
    FROM zomato_data
    GROUP BY restaurant_name, city, item_name
),
ranked AS (
    SELECT
        restaurant_name,
        city,
        item_name,
        item_votes,
        restaurant_popularity,
        ROUND(item_votes::numeric / NULLIF(restaurant_popularity,0), 3) AS contribution_share,
        RANK() OVER (PARTITION BY restaurant_name ORDER BY item_votes DESC) AS rnk
    FROM item_pop
)
SELECT *
FROM ranked
WHERE rnk <= 3               -- top 3 items per restaurant
ORDER BY restaurant_name, rnk;


--4️⃣ Which restaurants have significantly higher dining rating than the overall city dining rating?
WITH city_avg AS (
    SELECT
        city,
        AVG(dining_rating) AS city_dining_avg
    FROM zomato_data
    GROUP BY city
),
rest_avg AS (
    SELECT
        restaurant_name,
        city,
        AVG(dining_rating) AS rest_dining_avg
    FROM zomato_data
    GROUP BY restaurant_name, city
)
SELECT
    r.restaurant_name,
    r.city,
    r.rest_dining_avg,
    c.city_dining_avg,
    ROUND(r.rest_dining_avg - c.city_dining_avg, 2) AS rating_gap
FROM rest_avg r
JOIN city_avg c USING (city)
WHERE r.rest_dining_avg - c.city_dining_avg >= 0.5   -- “significantly higher” threshold
ORDER BY rating_gap DESC;


--5️⃣ Identify restaurants where delivery performance is falling behind dining performance (large rating gap).
WITH rest_stats AS (
    SELECT
        restaurant_name,
        city,
        AVG(dining_rating)  AS avg_dining_rating,
        AVG(delivery_rating) AS avg_delivery_rating
    FROM zomato_data
    GROUP BY restaurant_name, city
)
SELECT
    restaurant_name,
    city,
    avg_dining_rating,
    avg_delivery_rating,
    ROUND(avg_dining_rating - avg_delivery_rating, 2) AS rating_gap
FROM rest_stats
WHERE avg_dining_rating - avg_delivery_rating >= 0.5   -- big gap
  AND avg_dining_rating >= 3.5                         -- good dine-in
ORDER BY rating_gap DESC;


--6️⃣ Which cities pay the highest premium on food pricing compared to their cuisine average price?
WITH cuisine_avg AS (
    SELECT
        cuisine,
        AVG(prices) AS global_cuisine_avg_price
    FROM zomato_data
    GROUP BY cuisine
),
city_cuisine AS (
    SELECT
        city,
        cuisine,
        AVG(prices) AS city_cuisine_avg_price
    FROM zomato_data
    GROUP BY city, cuisine
)
SELECT
    cc.city,
    cc.cuisine,
    ROUND(cc.city_cuisine_avg_price, 2)      AS city_cuisine_avg_price,
    ROUND(ca.global_cuisine_avg_price, 2)    AS global_cuisine_avg_price,
    ROUND(cc.city_cuisine_avg_price - ca.global_cuisine_avg_price, 2) AS premium_amount
FROM city_cuisine cc
JOIN cuisine_avg ca USING (cuisine)
WHERE cc.city_cuisine_avg_price > ca.global_cuisine_avg_price
ORDER BY premium_amount DESC
LIMIT 20;


--7️⃣ Which cuisines consistently hold high ratings across multiple cities (with ranking)?
WITH city_cuisine_rating AS (
    SELECT
        city,
        cuisine,
        AVG(dining_rating) AS avg_dining_rating
    FROM zomato_data
    GROUP BY city, cuisine
),
ranked AS (
    SELECT
        city,
        cuisine,
        avg_dining_rating,
        DENSE_RANK() OVER (PARTITION BY city ORDER BY avg_dining_rating DESC) AS rnk
    FROM city_cuisine_rating
)
SELECT
    city,
    cuisine,
    ROUND(avg_dining_rating, 2) AS avg_dining_rating,
    rnk
FROM ranked
WHERE rnk <= 3                           -- top 3 cuisines in each city
ORDER BY city, rnk;

--8️⃣ Which restaurants offer premium-priced items but still receive poor ratings (weak value)?
WITH rest_value AS (
    SELECT
        restaurant_name,
        city,
        AVG(prices)         AS avg_price,
        AVG(dining_rating)  AS avg_dining_rating
    FROM zomato_data
    GROUP BY restaurant_name, city
),
city_price AS (
    SELECT
        city,
        AVG(prices) AS city_avg_price
    FROM zomato_data
    GROUP BY city
)
SELECT
    r.restaurant_name,
    r.city,
    ROUND(r.avg_price, 2)        AS avg_price,
    ROUND(c.city_avg_price, 2)   AS city_avg_price,
    ROUND(r.avg_dining_rating,2) AS avg_dining_rating
FROM rest_value r
JOIN city_price c USING (city)
WHERE r.avg_price > c.city_avg_price       -- premium priced
  AND r.avg_dining_rating < 3.2            -- weak rating threshold
ORDER BY r.avg_price DESC;


--9️⃣ Find restaurants that dominate in their cuisine category based on popularity within their city.
WITH city_cuisine_rest AS (
    SELECT
        city,
        cuisine,
        restaurant_name,
        SUM(votes) AS rest_votes
    FROM zomato_data
    GROUP BY city, cuisine, restaurant_name
),
with_share AS (
    SELECT
        city,
        cuisine,
        restaurant_name,
        rest_votes,
        ROUND(
          rest_votes::numeric /
          SUM(rest_votes) OVER (PARTITION BY city, cuisine),
          3
        ) AS popularity_share
    FROM city_cuisine_rest
)
SELECT
    city,
    cuisine,
    restaurant_name,
    rest_votes,
    popularity_share
FROM with_share
WHERE popularity_share >= 0.4          
ORDER BY popularity_share DESC;

--🔟 Which cities have the most highly-rated and expensive food items — indicating premium market zones?

SELECT
    city,
    COUNT(*) AS premium_item_count
FROM zomato_data
WHERE is_highly_rated = 1
  AND is_expensive    = 1
GROUP BY city
ORDER BY premium_item_count DESC;
