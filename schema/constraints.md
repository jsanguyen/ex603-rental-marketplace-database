# Constraints

Every rule below is enforced by the database, not by application code, so bad data cannot
get in through any client. Constraint names use the pattern `type_table_column` so an
error message points straight at the cause.

## Not null

Every column in every table is `NOT NULL`. There is no attribute in this schema whose
absence carries meaning, so a missing value always means bad data. `NOT NULL` rejects it
at write time.

## Primary keys

| Table | Primary key | Effect |
|-------|-------------|--------|
| `renters` | `renter_id` | one row per renter |
| `properties` | `property_id` | one row per listing |
| `viewings` | `viewing_id` | one row per viewing |
| `amenities` | `amenity_id` | one row per amenity |
| `listing_amenities` | (`property_id`, `amenity_id`) | one row per (listing, amenity) pair, so the same amenity cannot be tagged on a listing twice |

All single-column keys are `GENERATED ALWAYS AS IDENTITY`. The value is assigned by the
database and cannot be supplied or overwritten by a client, so two rows can never collide
on a key and a key never has to change.

## Unique

| Constraint | Columns | Protects against |
|------------|---------|------------------|
| `uq_amenities_name` | `amenities(name)` | the same amenity stored twice under two ids, which would split its listings across both and break amenity filters |
| `uq_viewings_visit` | `viewings(renter_id, property_id, viewed_at)` | the exact same viewing inserted twice, for example from a double-submitted form, which would inflate every count and skew `AVG(duration_min)` |

## Check

| Constraint | Rule | Protects against |
|------------|------|------------------|
| `chk_properties_bedrooms` | `bedrooms >= 0` | negative bedroom counts |
| `chk_properties_rent` | `monthly_rent >= 0` | negative rent |
| `chk_properties_zipcode` | `zipcode ~ '^[0-9]{5}$'` | letters, wrong length, or a missing leading zero in a ZIP code |
| `chk_viewings_duration` | `duration_min > 0` | zero or negative viewing lengths, which would drag down the average-duration queries |
| `chk_viewings_not_future` | `viewed_at <= now()` | viewings dated in the future from a data-entry or timezone mistake |

`chk_viewings_not_future` is evaluated when a row is inserted or updated, which is exactly
when a future date would be entered. If a target PostgreSQL build rejects `now()` inside a
`CHECK`, replace this one constraint with a `BEFORE INSERT OR UPDATE` trigger that raises
on `NEW.viewed_at > now()`.

## Defaults

| Column | Default | Reason |
|--------|---------|--------|
| `renters.joined_at` | `now()` | the sign-up time is the insert time |
| `properties.is_active` | `TRUE` | a new listing is on the market until someone withdraws it |

## Foreign keys and ON DELETE behaviour

There are four foreign keys. `ON UPDATE` is `NO ACTION` (the default) for all of them,
because every referenced key is a generated identity value that never changes, so there
is nothing to cascade on update.

| Foreign key | References | ON DELETE |
|-------------|------------|-----------|
| `viewings.renter_id` | `renters(renter_id)` | `RESTRICT` |
| `viewings.property_id` | `properties(property_id)` | `RESTRICT` |
| `listing_amenities.property_id` | `properties(property_id)` | `CASCADE` |
| `listing_amenities.amenity_id` | `amenities(amenity_id)` | `RESTRICT` |

### `viewings.renter_id` to `renters` — RESTRICT

A viewing is a record of something that happened, and `viewings` is the fact table every
count and average in the query catalogue is built from. If deleting a renter also deleted
their viewings (`CASCADE`), those totals would change retroactively and the history would
be wrong. `renter_id` is `NOT NULL`, so `SET NULL` is not allowed, and it would throw
away the "who" even if it were. `RESTRICT` blocks the delete while any viewing still
points at the renter. To remove a person, anonymise their `renters` row or set a
soft-delete flag instead of deleting it.

### `viewings.property_id` to `properties` — RESTRICT

Same reasoning as `renter_id`. Viewings-per-listing and the city and price-band
aggregates all read from `viewings`, so losing rows because a listing was deleted would
corrupt them. A listing that is no longer available is marked `is_active = FALSE`, not
deleted. `RESTRICT` enforces that a listing with history stays in the table.

### `listing_amenities.property_id` to `properties` — CASCADE

