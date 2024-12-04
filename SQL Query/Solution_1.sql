USE targets_db 
SHOW TABLES;

SELECT * 
FROM city_target_passenger_rating;

SELECT * 
FROM monthly_target_new_passengers;

SELECT * 
FROM monthly_target_trips;

USE trips_db 
SHOW TABLES;

SELECT * 
FROM dim_city;

SELECT * 
FROM dim_date;

SELECT * 
FROM dim_repeat_trip_distribution;

SELECT * 
FROM fact_passenger_summary;

SELECT * 
FROM fact_trips;


/*
Business Problem 1:- City Level fare and Trip Summery Report
*/
-- This query analyzes trip data at the city level.

USE trips_db 
SELECT
  dc.city_name,
  COUNT(ft.trip_id) AS total_trips,
  AVG(ft.distance_travelled_km) AS avg_distance_per_trip,
  AVG(ft.fare_amount) AS avg_fare_per_trip,
  (COUNT(ft.trip_id) / (SELECT COUNT(*) FROM fact_trips)) * 100 AS percentage_contribution_to_total_trips
FROM
  fact_trips AS ft
JOIN
  dim_city AS dc ON ft.city_id = dc.city_id
GROUP BY
  dc.city_name;

-- This SQL query aims to provide a comprehensive analysis of trip data at the city level. 
-- By calculating metrics like total trips, average distance, average fare, and percentage contribution, 
-- we can gain valuable insights into the performance of different cities.


/*
Business Problem 2:- Monthly city-level trips targets performance report 
*/
DESCRIBE targets_db.monthly_target_trips;

SELECT
  c.city_name,
  d.month_name,
  COUNT(f.trip_id) AS actual_trips,
  t.total_target_trips AS target_trips,
  CASE
    WHEN COUNT(f.trip_id) > t.total_target_trips THEN 'Above Target'
    ELSE 'Below Target'
  END AS performance_status,
  ROUND(((COUNT(f.trip_id) - t.total_target_trips) / t.total_target_trips) * 100, 2) AS percentage_difference
FROM trips_db.fact_trips f
LEFT JOIN trips_db.dim_city c ON f.city_id = c.city_id
LEFT JOIN trips_db.dim_date d ON DATE(f.date) = d.date  -- Match date to date
LEFT JOIN targets_db.monthly_target_trips t 
  ON f.city_id = t.city_id 
  AND MONTH(f.date) = MONTH(t.month)  -- Match month part of the date
GROUP BY 
  c.city_name, 
  d.month_name, 
  t.total_target_trips;
  
  
  
/*
Business Problem 3:- City Level Repeat passenger trip frequency report 
*/

WITH RepeatPassengerCounts AS (
  SELECT
    c.city_name,
    rtd.city_id,
    SUM(CASE WHEN rtd.trip_count = 2 THEN rtd.repeat_passenger_count ELSE 0 END) AS two_trips,
    SUM(CASE WHEN rtd.trip_count = 3 THEN rtd.repeat_passenger_count ELSE 0 END) AS three_trips,
    SUM(CASE WHEN rtd.trip_count = 4 THEN rtd.repeat_passenger_count ELSE 0 END) AS four_trips,
    SUM(CASE WHEN rtd.trip_count = 5 THEN rtd.repeat_passenger_count ELSE 0 END) AS five_trips,
    SUM(CASE WHEN rtd.trip_count = 6 THEN rtd.repeat_passenger_count ELSE 0 END) AS six_trips,
    SUM(CASE WHEN rtd.trip_count = 7 THEN rtd.repeat_passenger_count ELSE 0 END) AS seven_trips,
    SUM(CASE WHEN rtd.trip_count = 8 THEN rtd.repeat_passenger_count ELSE 0 END) AS eight_trips,
    SUM(CASE WHEN rtd.trip_count = 9 THEN rtd.repeat_passenger_count ELSE 0 END) AS nine_trips,
    SUM(CASE WHEN rtd.trip_count = 10 THEN rtd.repeat_passenger_count ELSE 0 END) AS ten_trips,
    SUM(rtd.repeat_passenger_count) AS total_repeat_passengers
  FROM
    dim_repeat_trip_distribution rtd
  LEFT JOIN
    dim_city c ON rtd.city_id = c.city_id
  GROUP BY
    c.city_name, rtd.city_id
)
SELECT
  city_name,
  (two_trips / total_repeat_passengers) * 100 AS "2-Trips",
  (three_trips / total_repeat_passengers) * 100 AS "3-Trips",
  (four_trips / total_repeat_passengers) * 100 AS "4-Trips",
  (five_trips / total_repeat_passengers) * 100 AS "5-Trips",
  (six_trips / total_repeat_passengers) * 100 AS "6-Trips",
  (seven_trips / total_repeat_passengers) * 100 AS "7-Trips",
  (eight_trips / total_repeat_passengers) * 100 AS "8-Trips",
  (nine_trips / total_repeat_passengers) * 100 AS "9-Trips",
  (ten_trips / total_repeat_passengers) * 100 AS "10-Trips"
