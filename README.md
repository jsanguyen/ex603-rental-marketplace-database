# Rental Marketplace Database

> A relational model of a property-rental marketplace that records renters, property
> listings, the amenities that classify them, and every viewing that gets booked — so
> the platform can answer who is looking at what, how engaged they are, and which
> listings are going stale.

**Author:** Jonathan Nguyen
**Theme:** Rental Marketplace
**Engine:** PostgreSQL 14

---

## The Domain

The platform is a rental marketplace, roughly like Airbnb or the rental side of Zillow. It connects people looking for a place to live with landlords who have space to rent, and its job is to turn browsing into booked viewings. The database exists to support that.

On the supply side, landlords publish properties. A listing has a title, a city, a bedroom count, a monthly rent, and an active/inactive flag showing whether it's still on the market. Each listing is tagged with amenities (parking, in-unit laundry, pet-friendly, air conditioning, and so on). These come from a shared catalogue so that "parking" means the same thing on every listing.

On the demand side, renters browse listings and book viewings, which are appointments to see a property at a specific time. A viewing records who saw which property, when, and how long they spent there.

The schema needs to answer questions from both sides. For renters and the product team: which listings get the most viewing interest, how long renters actually spend at a viewing, and which cities, price bands, or amenities draw the most attention.

For landlords and operations: which active listings have never been viewed, which are priced above the local average, and which have no amenity tags at all.

For data quality: are there viewings with impossible durations or future timestamps, and which renters are most active?

The queries range from single-listing lookups, to grouped aggregates over cities and price bands, to window functions that rank listings within a city.
---

## Schema

The full DDL is [`schema/schema.sql`](schema/schema.sql). It runs top to bottom on an empty
PostgreSQL 14 database, and it can be re-run because it starts by dropping the tables in
reverse order. The ERD is [`schema/erd.png`](schema/erd.png), and its Mermaid source is in
[`schema/schema-definition.md`](schema/schema-definition.md).

```sh
createdb rental_marketplace
psql -d rental_marketplace -v ON_ERROR_STOP=1 -f schema/schema.sql
```

### Tables

Listed in creation order. Each table is created after every table it references
([why this order](schema/creation-order.md)).

| # | Table | Role | What a row is |
|---|-------|------|---------------|
| 1 | `renters` | actor | a platform user who books viewings |
| 2 | `properties` | producer | a rental listing published by a landlord |
| 3 | `amenities` | catalog | one feature from the shared list, such as Parking |
| 4 | `viewings` | event | one completed visit by a renter to a property |
| 5 | `listing_amenities` | junction | one amenity tagged on one listing |

### Design decisions worth noticing

- **History is never deleted.** Both foreign keys on `viewings` are `ON DELETE RESTRICT`,
  so a renter or listing with viewings can't be removed. Listings leave the market with
  `is_active = FALSE`, and a departing renter's row is anonymised. Every count and average
  in the query set is built from `viewings`, so this keeps past numbers from changing.
- **Tags cascade, but the amenity list doesn't.** Deleting a listing takes its
  `listing_amenities` rows with it (`CASCADE`). Deleting an amenity that is still in use
  fails (`RESTRICT`), so retiring "Parking" can't quietly untag every listing.
- **Viewings are completed visits only.** `duration_min` is required and must be positive,
  and `viewed_at` can't be in the future. Bookings and no-shows belong somewhere else.
- **Keys.** Surrogate identity keys everywhere except the junction table, whose primary key
  is the (`property_id`, `amenity_id`) pair. `viewing_id` is `BIGINT` because `viewings`
  is the table that grows. A `UNIQUE` on (`renter_id`, `property_id`, `viewed_at`) stops a
  double-submitted form from recording the same visit twice.
- **Types.** Rent is `NUMERIC(10,2)`, never a float. ZIP codes are `VARCHAR(5)` with a
  five-digit `CHECK`, because they are labels with leading zeros, not numbers.
- **Nothing derived is stored.** Price bands and viewing counts are computed at query
  time, so they can't go stale.
- **Indexes on foreign keys.** PostgreSQL doesn't index foreign-key columns on its own, so
  the script adds them, along with the `city` and `zipcode` columns the reports group on.

The reasoning behind each `ON DELETE` choice and each `CHECK` constraint is in
[`analysis/unit2.md`](analysis/unit2.md), and the full constraint list is in
[`schema/constraints.md`](schema/constraints.md).

### Screenshots

| File | Shows |
|------|-------|
| [`01-reset-block-drops-tables.png`](screenshots/01-reset-block-drops-tables.png) | the reset block dropping all five tables |
| [`02-schema-sql-runs-clean.png`](screenshots/02-schema-sql-runs-clean.png) | the whole script running with no errors: 5 drops, 5 tables and 6 indexes created |
| [`03-tables-and-constraint-counts.png`](screenshots/03-tables-and-constraint-counts.png) | a catalog query confirming all five tables exist, with their key and `CHECK` constraint counts |
