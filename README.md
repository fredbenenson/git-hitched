# Git Hitched

An open-source wedding website with household-based RSVP system, multi-event support, and admin dashboard. Built with Ruby on Rails and Claude Code.

## Stack

- Ruby 3.2.8 / Rails 8.0.4
- PostgreSQL
- Tailwind CSS
- Hotwire (Turbo + Stimulus)
- Stripe (hotel room payments)

## Setup

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Visit `http://localhost:3000`.

## Data Model

```
households  1--*  guests
households  1--*  invitations    *--1  events
guests      1--*  rsvps          *--1  events
households  1--*  hotel_bookings
```

- **Household** -- the invite unit. One code per household, one or more guests.
- **Guest** -- individual person. Has a meal choice (`tbd`, `chicken`, `fish`, `vegetarian`, `vegan`) and optional dietary notes.
- **Event** -- welcome dinner, ceremony, reception, recovery, etc.
- **Invitation** -- links a household to an event (not every household is invited to every event).
- **RSVP** -- per-guest, per-event attendance. `attending` is nullable (`nil` = no response yet).
- **HotelBooking** -- a Stripe-backed hotel room reservation tied to an invite.

## Guest RSVP Flow

1. Visit `/rsvp`
2. Enter invite code or email address
3. See all guests in your household and the events you're invited to
4. For each guest + event: accept or decline
5. Select meal preference and note any dietary restrictions
6. Submit -- can return later with the same code/email to edit

## Routes

| Path | Description |
|---|---|
| `/` | Landing page |
| `/rsvp` | RSVP lookup |
| `/rsvp/:invite_code` | RSVP form for a household |
| `/details` | Venue, schedule, accommodations |
| `/travel` | Travel info |
| `/registry` | Registry links |
| `/faq` | FAQ |
| `/hotel_bookings/new` | Hotel room booking form (Stripe checkout) |
| `/admin` | Admin dashboard (HTTP basic auth) |
| `/admin/households` | CRUD households |
| `/admin/guests` | CRUD guests |
| `/admin/events` | CRUD events |
| `/admin/hotel_bookings` | Hotel booking management + refunds |
| `/admin/import` | CSV import |

## Admin

Protected by HTTP basic auth. Credentials come from environment variables:

```
ADMIN_USER=admin        # default: admin
ADMIN_PASSWORD=password  # default: password
```

Features:
- Dashboard with response rate, per-event attending/declined/pending counts, meal choice breakdown
- Full CRUD for households, guests, events
- Hotel booking management with Stripe refund support
- Search/filter on households and guests
- CSV import for bulk guest loading

### CSV Import Format

```csv
invite_code,name,email,first_name,last_name,is_primary,events
SMITH2025,The Smith Family,smith@example.com,John,Smith,true,Ceremony;Reception
SMITH2025,The Smith Family,smith@example.com,Jane,Smith,false,Ceremony;Reception
```

The `events` column is semicolon-separated. Events must already exist in the database.

## Hotel Bookings (Stripe)

Guests can reserve hotel rooms and pay via Stripe Checkout. The feature is gated behind a page flag in `config/pages.yml` (`hotel: true/false`).

### How it works

1. Guest fills out the booking form at `/hotel_bookings/new` (name, email, phone, rooms)
2. App creates a `HotelBooking` record and a Stripe Checkout Session
3. Guest is redirected to Stripe's hosted payment page
4. On successful payment, a webhook (`/stripe/webhooks`) confirms the booking
5. Confirmation emails are sent to the guest and admin
6. Admins can view all bookings and issue refunds at `/admin/hotel_bookings`

### Configuration

Edit the constants in `app/models/hotel_booking.rb`:

```ruby
NIGHTLY_RATE_CENTS = 220_00  # $220/night
TOTAL_ROOMS = 30             # room block size
PENDING_TIMEOUT = 30.minutes # checkout session expiration
```

Update check-in/check-out dates in `app/controllers/hotel_bookings_controller.rb` (the `new` and `create` actions).

### Stripe setup

Set these environment variables (or add to Rails encrypted credentials under `stripe:`):

```
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

For the webhook, configure Stripe to send `checkout.session.completed` events to `https://yourdomain.com/stripe/webhooks`.

Admin notification emails go to the address in `ADMIN_NOTIFICATION_EMAIL` env var (falls back to the address in `WEDDING[:from_email]`).

### Enabling

1. Set `hotel: true` in `config/pages.yml`
2. A "Hotel" link appears in the nav bar
3. A featured hotel block card appears on the `/stay` page with a "Book Your Room" button
4. Customize the hotel details in `app/views/pages/stay.html.erb` and `app/views/hotel_bookings/new.html.erb`
5. Optionally add hotel photos to `app/assets/images/hotel/` for the booking page carousel

## Customization

This is a template — to make it your own:

1. Update names in `config/initializers/wedding.rb`
2. Update event details in `db/seeds.rb`
3. Customize content pages in `app/views/pages/`
4. Set your domain in `config/environments/production.rb`
5. Update email sender in `config/initializers/wedding.rb`
6. Replace favicon and manifest files in `public/`
7. Configure hotel booking rates/dates (see Hotel Bookings section above)

## Tests

```bash
bin/rails test
```

## Content Pages

Static pages rendered from ERB views. Edit directly:

- `app/views/pages/home.html.erb`
- `app/views/pages/events.html.erb`
- `app/views/pages/travel.html.erb`
- `app/views/pages/stay.html.erb`
- `app/views/pages/explore.html.erb`
- `app/views/pages/attire.html.erb`
- `app/views/pages/faq.html.erb`

## Deployment

Configured for container-based deployment (Dockerfile included). Set these environment variables in production:

```
DATABASE_URL=postgres://...
ADMIN_USER=your_admin_user
ADMIN_PASSWORD=your_secure_password
SECRET_KEY_BASE=...
SENDGRID_API_KEY=...           # for email delivery
STRIPE_SECRET_KEY=sk_...       # for hotel bookings (optional)
STRIPE_WEBHOOK_SECRET=whsec_.. # for hotel bookings (optional)
```

Also supports deployment via [Render](https://render.com) (`render.yaml` included) or [Kamal](https://kamal-deploy.org) (`config/deploy.yml` included).

## License

MIT
