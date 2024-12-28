use db;
/* Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each 
 city's trips to the overall trips. This report will help in assessing trip volume, pricing efficiency, 
 and each city's contribution to the overall trip count. */

SELECT 
    c.city_name, 
    SUM(ft.fare_amount) / SUM(ft.distance_travelled_km) AS avg_fare_perkm,
    SUM(ft.fare_amount) / COUNT(*) AS avg_fare_pertrip,
    COUNT(*) AS total_trips,
    (COUNT(*) * 100.0) / (SELECT COUNT(*) FROM fact_trips) AS percent_contribution 
FROM 
    fact_trips ft
INNER JOIN 
    dim_city c 
ON 
    c.city_id = ft.city_id
GROUP BY 
    c.city_name
ORDER BY 
    percent_contribution DESC;

/* 2: Monthly City-Level Trips Target Performance Report
Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, compare the 
actual total trips with the target trips and categorise the performance as follows:
If actual trips are greater than target trips, mark it as "Above Target".
If actual trips are less than or equal to target trips, mark it as "Below Target".
Additionally, calculate the % difference between actual and target trips to quantify the performance gap.
Fields:
 	City_name   month name   actual_trips   target_trips   performance_status   % difference

*/
WITH target_trips AS (
    SELECT 
        c.city_name AS city,
        MONTHNAME(mt.month) AS month,
        SUM(mt.total_target_trips) AS targettrip
    FROM 
        dim_city c
    INNER JOIN
        monthly_target_trips mt
    ON 
        mt.city_id = c.city_id
    GROUP BY 
        city, month
),

actual_trips AS (
    SELECT 
        c.city_name AS city,
        MONTHNAME(ft.date) AS month,
        COUNT(ft.trip_id) AS Actualtrip
    FROM 
        dim_city c
    INNER JOIN 
        fact_trips ft
    ON 
        c.city_id = ft.city_id
    GROUP BY 
        city, month
)

SELECT 
    at.city,
    at.month,
    at.Actualtrip,
    tt.targettrip,
    CASE 
        WHEN at.Actualtrip > tt.targettrip THEN 'Above Target'
        WHEN at.Actualtrip < tt.targettrip THEN 'Below Target'
        ELSE 'On Target'
    END AS Status,
    round(((at.Actualtrip - tt.targettrip) / tt.targettrip) * 100,2) AS `%_Difference`
FROM 
    actual_trips at
LEFT JOIN 
    target_trips tt
ON 
    at.city = tt.city
AND 
    at.month = tt.month
ORDER BY 
    STR_TO_DATE(at.month, '%M');

 
/* 3: City-Level Repeat Passenger Trip Frequency Report
Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.
Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the total repeat passengers for that city.
This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or frequent usage patterns.
• Fields: city_name, 2-Trips, 3-Trips, 4-Trips, 5-Trips, 6-Trips, 7-Trips, 8-Trips, 9-Trips, 10-Trips
*/
 
SELECT 
    city_name,
    ROUND(`10-Trips` * 100.0 / total_passenger_count, 2) AS `10-Trips`,
    ROUND(`9-Trips` * 100.0 / total_passenger_count, 2) AS `9-Trips`,
    ROUND(`8-Trips` * 100.0 / total_passenger_count, 2) AS `8-Trips`,
    ROUND(`7-Trips` * 100.0 / total_passenger_count, 2) AS `7-Trips`,
    ROUND(`6-Trips` * 100.0 / total_passenger_count, 2) AS `6-Trips`,
    ROUND(`5-Trips` * 100.0 / total_passenger_count, 2) AS `5-Trips`,
    ROUND(`4-Trips` * 100.0 / total_passenger_count, 2) AS `4-Trips`,
    ROUND(`3-Trips` * 100.0 / total_passenger_count, 2) AS `3-Trips`,
    ROUND(`2-Trips` * 100.0 / total_passenger_count, 2) AS `2-Trips`
