class SeatingTable < ApplicationRecord
  belongs_to :event
  has_many :seat_assignments, dependent: :destroy

  SHAPES = %w[rect curve].freeze

  validates :name, presence: true, uniqueness: { scope: :event_id }
  validates :shape, inclusion: { in: SHAPES }
  validates :top_seats, :bottom_seats, :seat_count, numericality: { greater_than_or_equal_to: 0 }
  validate  :seat_count_matches_layout

  scope :ordered, -> { order(:sort_order, :id) }

  def occupied_count
    seat_assignments.count
  end

  def open_seats
    seat_count - occupied_count
  end

  # Returns ordered list of seat positions belonging to a row.
  # Seat numbering follows a clockwise convention:
  #   1..top_seats         -> top row (left to right)
  #   +1 if has_right_end  -> right end
  #   next bottom_seats    -> bottom row (right to left visually)
  #   +1 if has_left_end   -> left end
  def top_row_positions
    (1..top_seats).to_a
  end

  def right_end_position
    has_right_end ? top_seats + 1 : nil
  end

  # bottom row seat numbers, ordered LEFT-TO-RIGHT visually
  # (numbering itself goes right-to-left, so we reverse for display)
  def bottom_row_positions
    start = top_seats + (has_right_end ? 1 : 0) + 1
    finish = start + bottom_seats - 1
    (start..finish).to_a.reverse
  end

  def left_end_position
    has_left_end ? seat_count : nil
  end

  private

  def seat_count_matches_layout
    expected = top_seats.to_i + bottom_seats.to_i + (has_left_end ? 1 : 0) + (has_right_end ? 1 : 0)
    errors.add(:seat_count, "must equal top + bottom + ends (#{expected})") if expected != seat_count.to_i
  end
end
