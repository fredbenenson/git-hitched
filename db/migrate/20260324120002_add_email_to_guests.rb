class AddEmailToGuests < ActiveRecord::Migration[8.0]
  def change
    add_column :guests, :email, :string
  end
end
