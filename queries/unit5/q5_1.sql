-- ############################################################
-- Task 5.1 Connect Producers to Their Data
-- Theme is Rental Marketplace
--    actor = renters        producer = properties   event = viewings
--    catalog = amenities    junction = listing_amenities
--    metric = duration_min (the event number that gets aggregated)
-- Failure is still a renter no-show (no_show_reason = <Renter no show>).
--    The producers from Assignment 4 are 2 and 3 with 4 as the one to watch.
-- ############################################################


-- ============================================================
-- Q1. Who are the people behind the events? Write a query that joins
--     three tables to display the actor who performed each event, the
--     producer associated with the event, and the event's date and time.
-- ============================================================

-- ------------------------------------------------------------
-- 5.1a  Who booked each viewing, which property was it at and when?
--    Joins viewings to renters and properties so each row has renter_id
--    and renter_name next to property_id and property_label. Sorted by
--    when the viewing was scheduled. Uses JOIN on three tables and
--    ORDER BY.
-- ------------------------------------------------------------
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
-- Result: 200 rows which is every viewing so none got dropped by the
--    joins. renter_id and property_id are NOT NULL foreign keys so every
--    viewing has to match a renter and a property. Starts with viewing 4
--    on 2023-01-01 15:48 (Renter_01 at Property_01) which is one of the 12
--    no-shows from Unit 3. Names in this dataset are jst Renter_01 and
--    Property_01 style labels so they dont tell you much more than the
--    ids do. 14 and 15 arent in here since they have no viewings.


-- ============================================================
-- Q2. Do the producers identified in Assignment 4 share certain catalog
--     credentials or tags? Write a query that connects the producer table
--     to the catalog table through the junction table. Return the
--     producers associated with your theme's catalog tag.
-- ============================================================

-- ------------------------------------------------------------
-- 5.1b  Which properties have the Gym tag? Goes from properties through
--    listing_amenities to amenities and keeps the <Gym> rows. Uses JOIN
--    through the junction table and WHERE.
-- ------------------------------------------------------------
SELECT p.property_id,
       p.property_label,
       p.city,
       p.monthly_rent,
       a.amenity_name,
       la.verified_on
FROM   properties p
JOIN   listing_amenities la ON la.property_id = p.property_id
JOIN   amenities a ON a.amenity_id = la.amenity_id
WHERE  a.amenity_name = 'Gym'
ORDER BY p.property_id;
-- Result: 5 rows. 2, 3, 5, 10 and 11 have <Gym>. 2 and 3 both have it but
--    4 doesnt. 5 and 10 also have it and neither had a single no show in
--    4.2a (0 of 18 and 0 of 19) so Gym isnt what makes 2 and 3 stand out.
--    2, 3 and 5 are also all at about 3200 a month which is the top rent
--    on the platform. 5.1c looks at that.
-- Decision: The appendix only says the catalog is amenities and doesnt
--    name one tag so I picked <Gym> bc its the only amenity 2 and 3 both
--    have.


-- ============================================================
-- Q3. How do the producers compare with one another? Write a self join
--     to compare records within the producer table. Use the results to
--     explore whether the producers identified in Assignment 4 share
--     characteristics with other producers or whether differences in
--     activity levels may explain their performance.
-- ============================================================

-- ------------------------------------------------------------
-- 5.1c  Do the Assignment 4 producers (2 and 3 plus 4) look like other
--    properties at the same rent and is it just a volume thing? The self
--    join pairs each of them with every other property within 200 a month
--    of its rent. The CTE counts viewings and no-shows per property so
--    both sides of the pair get their numbers. o.property_id <>
--    f.property_id stops a property pairing with itself. The LEFT JOIN on
--    the peer side means a peer with no viewings would still show up with
--    0. Uses WITH (CTE) self JOIN on properties LEFT JOIN COALESCE and
--    WHERE IN.
-- ------------------------------------------------------------
WITH activity AS (
    SELECT property_id,
           COUNT(*) AS viewings,
           COUNT(*) FILTER (WHERE no_show_reason = 'Renter no show') AS no_shows
    FROM   viewings
    GROUP BY property_id
)
SELECT f.property_id AS flagged_id,
       fa.viewings AS flagged_viewings,
       fa.no_shows AS flagged_no_shows,
       o.property_id AS peer_id,
       o.monthly_rent AS peer_rent,
       COALESCE(oa.viewings, 0) AS peer_viewings,
       COALESCE(oa.no_shows, 0) AS peer_no_shows
FROM   properties f
JOIN   properties o ON o.property_id <> f.property_id
                   AND ABS(o.monthly_rent - f.monthly_rent) <= 200
JOIN   activity fa ON fa.property_id = f.property_id
LEFT JOIN activity oa ON oa.property_id = o.property_id
WHERE  f.property_id IN (2, 3, 4)
ORDER BY f.property_id, o.property_id;
-- Result: 15 rows 5 peers for each of the 3. The cutoff pulls in
--    the 6 most expensive listings 1 to 5 all at about 3200 plus 13 at
--    3095.58. So the flagged producers do share something in thast they're all in
--    the top rent tier. Between the 6 of them thats 7 of the 12 no-shows in
--    75 viewings (9.3%). The other 7 properties with viewings have 5 in 125
--    (4.0%). Activity doesnt explain 2. It had 16 viewings which is close
--    to 5 with 18 and 5 had 0 no-shows at the same rent. 3 at 13 isclose
--    to 1 and 13 at 11 each. 4 is the one where activity matters. Its 6
--    viewings is the fewest in the tier so 1 no-show is enough to make it
--    look bad. The tier numbers are still small so its a lead to check
--    not proof that expensive listings get more no-shows.
-- Decision: Peers are properties within 200 a month bc the 5 listings at
--    about 3200 are within 0.12 of each other. 13 is the next closest at
--    about 104 below. After that its 9 at about 885 below so any cutoff
--    from 105 to 880 gives the same peers. Same city doesn't work as the
--    pairing bc 2 is the only property in Danang so it would have no peers.
