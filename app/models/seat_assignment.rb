class SeatAssignment < ApplicationRecord
  belongs_to :rsvp
  belongs_to :seating_table

  has_one :event, through: :seating_table
  has_one :guest, through: :rsvp

  validates :seat_position, presence: true, numericality: { greater_than: 0 }
  validates :rsvp_id, uniqueness: true
  validates :seat_position, uniqueness: { scope: :seating_table_id }
  validate  :seat_position_within_table
  validate  :rsvp_event_matches_table_event

  private

  def seat_position_within_table
    return unless seating_table && seat_position
    if seat_position > seating_table.seat_count
      errors.add(:seat_position, "exceeds table capacity (#{seating_table.seat_count})")
    end
  end

  def rsvp_event_matches_table_event
    return unless rsvp && seating_table
    if rsvp.event_id != seating_table.event_id
      errors.add(:rsvp_id, "must be for the same event as the table")
    end
  end
end
