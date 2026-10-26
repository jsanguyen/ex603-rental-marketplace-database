-- ############################################################
-- Task 4.1 Measure the platform
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- Failure is still a renter no-show (no_show_reason = <Renter no show>), same
--    definition as Unit 3 so the numbers line up with the memo.
-- ############################################################


-- ============================================================
-- Q1. Calculate the following statistics across the entire event table
--     using your theme's metric: the count, total, average, minimum, and
--     maximum of your theme's metric across the whole event table, and
--     how many distinct actors appear. Review your results carefully.
--     For example, if your metric should never be zero but your minimum
--     value is zero, this may indicate another data-quality issue that
--     needs investigation.
-- ============================================================

-- ------------------------------------------------------------
-- 4.1a  How many viewings are there, how many minutes do they add up to,
--    what's the avg shortest and longest and how many different renters
--    booked them? Whole table with no filter. Also counts the 0 minute
--    rows and the cancelled rows and redoes the avg and shortest without
--    the cancelled viewings so the zero minimum can be checked in the same
--    result. Uses COUNT SUM AVG MIN MAX COUNT DISTINCT and FILTER.
-- ------------------------------------------------------------
SELECT COUNT(*) AS viewings,
       SUM(duration_min) AS total_min,
       ROUND(AVG(duration_min), 2) AS avg_min,
       MIN(duration_min) AS shortest_min,
       MAX(duration_min) AS longest_min,
       COUNT(DISTINCT renter_id) AS renters,
       COUNT(*) FILTER (WHERE duration_min = 0) AS zero_min,
       COUNT(*) FILTER (WHERE viewing_status = 'cancelled') AS cancelled,
       ROUND(AVG(duration_min) FILTER (WHERE viewing_status <> 'cancelled'), 2) AS avg_min_held,
       MIN(duration_min) FILTER (WHERE viewing_status <> 'cancelled') AS shortest_min_held
FROM   viewings;
-- Result: 200 viewings, 3628.19 minutes total, avg 18.14, shortest 0.00,
--    longest 70.86 and 30 different renters (all 30 in the renters table
--    booked at least one). The 0.00 is the red flag bc a viewing that
--    lasted 0 minutes didn't really happen. There are 34 zero rows and 34
--    cancelled rows and without the cancelled ones the shortest is 4.65
--    so the zeros are the cancelled viewings. They never happened
--    but got logged as 0 minutes instead of NULL and the CHECK on
--    duration_min is only >= 0 so nothing stopped it. Leaving them out the
--    avg is 21.86(3.72 minutes higher).
-- Decision: From here on any avg of duration_min only counts held
--    viewings (<attended> and <disputed>, the disputed ones did happen per
--    Unit 3). Viewing counts and no-show rates still use every row bc a
--    cancelled viewing is still a booking that got made. viewing_status is
--    NOT NULL so the <> doesn't have the Unit 3 NULL problem.


-- ============================================================
-- Q2. Write a query that calculates the event count and average metric
--     for each producer. Sort the results from the producer with the most
--     events to the producer with the fewest. Consider what these results
--     tell you about differences in activity and performance across
--     producers.
-- ============================================================

-- ------------------------------------------------------------
-- 4.1b  How many viewings did each property get and how long did they
--    last on avg? Starts from properties with a LEFT JOIN so 14 and 15
--    (no viewings) still show up, and COUNT(v.viewing_id) not COUNT(*) so
--    they get 0 instead of 1. Raw avg sits next to the held only avg to
--    show what the zeros do per property. Most viewings first and
--    property_id breaks ties. Uses LEFT JOIN GROUP BY COUNT AVG with
--    FILTER and ORDER BY.
-- ------------------------------------------------------------
SELECT p.property_id,
       p.city,
       COUNT(v.viewing_id) AS viewings,
       ROUND(AVG(v.duration_min), 2) AS avg_min_raw,
       ROUND(AVG(v.duration_min) FILTER (WHERE v.viewing_status <> 'cancelled'), 2) AS avg_min_held
FROM   properties p
LEFT JOIN viewings v ON v.property_id = p.property_id
GROUP BY p.property_id, p.city
ORDER BY viewings DESC, p.property_id;
-- Result: 15 rows. Activity goes from 21 viewings (property 6) down to 6
--    (property 4) then 14 and 15 at 0 with NULL avgs. Three ties (5 and 7
--    at 18, 2 and 11 at 16, 1 and 13 at 11) so the property_id tie-break
--    matters. Held avg mostly sits around 17 to 24 minutes. Raw avg make
--    property 11 look like the worst at 11.94 but thats just 5 of its 16
--    being cancelled zeros. Its held avg is 17.37 which is normal. 10 has
--    no cancellations so both avgs are 20.97. Property 4 has the highest
--    held avg (29.23) but thats only 4 held viewings. The raw avg is
--    mostly measuring cancellations not how long renters stay and the
--    small properties swing the most.


