# Task 1.4: Reasoning

## Modelling justification

### Primary keys

Every entity table uses a surrogate key that the database generates with `GENERATED ALWAYS AS IDENTITY`. Renters and properties don't have a natural key to use. Display names repeat, and two listings can share a title, a city and a ZIP code. Viewings do have a candidate key, (`renter_id`, `property_id`, `viewed_at`), and I enforce it with a `UNIQUE` constraint so a double-submitted form can't record the same visit twice. I didn't make it the primary key because a timestamp is the kind of value that gets corrected later, and a key shouldn't change when someone fixes a data-entry mistake. `viewing_id` is `BIGINT` because this is the table that keeps growing.

`amenities` is the one place where a natural key is tempting, since `name` is already unique. I kept a surrogate so that renaming "AC" to "Air conditioning" changes one row and leaves every `listing_amenities` row that points at it alone. `name` is still `UNIQUE`, so nothing is lost.

`listing_amenities` goes the other way. The pair (`property_id`, `amenity_id`) is the whole row, so it is the primary key. A surrogate id would add a column with no meaning and would still need a unique constraint on the pair to stop duplicate tags.

Since every referenced key is generated and never changes, `ON UPDATE` has nothing to do and stays at the default.

### ON DELETE

Both foreign keys on `viewings` are `RESTRICT`. Every count, average and ranking in the query set comes from `viewings`, so cascading a delete from `renters` or `properties` would quietly rewrite past totals. `SET NULL` isn't available because both columns are `NOT NULL`, and a viewing with no renter or no property isn't worth keeping anyway. In practice this means nothing with history can be hard-deleted. A listing that leaves the market gets `is_active = FALSE`, and a renter who leaves gets their row anonymised.

`listing_amenities.property_id` is `CASCADE`. A tag row only describes a listing and means nothing once the listing is gone. Because of the `RESTRICT` on `viewings`, the only properties that can actually be deleted are ones nobody has viewed, like test rows or a listing created by mistake, and there's no reason to make someone clear their tags by hand first.

`listing_amenities.amenity_id` is `RESTRICT`. The amenity list is small and shared. If deleting "Parking" cascaded, every listing would lose its parking tag, and amenity filters would start returning fewer results without any error. `RESTRICT` makes that delete fail until the amenity is no longer used.

### Schema versus application

My rule was that anything checkable from a single row goes in the schema. Every column is `NOT NULL`, because no attribute here has a meaningful absence. `CHECK` constraints reject negative bedrooms and rent, ZIP codes that aren't five digits, durations of zero or less, and viewings dated in the future. These are cheap to check on insert, and a bad duration or a future date would feed straight into the average-duration queries. I'd rather the database refuse the row than rely on every query to filter it out.

Rules that need a second table are left to the application. Nothing in the schema stops a viewing dated before the listing's `listed_on` or before the renter's `joined_at`. Each of those would need a trigger on the busiest table in the database. ZIP-to-city consistency can't be checked at all without a ZIP reference table, which the five-table limit rules out. The schema also allows a viewing against a listing where `is_active = FALSE`, which is intended: a viewing entered late can belong to a listing that has since been filled.

## Reflection

The requirements describe viewings as appointments that renters book. That could mean a `viewings` table holding upcoming bookings as well as finished ones. I modelled it as completed visits only. `duration_min` is `NOT NULL` and `viewed_at` can't be in the future, so a row can only be written once the viewing has happened.

Another designer could reasonably add a status column (booked, completed, cancelled, no-show) and let `duration_min` stay null until the visit ends. That design could power an "upcoming viewings" screen. Mine can't.

I chose completed-only because of how the table is read. Nearly every query is an aggregate: viewings per listing, average duration, listings never viewed, rankings within a city. If bookings lived in the same table, each of those would need `WHERE status = 'completed'`, and leaving it off once gives wrong answers. A listing with one cancelled booking would drop off the never-viewed list, and cities with lots of no-shows would look more popular than they are.

The write pattern points the same way. With completed visits only, `viewings` is append-only: one insert per visit, and the row never changes after that. A bookings table takes an insert and then updates as each appointment moves through its statuses, all on the largest table. The cost is that scheduling has to live somewhere else, and this schema doesn't say where.
