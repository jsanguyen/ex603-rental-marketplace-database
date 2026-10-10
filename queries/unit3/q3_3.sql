 -- ############################################################
-- Task 3.3 Hand the team a corrected query
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- Failure state is a renter no-show and the frozen payout is agent commissions.
-- ############################################################

-- The question. Which renters were involved in the renter no-show viewings?
--    Step 1 find the no-show viewings, step 2 find the renters on them.


-- ============================================================
-- Q1. Answer a two-step question about your data and express it three
--     ways. First as a subquery using IN or NOT IN. Then as a Common
--     Table Expression using WITH. Then a third way, distinct from both.
-- ============================================================

-- ------------------------------------------------------------
-- 3.3a  Way 1. Renters whose id is in the list of no-show viewings.
--    Uses a subquery with IN.
-- ------------------------------------------------------------
SELECT r.renter_id, r.renter_name, r.search_city
FROM   renters r
WHERE  r.renter_id IN (
           SELECT renter_id
           FROM   viewings
           WHERE  no_show_reason = 'Renter no show'
       )
ORDER BY r.renter_id;
-- Result: 10 renters, ids 1, 4, 6, 7, 15, 17, 19, 21, 27 and 29.

-- ------------------------------------------------------------
-- 3.3b  Way 2. Same thing but step 1 is its own named CTE.
--    Uses WITH, DISTINCT and JOIN.
-- ------------------------------------------------------------
WITH no_show_renters AS (
    SELECT DISTINCT renter_id
    FROM   viewings
    WHERE  no_show_reason = 'Renter no show'
)
SELECT r.renter_id, r.renter_name, r.search_city
FROM   renters r
JOIN   no_show_renters n ON n.renter_id = r.renter_id
ORDER BY r.renter_id;
-- Result: Same 10 renters.

-- ------------------------------------------------------------
-- 3.3c  Way 3. For each renter check if any of their viewings is a
--    no-show. Uses a correlated subquery with EXISTS.
-- ------------------------------------------------------------
SELECT r.renter_id, r.renter_name, r.search_city
FROM   renters r
WHERE  EXISTS (
           SELECT 1
           FROM   viewings v
           WHERE  v.renter_id = r.renter_id
           AND    v.no_show_reason = 'Renter no show'
       )
ORDER BY r.renter_id;
-- Result: Same 10 renters.


-- ============================================================
-- Q2. Demonstrate that all three return identical result sets. Matching
--     row counts is not enough: show that the rows themselves match.
-- ============================================================

-- ------------------------------------------------------------
-- 3.3d  Do the three ways return the exact same rows? Puts all three in
--    CTEs and uses EXCEPT ALL both directions to find any row one has and
--    the other doesn't. IN is checked against CTE and against EXISTS so
--    if both are 0 then CTE and EXISTS match too. Uses WITH and EXCEPT ALL.
-- ------------------------------------------------------------
WITH way_in AS (
    SELECT r.renter_id, r.renter_name, r.search_city
    FROM   renters r
    WHERE  r.renter_id IN (
               SELECT renter_id
               FROM   viewings
               WHERE  no_show_reason = 'Renter no show'
           )
),
way_cte AS (
    WITH no_show_renters AS (
        SELECT DISTINCT renter_id
        FROM   viewings
        WHERE  no_show_reason = 'Renter no show'
    )
    SELECT r.renter_id, r.renter_name, r.search_city
    FROM   renters r
    JOIN   no_show_renters n ON n.renter_id = r.renter_id
),
way_exists AS (
    SELECT r.renter_id, r.renter_name, r.search_city
    FROM   renters r
    WHERE  EXISTS (
               SELECT 1
               FROM   viewings v
               WHERE  v.renter_id = r.renter_id
               AND    v.no_show_reason = 'Renter no show'
           )
),
mismatches AS (
    (SELECT * FROM way_in     EXCEPT ALL SELECT * FROM way_cte)
    UNION ALL
    (SELECT * FROM way_cte    EXCEPT ALL SELECT * FROM way_in)
    UNION ALL
    (SELECT * FROM way_in     EXCEPT ALL SELECT * FROM way_exists)
    UNION ALL
    (SELECT * FROM way_exists EXCEPT ALL SELECT * FROM way_in)
)
SELECT (SELECT COUNT(*) FROM way_in)     AS in_rows,
       (SELECT COUNT(*) FROM way_cte)    AS cte_rows,
       (SELECT COUNT(*) FROM way_exists) AS exists_rows,
       (SELECT COUNT(*) FROM mismatches) AS mismatched_rows;
-- Result: 10 | 10 | 10 | 0. Same count and 0 rows that only one version
--    has so it's the same 10 renters with the same names and cities.


-- ============================================================
-- Q3. Name one input condition under which the three would not be
--     equivalent.
-- ============================================================

-- Duplicates. Renters 1 and 21 each have 2 no-shows. IN and EXISTS only
--    check if a match exists so each renter comes back once. The CTE
--    version only matches because of the DISTINCT. Take it out and the JOIN
--    returns 12 rows instead of 10 with renters 1 and 21 listed twice, so a
--    dashboard counting rows would say 12 renters no-showed when it's 10.
-- Decision: Hand the team the EXISTS version (3.3c). It can't list a renter
--    twice and doesn't need a DISTINCT to be right.
