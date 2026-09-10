-- Hospitality revenue analysis: table definitions
-- Run from the repo root:  psql -U postgres -d atliq_hospitality -f sql/01_create_tables.sql

DROP TABLE IF EXISTS fact_bookings CASCADE;
DROP TABLE IF EXISTS fact_aggregated_bookings CASCADE;
DROP TABLE IF EXISTS dim_hotels CASCADE;
DROP TABLE IF EXISTS dim_rooms CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;


CREATE TABLE dim_hotels (
    property_id   INTEGER PRIMARY KEY,
    property_name TEXT    NOT NULL,
    category      TEXT    NOT NULL,
    city          TEXT    NOT NULL
);


CREATE TABLE dim_rooms (
    room_id    TEXT PRIMARY KEY,
    room_class TEXT NOT NULL
);


-- date columns arrive as '01-May-22'; loaded as text, converted in 03_transform.sql
CREATE TABLE dim_date (
    date_actual TEXT,
    mmm_yy      TEXT,
    week_no     TEXT,
    day_type    TEXT
);


CREATE TABLE fact_aggregated_bookings (
    property_id         INTEGER NOT NULL,
    check_in_date       TEXT    NOT NULL,
    room_category       TEXT    NOT NULL,
    successful_bookings INTEGER NOT NULL,
    capacity            INTEGER NOT NULL
);


CREATE TABLE fact_bookings (
    booking_id        TEXT    PRIMARY KEY,
    property_id       INTEGER NOT NULL,
    booking_date      DATE    NOT NULL,
    check_in_date     DATE    NOT NULL,
    checkout_date     DATE    NOT NULL,
    no_guests         INTEGER NOT NULL,
    room_category     TEXT    NOT NULL,
    booking_platform  TEXT    NOT NULL,
    ratings_given     NUMERIC,
    booking_status    TEXT    NOT NULL,
    revenue_generated INTEGER NOT NULL,
    revenue_realized  INTEGER NOT NULL
);
