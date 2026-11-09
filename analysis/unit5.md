# Task 5.1: Write up

## What could use the three-table join from Q1

A viewing history page for each property, the kind a regional manager would open when following up on a property like 2. It would show each viewing at that property with who booked it and when. With viewing_status and no_show_reason added the manager could see which renters missed their appointment there and then check if those same renters missed appointments at other properties too.

## Why the junction table matters for Q2

A property can have more than one amenity and each amenity can be on more than one property. Property 2 has three amenities and Gym is on five properties. listing_amenities stores one row per property and amenity pair so finding every property with Gym is two joins and a WHERE on the amenity name.

Without it the amenities would have to go on the properties table somehow. If they were in a text column like "Balcony,Gym,Pool" you'd have to search it with LIKE '%Gym%' which breaks if someone types gym in lowercase or spells it differently. The other way is a column per amenity like has_gym and has_pool but then adding a new amenity means changing the table. verified_on also belongs to the pair so without the junction table theres nowhere to record when each tag was checked.

# Task 5.2: Write up

## Which producers the inner join excluded

Properties 14 and 15. The LEFT JOIN in 5.2a returned 15 producers and the INNER JOIN in 5.2b returned 13. NOT EXISTS in 5.2e and EXCEPT in 5.2f both came back with the same two ids.

## What it means when a producer has no events

It means nobody booked a viewing at that property in the whole year of data we have (2023). 14 and 15 are both marked available and their rents are low (651.07 and 1342.76) so they should be easy to book. 14 has been listed since April 2022 so being new doesnt explain it. 14 is also in Saigon which is the busiest city (62 viewings in 4.2b) so its not like nobody books there.

There are a few reasons it could happen.

- The listing isnt showing up when renters search bc its missing details or tags the filters use.
- It got rented outside the platform and nobody switched is_available off.
- The landlord isnt answering booking requests so nothing turns into a viewing.
- Viewings for it are being logged under the wrong property_id.

## How an inner join report gives leadership an incomplete picture

A report built on an inner join between properties and viewings only has the 13 properties with viewings in it. 14 and 15  arent there and nothign in the report says they got dropped. Most of the Unit 4 per-property queries had the same blind spot bc they started from viewings. 4.1c and 4.2a only list 13 properties and 4.2b counts 13 properties across the five cities. Only 4.1b used a LEFT JOIN and showed 14 and 15 with 0. Averages move too. 200 viewings over 13 properties is about 15.4 each but over all 15 its about 13.3.

## Why leadership would want to find producers that were never active

These are listings the platform has but isnt getting anything from. A landlord whose listing gets no viewings for a year probably isnt happy and might leave. If the cause is on our side like the listign not showing up in search orother listings could have the same problem and its better to find it early. Leaving them out also makes the platform look better than it is since a property with no viewings could get read as one with a 0% no-show rate.

## What leadership could do

Have someone on the listings team check 14 and 15 directly. That means checking whether they show up in search and whether the listing details are complete. Its worth asking the landlords if they're still available. Leadership could also add a report that flags any available listing with no viewings after a set time (60 days for example) so this gets caught early instead of a year later. Until then 14 and 15 should show up in the per-property reports as having no activity instead of being left out.

## What the data shows vs what needs more investigation

The data shows 14 and 15 had no viewings at all in 2023. It shows both are marked available with low rents. 14 has been listed since April 2022 and 15 since November 2022.

The data doesnt show why. There's no record of whether renters ever saw these listings in search. It also cant tell us if they're actually still available or if the landlords are responding. Finding that out would need search logs plus talking to the landlords. One thing that can be checked with the data we already have is whether 14 and 15 have any amenity tags in listing_amenities, since a listing with no tags wouldn't come up when renters filter by amenity.

# Task 5.3: Write up

## When a Cartesian product would be useful here

A listing completeness check. 5.3a pairs every property with every amenity which is 75 pairs from 15 properties and 5 amenities. If you LEFT JOIN those pairs to listing_amenities any pair that doesnt match is an amenty that property doesnt have tagged. A property where all 5 come back unmatched has no tags at al which is the check 5.2 suggested for 14 and 15.

Most of the time though a Cartesian product is a mistake. Joining viewings to properties and forgetting the ON gives 200 x 15 = 3000 rows and every count is 15 times too big without any error.

## The plan for the 5.1a join

From EXPLAIN ANALYZE in 5.3b. The times change every run but the rest stays the same.

