class CreateSeatingTables < ActiveRecord::Migration[8.0]
  def change
    create_table :seating_tables do |t|
      t.references :event, null: false, foreign_key: true
      t.string  :name,           null: false
      t.string  :shape,          null: false, default: "rect"
      t.integer :top_seats,      null: false, default: 0
      t.integer :bottom_seats,   null: false, default: 0
      t.boolean :has_left_end,   null: false, default: false
      t.boolean :has_right_end,  null: false, default: false
      t.integer :seat_count,     null: false
      t.integer :pos_x,          null: false, default: 0
      t.integer :pos_y,          null: false, default: 0
      t.integer :sort_order,     null: false, default: 0
      t.timestamps
    end

    add_index :seating_tables, [ :event_id, :name ], unique: true

    create_table :seat_assignments do |t|
      t.references :rsvp,           null: false, foreign_key: true
      t.references :seating_table,  null: false, foreign_key: true
      t.integer :seat_position,     null: false
      t.boolean :locked,            null: false, default: false
      t.timestamps
    end

    add_index :seat_assignments, :rsvp_id, unique: true, name: "index_seat_assignments_on_rsvp_id_uniq"
    add_index :seat_assignments, [ :seating_table_id, :seat_position ], unique: true, name: "index_seat_assignments_on_table_and_position"
  end
end
