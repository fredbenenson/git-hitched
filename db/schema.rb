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

ActiveRecord::Schema[8.0].define(version: 2026_03_23_155929) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "event_invites", force: :cascade do |t|
    t.bigint "invite_id", null: false
    t.bigint "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_invites_on_event_id"
    t.index ["invite_id", "event_id"], name: "index_event_invites_on_invite_id_and_event_id", unique: true
    t.index ["invite_id"], name: "index_event_invites_on_invite_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "name"
    t.date "date"
    t.time "start_time"
    t.string "location"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location_url"
    t.string "address"
    t.string "maps_url"
    t.string "time_description"
    t.string "attire"
    t.text "attire_description"
    t.string "subtitle"
    t.integer "sort_order"
    t.string "image"
  end

  create_table "guests", force: :cascade do |t|
    t.bigint "invite_id", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.integer "meal_choice", default: 0
    t.text "dietary_notes"
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_child", default: false, null: false
    t.boolean "needs_childcare", default: false, null: false
    t.integer "age"
    t.index ["invite_id"], name: "index_guests_on_invite_id"
  end

  create_table "hotel_bookings", force: :cascade do |t|
    t.bigint "invite_id", null: false
    t.string "guest_name", null: false
    t.string "email", null: false
    t.string "phone"
    t.date "check_in", null: false
    t.date "check_out", null: false
    t.integer "rooms", default: 1, null: false
    t.integer "amount_cents", null: false
    t.string "currency", default: "usd", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.string "status", default: "pending", null: false
    t.text "notes"
    t.datetime "confirmed_at"
    t.datetime "refunded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_id"], name: "index_hotel_bookings_on_invite_id"
    t.index ["status"], name: "index_hotel_bookings_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_hotel_bookings_on_stripe_checkout_session_id", unique: true
  end

  create_table "invites", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "children_attending", default: false, null: false
    t.boolean "attending"
    t.text "notes"
  end

  create_table "rsvps", force: :cascade do |t|
    t.bigint "guest_id", null: false
    t.bigint "event_id", null: false
    t.boolean "attending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_rsvps_on_event_id"
    t.index ["guest_id", "event_id"], name: "index_rsvps_on_guest_id_and_event_id", unique: true
    t.index ["guest_id"], name: "index_rsvps_on_guest_id"
  end

  add_foreign_key "event_invites", "events"
  add_foreign_key "event_invites", "invites"
  add_foreign_key "guests", "invites"
  add_foreign_key "hotel_bookings", "invites"
  add_foreign_key "rsvps", "events"
  add_foreign_key "rsvps", "guests"
end
