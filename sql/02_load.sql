-- Load the source CSVs
-- Run from the repo root:  psql -U postgres -d atliq_hospitality -f sql/02_load.sql

\copy dim_hotels               FROM 'data/dim_hotels.csv'               WITH (FORMAT csv, HEADER true)
\copy dim_rooms                FROM 'data/dim_rooms.csv'                WITH (FORMAT csv, HEADER true)
\copy dim_date                 FROM 'data/dim_date.csv'                 WITH (FORMAT csv, HEADER true)
\copy fact_aggregated_bookings FROM 'data/fact_aggregated_bookings.csv' WITH (FORMAT csv, HEADER true)
\copy fact_bookings            FROM 'data/fact_bookings.csv'            WITH (FORMAT csv, HEADER true)

SELECT 'dim_hotels'               AS table_name, COUNT(*) AS rows FROM dim_hotels
UNION ALL SELECT 'dim_rooms',                    COUNT(*) FROM dim_rooms
UNION ALL SELECT 'dim_date',                     COUNT(*) FROM dim_date
UNION ALL SELECT 'fact_aggregated_bookings',     COUNT(*) FROM fact_aggregated_bookings
UNION ALL SELECT 'fact_bookings',                COUNT(*) FROM fact_bookings;
