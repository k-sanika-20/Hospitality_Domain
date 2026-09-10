-- Type conversion, cleaning and keys
-- Run from the repo root:  psql -U postgres -d atliq_hospitality -f sql/03_transform.sql

-- 'weekeday' is misspelled in every weekday row of the source file
UPDATE dim_date SET day_type = 'weekday' WHERE day_type = 'weekeday';

-- '01-May-22' -> a real DATE
ALTER TABLE dim_date
    ALTER COLUMN date_actual TYPE DATE USING TO_DATE(date_actual, 'DD-Mon-YY');

ALTER TABLE fact_aggregated_bookings
    ALTER COLUMN check_in_date TYPE DATE USING TO_DATE(check_in_date, 'DD-Mon-YY');

ALTER TABLE dim_date
    ALTER COLUMN date_actual SET NOT NULL,
    ADD PRIMARY KEY (date_actual);

ALTER TABLE fact_aggregated_bookings
    ADD PRIMARY KEY (property_id, check_in_date, room_category);

-- room class sort order, so charts run Standard -> Presidential
ALTER TABLE dim_rooms ADD COLUMN class_rank SMALLINT;
UPDATE dim_rooms SET class_rank = CASE room_class
    WHEN 'Standard'     THEN 1
    WHEN 'Elite'        THEN 2
    WHEN 'Premium'      THEN 3
    WHEN 'Presidential' THEN 4
END;

-- booking channels grouped into direct / OTA / other
ALTER TABLE fact_bookings ADD COLUMN channel_type TEXT;
UPDATE fact_bookings SET channel_type = CASE
    WHEN booking_platform LIKE 'direct%' THEN 'Direct'
    WHEN booking_platform = 'others'     THEN 'Other'
    ELSE 'OTA'
END;

-- derived measures used throughout the analysis
ALTER TABLE fact_bookings ADD COLUMN lead_time_days  INTEGER;
ALTER TABLE fact_bookings ADD COLUMN length_of_stay  INTEGER;
ALTER TABLE fact_bookings ADD COLUMN revenue_lost    INTEGER;

UPDATE fact_bookings SET
    lead_time_days = check_in_date - booking_date,
    length_of_stay = checkout_date - check_in_date,
    revenue_lost   = revenue_generated - revenue_realized;

ALTER TABLE fact_bookings
    ADD CONSTRAINT fk_bookings_property FOREIGN KEY (property_id)   REFERENCES dim_hotels (property_id),
    ADD CONSTRAINT fk_bookings_room     FOREIGN KEY (room_category) REFERENCES dim_rooms  (room_id),
    ADD CONSTRAINT chk_revenue          CHECK (revenue_realized <= revenue_generated),
    ADD CONSTRAINT chk_stay             CHECK (checkout_date > check_in_date),
    ADD CONSTRAINT chk_lead             CHECK (booking_date <= check_in_date);

ALTER TABLE fact_aggregated_bookings
    ADD CONSTRAINT fk_agg_property FOREIGN KEY (property_id)   REFERENCES dim_hotels (property_id),
    ADD CONSTRAINT fk_agg_room     FOREIGN KEY (room_category) REFERENCES dim_rooms  (room_id),
    ADD CONSTRAINT chk_capacity    CHECK (successful_bookings <= capacity);

CREATE INDEX ix_bookings_checkin  ON fact_bookings (check_in_date);
CREATE INDEX ix_bookings_property ON fact_bookings (property_id, check_in_date);
CREATE INDEX ix_agg_checkin       ON fact_aggregated_bookings (check_in_date);
