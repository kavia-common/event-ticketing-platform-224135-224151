BEGIN;

-- Roles
INSERT INTO roles (name, description)
VALUES
  ('user', 'Default end-user role'),
  ('admin', 'Administrator role')
ON CONFLICT (name) DO NOTHING;

-- Users (password_hash intentionally dummy; real backend should set proper hashes)
INSERT INTO users (email, password_hash, first_name, last_name, is_active, is_email_verified)
VALUES
  ('admin@tickety.local', 'demo-admin-hash', 'Admin', 'User', TRUE, TRUE),
  ('user@tickety.local', 'demo-user-hash', 'Demo', 'User', TRUE, TRUE)
ON CONFLICT (email) DO NOTHING;

-- Assign admin role
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.name = 'admin'
WHERE u.email = 'admin@tickety.local'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.name = 'user'
WHERE u.email = 'user@tickety.local'
ON CONFLICT DO NOTHING;

-- Venue
INSERT INTO venues (name, description, city, state, country, timezone)
VALUES ('Retro Dome', 'A classic venue for retro nights', 'Austin', 'TX', 'US', 'America/Chicago')
ON CONFLICT DO NOTHING;

-- Seat map
INSERT INTO seat_maps (venue_id, name, layout_json)
SELECT v.id, 'Main Map', jsonb_build_object('version', 1, 'note', 'demo layout')
FROM venues v
WHERE v.name = 'Retro Dome'
ON CONFLICT (venue_id, name) DO NOTHING;

-- Seats (small demo grid: Section A, Row A, seats 1-10)
INSERT INTO seats (seat_map_id, section, row_label, seat_number, label, x, y)
SELECT sm.id, 'A', 'A', gs::text, 'A-A-' || gs::text, gs::numeric, 1::numeric
FROM seat_maps sm
JOIN venues v ON v.id = sm.venue_id
CROSS JOIN generate_series(1,10) gs
WHERE v.name = 'Retro Dome' AND sm.name = 'Main Map'
ON CONFLICT (seat_map_id, section, row_label, seat_number) DO NOTHING;

-- Event
INSERT INTO events (venue_id, seat_map_id, title, description, category, status, start_at, end_at, created_by)
SELECT v.id, sm.id, 'Synthwave Night', 'A retro synthwave concert experience.', 'concert', 'published',
       now() + interval '14 days', now() + interval '14 days' + interval '3 hours',
       (SELECT id FROM users WHERE email='admin@tickety.local' LIMIT 1)
FROM venues v
JOIN seat_maps sm ON sm.venue_id = v.id
WHERE v.name = 'Retro Dome' AND sm.name='Main Map'
ON CONFLICT DO NOTHING;

-- Ticket types: GA and VIP Seated
INSERT INTO ticket_types (event_id, name, description, is_seated, inventory_total, sales_start_at, sales_end_at)
SELECT e.id, 'General Admission', 'Standing room', FALSE, 200, now() - interval '1 day', e.start_at
FROM events e
WHERE e.title='Synthwave Night'
ON CONFLICT (event_id, name) DO NOTHING;

INSERT INTO ticket_types (event_id, name, description, is_seated, inventory_total, sales_start_at, sales_end_at)
SELECT e.id, 'VIP Seat', 'Best seats in the house', TRUE, NULL, now() - interval '1 day', e.start_at
FROM events e
WHERE e.title='Synthwave Night'
ON CONFLICT (event_id, name) DO NOTHING;

-- Pricing tiers
INSERT INTO pricing_tiers (ticket_type_id, name, currency, price_cents, fee_cents, start_at, end_at, is_active)
SELECT tt.id, 'Standard', 'USD', 4500, 400, now() - interval '1 day', NULL, TRUE
FROM ticket_types tt
WHERE tt.name='General Admission'
ON CONFLICT (ticket_type_id, name) DO NOTHING;

INSERT INTO pricing_tiers (ticket_type_id, name, currency, price_cents, fee_cents, start_at, end_at, is_active)
SELECT tt.id, 'Standard', 'USD', 12000, 700, now() - interval '1 day', NULL, TRUE
FROM ticket_types tt
WHERE tt.name='VIP Seat'
ON CONFLICT (ticket_type_id, name) DO NOTHING;

-- Promo code
INSERT INTO promo_codes (code, description, discount_type, discount_value, currency, max_redemptions, per_user_limit, starts_at, ends_at, is_active, created_by)
VALUES (
  'RETRO10',
  '10% off for retro fans',
  'percent',
  10,
  'USD',
  1000,
  1,
  now() - interval '1 day',
  now() + interval '30 days',
  TRUE,
  (SELECT id FROM users WHERE email='admin@tickety.local' LIMIT 1)
)
ON CONFLICT (code) DO NOTHING;

COMMIT;