```
Sort  (cost=16.93..17.43 rows=200 width=55) (actual time=0.166..0.171 rows=200 loops=1)
  Sort Key: v.scheduled_at, v.viewing_id
  Sort Method: quicksort  Memory: 53kB
  ->  Hash Join  (cost=3.01..9.29 rows=200 width=55) (actual time=0.035..0.113 rows=200 loops=1)
        Hash Cond: (v.property_id = p.property_id)
        ->  Hash Join  (cost=1.68..7.28 rows=200 width=43) (actual time=0.020..0.073 rows=200 loops=1)
              Hash Cond: (v.renter_id = r.renter_id)
              ->  Seq Scan on viewings v  (cost=0.00..5.00 rows=200 width=33) (actual time=0.005..0.022 rows=200 loops=1)
              ->  Hash  (cost=1.30..1.30 rows=30 width=14) (actual time=0.012..0.012 rows=30 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 10kB
                    ->  Seq Scan on renters r  (cost=0.00..1.30 rows=30 width=14) (actual time=0.004..0.006 rows=30 loops=1)
        ->  Hash  (cost=1.15..1.15 rows=15 width=16) (actual time=0.010..0.010 rows=15 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              ->  Seq Scan on properties p  (cost=0.00..1.15 rows=15 width=16) (actual time=0.006..0.007 rows=15 loops=1)
Planning Time: 2.577 ms
Execution Time: 0.217 ms
```

The way I read it from the bottom up, PostgreSQL scans renters and builds a hash table out of it. Then it scans viewings and looks up each viewing's renter in that hash. It does the same thing again with properties for the second join and sorts everything at the end for the ORDER BY.

## Which join algorithms PostgreSQL chose

Two hash joins. The inner one joins viewings to renters on renter_id. The outer one joins that result to properties on property_id. The Sort at the top isn't a join, its just the ORDER BY.

## What in the plan explains it

- The Seq Scans on renters and properties say rows=30 and rows=15. Thats tiny so building a hash table from each one is cheap. Both Hash nodes say Batches 1 with 10kB and 9kB of memory which means each one fit in memory in one go.
- viewings is read with a Seq Scan bc the query wants all 200 rows. rental.sql also doesn't make an index on viewings.renter_id or viewings.property_id so there was no index to use even if it wanted one.
- renters and properties do have primary key indexes but PostgreSQL still read them straight through. With 30 and 15 rows reading the whole table is cheaper than going through an index.
- The estimated rows match the actual rows at every step so the planner had good numbers to work with.

## Why its useful to know which algorithm got picked

It shows you where the time goes before it becomes a problem. If a report gets slow you look at the plan and fix the step thats slow instead of guessing. A Seq Scan on viewings for a query about one property means an index is missing. A Hash with Batches above 1 means it ran out of memory and went to disk.

## What would make a different algorithm a better fit

If a query only wanted one property, like WHERE v.property_id = 2, an index on viewings.property_id would let PostgreSQL do a nested loop that jumps straight to those 16 viewings. Right now it would still scan all 200 bc that index doesn't exist. If renters grew big enough that its hash didn't fit in the 4MB work_mem the Hash node would show more than 1 batch. A merge join could take over at that point if both sides could be read already sorted by renter_id.

The part I expect to slow down first as the platform grows is the Seq Scan on viewings with the Sort on top of it. Every run reads every viewing and sorts all of them. The sort used 53kB here. With millions of viewings it wouldn't fit in memory and would have to sort on disk.

# Task 5.4: Reflection

Right now PostgreSQL uses two hash joins bc renters has 30 rows and properties has 15. It builds a hash table from each one in memory and runs all 200 viewings past them once. That works bc the query wants every viewing and both lookup tables fit easily in 4MB of work_mem.

If a report only wanted the viewings for property 2 an index on viewings.property_id would let PostgreSQL use a nested loop with an index scan. It would go straight to those 16 rows instead of reading all 200. The course data doesnt have that index so right now it would scan everything and throw most of it away.

If renters grew into the millions its hash table might not fit in work_mem anymore. The plan would show more than 1 batch bc parts of the hash get written to disk, which is a lot slower. A merge join could win then if both sides can be read in renter_id order from indexes since it just walks the two sorted lists together.

The other thing is how many rows actually match. When only a few rows match a nested loop with an index is usually fastest. When most of the table matches a hash join like this one is.
