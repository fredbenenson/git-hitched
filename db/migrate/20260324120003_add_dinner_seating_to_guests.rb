class AddDinnerSeatingToGuests < ActiveRecord::Migration[8.0]
  def change
    add_column :guests, :reception_seating, :integer, default: 0, null: false
    add_column :guests, :needs_highchair, :boolean, default: false, null: false
  end
end
