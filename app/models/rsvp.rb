class Rsvp < ApplicationRecord
  belongs_to :guest
  belongs_to :event
  has_one :seat_assignment, dependent: :destroy
  has_one :seating_table, through: :seat_assignment

  validates :guest_id, uniqueness: { scope: :event_id }
end
