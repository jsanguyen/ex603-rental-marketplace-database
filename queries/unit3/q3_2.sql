-- ############################################################
-- Task 3.2 Find the bug
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- Failure state is a renter no-show and the frozen payout is agent commissions.
-- ############################################################


-- ============================================================
-- Part A. The rows that vanished
--     SQL uses three-valued logic: TRUE, FALSE, and UNKNOWN. A comparison
--     against NULL yields UNKNOWN, and a WHERE clause keeps only rows
--     where the predicate is TRUE. A filter that looks exhaustive can
--     therefore discard rows silently, without an error and without
--     warning anyone.
-- ============================================================

-- Column picked is viewings.no_show_reason. It's nullable and already has
--    166 NULLs (every <attended> and <disputed> viewing, see 3.1f) so I
--    didn't need to insert any.

-- ------------------------------------------------------------
-- 3.2a  How many viewings were NOT a renter no-show? Should be every
--    viewing except the 12 no-shows so 188 expected. Uses WHERE with <>.
-- ------------------------------------------------------------
SELECT COUNT(*) AS not_a_no_show
FROM   viewings
WHERE  no_show_reason <> 'Renter no show';
-- Result: 22. Way off from 188. It only counted the cancellations with some
--    other reason (<Agent unavailable> <Property withdrawn> <Renter
--    cancelled>). For the 166 rows where no_show_reason is NULL the
--    comparison NULL <> 'Renter no show' is UNKNOWN not TRUE so WHERE threw
--    them out. No error, the number just looks small.

-- ------------------------------------------------------------
-- 3.2b  Which rows did 3.2a silently drop, and do the counts add up to
--    the table? Puts the <> count, the = count, the NULL count and the
--    table total side by side. Uses COUNT with FILTER.
-- ------------------------------------------------------------
SELECT COUNT(*)                                                    AS table_total,
       COUNT(*) FILTER (WHERE no_show_reason <> 'Renter no show')  AS not_a_no_show,
       COUNT(*) FILTER (WHERE no_show_reason =  'Renter no show')  AS no_show,
       COUNT(*) FILTER (WHERE no_show_reason IS NULL)              AS vanished_nulls
FROM   viewings;
-- Result: 200 total, 22 not a no-show, 12 no-show, 166 NULL.
--    <> and = look like they should cover everything but 22 + 12 = 34, not
--    200. The missing 166 are exactly the NULL rows. 22 + 12 + 166 = 200 so
--    the NULLs are the whole gap.

-- ------------------------------------------------------------
-- 3.2c  Fixed version of 3.2a. Viewings that were not a renter no-show,
--    counting NULL reasons as "not a no-show" since those viewings
--    happened. Uses WHERE with OR ... IS NULL.
-- ------------------------------------------------------------
SELECT COUNT(*) AS not_a_no_show
FROM   viewings
WHERE  no_show_reason <> 'Renter no show'
   OR  no_show_reason IS NULL;
-- Result: 188. Matches what was expected and 188 + 12 no-shows = 200.

-- ------------------------------------------------------------
-- 3.2d  Same fix written with COALESCE instead. Swaps NULL for a label
--    first so the <> has a real value to compare. Uses COALESCE.
-- ------------------------------------------------------------
SELECT COUNT(*) AS not_a_no_show
FROM   viewings
WHERE  COALESCE(no_show_reason, 'No reason provided') <> 'Renter no show';
-- Result: 188. Same answer as 3.2c. Either fix works, the IS NULL one is
--    more obvious to read.


-- ============================================================
-- Part B. The alias that did not exist yet
--     SQL is written FROM, WHERE, SELECT, ORDER BY, but it is not
--     evaluated in that order.
-- ============================================================

-- Postgres actually runs it FROM then WHERE then GROUP BY then HAVING then
--    SELECT then ORDER BY. WHERE runs before SELECT so any alias made in
--    SELECT doesn't exist yet when WHERE looks for it. ORDER BY runs last
--    so it can use the alias fine.

-- ------------------------------------------------------------
-- 3.2e  Broken on purpose. Flag each viewing as a no-show (1) or not (0)
--    and keep only the no-shows using the alias. Uses CASE and an alias
--    in WHERE. This one errors when you run it.
-- ------------------------------------------------------------
SELECT viewing_id,
       property_id,
       CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END AS is_no_show
FROM   viewings
WHERE  is_no_show = 1;
-- Result: Error, no rows.
--    ERROR:  column "is_no_show" does not exist
--    LINE 5: WHERE  is_no_show = 1;
--                   ^
--    WHERE got checked before SELECT made is_no_show so Postgres has no idea
--    what it is.

-- ------------------------------------------------------------
-- 3.2f  Fix 1. Same thing but the CASE is repeated in WHERE instead of
--    using the alias. Uses CASE in SELECT and WHERE.
-- ------------------------------------------------------------
SELECT viewing_id,
       property_id,
       CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END AS is_no_show
FROM   viewings
WHERE  CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END = 1
ORDER BY viewing_id;
-- Result: 12 rows, viewings 4, 12, 21, 26, 31, 40, 46, 65, 103, 125, 163
--    and 181. Works but the CASE is written twice so if someone edits one
--    and not the other they quietly stop matching.

-- ------------------------------------------------------------
-- 3.2g  Fix 2. Build the flag inside a CTE first so is_no_show is a real
--    column by the time the outer WHERE runs. Uses WITH (CTE).
-- ------------------------------------------------------------
WITH flagged AS (
    SELECT viewing_id,
           property_id,
           CASE WHEN no_show_reason = 'Renter no show' THEN 1 ELSE 0 END AS is_no_show
    FROM   viewings
)
SELECT viewing_id, property_id, is_no_show
FROM   flagged
WHERE  is_no_show = 1
ORDER BY viewing_id;
-- Result: 12 rows, same as 3.2f. The CASE only lives in one place so this is
--    the cleaner fix. Side note the CASE gives NULL reasons a 0 since
--    NULL = 'Renter no show' is UNKNOWN and falls to ELSE, so the Part A
--    problem doesn't hit here.
