# Hospitality_Domain
# Real-Time Revenue Insights Dashboard for Hospitality Analytics

This project involves the development of a comprehensive Power BI dashboard designed to provide real-time insights into revenue, occupancy, and other key performance metrics in the hospitality industry.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Data Model](#data-model)
- [DAX Formulas](#dax-formulas)


## Overview

The Real-Time Revenue Insights Dashboard helps stakeholders in the hospitality industry monitor and analyze crucial metrics such as revenue, occupancy rates, booking trends, and customer satisfaction. The dashboard is built using Power BI and leverages DAX (Data Analysis Expressions) for advanced data calculations and visualizations.

## Features

- **Revenue Tracking**: Summarizes total revenue, successful bookings, and calculates Average Daily Rate (ADR) and Revenue per Available Room (RevPAR).
- **Occupancy and Capacity Analysis**: Displays occupancy rates, total capacity, and successful booking percentages.
- **Performance Metrics**: Key Performance Indicators (KPIs) such as occupancy %, ADR, RevPAR, and realisation %.
- **Cancellation and No-Show Analysis**: Tracks and analyzes booking cancellations and no-show rates.
- **Booking Trends**: Visualizes booking distribution by platform and room class.
- **Week-over-Week Change Analysis**: Dynamic calculations for week-over-week changes in key metrics.
- **Customer Rating Insights**: Incorporates average customer ratings into the dashboard.
- **Flexible Date Range Metrics**: Calculates metrics over customizable date ranges for flexible reporting.

## Data Model

The data model includes the following tables:
- **fact_bookings**: Contains booking data including revenue, booking status, ratings, and booking platform.
- **dim_date**: Date dimension table to support date-based calculations.
- **fact_aggregated_bookings**: Aggregated booking data including total capacity and successful bookings.
- **dim_rooms**: Room dimension table with room class information.

## DAX Formulas

Key DAX formulas used in this project include:
- Revenue: `SUM(fact_bookings[revenue_realized])`
- Total Bookings: `COUNT(fact_bookings[booking_id])`
- Total Capacity: `SUM(fact_aggregated_bookings[capacity])`
- Occupancy %: `DIVIDE([Total Successful Bookings],[Total Capacity],0)`
- ADR: `DIVIDE([Revenue], [Total Bookings],0)`
- RevPAR: `DIVIDE([Revenue],[Total Capacity])`
- Week-over-Week Change %: 
  ```DAX
  Var selv = IF(HASONEFILTER(dim_date[wn]),SELECTEDVALUE(dim_date[wn]),MAX(dim_date[wn]))
  var revcw = CALCULATE([Revenue],dim_date[wn]= selv)
  var revpw =  CALCULATE([Revenue],FILTER(ALL(dim_date),dim_date[wn]= selv-1))
  return DIVIDE(revcw,revpw,0)-1
