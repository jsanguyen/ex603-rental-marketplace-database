-- ############################################################
-- Task 5.3 Understand Join Performance and Execution Plans
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- rental.sql only makes indexes for primary keys and unique columns so
--    viewings.renter_id and viewings.property_id have no index.
-- ############################################################


-- ============================================================
-- Part A. Explore CROSS JOIN
--     Write a CROSS JOIN between two small tables. Then count the rows in
--     each source table, run the CROSS JOIN and count the resulting rows,
--     show how the result matches the multiplication of the two source
--     table counts. Explain when a Cartesian product might be useful and
--     when it could indicate a query error. Choose small tables so the
--     result is manageable.
-- ============================================================

-- ------------------------------------------------------------
-- 5.3a  How many rows do you get pairing every amenity with every
--    property and is it amenities times properties? The two scalar
--    subqueries count each source table and expected_rows multiplies
--    them. cross_join_rows is the actual count from the CROSS JOIN. Uses
--    CROSS JOIN COUNT and scalar subqueries.
-- ------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM amenities) AS amenity_rows,
       (SELECT COUNT(*) FROM properties) AS property_rows,
       (SELECT COUNT(*) FROM amenities) * (SELECT COUNT(*) FROM properties) AS expected_rows,
       COUNT(*) AS cross_join_rows
FROM   amenities a
CROSS JOIN properties p;
-- Result: 5 amenities and 15 properties so 5 x 15 = 75 expected and the
--    CROSS JOIN gave 75. Every amenity got paired with every property.
--    Useful when you want every combination like a grid of
--    every property against every amenity to see which tags each one is
--    missing. Its a red flag when it happens by accident. Joining
--    viewings to properties without the ON would give 200 x 15 = 3000
--    rows and every count would be 15 times too big with no error.


-- ============================================================
-- Part B. Examine a Query Execution Plan
--     Return to your three-table join from Task 5.1, Part A. Use
--     PostgreSQL's EXPLAIN command to examine how the database plans to
--     execute the query. Capture the full execution plan. Identify the
--     join algorithm or algorithms used, such as Nested Loop, Hash Join,
--     or Merge Join. Explain why PostgreSQL may have selected these
--     algorithms, considering table sizes and available indexes. Predict
--     which part of the query might become less efficient as the dataset
--     grows.
-- ============================================================

-- ------------------------------------------------------------
-- 5.3b  How does PostgreSQL actually run the 5.1a join? Same query as
--    5.1a with EXPLAIN ANALYZE in front. ANALYZE runs the query for real
--    so the plan has actual rows and times next to the estimates. Its
--    safe here bc its only a SELECT. Uses EXPLAIN ANALYZE.
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT v.viewing_id,
       v.scheduled_at,
       r.renter_id,
       r.renter_name,
       p.property_id,
       p.property_label,
       v.viewing_status
FROM   viewings v
JOIN   renters r ON r.renter_id = v.renter_id
JOIN   properties p ON p.property_id = v.property_id
ORDER BY v.scheduled_at, v.viewing_id;
-- Result: 16 line plan full copy in analysis/unit5.md. Two Hash Joins.
--    The inner one hashes renters (30 rows) and runs the 200 viewings
--    past it on renter_id. The outer one hashes properties (15 rows) and
--    matches on property_id. A Sort on top does the ORDER BY. All three
--    tables are read with a Seq Scan. Both Hash nodes say Batches 1 with
--    10kB and 9kB of memory so they fit in memory easily. Estimated rows
--    match actual rows at every step (200, 30 and 15). Times change every
--    run but the whole thing takes well under a millisecond. My
--    prediction is the Seq Scan on viewings plus the Sort are what get
--    worse as the platform grows. Every run reads every viewing then
--    sorts all of them (quicksort in 53kB now). With millions of viewings
--    the sort wont fit in the 4MB work_mem and has to go to disk. The hash
--    joins stay cheap as long as renters and properties are small enough
--    to hash in memory.
