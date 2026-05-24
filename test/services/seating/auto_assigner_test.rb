require "test_helper"

class Seating::AutoAssignerTest < ActiveSupport::TestCase
  setup do
    @event = events(:welcome)
    # Wipe seeded fixture state we don't want to lean on.
    SeatAssignment.delete_all
    @event.seating_tables.destroy_all
    @event.rsvps.destroy_all
    Guest.where.not(id: guests(:mike_johnson).id).destroy_all  # keep one untouched primary
    Invite.where.not(id: [ invites(:smiths).id, invites(:johnsons).id ]).destroy_all
  end

  test "assigns all attending guests when capacity is sufficient" do
    table = create_table(name: "T1", top: 4, bottom: 4)
    create_attending_invite(name: "Solo A", size: 1)
    create_attending_invite(name: "Couple B", size: 2)
    create_attending_invite(name: "Family C", size: 3)

    result = Seating::AutoAssigner.new(@event).call

    assert_equal 6, result.assigned_count
    assert_empty result.unseated
    assert_equal 6, SeatAssignment.joins(:seating_table).where(seating_tables: { event_id: @event.id }).count

    # Largest group (3) goes to the only table and gets the first 3 positions.
    family_positions = positions_for(table, "Family C")
    assert_equal [ 1, 2, 3 ], family_positions.sort
  end

  test "preserves locked assignments when re-running" do
    table = create_table(name: "T1", top: 3, bottom: 3)
    pinned = create_attending_invite(name: "Anchor", size: 1).first
    SeatAssignment.create!(rsvp: pinned, seating_table: table, seat_position: 4, locked: true)

    other = create_attending_invite(name: "Other", size: 2)

    result = Seating::AutoAssigner.new(@event).call

    assert_equal 2, result.assigned_count
    pinned_row = SeatAssignment.find_by!(rsvp: pinned)
    assert pinned_row.locked
    assert_equal 4, pinned_row.seat_position
    refute_includes other.map { |r| SeatAssignment.find_by(rsvp: r).seat_position }, 4
  end

  test "splits a group across tables when no single table has room" do
    small = create_table(name: "T1", top: 1, bottom: 1)  # 2 seats
    big   = create_table(name: "T2", top: 3, bottom: 2)  # 5 seats
    create_attending_invite(name: "Big Family", size: 6)

    result = Seating::AutoAssigner.new(@event).call

    assert_equal 6, result.assigned_count
    big_positions   = positions_for(big,   "Big Family")
    small_positions = positions_for(small, "Big Family")
    # Worst-fit puts the first chunk at the larger table; remainder lands at the smaller one.
    assert_equal 5, big_positions.size
    assert_equal 1, small_positions.size
  end

  test "groups linked invites together" do
    table = create_table(name: "T1", top: 4, bottom: 4)
    primary = create_attending_invite(name: "Primary", size: 2)
    linked  = create_attending_invite(name: "Linked", size: 2, linked_to: primary.first.guest.invite)
    create_attending_invite(name: "Filler", size: 2)

    Seating::AutoAssigner.new(@event).call

    primary_table = SeatAssignment.find_by!(rsvp: primary.first).seating_table_id
    linked_table  = SeatAssignment.find_by!(rsvp: linked.first).seating_table_id
    assert_equal primary_table, linked_table, "linked invites must share a table"
  end

  test "returns unseated members when capacity is exceeded" do
    create_table(name: "T1", top: 1, bottom: 1)  # 2 seats
    invite = create_attending_invite(name: "Trio", size: 3)

    result = Seating::AutoAssigner.new(@event).call

    assert_equal 2, result.assigned_count
    assert_equal 1, result.unseated.size
    assert_includes invite.map(&:id), result.unseated.first.id
  end

  test "clears prior unlocked assignments on each run" do
    table = create_table(name: "T1", top: 2, bottom: 2)
    invite = create_attending_invite(name: "Pair", size: 2)
    Seating::AutoAssigner.new(@event).call
    first_run_positions = invite.map { |r| SeatAssignment.find_by(rsvp: r).seat_position }.sort

    # Re-run should not duplicate rows or error on uniqueness.
    Seating::AutoAssigner.new(@event).call
    second_run_positions = invite.map { |r| SeatAssignment.find_by(rsvp: r).seat_position }.sort

    assert_equal first_run_positions, second_run_positions
    assert_equal 2, SeatAssignment.joins(:seating_table).where(seating_tables: { event_id: @event.id }).count
  end

  private

  def create_table(name:, top:, bottom:, left_end: false, right_end: false)
    SeatingTable.create!(
      event: @event,
      name: name,
      shape: "rect",
      top_seats: top,
      bottom_seats: bottom,
      has_left_end: left_end,
      has_right_end: right_end,
      seat_count: top + bottom + (left_end ? 1 : 0) + (right_end ? 1 : 0),
      pos_x: 50,
      pos_y: 50,
      sort_order: @event.seating_tables.count + 1
    )
  end

  # Creates an invite + N guests + N attending RSVPs. Returns the RSVPs.
  def create_attending_invite(name:, size:, linked_to: nil)
    invite = Invite.create!(
      name: name,
      email: "#{name.parameterize}@example.com",
      linked_invite: linked_to
    )
    size.times.map do |i|
      guest = Guest.create!(invite: invite, first_name: "#{name.tr(' ', '')}#{i}", last_name: name, is_primary: i.zero?)
      Rsvp.create!(guest: guest, event: @event, attending: true)
    end
  end

  def positions_for(table, invite_name)
    SeatAssignment
      .joins(rsvp: { guest: :invite })
      .where(seating_table: table, invites: { name: invite_name })
      .pluck(:seat_position)
  end
end
