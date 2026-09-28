-- =================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme: Rental Marketplace
-- Author: Jonathan Nguyen
-- Target: PostgreSQL 14+
-- =================================================================
-- Reset. Reverse creation order, so no dependency blocks a drop.
-- Creation order: renters, properties, amenities, viewings, listing_amenities
-- (see creation-order.md in this folder).

DROP TABLE IF EXISTS listing_amenities CASCADE;
DROP TABLE IF EXISTS viewings          CASCADE;
DROP TABLE IF EXISTS amenities         CASCADE;
DROP TABLE IF EXISTS properties        CASCADE;
DROP TABLE IF EXISTS renters           CASCADE;

-- =================================================================
-- Types (see schema/schema-definition.md for each column's domain)
--   Surrogate keys  INTEGER GENERATED ALWAYS AS IDENTITY, except
--                   viewings.viewing_id, which is BIGINT because the
--                   event table grows by one row per appointment.
--   Short text      VARCHAR(n) sized to the data, e.g. VARCHAR(5) for
--                   a US ZIP code. No column needs TEXT.
--   Flag            BOOLEAN, compared with TRUE / FALSE.
--   Counts          SMALLINT for bedrooms (the ERD's choice; a unit
--                   never has more than a handful), INTEGER elsewhere.
--   Money           NUMERIC(10,2), never FLOAT.
--   Point in time   TIMESTAMP.  Date only  DATE.
--   Duration        INTEGER with the unit in the name: duration_min.
--   Derived values  None stored. Price bands and viewing counts are
--                   computed at query time: band edges are a reporting
--                   choice that can change without a schema change,
--                   and a stored count would go stale on every insert.
-- There are no ratings or scores in this schema, so NUMERIC(3,2) is
-- not used.
-- =================================================================

-- ----------------------------------------------------------------
-- 1. renters (actor) — first, because it references nothing.
--  A renter is a platform user who books viewings.
-- ----------------------------------------------------------------
CREATE TABLE renters (
    renter_id     INTEGER       GENERATED ALWAYS AS IDENTITY,
    display_name  VARCHAR(100)  NOT NULL,
    joined_at     TIMESTAMP     NOT NULL DEFAULT now(),
    CONSTRAINT pk_renters PRIMARY KEY (renter_id)
);

-- ----------------------------------------------------------------
-- 2. properties (producer) — references nothing.
--  A rental listing published by a landlord. Listings that leave
--  the market are set is_active = FALSE, not deleted.
-- ----------------------------------------------------------------
CREATE TABLE properties (
    property_id    INTEGER        GENERATED ALWAYS AS IDENTITY,
    title          VARCHAR(150)   NOT NULL,
    city           VARCHAR(80)    NOT NULL,
    zipcode        VARCHAR(5)     NOT NULL,
    bedrooms       SMALLINT       NOT NULL,
    monthly_rent   NUMERIC(10,2)  NOT NULL,
    is_active      BOOLEAN        NOT NULL DEFAULT TRUE,
    landlord_name  VARCHAR(100)   NOT NULL,
    listed_on      DATE           NOT NULL,
    CONSTRAINT pk_properties PRIMARY KEY (property_id),
    CONSTRAINT chk_properties_bedrooms CHECK (bedrooms >= 0),
    CONSTRAINT chk_properties_rent     CHECK (monthly_rent >= 0),
    CONSTRAINT chk_properties_zipcode  CHECK (zipcode ~ '^[0-9]{5}$')
);

-- ----------------------------------------------------------------
-- 3. amenities (catalog) — references nothing.
--  Shared list of features, so each amenity has one name.
-- ----------------------------------------------------------------
CREATE TABLE amenities (
    amenity_id  INTEGER      GENERATED ALWAYS AS IDENTITY,
    name        VARCHAR(60)  NOT NULL,
    CONSTRAINT pk_amenities      PRIMARY KEY (amenity_id),
    CONSTRAINT uq_amenities_name UNIQUE (name)
);

-- ----------------------------------------------------------------
-- 4. viewings (event) — after renters (1) and properties (2).
--  One row per appointment. Both FKs are RESTRICT: a viewing is
--  history, and deleting it would silently change every count.
-- ----------------------------------------------------------------
CREATE TABLE viewings (
    viewing_id    BIGINT     GENERATED ALWAYS AS IDENTITY,
    renter_id     INTEGER    NOT NULL,
    property_id   INTEGER    NOT NULL,
    viewed_at     TIMESTAMP  NOT NULL,
    duration_min  INTEGER    NOT NULL,
    CONSTRAINT pk_viewings PRIMARY KEY (viewing_id),
    CONSTRAINT uq_viewings_visit UNIQUE (renter_id, property_id, viewed_at),
    CONSTRAINT chk_viewings_duration   CHECK (duration_min > 0),
    CONSTRAINT chk_viewings_not_future CHECK (viewed_at <= now()),
    CONSTRAINT fk_viewings_renter
        FOREIGN KEY (renter_id) REFERENCES renters (renter_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_viewings_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------
-- 5. listing_amenities (junction) — after properties (2) and
--  amenities (3). Resolves the M:N between them. The primary key
--  is the pair of foreign keys, not a new id, so a listing cannot
--  carry the same amenity twice.
-- ----------------------------------------------------------------
CREATE TABLE listing_amenities (
    property_id  INTEGER  NOT NULL,
    amenity_id   INTEGER  NOT NULL,
    CONSTRAINT pk_listing_amenities PRIMARY KEY (property_id, amenity_id),
    CONSTRAINT fk_la_property
        FOREIGN KEY (property_id) REFERENCES properties (property_id)
        ON DELETE CASCADE,   -- a tag means nothing without its listing
    CONSTRAINT fk_la_amenity
        FOREIGN KEY (amenity_id) REFERENCES amenities (amenity_id)
        ON DELETE RESTRICT   -- removing an in-use amenity must be deliberate
);

-- ----------------------------------------------------------------
-- Indexes. PostgreSQL indexes primary keys and UNIQUE constraints
-- itself, but not foreign-key columns, so those are added here
-- along with the columns the queries group and filter on.
-- ----------------------------------------------------------------
CREATE INDEX idx_viewings_renter           ON viewings (renter_id);
CREATE INDEX idx_viewings_property         ON viewings (property_id);
CREATE INDEX idx_viewings_viewed_at        ON viewings (viewed_at);
CREATE INDEX idx_listing_amenities_amenity ON listing_amenities (amenity_id);
CREATE INDEX idx_properties_city           ON properties (city);
CREATE INDEX idx_properties_zipcode        ON properties (zipcode);