FROM (
    SELECT 
        c.city_name,
        SUM(CASE WHEN r.trip_count = '10-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `10-Trips`,
        SUM(CASE WHEN r.trip_count = '9-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `9-Trips`,
        SUM(CASE WHEN r.trip_count = '8-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `8-Trips`,
        SUM(CASE WHEN r.trip_count = '7-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `7-Trips`,
        SUM(CASE WHEN r.trip_count = '6-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `6-Trips`,
        SUM(CASE WHEN r.trip_count = '5-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `5-Trips`,
        SUM(CASE WHEN r.trip_count = '4-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `4-Trips`,
        SUM(CASE WHEN r.trip_count = '3-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `3-Trips`,
        SUM(CASE WHEN r.trip_count = '2-Trips' THEN r.repeat_passenger_count ELSE 0 END) AS `2-Trips`,
        SUM(r.repeat_passenger_count) AS total_passenger_count
    FROM 
        dim_city c
    INNER JOIN 
        dim_repeat_trip_distribution r
    ON 
        c.city_id = r.city_id
    GROUP BY 
        c.city_name
) AS sub;

/*- 4: Identify Cities with Highest and Lowest Total New Passengers
Generate a report that calculates the total new passengers for each city and ranks them based on this value. 
Identify the top 3 cities with the highest number of new passengers as well as the bottom 3 cities with the lowest 
number of new passengers, categorising them as "Top 3" or "Bottom 3" accordingly.
Fields
 	city_name
 	total new_passengers
 	city_category ("Top 3" or "Bottom 3")

*/
WITH RankedCities AS 
(SELECT c.city_name,SUM(n.new_passengers) AS total_new_passengers,
RANK() OVER (ORDER BY SUM(n.new_passengers) DESC) AS rank_desc,
RANK() OVER (ORDER BY SUM(n.new_passengers)) AS rank_asc
FROM fact_passenger_summary n
JOIN dim_city c 
ON c.city_id = n.city_id
GROUP BY  c.city_name)
SELECT city_name, total_new_passengers,
    CASE 
        WHEN rank_desc <= 3 THEN 'Top 3'
        WHEN rank_asc <= 3 THEN 'Bottom 3'
        ELSE 'Other' END AS city_category
FROM RankedCities order by total_new_passengers desc ;
    

/* - 5: Identify Month with Highest Revenue for Each City
Generate a report that identifies the month with the highest revenue for each city. For each city, display the month_name, 
the revenue amount for that month, and the percentage contribution of that month's revenue to the city's total revenue.
Fields
 	city_name   highest_revenue month   revenue   percentage_contribution (%)
*/

WITH city_monthly_revenue AS 
(SELECT c.city_name AS city, MONTHNAME(ft.date) AS Month, SUM(ft.fare_amount) AS revenue
FROM dim_city c
JOIN fact_trips ft 
ON c.city_id = ft.city_id
GROUP BY c.city_name, MONTH(ft.date), MONTHNAME(ft.date)),

city_total_revenue AS 
(SELECT city, SUM(revenue) AS total_revenue 
FROM city_monthly_revenue
GROUP BY city),

Maxrevenue AS 
(SELECT city,
MAX(revenue) AS max_revenue
FROM city_monthly_revenue
GROUP BY city)

SELECT cmr.city, cmr.Month, cmr.revenue AS highest_revenue,
ROUND((cmr.revenue / ctr.total_revenue) * 100, 2) AS percentage_contribution
FROM city_monthly_revenue cmr
JOIN Maxrevenue mr 
ON cmr.city = mr.city 
AND cmr.revenue = mr.max_revenue
JOIN city_total_revenue ctr 
ON cmr.city = ctr.city order by highest_revenue desc;
    

/*- 6: Repeat Passenger Rate Analysis
Generate a report that calculates two metrics:
1.	Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers
to the total passengers.
2.	City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.
These metrics will provide insights into monthly repeat trends as well as the overall repeat behaviour for each city.
Fields:
  city_name   month   total_passengers   repeat_passengers   monthly_repeat_passenger_rate (%): Repeat passenger rate at the city and month level   city_repeat_passenger_rate (%): Overall repeat passenger rate for each city, aggregated across months
*/
WITH MonthlyData AS
    (SELECT 
        c.city_name,
        MONTHNAME(fp.month) AS Month,
        SUM(fp.total_passengers) AS total_passengers,
        SUM(fp.repeat_passengers) AS repeat_passengers,
        ROUND((SUM(fp.repeat_passengers) / SUM(fp.total_passengers)) * 100, 2) AS monthly_repeat_rate
FROM dim_city c
INNER JOIN fact_passenger_summary fp 
ON c.city_id = fp.city_id
GROUP BY c.city_name, MONTH(fp.month), MONTHNAME(fp.month)),

CityWideData AS
(SELECT 
        city_name,
        SUM(total_passengers) AS city_total_passengers,
        SUM(repeat_passengers) AS city_repeat_passengers,
        ROUND((SUM(repeat_passengers) / SUM(total_passengers)) * 100, 2) AS city_repeat_passenger_rate
FROM MonthlyData
GROUP BY city_name)

SELECT 
    m.city_name,
    m.Month,
    m.total_passengers,
    m.repeat_passengers,
    m.monthly_repeat_rate,
    c.city_repeat_passenger_rate
FROM MonthlyData m
JOIN CityWideData c
ON m.city_name = c.city_name;