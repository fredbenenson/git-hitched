class CreateHotelBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :hotel_bookings do |t|
      t.references :invite, null: false, foreign_key: true
      t.string :guest_name, null: false
      t.string :email, null: false
      t.string :phone
      t.date :check_in, null: false
      t.date :check_out, null: false
      t.integer :rooms, null: false, default: 1
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "usd"
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.string :status, null: false, default: "pending"
      t.text :notes
      t.datetime :confirmed_at
      t.datetime :refunded_at

      t.timestamps
    end

    add_index :hotel_bookings, :stripe_checkout_session_id, unique: true
    add_index :hotel_bookings, :status
  end
end
