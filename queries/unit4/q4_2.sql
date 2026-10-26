-- ############################################################
-- Task 4.2 Build the breakdown leadership asked for
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- Failure is still a renter no-show (no_show_reason = <Renter no show>).
--    Avgs of duration_min only count held viewings (not <cancelled>) like
--    4.1a decided, region is properties.city like 4.1d.
-- ############################################################


-- ============================================================
-- Part A. Two numbers in one pass
--     For each producer, compute the total number of events and the total
--     number of events classified as failures, in a single pass over the
--     event table, without a WHERE clause filtering the whole query. The
--     outliers here are the producers you will name in your finding.
-- ============================================================

-- ------------------------------------------------------------
-- 4.2a  For each property how many viewings did it get and how many of
--    those were renter no-shows? Both counts come out of one pass over
--    viewings with no WHERE. The CASE turns each row into a 1 or a 0 and
--    SUM adds them up, NULL reasons fall to ELSE 0 so they count as not a
--    no-show. Most no-shows first then highest rate. Uses SUM(CASE) COUNT
--    GROUP BY and ORDER BY.
-- ------------------------------------------------------------
SELECT property_id,
       COUNT(*) AS viewings,
       SUM(CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END) AS no_shows,
       ROUND(100.0 * SUM(CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS no_show_pct
FROM   viewings
GROUP BY property_id
ORDER BY no_shows DESC, no_show_pct DESC, property_id;
-- Result: 13 rows. Properties 2 (3 of 16, 18.8%) and 3 (2 of 13, 15.4%)
--    are the outliers. They're the only ones with more than 1 no-show and
--    together they have 5 of the 12. 4 shows 16.7% but thats 1 of 6 and
--    its under the 10 viewing threshold from 4.1c so I'm not calling it an
--    outlier. 1, 9, 11, 12, 7 and 6 have 1 each and 5, 8, 10 and 13 have
--    none. Viewings add up to 200 and no-shows to 12 so no rows got lost
--    the way the Unit 3 WHERE lost them.


-- ============================================================
-- Part B. Subtotals and a grand total
--     The regional director wants subtotals per region and a platform
--     grand total, not the detail rows. Write a query that produces
--     regional subtotals and a platform-wide grand total without including
--     the individual detail rows.
-- ============================================================

-- ------------------------------------------------------------
-- 4.2b  What's the no-show rate and held avg for each city and for the
--    whole platform? Only the city level and the grand total come back,
--    no per property rows. GROUPING SETS lists exactly those two levels,
--    (p.city) is the region subtotals and () is the grand total. ROLLUP
--    (p.city, v.property_id) would've added a row per property which is
--    the detail the director doesn't want. GROUPING(p.city) is 1 on the
--    grand total row so the CASE labels it and the ORDER BY puts it last.
--    Uses GROUP BY GROUPING SETS GROUPING CASE COUNT and AVG with FILTER.
-- ------------------------------------------------------------
SELECT CASE WHEN GROUPING(p.city) = 1 THEN 'Platform total' ELSE p.city END AS region,
       COUNT(DISTINCT v.property_id) AS properties,
       COUNT(*) AS viewings,
       COUNT(*) FILTER (WHERE v.no_show_reason = 'Renter no show') AS no_shows,
       ROUND(100.0 * COUNT(*) FILTER (WHERE v.no_show_reason = 'Renter no show')
             / COUNT(*), 1) AS no_show_pct,
       ROUND(AVG(v.duration_min) FILTER (WHERE v.viewing_status <> 'cancelled'), 2) AS avg_min_held
FROM   viewings v
JOIN   properties p ON p.property_id = v.property_id
GROUP BY GROUPING SETS ((p.city), ())
ORDER BY GROUPING(p.city), p.city;
-- Result: 6 rows. The first 5 (Danang, Haiphong, Hanoi, Hue and Saigon) are
--    the region subtotals and the last row <Platform total> is the grand
--    total. Danang is the worst at 18.8% (3 of 16) but its only one
--    property so thats really just property 2. Haiphong is next at 8.0%
--    (4 of 50) then Hue 5.6% then Saigon 3.2% and Hanoi 2.8%. Saigon has the
--    longest held avg at 24.80. Grand total is 13 properties, 200 viewings,
--    12 no-shows, 6.0% and 21.86 held avg which matches 4.1a so the
--    subtotals add up to the platform. 13 not 15 properties bc 14 and 15
--    have no viewings.


-- ============================================================
-- Part C. A two-step pipeline
--     Leadership wants to establish a baseline for evaluating high-volume
--     producers. That needs two steps: use a WITH clause to create an
--     intermediate result that summarizes performance for each producer,
--     then use a second aggregation or filter on that intermediate result
--     to calculate a baseline for high-volume producers.
-- ============================================================

-- ------------------------------------------------------------
-- 4.2c  What does a normal no-show rate look like for a busy property?
--    Step 1 the CTE sums up each property (viewings, no-shows, rate, held
--    viewings and held minutes). Step 2 keeps only properties with 15 or
--    more viewings and rolls them into one baseline row. Uses WITH (CTE)
--    WHERE on the CTE and COUNT SUM AVG MIN MAX.
-- ------------------------------------------------------------
WITH producer_summary AS (
    SELECT property_id,
           COUNT(*) AS viewings,
           COUNT(*) FILTER (WHERE no_show_reason = 'Renter no show') AS no_shows,
           100.0 * COUNT(*) FILTER (WHERE no_show_reason = 'Renter no show') / COUNT(*) AS no_show_pct,
           COUNT(*) FILTER (WHERE viewing_status <> 'cancelled') AS held,
           SUM(duration_min) FILTER (WHERE viewing_status <> 'cancelled') AS held_min
    FROM   viewings
    GROUP BY property_id
)
SELECT COUNT(*) AS producers,
       SUM(viewings) AS viewings,
       SUM(no_shows) AS no_shows,
       ROUND(100.0 * SUM(no_shows) / SUM(viewings), 1) AS baseline_no_show_pct,
       ROUND(AVG(no_show_pct), 1) AS avg_producer_pct,
       ROUND(MIN(no_show_pct), 1) AS lowest_pct,
       ROUND(MAX(no_show_pct), 1) AS highest_pct,
       ROUND(SUM(held_min) / SUM(held), 2) AS baseline_avg_min_held
FROM   producer_summary
WHERE  viewings >= 15;
-- Result: 1 row. 8 properties pass (6, 8, 10, 5, 7, 12, 2 and 11 from
--    4.1b) with 145 viewings and 7 no-shows so the baseline is 4.8%. The
--    avg of the 8 property rates is 5.1% which is a bit higher bc that way every
--    property counts the same no matter how many viewings it had. Rates run
--    from 0.0 to 18.8 and the 18.8 is property 2, almost 4 times the
--    baseline. Baseline held avg is 22.31 minutes. The baseline is lower
--    than the 6.0% platform rate bc the 5 smaller properties left out have
--    5 of the 12 no-shows in only 55 viewings.
-- Decision: High volume is 15 or more viewings. Thats about the avg per
--    property (200 viewings over 13 properties is 15.4) so high volume
--    means busier than a typical property and its above the 10 from 4.1c
--    so everything in the baseline already passed that floor. The baseline
--    is the pooled 4.8% not the 5.1% avg of rates bc every viewing counts
--    once that way.
