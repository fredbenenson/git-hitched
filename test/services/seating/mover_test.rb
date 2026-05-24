require "test_helper"

class Seating::MoverTest < ActiveSupport::TestCase
  setup do
    @event = events(:welcome)
    SeatAssignment.delete_all
    @event.seating_tables.destroy_all
    @event.rsvps.destroy_all
    Guest.where.not(id: guests(:mike_johnson).id).destroy_all
    Invite.where.not(id: [ invites(:smiths).id, invites(:johnsons).id ]).destroy_all
  end

  test "moves a seated rsvp to an empty seat" do
    table = create_table(name: "T1", top: 2, bottom: 2)
    a = attending_rsvp(name: "Alice")
    SeatAssignment.create!(rsvp: a, seating_table: table, seat_position: 1)

    result = move([ a.id ], { type: "seat", table_id: table.id, position: 3 })

    assert result.ok?
    assert_equal 3, SeatAssignment.find_by!(rsvp: a).seat_position
    assert_equal [ table.id ], result.affected_table_ids
    refute result.rail_changed
  end

  test "swaps two seated rsvps when dropping on a filled seat" do
    table = create_table(name: "T1", top: 2, bottom: 2)
    a = attending_rsvp(name: "Alice")
    b = attending_rsvp(name: "Bob")
    SeatAssignment.create!(rsvp: a, seating_table: table, seat_position: 1)
    SeatAssignment.create!(rsvp: b, seating_table: table, seat_position: 2)

    result = move([ a.id ], { type: "seat", table_id: table.id, position: 2 })

    assert result.ok?
    assert_equal 2, SeatAssignment.find_by!(rsvp: a).seat_position
    assert_equal 1, SeatAssignment.find_by!(rsvp: b).seat_position
    refute result.rail_changed
  end

  test "swaps across tables" do
    t1 = create_table(name: "T1", top: 1, bottom: 1)
    t2 = create_table(name: "T2", top: 1, bottom: 1)
    a = attending_rsvp(name: "Alice")
    b = attending_rsvp(name: "Bob")
    SeatAssignment.create!(rsvp: a, seating_table: t1, seat_position: 1)
    SeatAssignment.create!(rsvp: b, seating_table: t2, seat_position: 1)

    result = move([ a.id ], { type: "seat", table_id: t2.id, position: 1 })

    assert result.ok?
    assert_equal t2.id, SeatAssignment.find_by!(rsvp: a).seating_table_id
    assert_equal t1.id, SeatAssignment.find_by!(rsvp: b).seating_table_id
    assert_equal [ t1.id, t2.id ].sort, result.affected_table_ids.sort
  end

  test "bumps a seated rsvp to the rail when an unseated rsvp drops on their seat" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    seated = attending_rsvp(name: "Seated")
    floater = attending_rsvp(name: "Floater")
    SeatAssignment.create!(rsvp: seated, seating_table: table, seat_position: 1)

    result = move([ floater.id ], { type: "seat", table_id: table.id, position: 1 })

    assert result.ok?
    assert_equal table.id, SeatAssignment.find_by!(rsvp: floater).seating_table_id
    assert_nil SeatAssignment.find_by(rsvp: seated)
    assert result.rail_changed
  end

  test "assigns an unseated rsvp to an empty seat" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    a = attending_rsvp(name: "Alice")

    result = move([ a.id ], { type: "seat", table_id: table.id, position: 2 })

    assert result.ok?
    assert_equal 2, SeatAssignment.find_by!(rsvp: a).seat_position
    assert result.rail_changed
  end

  test "refuses to move into a locked seat" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    pinned = attending_rsvp(name: "Pinned")
    a = attending_rsvp(name: "Alice")
    SeatAssignment.create!(rsvp: pinned, seating_table: table, seat_position: 1, locked: true)

    result = move([ a.id ], { type: "seat", table_id: table.id, position: 1 })

    refute result.ok?
    assert_equal :dest_locked, result.error
    assert_equal 1, SeatAssignment.find_by!(rsvp: pinned).seat_position
    assert_nil SeatAssignment.find_by(rsvp: a)
  end

  test "refuses to move a locked rsvp" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    pinned = attending_rsvp(name: "Pinned")
    SeatAssignment.create!(rsvp: pinned, seating_table: table, seat_position: 1, locked: true)

    result = move([ pinned.id ], { type: "seat", table_id: table.id, position: 2 })

    refute result.ok?
    assert_equal :source_locked, result.error
    assert_equal 1, SeatAssignment.find_by!(rsvp: pinned).seat_position
  end

  test "dropping a guest onto their own seat is a no-op success" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    a = attending_rsvp(name: "Alice")
    SeatAssignment.create!(rsvp: a, seating_table: table, seat_position: 1)

    result = move([ a.id ], { type: "seat", table_id: table.id, position: 1 })

    assert result.ok?
    assert_empty result.affected_table_ids
    refute result.rail_changed
  end

  test "multi-drop to a table fills next N unlocked positions in numerical order" do
    table = create_table(name: "T1", top: 3, bottom: 3)
    SeatAssignment.create!(rsvp: attending_rsvp(name: "Occupant"), seating_table: table, seat_position: 1)
    a = attending_rsvp(name: "A")
    b = attending_rsvp(name: "B")
    c = attending_rsvp(name: "C")

    result = move([ a.id, b.id, c.id ], { type: "table", table_id: table.id })

    assert result.ok?
    assert_equal 2, SeatAssignment.find_by!(rsvp: a).seat_position
    assert_equal 3, SeatAssignment.find_by!(rsvp: b).seat_position
    assert_equal 4, SeatAssignment.find_by!(rsvp: c).seat_position
  end

  test "multi-drop to a table refuses the whole drop when not enough room" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    a = attending_rsvp(name: "A")
    b = attending_rsvp(name: "B")
    c = attending_rsvp(name: "C")

    result = move([ a.id, b.id, c.id ], { type: "table", table_id: table.id })

    refute result.ok?
    assert_equal :not_enough_room, result.error
    assert_equal 0, SeatAssignment.count
  end

  test "multi-drop to a table skips locked positions" do
    table = create_table(name: "T1", top: 2, bottom: 2)
    pinned = attending_rsvp(name: "Pinned")
    SeatAssignment.create!(rsvp: pinned, seating_table: table, seat_position: 1, locked: true)
    a = attending_rsvp(name: "A")
    b = attending_rsvp(name: "B")

    result = move([ a.id, b.id ], { type: "table", table_id: table.id })

    assert result.ok?
    assert_equal 2, SeatAssignment.find_by!(rsvp: a).seat_position
    assert_equal 3, SeatAssignment.find_by!(rsvp: b).seat_position
    assert_equal 1, SeatAssignment.find_by!(rsvp: pinned).seat_position
  end

  test "multi-drop to a table counts own old positions as free" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    a = attending_rsvp(name: "A")
    b = attending_rsvp(name: "B")
    SeatAssignment.create!(rsvp: a, seating_table: table, seat_position: 1)
    SeatAssignment.create!(rsvp: b, seating_table: table, seat_position: 2)

    # Re-drop the same two onto the same table — should succeed (their own seats
    # free up first).
    result = move([ a.id, b.id ], { type: "table", table_id: table.id })

    assert result.ok?
    assert_equal [ 1, 2 ], [ SeatAssignment.find_by!(rsvp: a).seat_position, SeatAssignment.find_by!(rsvp: b).seat_position ]
  end

  test "drop to unseated unassigns the rsvps" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    a = attending_rsvp(name: "A")
    SeatAssignment.create!(rsvp: a, seating_table: table, seat_position: 1)

    result = move([ a.id ], { type: "unseated" })

    assert result.ok?
    assert_nil SeatAssignment.find_by(rsvp: a)
    assert result.rail_changed
    assert_equal [ table.id ], result.affected_table_ids
  end

  test "drop to unseated refuses locked rsvps" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    a = attending_rsvp(name: "A")
    SeatAssignment.create!(rsvp: a, seating_table: table, seat_position: 1, locked: true)

    result = move([ a.id ], { type: "unseated" })

    refute result.ok?
    assert_equal :source_locked, result.error
    assert SeatAssignment.find_by!(rsvp: a).locked
  end

  test "rsvps from a different event are rejected" do
    other = Event.create!(name: "Other Event", date: Date.tomorrow)
    table = create_table(name: "T1", top: 1, bottom: 1)
    foreign = Rsvp.create!(guest: guests(:mike_johnson), event: other, attending: true)

    result = move([ foreign.id ], { type: "seat", table_id: table.id, position: 1 })

    refute result.ok?
    assert_equal :invalid_input, result.error
  end

  test "snapshot captures before-state for all affected rsvps" do
    table = create_table(name: "T1", top: 1, bottom: 1)
    a = attending_rsvp(name: "A")
    b = attending_rsvp(name: "B")
    SeatAssignment.create!(rsvp: a, seating_table: table, seat_position: 1)
    SeatAssignment.create!(rsvp: b, seating_table: table, seat_position: 2)

    result = move([ a.id ], { type: "seat", table_id: table.id, position: 2 })

    assert result.ok?
    snap_by_rsvp = result.undo_snapshot.index_by { |e| e["rsvp_id"] }
    assert_equal 1, snap_by_rsvp[a.id]["seat_position"]
    assert_equal 2, snap_by_rsvp[b.id]["seat_position"]
  end

  private

  def move(rsvp_ids, destination)
    Seating::Mover.new(@event, rsvp_ids: rsvp_ids, destination: destination).call
  end

  def create_table(name:, top:, bottom:)
    SeatingTable.create!(
      event: @event,
      name: name,
      shape: "rect",
      top_seats: top,
      bottom_seats: bottom,
      has_left_end: false,
      has_right_end: false,
      seat_count: top + bottom,
      pos_x: 50,
      pos_y: 50,
      sort_order: @event.seating_tables.count + 1
    )
  end

  def attending_rsvp(name:)
    invite = Invite.create!(name: name, email: "#{name.parameterize}-#{SecureRandom.hex(2)}@example.com")
    guest  = Guest.create!(invite: invite, first_name: name, last_name: "Test", is_primary: true)
    Rsvp.create!(guest: guest, event: @event, attending: true)
  end
end
