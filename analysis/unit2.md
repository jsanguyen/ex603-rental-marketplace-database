# Task 2.2: Reasoning

## Constraints table

| Foreign key | ON DELETE | Reason |
|-------------|-----------|--------|
| `viewings.renter_id` -> `renters` | `RESTRICT` | A viewing already happened. Deleting it along with the renter changes every count that depends on it. |
| `viewings.property_id` -> `properties` | `RESTRICT` | The listing, city and price-band reports all come from viewing history, so a listing that has been viewed has to stay. |
| `listing_amenities.property_id` -> `properties` | `CASCADE` | A tag describes one listing. Once the listing is gone the tag means nothing. |
| `listing_amenities.amenity_id` -> `amenities` | `RESTRICT` | Deleting an amenity that listings still use should fail, not silently strip the tag off all of them. |

`ON UPDATE` is left at the default on all four. Every referenced key is an identity value the database assigns and never changes, so there's nothing to propagate.

### `viewings.renter_id`: RESTRICT

What actually happens here is a renter leaving: they close their account, or ops removes a spam account. Either way their viewings shouldn't go with them. Those rows aren't really about the renter. Landlords see them as their listing's history, and every aggregate in the query set is computed from them: viewings per listing, average duration, most active renters, listings never viewed.

With `CASCADE`, closing one account would silently change numbers other people have already looked at. A listing's count drops after the fact. A listing only that renter viewed shows up on the never-viewed list again. Last month's totals stop matching last month's report. `SET NULL` is out because `renter_id` is `NOT NULL`, and even if it weren't, a viewing with no renter is useless for the per-renter queries.

The downside is that a renter with any history can never be deleted. Leaving the platform has to mean anonymising the row instead, e.g. `display_name` becomes "Deleted user". A privacy deletion request would go the same way: personal data gone, anonymous facts kept.

### `viewings.property_id`: RESTRICT

Listings come off the market because they got rented, the landlord pulled them, or the landlord left. The platform handles all of those with `is_active = FALSE` and keeps the row. A hard delete would only ever be someone running one by hand, and `RESTRICT` makes that fail as long as any viewing still points at the listing.

Who'd be hurt otherwise: renters, whose own history includes the listing; ops, whose city and price-band reports include its viewings; other landlords, who compare against the local average. Deleting one popular listing under `CASCADE` lowers the city's viewing total, moves the average duration, and makes every renter who saw it look less active. It would also let a landlord delete a listing that did badly and take the evidence with it. `SET NULL` is impossible for the same `NOT NULL` reason.

### `listing_amenities.property_id`: CASCADE

This case is narrower than it looks. Because `viewings.property_id` is `RESTRICT`, the only listings that can be deleted at all are ones nobody has ever viewed: a duplicate posted by accident, a listing with the wrong address that got replaced straight away, test data. When one of those goes, its tags go too.

Nothing is lost. The tags only described that listing, and the amenity filters shouldn't return it anymore anyway. `RESTRICT` would make the same delete fail until someone removed each tag row by hand first. That extra step protects nothing, since a tag row is worthless on its own, and if the step gets skipped the delete just doesn't work. `SET NULL` isn't an option because `property_id` is part of the primary key.

### `listing_amenities.amenity_id`: RESTRICT

This one is about ops cleaning up the amenity catalogue: retiring an amenity, or merging "AC" into "Air conditioning". It affects every landlord whose listing carries the tag and every renter who filters on it.

Cascade would mean deleting "Pet friendly" removes the tag from every listing that has it, with no error anywhere. The pet-friendly filter starts returning nothing. Landlords don't know their listings changed. The "listings with no amenity tags" report grows with listings nobody actually untagged. `RESTRICT` makes the delete fail while the amenity is in use, so a merge has to be done in the right order: repoint the tag rows to the surviving amenity, then delete the old one. An amenity no listing uses can still be deleted normally.

## CHECK constraints

### `chk_properties_bedrooms`: `bedrooms >= 0`

Blocks negative bedroom counts. These usually come from an import that uses `-1` for "unknown", or a typo on the listing form. Zero is fine; that's a studio. A negative value would drag down any average-bedrooms figure and fall outside every bedroom filter, so the listing would just vanish from search and nobody would notice.

### `chk_properties_rent`: `monthly_rent >= 0`

Blocks negative rent. Could be a sign flipped in an import, or someone entering a move-in discount as negative rent instead of lowering the price. One negative value pulls down the city average that the "priced above the local average" query compares against, so other listings in the city look overpriced. Zero rent is still allowed, though, so a listing whose price hasn't been set yet could go in as `0.00` and skew the same average. `monthly_rent > 0` would close that.

### `chk_properties_zipcode`: `zipcode ~ '^[0-9]{5}$'`

Rejects any ZIP that isn't exactly five digits. `VARCHAR(5)` already stops values that are too long, but it happily accepts `2134`, `ABCDE`, or a value with a trailing space. Spreadsheet imports are the likely culprit: `02134` gets read as a number, loses the leading zero, arrives as `2134`. A ZIP+4 like `78701-1234` getting truncated is another. The price analysis groups by `zipcode`, so a bad value either splits one area into two groups or makes a group of one.

### `chk_viewings_duration`: `duration_min > 0`

Rejects zero or negative durations. Negative happens when check-in and check-out are entered backwards and the duration is computed from them. Zero happens when a form fills a blank with `0`, or when a no-show gets recorded as a viewing. A no-show isn't a completed viewing, and the table only holds completed ones (see Unit 1). All of these pull down the average-duration figures, which are the main thing the queries aggregate. There's no upper bound, so a 600-minute viewing would go in. Implausibly long durations are left to the data-quality query because there's no single cutoff that's clearly wrong.

### `chk_viewings_not_future`: `viewed_at <= now()`

Rejects viewings dated in the future. Could come from an appointment entered when it was booked instead of after it happened, a mistyped year, or a timezone mix-up. `viewed_at` is a `TIMESTAMP` without time zone, so a value written as UTC by one client and read as local time by another can land hours ahead. A future viewing would count toward "viewings this month" before it happened, and if the appointment got cancelled the row would sit there as a visit that never took place.

`now()` moves, which is normally a reason not to use it in a `CHECK`. It's safe here because time only goes one way: a row that passed on insert still passes if the constraint is re-checked later, say during a restore.