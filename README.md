# Hotel Revenue Performance Analysis & Dashboarding

An end-to-end analysis of 134,590 hotel bookings across a 25-property chain, built as a
three-layer workflow: **PostgreSQL** for extraction and transformation, **Python** for
cleaning and exploratory analysis, **Power BI** for the reporting layer.

```mermaid
flowchart LR
    A[5 source CSVs] --> B[(PostgreSQL)]
    B --> C[Transformation<br/>type casting, derived columns]
    C --> D[8 analytical views]
    D --> E[Python EDA<br/>pandas · seaborn]
    D --> F[Power BI dashboard]
    C --> G[8 validation checks]
```

---

## Data

AtliQ Hotels, a fictional Indian hotel chain, from the Codebasics resume-project dataset.
Five files covering **1 May – 31 July 2022**.

| Table | Rows | Grain |
|---|---:|---|
| `fact_bookings` | 134,590 | One row per booking |
| `fact_aggregated_bookings` | 9,200 | Property × date × room category |
| `dim_hotels` | 25 | Property (4 cities, 2 categories) |
| `dim_rooms` | 4 | Room class |
| `dim_date` | 92 | Calendar day |

Booking outcomes split 70.1% Checked Out, 24.8% Cancelled, 5.0% No Show. Overall revenue
realisation is 85.1% — cancelled bookings realise exactly 40% of generated revenue under a
fixed refund rule.

---

## Dashboard

Four pages, built on the eight SQL views rather than the raw tables — occupancy, ADR, RevPAR
and realisation are computed once in the database and consumed as governed queries.

| Executive | Property performance |
|---|---|
| ![Executive](docs/figures/Executive.png) | ![Property performance](docs/figures/dashboard_property.png) |

| Channel & cancellation | Demand & mix |
|---|---|
| ![Channel and cancellation](docs/figures/Channels and Cancellations.png) | ![Demand and mix](docs/figures/dashboard_demand.png) |

Three decisions worth noting:

**Ratio metrics are re-aggregated, not averaged.** Occupancy, ADR, RevPAR and realisation are
DAX measures that re-divide the totals (`DIVIDE([Rooms Sold], [Total Capacity])`) rather than
averaging the per-row percentages the views already contain. Averaging 2,300 daily occupancy
figures gives the average of a ratio, not the chain's occupancy.

**Drillthrough keys on `property_id`, not `property_name`.** Five property names repeat across
cities, so the name alone cannot identify a property. The property table carries `property_id`
and the drillthrough filter uses it.

**Cancellation-rate axes are pinned to 0–40%.** Auto-scaling would zoom into the 29.4–30.2%
band and turn a 0.8-point spread across fifteen segments into what looks like a strong pattern.
See finding 3.

---

## Findings

### 1. Weekend demand is the dominant pattern

Occupancy runs 51–52% on weekdays against 73–74% at weekends, and RevPAR moves from roughly
₹6,500 to ₹9,400. The gap is near-identical for Business and Luxury properties, which is
unusual — business hotels normally fill mid-week. Demand appears leisure-driven across both
categories, making weekday capacity the clearest revenue opportunity in the data.

![Occupancy by day type](docs/figures/occupancy_by_daytype.png)

### 2. The city gap is a pricing gap, not a demand gap

| City | Occupancy | ADR | RevPAR |
|---|---:|---:|---:|
| Mumbai | 57.9% | ₹15,387 | ₹8,907 |
| Delhi | 60.5% | ₹12,154 | ₹7,359 |
| Bangalore | 55.8% | ₹13,131 | ₹7,323 |
| Hyderabad | 58.1% | ₹9,322 | ₹5,414 |

Occupancy sits in a narrow 56–61% band, so every market fills rooms at a similar rate. ADR
does not. RevPAR therefore tracks rate almost exactly. Delhi is the clearest case: it has the
**highest occupancy of the four and still ranks second on RevPAR**, because its rooms are
priced ₹3,200 below Mumbai's. The busiest market is not the most profitable one.

![RevPAR by city](docs/figures/revpar_by_city.png)

### 3. Cancellation behaviour carries no signal

Across fifteen segments — four lead-time buckets, seven booking platforms, four room classes —
the share of bookings that never checked out stays between **29.4% and 30.2%**, against an
overall rate of 29.9%. No channel is riskier, no room class is riskier, and booking further
ahead does not raise cancellation risk.

Combined with `lead_time_days` taking only eleven distinct values, this indicates cancellations
were assigned independently of booking attributes when the dataset was generated. The practical
consequence is that cancellation cannot be predicted or targeted from this data; the 29.9% loss
behaves as a fixed rate, and revenue-protection effort belongs in pricing rather than channel or
lead-time policy.

![Cancellation flatness](docs/figures/cancellation_flatness.png)

### 4. Revenue concentrates above the volume line

| Room class | Share of bookings | Share of revenue | ADR |
|---|---:|---:|---:|
| Standard | 28.6% | 18.1% | ₹8,052 |
| Elite | 36.8% | 32.8% | ₹11,317 |
| Premium | 22.7% | 27.0% | ₹15,120 |
| Presidential | 11.9% | 22.0% | ₹23,440 |

