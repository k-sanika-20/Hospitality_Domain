-- Analytical views: everything Power BI and the notebook read from
-- Run from the repo root:  psql -U postgres -d atliq_hospitality -f sql/04_views.sql

-- Daily KPIs per property: occupancy, ADR, RevPAR, realisation
CREATE OR REPLACE VIEW v_daily_property_kpi AS
WITH cap AS (
    SELECT property_id,
           check_in_date,
           SUM(capacity)            AS capacity,
           SUM(successful_bookings) AS successful_bookings
    FROM fact_aggregated_bookings
    GROUP BY 1, 2
),
rev AS (
    SELECT property_id,
           check_in_date,
           COUNT(*)                                                AS total_bookings,
           COUNT(*) FILTER (WHERE booking_status = 'Cancelled')    AS cancelled,
           COUNT(*) FILTER (WHERE booking_status = 'No Show')      AS no_show,
           SUM(revenue_generated)                                  AS revenue_generated,
           SUM(revenue_realized)                                   AS revenue_realized
    FROM fact_bookings
    GROUP BY 1, 2
)
SELECT c.check_in_date AS stay_date,
       h.property_id,
       h.property_name,
       h.category,
       h.city,
       c.capacity,
       c.successful_bookings,
       ROUND(c.successful_bookings::numeric / NULLIF(c.capacity, 0), 4)      AS occupancy_pct,
       r.total_bookings,
       r.cancelled,
       r.no_show,
       r.revenue_generated,
       r.revenue_realized,
       ROUND(r.revenue_realized::numeric / NULLIF(r.total_bookings, 0), 2)   AS adr,
       ROUND(r.revenue_realized::numeric / NULLIF(c.capacity, 0), 2)         AS revpar,
       ROUND(r.revenue_realized::numeric / NULLIF(r.revenue_generated, 0), 4) AS realisation_pct
FROM cap c
JOIN dim_hotels h USING (property_id)
LEFT JOIN rev r
       ON r.property_id = c.property_id
      AND r.check_in_date = c.check_in_date;


-- One row per property, ranked by RevPAR within its city
CREATE OR REPLACE VIEW v_property_summary AS
SELECT property_id,
       property_name,
       category,
       city,
       SUM(capacity)                                                              AS capacity,
       SUM(successful_bookings)                                                   AS successful_bookings,
       ROUND(SUM(successful_bookings)::numeric / NULLIF(SUM(capacity), 0), 4)     AS occupancy_pct,
       SUM(total_bookings)                                                        AS total_bookings,
       SUM(revenue_realized)                                                      AS revenue,
       ROUND(SUM(revenue_realized)::numeric / NULLIF(SUM(total_bookings), 0), 2)  AS adr,
       ROUND(SUM(revenue_realized)::numeric / NULLIF(SUM(capacity), 0), 2)        AS revpar,
       RANK() OVER (PARTITION BY city
                    ORDER BY SUM(revenue_realized)::numeric / NULLIF(SUM(capacity), 0) DESC)
                                                                                  AS revpar_rank_in_city
FROM v_daily_property_kpi
GROUP BY 1, 2, 3, 4;


-- RevPAR and occupancy by city and hotel category
CREATE OR REPLACE VIEW v_city_category_kpi AS
SELECT city,
       category,
       COUNT(DISTINCT property_id)                                               AS properties,
       ROUND(SUM(successful_bookings)::numeric / NULLIF(SUM(capacity), 0), 4)    AS occupancy_pct,
       SUM(revenue_realized)                                                     AS revenue,
       ROUND(SUM(revenue_realized)::numeric / NULLIF(SUM(total_bookings), 0), 2) AS adr,
       ROUND(SUM(revenue_realized)::numeric / NULLIF(SUM(capacity), 0), 2)       AS revpar
FROM v_daily_property_kpi
GROUP BY 1, 2;