A `listing_amenities` row is not a fact on its own. It only says "this listing advertises
this amenity". If a property is ever genuinely deleted, its tag rows have no meaning and
should go with it, and no query depends on tag rows for properties that no longer exist.
`CASCADE` removes them automatically and prevents orphan rows. In normal operation a
property with viewings cannot be deleted at all because of the `RESTRICT` above, so this
cascade mainly covers test data or a listing that was created by mistake and never
viewed.

### `listing_amenities.amenity_id` to `amenities` — RESTRICT

`amenities` is a small, curated list. Deleting an amenity that is still in use should be a
deliberate act. With `CASCADE`, removing "Parking" would silently strip the parking tag
from every listing that has it, and nobody would notice until a filter started returning
fewer listings. `RESTRICT` blocks the delete until the amenity is no longer referenced.
If an amenity really is unused, `RESTRICT` still allows it to be deleted.

## Indexes

PostgreSQL creates an index for every primary key and unique constraint automatically. It
does not index foreign-key columns, so those are added by hand, along with the columns
the query catalogue groups and filters on.

| Index | Columns | Supports |
|-------|---------|----------|
| `idx_viewings_renter` | `viewings(renter_id)` | the `renter_id` foreign-key check and joins back to `renters` |
| `idx_viewings_property` | `viewings(property_id)` | the `property_id` foreign-key check and viewings-per-listing |
| `idx_viewings_viewed_at` | `viewings(viewed_at)` | time-range filters such as "last 7 days" and monthly rollups |
| `idx_listing_amenities_amenity` | `listing_amenities(amenity_id)` | the `amenity_id` foreign-key check and "listings that have amenity X"; the composite primary key already indexes `property_id` first |
| `idx_properties_city` | `properties(city)` | `GROUP BY city` |
| `idx_properties_zipcode` | `properties(zipcode)` | `GROUP BY zipcode` |

## Reference DDL

The constraint and index statements, ready to paste into `schema.sql`.

```sql
-- renters
ALTER TABLE renters
    ADD CONSTRAINT pk_renters PRIMARY KEY (renter_id);

-- properties
ALTER TABLE properties
    ADD CONSTRAINT pk_properties        PRIMARY KEY (property_id),
    ADD CONSTRAINT chk_properties_bedrooms CHECK (bedrooms >= 0),
    ADD CONSTRAINT chk_properties_rent     CHECK (monthly_rent >= 0),
    ADD CONSTRAINT chk_properties_zipcode  CHECK (zipcode ~ '^[0-9]{5}$');

-- amenities
ALTER TABLE amenities
    ADD CONSTRAINT pk_amenities   PRIMARY KEY (amenity_id),
    ADD CONSTRAINT uq_amenities_name UNIQUE (name);

-- viewings
ALTER TABLE viewings
    ADD CONSTRAINT pk_viewings PRIMARY KEY (viewing_id),
    ADD CONSTRAINT chk_viewings_duration   CHECK (duration_min > 0),
    ADD CONSTRAINT chk_viewings_not_future  CHECK (viewed_at <= now()),
    ADD CONSTRAINT uq_viewings_visit UNIQUE (renter_id, property_id, viewed_at),
    ADD CONSTRAINT fk_viewings_renter
        FOREIGN KEY (renter_id)  REFERENCES renters (renter_id)     ON DELETE RESTRICT,
    ADD CONSTRAINT fk_viewings_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id) ON DELETE RESTRICT;

-- listing_amenities
ALTER TABLE listing_amenities
    ADD CONSTRAINT pk_listing_amenities PRIMARY KEY (property_id, amenity_id),
    ADD CONSTRAINT fk_la_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_la_amenity
        FOREIGN KEY (amenity_id)  REFERENCES amenities (amenity_id)   ON DELETE RESTRICT;

-- indexes on foreign keys and grouping columns
CREATE INDEX idx_viewings_renter           ON viewings (renter_id);
CREATE INDEX idx_viewings_property         ON viewings (property_id);
CREATE INDEX idx_viewings_viewed_at        ON viewings (viewed_at);
CREATE INDEX idx_listing_amenities_amenity ON listing_amenities (amenity_id);
CREATE INDEX idx_properties_city           ON properties (city);
CREATE INDEX idx_properties_zipcode        ON properties (zipcode);
```