Premium is the first class where revenue share exceeds booking share. Presidential is the
sharpest case — 11.9% of bookings produce 22.0% of revenue. Because cancellation rates are
identical across classes, the upper two classes are strictly more valuable per room sold, which
argues for upgrade and upsell effort over discounting to fill Standard inventory.

![Room class ladder](docs/figures/room_class_ladder.png)

### 5. Missing ratings are structural — and hide a trap

No cancelled or no-show booking carries a rating, because those guests never stayed. The 57.9%
missing rate is 40% who *could not* rate plus 40% of checked-out guests who chose not to. Among
guests who stayed, response is 60% and uniform across every platform (42.0–42.8%) and room class
(41.7–42.8%), so there is no segment bias in who responds.

**The trap:** bookings with a rating show mean realised revenue of ₹14,927 against ₹11,073 for
those without — which looks like "guests who rate spend more." They do not. Cancelled bookings
realise only 40% of generated revenue and can never carry a rating, so the entire ₹3,854 gap is
the refund policy, not guest behaviour. The correct denominator for average rating is the 94,411
checked-out bookings, giving 3.62 — reported as the rating from guests who stayed, not from all
bookings.

![Rating coverage](docs/figures/rating_coverage.png)

---

## Data quality

All five files load with no orphan foreign keys, no duplicate booking IDs, and no impossible
stay dates — verified by `sql/05_checks.sql`, which runs eight checks that each return zero rows
when healthy. Three genuine problems surfaced:

| Issue | Detail | Handling |
|---|---|---|
| Misspelled day type | `weekeday` in all 65 weekday rows of `dim_date` | Corrected in `03_transform.sql` |
| Mislabelled property | Property IDs follow city blocks (165xx Delhi, 175xx Mumbai, 185xx Hyderabad, 195xx Bangalore). Property 16559 is labelled Mumbai but sits in the Delhi block, producing two "Atliq Exotica" entries in Mumbai | Flagged, not silently changed — documented as a suspected source error |
| Partial week | Data ends 31 July, so week 32 contains a single day | Excluded from week-over-week visuals; unfiltered it shows a spurious 82% drop |

---

## Repository

```
├── data/                       5 source CSVs
├── sql/
│   ├── 01_create_tables.sql    Schema
│   ├── 02_load.sql             \copy loads + row-count verification
│   ├── 03_transform.sql        Type casting, cleaning, derived columns, constraints, indexes
│   ├── 04_views.sql            8 analytical views
│   └── 05_checks.sql           8 validation checks
├── notebooks/
│   └── cleaning_and_eda.ipynb  Cleaning pass and five analyses
├── docs/figures/               Charts from the notebook, dashboard screenshots
├── dashboard/                  Power BI file
└── requirements.txt
```

### Transformation layer

`03_transform.sql` converts `DD-Mon-YY` text dates to `DATE`, corrects the `weekeday` typo,
and derives `lead_time_days`, `length_of_stay`, `revenue_lost`, a `class_rank` ordering for room
classes, and a `channel_type` grouping (Direct / OTA / Other) over the seven raw platforms. It
then applies foreign keys, CHECK constraints (`revenue_realized <= revenue_generated`,
`checkout_date > check_in_date`, `booking_date <= check_in_date`,
`successful_bookings <= capacity`) and indexes on the date and property columns.

### Analytical views

`v_daily_property_kpi`, `v_property_summary`, `v_city_category_kpi`, `v_platform_performance`,
`v_weekly_revenue`, `v_room_class_performance`, `v_cancellation_by_leadtime`,
`v_daytype_occupancy`.

`v_property_summary` ranks each property by RevPAR within its city using
`RANK() OVER (PARTITION BY city ...)`, and `v_weekly_revenue` computes week-over-week movement
with `LAG()` plus a four-week rolling average.

---

## Running it

The database runs on a serverless PostgreSQL instance, so no local server is required.

```bash
# 1. Point at your database
echo 'DATABASE_URL=postgresql://user:pass@host/dbname?sslmode=require' > .env

# 2. Build it, from the repo root
psql $DATABASE_URL -f sql/01_create_tables.sql
psql $DATABASE_URL -f sql/02_load.sql      # expect 25 / 4 / 92 / 9,200 / 134,590
psql $DATABASE_URL -f sql/03_transform.sql
psql $DATABASE_URL -f sql/04_views.sql
psql $DATABASE_URL -f sql/05_checks.sql    # checks 7 and 8 return the known data issues

# 3. Analysis
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
jupyter lab notebooks/cleaning_and_eda.ipynb
```

The notebook configures SQLAlchemy with `pool_pre_ping` and `pool_recycle=300` so it survives
the serverless database suspending itself between queries.

Power BI connects via **Get Data → PostgreSQL**, Import mode, importing the `v_` views with
encryption enabled.

Chart colours (`#1f6fd0`, `#c06a00`) are checked for colour-blind separation and carry data
labels throughout, so every figure stays readable in greyscale and for red-green colour
deficiency.

---

## Limitations

- **92 days of data.** Sufficient for descriptive analysis, which is what this project claims.
  Not sufficient for forecasting — thirteen weeks cannot support a seasonality model.
- **Cancellations are synthetic.** As shown in finding 3, they carry no relationship to booking
  attributes, so no predictive model of cancellation is justified on this data.
- **Public dataset.** From the Codebasics resume-project series. The dashboard is a common
  exercise; the SQL warehouse, validation suite and analysis here are original work.
