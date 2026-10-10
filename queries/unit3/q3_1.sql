-- ############################################################
-- Task 3.1 Establish what the data contains
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- Failure state is a renter no-show and the frozen payout is agent commissions.
-- ############################################################


-- ============================================================
-- Q1. Find active, highly rated producers. Use your theme's filter
--     condition from the appendix. Sort them and return the first ten.
-- ============================================================

-- ------------------------------------------------------------
-- 3.1a  Available properties at 2000 or less a month, these are the producers
--    the audit is built on. Appendix filter is is_available = 1 AND
--    monthly_rent <= 2000 but PostgreSQL wants TRUE instead of 1. For rent
--    lower is better so it's sorted cheapest first and ties get broken by
--    property_id. Uses SELECT WHERE ORDER BY LIMIT.
-- ------------------------------------------------------------
SELECT property_id, property_label, city, monthly_rent
FROM   properties
WHERE  is_available = TRUE
AND    monthly_rent <= 2000
ORDER BY monthly_rent, property_id
LIMIT 10;
-- Result: Received 7 rows back so less than ten qualify. Properties 6, 7, 14,
--    15, 10, 11 and 8 (rent goes from 600.05 up to 1954.33). 6 and 7 are tied
--    at exactly 600.05 so without the property_id tie-break their order could
--    flip between runs. 12 just misses at 2041.08. 14 and 15 make the list but
--    have no viewings at all so any query that JOINs properties to viewings
--    will drop them.


-- ============================================================
-- Q2. Find all possible event statuses. Display the distinct values in
--     the event status column. Look carefully at the results. Are there
--     more statuses than you expected?
-- ============================================================

-- ------------------------------------------------------------
-- 3.1b  Every status a viewing can end up in, to see what values a failure
--    rate could be counting. Uses SELECT DISTINCT and ORDER BY.
-- ------------------------------------------------------------
SELECT DISTINCT viewing_status
FROM   viewings
ORDER BY viewing_status;
-- Result: 3 values came back, <attended> <cancelled> and <disputed>. I
--    expected 2 (<attended> or <cancelled>). <disputed> is the extra one and it's
--    not really a success or a no-show so any failure rate has to pick a side.
--    A query that counts everything that's not <attended> as a failure would
--    pull it in. No weird casing or spacing versions either.
-- Decision: Theme says the failure state is a renter no-show so failure here
--    means no_show_reason = <Renter no show> (12 rows, 6.0%). Status alone
--    isn't enough bc <cancelled> also includes cancellations that weren't the
--    renter's fault (see 3.1g). <disputed> viewings still happened so they're
--    not failures. Using this definition for the rest of the file.


-- ============================================================
-- Q3. Filter the events in two different ways. Write: one query that
--     filters a numeric range, and one query that filters using an
--     explicit list of values with IN.
-- ============================================================

-- ------------------------------------------------------------
-- 3.1c  Which viewings were 10 min or less? Checking if the <short> ones are
--    real visits or not. Uses WHERE ... BETWEEN.
-- ------------------------------------------------------------
SELECT viewing_id, property_id, viewing_status, duration_min, no_show_reason
FROM   viewings
WHERE  duration_min BETWEEN 0 AND 10
ORDER BY duration_min, viewing_id;
-- Result: 63 rows. 34 of them are exactly 0.00 min and all 34 are
--    <cancelled>. The rest (28 <attended> and 1 <disputed>) start at 4.65 min.
--    So a cancelled viewing gets stored as 0 minutes instead of NULL which
--    drags down any avg duration that includes them.

-- ------------------------------------------------------------
-- 3.1d  Which viewings didn't end as a clean <attended>? This is the widest
--    possible take on <failure>. Uses WHERE ... IN.
-- ------------------------------------------------------------
SELECT viewing_id, property_id, viewing_status, no_show_reason
FROM   viewings
WHERE  viewing_status IN ('cancelled', 'disputed')
ORDER BY viewing_status, viewing_id;
-- Result: 44 of 200 rows (22%), 34 <cancelled> + 10 <disputed>. This is just
--    the upper bound not the failure definition (see 3.1b). Even this is
--    nowhere near the dashboard's "about half". Actual renter no-shows are
--    only 12 of the 34 cancellations (6.0%).


-- ============================================================
-- Q4. Work with text and missing values. Write queries that: find
--     producers whose names match a text pattern using LIKE, and
--     identify records where a reason/value is missing (NULL). Use
--     COALESCE to replace a missing value with a useful label such as:
--     No reason provided.
-- ============================================================

-- ------------------------------------------------------------
-- 3.1e  Which properties have a label starting with <Property_1>? In LIKE
--    the _ is a wildcard for any one character so it's escaped (\_) to match
--    an actual underscore. Uses WHERE ... LIKE.
-- ------------------------------------------------------------
SELECT property_id, property_label, city, is_available
FROM   properties
WHERE  property_label LIKE 'Property\_1%'
ORDER BY property_id;
-- Result: 6 rows, properties 10 to 15 (<Property_10> to <Property_15>).
--    Every label is just <Property_NN> so the label tells you which property
--    it is and that's it.