-- ============================================================
-- Q3. Which producers have enough volume for their rate to mean
--     anything? A producer with only a few events may have a high failure
--     rate that is not representative of their usual performance. Choose a
--     minimum event-count threshold and use HAVING to include only
--     producers who meet that threshold. Explain why you selected your
--     threshold.
-- ============================================================

-- ------------------------------------------------------------
-- 4.1c  Which properties have enough viewings for their no-show rate to
--    mean something, and what's the rate for each? Keeps properties with
--    10 or more viewings and sorts highest rate first, then more viewings
--    first. Uses GROUP BY COUNT with FILTER HAVING and ORDER BY.
-- ------------------------------------------------------------
SELECT property_id,
       COUNT(*) AS viewings,
       COUNT(*) FILTER (WHERE no_show_reason = 'Renter no show') AS no_shows,
       ROUND(100.0 * COUNT(*) FILTER (WHERE no_show_reason = 'Renter no show')
             / COUNT(*), 1) AS no_show_pct
FROM   viewings
GROUP BY property_id
HAVING COUNT(*) >= 10
ORDER BY no_show_pct DESC, viewings DESC, property_id;
-- Result: 12 rows. Property 2 is top at 18.8% (3 of 16) then 3 at 15.4%
--    (2 of 13) 1 at 9.1%, 9 at 7.1%, 11 at 6.3%, 12 at 5.9%, 7 at 5.6%
--    and 6 at 4.8% (1 no-show each). 8, 10, 5 and 13 have none. 2 and 3
--    together have 5 of the 12 no-shows from only 29 of the 200 viewings.
--    HAVING dropped 4 (1 of 6, 16.7%) which would have ranked 2nd on a
--    single no-show. 14 and 15 aren't in viewings at all.
-- Decision: Threshold is 10 viewings. At the 6% platform rate you'd only
--    expect about 1 no-show per 17 viewings so a proprty under 10 nearly
--    usually has 0 or 1 and one renter not showing up moves its rate by
--    more than 10 points. Thats what happened to 4. 10 still keeps 12 of
--    the 13 properties that have viewings. 15 wouldve been the other
--    pick (close to the avg of about 15 per property) but it cuts the list
--    to 8 and drops 3, the second highest. Even at 10 one no-show is worth
--    10 points so these rates are a screen for who to look at.
--    I wouldnt necessarily call is proof


-- ============================================================
-- Q4. How does the picture change along two dimensions at once?
--     Leadership also wants to understand how performance varies across
--     regions. Write a query that groups the data by two dimensions,
--     including region, and calculates the relevant summary statistics.
--     Your results should contain one row for each combination of the two
--     dimensions so that regional leaders can review their results.
-- ============================================================

-- ------------------------------------------------------------
-- 4.1d  For each city how did each quarter of 2023 go? Viewings, no-shows,
--    no-show rate and avg held minutes for every city and quarter pair.
--    Uses JOIN GROUP BY on two columns TO_CHAR and COUNT AVG with FILTER.
-- ------------------------------------------------------------
SELECT p.city                                AS region,
       TO_CHAR(v.scheduled_at, 'YYYY-"Q"Q')  AS quarter,
       COUNT(*)                                                    AS viewings,
       COUNT(*) FILTER (WHERE v.no_show_reason = 'Renter no show') AS no_shows,
       ROUND(100.0 * COUNT(*) FILTER (WHERE v.no_show_reason = 'Renter no show')
             / COUNT(*), 1)                                        AS no_show_pct,
       ROUND(AVG(v.duration_min) FILTER (WHERE v.viewing_status <> 'cancelled'), 2) AS avg_min_held
FROM   viewings v
JOIN   properties p ON p.property_id = v.property_id
GROUP BY p.city, TO_CHAR(v.scheduled_at, 'YYYY-"Q"Q')
ORDER BY region, quarter;
-- Result: 20 rows, 5 cities times 4 quarters with none missing. Saigon is
--    the busiest (62 viewings, 2 no-shows) and its held avg stays between
--    21.99 and 26.35 every quarter. Haiphong has the most no-shows (4 of
--    50) with 2 of them in 2023-Q2. Danang has the worst rate cells(50.0%
--    in 2023-Q1 and 50.0% in 2023-Q4) but those are 2 of 4 and 1 of 2.
--
--    Danang only has one property (2) so it never gets more than 6 viewings
--    in a quarter. Hanoi 2023-Q4 held avg drops to 11.64 while its other
--    quarters are over 21, and none of its 8 viewings that quarter were
--    noshows. 17 of the 20 cells are under 15 viewings so the quarter
--    rates bounce around a lot the same small number problem as 4.1c
-- 
-- Decision: Theres no region column so region is the properties city
--    (properties.city), thats the listing a regional leader would own.
--    viewings.booking_city was the other option but thats where the
--    booking came from not where the listign is. Quarter is the second
--    dimension bc every city has viewings in every quarter so each
--    regional leader gets a full year.
