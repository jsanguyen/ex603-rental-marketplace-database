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