-- Data validation. Every check should return zero rows.
-- Run from the repo root:  psql -U postgres -d atliq_hospitality -f sql/05_checks.sql

\echo '1. Bookings referencing a property that does not exist'
SELECT b.booking_id, b.property_id
FROM fact_bookings b
LEFT JOIN dim_hotels h USING (property_id)
WHERE h.property_id IS NULL;

\echo '2. Realised revenue above generated revenue'
SELECT booking_id, revenue_generated, revenue_realized
FROM fact_bookings
WHERE revenue_realized > revenue_generated;

\echo '3. Occupancy above capacity'
SELECT property_id, check_in_date, room_category, successful_bookings, capacity
FROM fact_aggregated_bookings
WHERE successful_bookings > capacity;

\echo '4. Duplicate booking ids'
SELECT booking_id, COUNT(*)
FROM fact_bookings
GROUP BY booking_id
HAVING COUNT(*) > 1;

\echo '5. Stay dates that make no sense'
SELECT booking_id, booking_date, check_in_date, checkout_date
FROM fact_bookings
WHERE checkout_date <= check_in_date
   OR booking_date > check_in_date;

\echo '6. Stay dates with no matching row in dim_date'
SELECT DISTINCT b.check_in_date
FROM fact_bookings b
LEFT JOIN dim_date d ON d.date_actual = b.check_in_date
WHERE d.date_actual IS NULL;

\echo '7. Property city inconsistent with its id block (165xx Delhi, 175xx Mumbai, 185xx Hyderabad, 195xx Bangalore)'
SELECT property_id, property_name, city
FROM dim_hotels
WHERE city <> CASE LEFT(property_id::text, 3)
                   WHEN '165' THEN 'Delhi'
                   WHEN '175' THEN 'Mumbai'
                   WHEN '185' THEN 'Hyderabad'
                   WHEN '195' THEN 'Bangalore'
              END;

\echo '8. Partial weeks - these distort any week-over-week chart'
SELECT d.week_no, COUNT(DISTINCT d.date_actual) AS days_in_range
FROM dim_date d
GROUP BY d.week_no
HAVING COUNT(DISTINCT d.date_actual) < 7
ORDER BY d.week_no;

\echo 'Coverage summary (informational, not a failure)'
SELECT MIN(check_in_date)                                   AS first_stay,
       MAX(check_in_date)                                   AS last_stay,
       COUNT(DISTINCT check_in_date)                        AS distinct_days,
       COUNT(*)                                             AS bookings,
       COUNT(*) FILTER (WHERE ratings_given IS NULL)        AS bookings_without_rating,
       ROUND(100.0 * COUNT(*) FILTER (WHERE ratings_given IS NULL) / COUNT(*), 1)
                                                            AS pct_without_rating
FROM fact_bookings;
