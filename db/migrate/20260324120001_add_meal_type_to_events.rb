class AddMealTypeToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :meal_type, :string
  end
end
