# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_24_120006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "event_invites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "invite_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_invites_on_event_id"
    t.index ["invite_id", "event_id"], name: "index_event_invites_on_invite_id_and_event_id", unique: true
    t.index ["invite_id"], name: "index_event_invites_on_invite_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "address"
    t.string "attire"
    t.text "attire_description"
    t.datetime "created_at", null: false
    t.date "date"
    t.text "description"
    t.string "image"
    t.string "location"
    t.string "location_url"
    t.string "maps_url"
    t.string "meal_type"
    t.string "name"
    t.integer "sort_order"
    t.time "start_time"
    t.string "subtitle"
    t.string "time_description"
    t.datetime "updated_at", null: false
  end

  create_table "guests", force: :cascade do |t|
    t.integer "age"
    t.datetime "created_at", null: false
    t.text "dietary_notes"
    t.string "email"
    t.string "first_name", null: false
    t.bigint "invite_id", null: false
    t.boolean "is_child", default: false, null: false
    t.boolean "is_primary", default: false, null: false
    t.string "last_name"
    t.integer "meal_choice", default: 0
    t.boolean "needs_childcare", default: false, null: false
    t.boolean "needs_highchair", default: false, null: false
    t.integer "reception_seating", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["invite_id"], name: "index_guests_on_invite_id"
  end

  create_table "hotel_bookings", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.date "check_in", null: false
    t.date "check_out", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "usd", null: false
    t.string "email", null: false
    t.string "guest_name", null: false
    t.bigint "invite_id", null: false
    t.text "notes"
    t.string "phone"
    t.datetime "refunded_at"
    t.integer "rooms", default: 1, null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.datetime "updated_at", null: false
    t.index ["invite_id"], name: "index_hotel_bookings_on_invite_id"
    t.index ["status"], name: "index_hotel_bookings_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_hotel_bookings_on_stripe_checkout_session_id", unique: true
  end

  create_table "invites", force: :cascade do |t|
    t.boolean "attending"
    t.boolean "children_attending", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "linked_invite_id"
    t.string "name", null: false
    t.text "notes"
    t.datetime "responded_at"
    t.boolean "send_reminder", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["linked_invite_id"], name: "index_invites_on_linked_invite_id"
  end

  create_table "rsvps", force: :cascade do |t|
    t.boolean "attending"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "guest_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_rsvps_on_event_id"
    t.index ["guest_id", "event_id"], name: "index_rsvps_on_guest_id_and_event_id", unique: true
    t.index ["guest_id"], name: "index_rsvps_on_guest_id"
  end

  create_table "seat_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "locked", default: false, null: false
    t.bigint "rsvp_id", null: false
    t.integer "seat_position", null: false
    t.bigint "seating_table_id", null: false
    t.datetime "updated_at", null: false
    t.index ["rsvp_id"], name: "index_seat_assignments_on_rsvp_id"
    t.index ["rsvp_id"], name: "index_seat_assignments_on_rsvp_id_uniq", unique: true
    t.index ["seating_table_id", "seat_position"], name: "index_seat_assignments_on_table_and_position", unique: true
    t.index ["seating_table_id"], name: "index_seat_assignments_on_seating_table_id"
  end

  create_table "seating_tables", force: :cascade do |t|
    t.integer "bottom_seats", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.boolean "has_left_end", default: false, null: false
    t.boolean "has_right_end", default: false, null: false
    t.string "name", null: false
    t.integer "pos_x", default: 0, null: false
    t.integer "pos_y", default: 0, null: false
    t.integer "seat_count", null: false
    t.string "shape", default: "rect", null: false
    t.integer "sort_order", default: 0, null: false
    t.integer "top_seats", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "name"], name: "index_seating_tables_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_seating_tables_on_event_id"
  end

  add_foreign_key "event_invites", "events"
  add_foreign_key "event_invites", "invites"
  add_foreign_key "guests", "invites"
  add_foreign_key "hotel_bookings", "invites"
  add_foreign_key "invites", "invites", column: "linked_invite_id"
  add_foreign_key "rsvps", "events"
  add_foreign_key "rsvps", "guests"
  add_foreign_key "seat_assignments", "rsvps"
  add_foreign_key "seat_assignments", "seating_tables"
  add_foreign_key "seating_tables", "events"
end
