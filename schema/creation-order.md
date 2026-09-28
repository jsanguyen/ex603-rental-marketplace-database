# Task 2.1, Step 1: Creation Order

A table can only be created after every table its foreign keys reference. This page lists
each table in the [ERD](erd.png) with the tables it points at, then derives the order
`schema.sql` creates them in.

## Outgoing references

An arrow here means "has a foreign key to". It runs from the many side of each
relationship in the ERD to the one side.

| Table | References | Foreign keys |
|-------|------------|--------------|
| `renters` | none | none |
| `properties` | none | none |
| `amenities` | none | none |
| `viewings` | `renters`, `properties` | `renter_id` to `renters`, `property_id` to `properties` |
| `listing_amenities` | `properties`, `amenities` | `property_id` to `properties`, `amenity_id` to `amenities` |

There are no cycles and no self-references, so every table can be created with its
foreign keys declared inline. Nothing has to be added later with `ALTER TABLE`.

## Levels

Grouping tables by how many steps they are from a table with no references:

- **Level 0** (no outgoing arrows): `renters`, `properties`, `amenities`
- **Level 1** (only reference level 0): `viewings`, `listing_amenities`

Every level 0 table must exist before any level 1 table. Order within a level does not
matter, because tables in the same level do not reference each other.

## Creation order

| # | Table | Role | Depends on |
|---|-------|------|------------|
| 1 | `renters` | actor | none |
| 2 | `properties` | producer | none |
| 3 | `amenities` | catalog | none |
| 4 | `viewings` | event | `renters` (1), `properties` (2) |
| 5 | `listing_amenities` | junction | `properties` (2), `amenities` (3) |

Each table's dependencies appear above it, so the script has no forward references.

Indexes on foreign-key and grouping columns (see [`constraints.md`](constraints.md)) are
created after all five tables, since each index only needs its own table to exist.

## Drop order

[`schema.sql`](schema.sql) starts by dropping any existing tables so it can be re-run. It
drops them in the reverse order: `listing_amenities`, `viewings`, `amenities`, `properties`, `renters`.
A referenced table cannot be dropped while a foreign key still points at it, so children
go first.