-- ------------------------------------------------------------
-- 3.1f  Which viewings have no no_show_reason and what status are they?
--    Uses WHERE ... IS NULL and GROUP BY.
-- ------------------------------------------------------------
SELECT viewing_status, COUNT(*) AS viewings_without_reason
FROM   viewings
WHERE  no_show_reason IS NULL
GROUP BY viewing_status
ORDER BY viewing_status;
-- Result: 166 viewings have a NULL reason, 156 <attended> + 10 <disputed>.
--    Every <cancelled> one has a reason. The NULLs make sense. If the viewing
--    happened there's nothing to explain.

-- ------------------------------------------------------------
-- 3.1g  How many viewings per status and reason, showing <No reason
--    provided> instead of NULL. Uses COALESCE and GROUP BY.
-- ------------------------------------------------------------
SELECT viewing_status,
       COALESCE(no_show_reason, 'No reason provided') AS reason,
       COUNT(*)                                       AS viewings
FROM   viewings
GROUP BY viewing_status, COALESCE(no_show_reason, 'No reason provided')
ORDER BY viewing_status, reason;
-- Result: 6 rows
--    <attended>  / <No reason provided>  156
--    <cancelled> / <Agent unavailable>     7
--    <cancelled> / <Property withdrawn>    7
--    <cancelled> / <Renter cancelled>      8
--    <cancelled> / <Renter no show>       12
--    <disputed>  / <No reason provided>   10
--    Lines up with the 3.1b decision. The 3 ways you could define failure
--      no_show_reason = <Renter no show>   12 rows    6.0%   <- the one I'm using
--      viewing_status = <cancelled>        34 rows   17.0%
--      viewing_status <> <attended>        44 rows   22.0%
--    Only the 12 <Renter no show> rows are actual no-shows. The other 22
--    cancellations were on the agent or landlord or the renter cancelled
--    ahead of time so they shouldn't count.


-- ============================================================
-- Q5. Make the results easier to understand. Create a query with
--     calculated/computed columns that would make sense to someone who
--     does not work with SQL. Depending on your theme, you might calculate
--     or label: a payout amount, a time of day, a value/rating category,
--     or another useful business measure. Use CASE where appropriate to
--     create plain-language categories.
-- ============================================================

-- ------------------------------------------------------------
-- 3.1h  Every viewing in plain English. When it was, what time of day,
--    what actually happened, how interested the renter was and how long
--    they spent there. Cancelled ones say "Did not happen" instead of 0 min
--    (see 3.1c). Uses JOIN, CASE, TO_CHAR, EXTRACT and ORDER BY.
-- ------------------------------------------------------------
SELECT v.viewing_id                               AS "Viewing #",
       p.property_label                           AS "Property",
       p.city                                     AS "City",
       TO_CHAR(v.scheduled_at, 'Mon DD, YYYY')    AS "Date",
       TO_CHAR(v.scheduled_at, 'HH12:MI AM')      AS "Time",
       CASE
           WHEN EXTRACT(HOUR FROM v.scheduled_at) BETWEEN 5 AND 11  THEN 'Morning'
           WHEN EXTRACT(HOUR FROM v.scheduled_at) BETWEEN 12 AND 16 THEN 'Afternoon'
           WHEN EXTRACT(HOUR FROM v.scheduled_at) BETWEEN 17 AND 21 THEN 'Evening'
           ELSE 'Late night'
       END                                        AS "Time of day",
       CASE
           WHEN v.viewing_status = 'attended'         THEN 'Showed up'
           WHEN v.viewing_status = 'disputed'         THEN 'Happened but disputed'
           WHEN v.no_show_reason = 'Renter no show'   THEN 'Renter no-show'
           ELSE 'Cancelled for another reason'
       END                                        AS "What happened",
       CASE
           WHEN v.interest_score >= 2.00 THEN 'Very high'
           WHEN v.interest_score >= 1.50 THEN 'High'
           WHEN v.interest_score >  1.00 THEN 'Moderate'
           ELSE 'Low'
       END                                        AS "Renter interest",
       CASE
           WHEN v.viewing_status = 'cancelled' THEN 'Did not happen'
           ELSE ROUND(v.duration_min) || ' min'
       END                                        AS "Time spent"
FROM   viewings v
JOIN   properties p ON p.property_id = v.property_id
ORDER BY v.scheduled_at, v.viewing_id;
-- Result: 200 rows, one per viewing.
--    What happened    <Showed up> 156, <Cancelled for another reason> 22,
--                     <Renter no-show> 12, <Happened but disputed> 10
--    Renter interest  <Low> 99, <Moderate> 46, <High> 29, <Very high> 26
--    Time of day      <Morning> 56, <Late night> 54, <Evening> 51,
--                     <Afternoon> 39
--    Splitting out <Renter no-show> as its own label makes the real failure
--    count obvious without knowing the columns. The no-shows are spread out
--    across the day (4 morning, 3 afternoon, 2 evening, 3 late night) so
--    time of day doesn't explain them. Weird thing though, 54 viewings (27%)
--    are scheduled between 10 PM and 5 AM which isn't normal for property
--    viewings. Could be a timezone issue in scheduled_at, worth checking.
