-- ############################################################
-- Task 5.2 Find Records That Joins May Exclude
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- The producer to event relationship is properties to viewings on
--    property_id.
-- ############################################################


-- ============================================================
-- Part A. Compare INNER JOIN and LEFT JOIN
--     Write two queries to compare the results of an inner join and a
--     left join. Use LEFT JOIN to return all producers, including those
--     who have never had an event. Write an equivalent query using INNER
--     JOIN. Compare the results and determine how many producers are
--     excluded by the inner join. Explain which producers are missing and
--     why. Your results must include a count of the producers excluded by
--     the inner join.
--     Hint: When counting producers, use their unique identifiers so that
--     producers with multiple events are not counted more than once.
-- ============================================================

-- ------------------------------------------------------------
-- 5.2a  How many producers come back when every property is kept even
--    with no viewings? LEFT JOIN from properties to viewings.
--    COUNT(DISTINCT p.property_id) counts each property once bc a property
--    with 21 viewings shows up on 21 rows. producers_excluded is the total
--    in properties minus the ones that came back. no_viewing_ids lists the
--    properties whose viewing side came back NULL. Uses LEFT JOIN COUNT
--    DISTINCT a scalar subquery and STRING_AGG with FILTER.
-- ------------------------------------------------------------
SELECT COUNT(*) AS joined_rows,
       COUNT(DISTINCT p.property_id) AS producers,
       (SELECT COUNT(*) FROM properties) - COUNT(DISTINCT p.property_id) AS producers_excluded,
       STRING_AGG(p.property_id::text, ', ' ORDER BY p.property_id)
           FILTER (WHERE v.viewing_id IS NULL) AS no_viewing_ids
FROM   properties p
LEFT JOIN viewings v ON v.property_id = p.property_id;
-- Result: 202 joined rows, 15 producers, 0 excluded and no viewings for
--    14 and 15. 202 is the 200 viewings plus one NULL row each for 14 and
--    15. Counting rows instead of distinct ids would make it look like
--    there were 202 of something.

-- ------------------------------------------------------------
-- 5.2b  Same thing with INNER JOIN. How many producers does it drop?
--    Identical to 5.2a except JOIN instead of LEFT JOIN. Uses JOIN COUNT
--    DISTINCT a scalar subquery and STRING_AGG with FILTER.
-- ------------------------------------------------------------
SELECT COUNT(*) AS joined_rows,
       COUNT(DISTINCT p.property_id) AS producers,
       (SELECT COUNT(*) FROM properties) - COUNT(DISTINCT p.property_id) AS producers_excluded,
       STRING_AGG(p.property_id::text, ', ' ORDER BY p.property_id)
           FILTER (WHERE v.viewing_id IS NULL) AS no_viewing_ids
FROM   properties p
JOIN   viewings v ON v.property_id = p.property_id;
-- Result: 200 rows, 13 producers and 2 excluded. no_viewing_ids is NULL
--    bc an inner join never makes the NULL viewing rows so it cant even
--    list which ones it dropped. The 2 missing are 14 and 15 from 5.2a.
--    They have no rows in viewings so theres nothing for the inner join to
--    match them to and they just disappear without an error. Thats the
--    same reason they never showed up in Unit 4.


-- ============================================================
-- Part B. Explore RIGHT JOIN and FULL OUTER JOIN
--     Write a RIGHT JOIN that returns the same records as your LEFT JOIN
--     from Part A. Compare the results to confirm that they match. Write a
--     FULL OUTER JOIN that includes matching and unmatched records from
--     both tables. Explain what a full outer join can reveal that a left
--     join or right join alone may not show. Be sure to verify your
--     results rather than assuming the queries are equivalent.
-- ============================================================