FROM
  RepeatPassengerCounts;



/*
Business Problem 4:- Identify cities with highest and lowest total new passengers
*/

WITH RankedCities AS (
  SELECT
    c.city_name,
    fps.new_passengers,
    ROW_NUMBER() OVER (ORDER BY fps.new_passengers DESC) AS rank_desc,
    ROW_NUMBER() OVER (ORDER BY fps.new_passengers ASC) AS rank_asc
  FROM
    fact_passenger_summary fps
  LEFT JOIN
    dim_city c ON fps.city_id = c.city_id
),
CategorizedCities AS (
  SELECT
    city_name,
    new_passengers,
    CASE
      WHEN rank_desc <= 3 THEN 'Top 3'
      WHEN rank_asc <= 3 THEN 'Bottom 3'
      ELSE NULL
    END AS city_category
  FROM
    RankedCities
  WHERE
    rank_desc <= 3 OR rank_asc <= 3
)
SELECT
  city_name,
  new_passengers,
  city_category
FROM
  CategorizedCities
ORDER BY
  city_category, new_passengers DESC;



/*
Business Problem 5:- Identify month with highest revenue for each city
*/

 WITH CityMonthlyRevenue AS (
    SELECT 
        c.city_name, 
        MONTH(fps.date) AS month,  -- Extracting the month from the date field
        SUM(fps.fare_amount) AS total_revenue,  -- Calculating total revenue based on fare_amount
        SUM(SUM(fps.fare_amount)) OVER (PARTITION BY c.city_name) AS city_total_revenue  -- Total revenue for each city
    FROM 
        fact_trips fps
    LEFT JOIN 
        dim_city c ON fps.city_id = c.city_id
    GROUP BY 
        c.city_name, MONTH(fps.date)
), HighestRevenueMonth AS (
    SELECT 
        city_name, 
        month AS highest_revenue_month, 
        total_revenue AS revenue, 
        city_total_revenue, 
        ROW_NUMBER() OVER (PARTITION BY city_name ORDER BY total_revenue DESC) AS row_num
    FROM 
        CityMonthlyRevenue
)
SELECT 
    city_name, 
    highest_revenue_month, 
    revenue, 
    ROUND((revenue / city_total_revenue) * 100, 2) AS "percentage_contribution (%)"
FROM 
    HighestRevenueMonth 
WHERE 
    row_num = 1
ORDER BY 
    city_name;


/*
Business Problem 6:- Repeat passenger rate analysis 
*/

WITH CityMonthlyRepeatRate AS (
    SELECT 
        c.city_name,
        fps.month,  -- Extracting the month from the fact_passenger_summary table
        SUM(fps.total_passengers) AS total_passengers,  -- Total passengers for each city and month
        SUM(fps.repeat_passengers) AS repeat_passengers  -- Repeat passengers for each city and month
    FROM 
        fact_passenger_summary fps  -- Use the fact_passenger_summary table
    LEFT JOIN 
        dim_city c ON fps.city_id = c.city_id  -- Joining with the city dimension table
    GROUP BY 
        c.city_name, fps.month  -- Group by city name and month
), CityWideRepeatRate AS (
    SELECT 
        c.city_name,
        SUM(fps.repeat_passengers) AS total_repeat_passengers,  -- Total repeat passengers for the city across all months
        SUM(fps.total_passengers) AS total_passengers_all_months  -- Total passengers for the city across all months
    FROM 
        fact_passenger_summary fps
    LEFT JOIN 
        dim_city c ON fps.city_id = c.city_id
    GROUP BY 
        c.city_name  -- Group by city name for city-wide metrics
)
SELECT 
    cm.city_name,
    cm.month,
    cm.total_passengers,
    cm.repeat_passengers,
    ROUND((cm.repeat_passengers / cm.total_passengers) * 100, 2) AS monthly_repeat_passenger_rate,
    ROUND((cwr.total_repeat_passengers / cwr.total_passengers_all_months) * 100, 2) AS city_repeat_passenger_rate
FROM 
    CityMonthlyRepeatRate cm
JOIN 
    CityWideRepeatRate cwr ON cm.city_name = cwr.city_name
ORDER BY 
    cm.city_name, cm.month;