-- Booking channel economics: volume, cancellation rate, revenue lost
CREATE OR REPLACE VIEW v_platform_performance AS
SELECT booking_platform,
       channel_type,
       COUNT(*)                                                                   AS bookings,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                         AS pct_of_bookings,
       COUNT(*) FILTER (WHERE booking_status = 'Cancelled')                       AS cancelled,
       COUNT(*) FILTER (WHERE booking_status = 'No Show')                         AS no_show,
       ROUND(100.0 * COUNT(*) FILTER (WHERE booking_status <> 'Checked Out')
             / COUNT(*), 2)                                                       AS lost_rate_pct,
       SUM(revenue_generated)                                                     AS revenue_generated,
       SUM(revenue_realized)                                                      AS revenue_realized,
       SUM(revenue_lost)                                                          AS revenue_lost,
       ROUND(AVG(revenue_realized), 2)                                            AS adr,
       ROUND(AVG(ratings_given), 2)                                               AS avg_rating
FROM fact_bookings
GROUP BY 1, 2;


-- Week-over-week revenue movement
CREATE OR REPLACE VIEW v_weekly_revenue AS
WITH weekly AS (
    SELECT d.week_no,
           MIN(b.check_in_date)   AS week_start,
           COUNT(*)               AS bookings,
           SUM(b.revenue_realized) AS revenue
    FROM fact_bookings b
    JOIN dim_date d ON d.date_actual = b.check_in_date
    GROUP BY 1
)
SELECT week_no,
       week_start,
       bookings,
       revenue,
       LAG(revenue) OVER (ORDER BY week_start)                                    AS prev_week_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY week_start))
             / NULLIF(LAG(revenue) OVER (ORDER BY week_start), 0), 2)             AS wow_change_pct,
       ROUND(AVG(revenue) OVER (ORDER BY week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 0)
                                                                                  AS revenue_4wk_avg
FROM weekly;


-- Room class mix
CREATE OR REPLACE VIEW v_room_class_performance AS
SELECT r.room_class,
       r.class_rank,
       COUNT(*)                                                                   AS bookings,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                         AS pct_of_bookings,
       SUM(b.revenue_realized)                                                    AS revenue,
       ROUND(AVG(b.revenue_realized), 2)                                          AS adr,
       ROUND(100.0 * COUNT(*) FILTER (WHERE b.booking_status <> 'Checked Out')
             / COUNT(*), 2)                                                       AS lost_rate_pct
FROM fact_bookings b
JOIN dim_rooms r ON r.room_id = b.room_category
GROUP BY 1, 2;


-- Does booking further ahead make cancellation more likely?
CREATE OR REPLACE VIEW v_cancellation_by_leadtime AS
SELECT CASE
           WHEN lead_time_days = 0      THEN '0 (same day)'
           WHEN lead_time_days <= 2     THEN '1-2 days'
           WHEN lead_time_days <= 7     THEN '3-7 days'
           WHEN lead_time_days <= 14    THEN '8-14 days'
           ELSE '15+ days'
       END                                                                        AS lead_time_bucket,
       MIN(lead_time_days)                                                        AS bucket_sort,
       COUNT(*)                                                                   AS bookings,
       ROUND(100.0 * COUNT(*) FILTER (WHERE booking_status = 'Cancelled')
             / COUNT(*), 2)                                                       AS cancellation_rate_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE booking_status = 'No Show')
             / COUNT(*), 2)                                                       AS no_show_rate_pct,
       SUM(revenue_lost)                                                          AS revenue_lost
FROM fact_bookings
GROUP BY 1;


-- Weekday vs weekend occupancy, split by hotel category
CREATE OR REPLACE VIEW v_daytype_occupancy AS
SELECT d.day_type,
       k.category,
       ROUND(SUM(k.successful_bookings)::numeric / NULLIF(SUM(k.capacity), 0), 4) AS occupancy_pct,
       ROUND(SUM(k.revenue_realized)::numeric / NULLIF(SUM(k.capacity), 0), 2)    AS revpar,
       ROUND(SUM(k.revenue_realized)::numeric / NULLIF(SUM(k.total_bookings), 0), 2) AS adr
FROM v_daily_property_kpi k
JOIN dim_date d ON d.date_actual = k.stay_date
GROUP BY 1, 2;