-- ------------------------------------------------------------
-- 5.2c  Does a RIGHT JOIN give the same result as the 5.2a LEFT JOIN?
--    Same select list but the tables are swapped so viewings is on the
--    left and properties is on the right, which keeps every property.
--    Uses RIGHT JOIN COUNT DISTINCT a scalar subquery and STRING_AGG with
--    FILTER.
-- ------------------------------------------------------------
SELECT COUNT(*) AS joined_rows,
       COUNT(DISTINCT p.property_id) AS producers,
       (SELECT COUNT(*) FROM properties) - COUNT(DISTINCT p.property_id) AS producers_excluded,
       STRING_AGG(p.property_id::text, ', ' ORDER BY p.property_id)
           FILTER (WHERE v.viewing_id IS NULL) AS no_viewing_ids
FROM   viewings v
RIGHT JOIN properties p ON p.property_id = v.property_id;
-- Result: 202 rows, 15 producers, 0 excluded and no viewings for 14 and
--    15. Matches 5.2a on every column. The counts could match by
--    luck so no_viewing_ids is there to check its the same 2 properties
--    and not just the same number of them.

-- ------------------------------------------------------------
-- 5.2d  What does a FULL OUTER JOIN show about unmatched rows on both
--    sides? matched_rows is viewings that found their property. The last
--    two columns count rows where one side came back NULL. Uses FULL
--    OUTER JOIN and COUNT with FILTER.
-- ------------------------------------------------------------
SELECT COUNT(*) AS joined_rows,
       COUNT(*) FILTER (WHERE p.property_id IS NOT NULL AND v.viewing_id IS NOT NULL) AS matched_rows,
       COUNT(*) FILTER (WHERE v.viewing_id IS NULL) AS producers_with_no_viewing,
       COUNT(*) FILTER (WHERE p.property_id IS NULL) AS viewings_with_no_producer
FROM   properties p
FULL OUTER JOIN viewings v ON v.property_id = p.property_id;
-- Result: 202 rows with 200 matched. 2 producers with no viewing (14 and
--    15) and 0 viewings with no producer. A LEFT or RIGHT JOIN only keeps
--    the unmatched rows from one side so youd need two queries to check
--    both. The full outer gets both in one go. Here the viewngs side is 0
--    bc viewings.property_id is a NOT NULL foreign key so a viewing cant
--    point at a property that doesnt exist. If viewings came in from a CSV
--    into a table without that constraint the full outer would catch
--    orphan viewings that a LEFT JOIN from properties never would.


-- ============================================================
-- Part C. Find Producers with No Events Using Two Approaches
--     Write two queries that identify producers who have never had an
--     event and compare them. NOT EXISTS. EXCEPT. Run both queries and
--     compare their results. In one or two sentences, explain how the
--     approaches differ and confirm whether they identify the same
--     producers.
-- ============================================================

-- ------------------------------------------------------------
-- 5.2e  Which properties have never had a viewing? For each property the
--    subquery looks for any viewing with its property_id and NOT EXISTS
--    keeps the property if there isnt one. Uses WHERE NOT EXISTS with a
--    correlated subquery.
-- ------------------------------------------------------------
SELECT p.property_id,
       p.property_label,
       p.city,
       p.monthly_rent,
       p.is_available,
       p.listed_on
FROM   properties p
WHERE  NOT EXISTS (SELECT 1
                   FROM   viewings v
                   WHERE  v.property_id = p.property_id)
ORDER BY p.property_id;
-- Result: 2 rows, 14 and 15. Both are available and both are cheap
--    (651.07 in Saigon and 1342.76 in Hue are the 3rd and 4th lowest rents
--    from 3.1a) so they should be getting viewings. 14 has been listed
--    since 2022-04-11 so it isnt just new. 15 was listed 2022-11-18.

-- ------------------------------------------------------------
-- 5.2f  Same question with EXCEPT. Takes every property_id in properties
--    and removes any that show up in viewings. Uses EXCEPT.
-- ------------------------------------------------------------
SELECT property_id FROM properties
EXCEPT
SELECT property_id FROM viewings
ORDER BY property_id;
-- Result: 2 rows, 14 and 15 so it finds the same producers as 5.2e.
--    NOT EXISTS checks each property one at a time and can return any of
--    its columns while EXCEPT compares two whole lists of ids so it only
--    gives back property_id and drops duplicates.
