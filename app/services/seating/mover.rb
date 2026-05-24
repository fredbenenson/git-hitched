module Seating
  # Moves one or more RSVPs to a new destination (specific seat, table, or the
  # unseated rail). Used by the drag-and-drop seating UI.
  #
  # Destination shapes:
  #   { type: "seat",     table_id:, position: }   # single rsvp only; swaps if filled
  #   { type: "table",    table_id: }              # multi; fills next N unlocked empty positions
  #   { type: "unseated"  }                        # unassigns all rsvps
  #
  # Returns Result with:
  #   ok                  — true on success
  #   error               — symbol code on failure (see ERRORS)
  #   affected_table_ids  — tables whose seat layout changed (for turbo-stream redraw)
  #   rail_changed        — true if the unseated list gained or lost anyone
  #   undo_snapshot       — array of {rsvp_id, seating_table_id, seat_position, locked} entries
  #                         representing the BEFORE state of every changed rsvp.
  class Mover
    Result = Struct.new(:ok, :error, :affected_table_ids, :rail_changed, :undo_snapshot, keyword_init: true) do
      def ok?; ok; end
    end

    ERRORS = %i[invalid_input dest_locked source_locked not_enough_room].freeze

    def initialize(event, rsvp_ids:, destination:)
      @event = event
      @rsvp_ids = Array(rsvp_ids).map(&:to_i).uniq
      @destination = (destination || {}).deep_symbolize_keys
    end

    def call
      return fail_with(:invalid_input) if @rsvp_ids.empty?
      return fail_with(:invalid_input) unless rsvps_belong_to_event?

      result = nil
      ApplicationRecord.transaction do
        result = case @destination[:type].to_s
                 when "seat"     then move_to_seat
                 when "table"    then move_to_table
                 when "unseated" then move_to_unseated
                 else                 fail_with(:invalid_input)
                 end
        raise ActiveRecord::Rollback unless result.ok?
      end
      result
    end

    private

    def rsvps_belong_to_event?
      Rsvp.where(id: @rsvp_ids, event_id: @event.id).count == @rsvp_ids.size
    end

    def move_to_seat
      return fail_with(:invalid_input) if @rsvp_ids.size != 1

      dest_table_id = @destination[:table_id].to_i
      dest_position = @destination[:position].to_i
      return fail_with(:invalid_input) if dest_table_id.zero? || dest_position.zero?
      return fail_with(:invalid_input) unless table_belongs_to_event?(dest_table_id)

      source_rsvp_id = @rsvp_ids.first
      source = SeatAssignment.find_by(rsvp_id: source_rsvp_id)
      dest   = SeatAssignment.find_by(seating_table_id: dest_table_id, seat_position: dest_position)

      return fail_with(:source_locked) if source&.locked
      return fail_with(:dest_locked)   if dest&.locked

      # Dropping on the same seat → no-op success.
      if source && source.seating_table_id == dest_table_id && source.seat_position == dest_position
        return success(affected_table_ids: [], rail_changed: false, undo_snapshot: [])
      end

      snapshot_rsvp_ids = [ source_rsvp_id, dest&.rsvp_id ].compact.uniq
      snapshot = build_snapshot(snapshot_rsvp_ids)

      affected = []
      rail_changed = false
      now = Time.current

      SeatAssignment.where(rsvp_id: snapshot_rsvp_ids).delete_all

      new_rows = []
      new_rows << seat_row(source_rsvp_id, dest_table_id, dest_position, now)
      affected << dest_table_id

      if source
        affected << source.seating_table_id
        # If dest was filled, the bumped rsvp goes to source's old seat (swap).
        # If dest was empty, source's old seat just empties out (move).
        if dest
          new_rows << seat_row(dest.rsvp_id, source.seating_table_id, source.seat_position, now)
        end
      else
        # Source was unseated → moving in (rail loses source).
        # If dest was filled, occupant goes to rail (bump).
        rail_changed = true
      end

      SeatAssignment.insert_all!(new_rows) if new_rows.any?

      success(
        affected_table_ids: affected.uniq,
        rail_changed: rail_changed,
        undo_snapshot: snapshot
      )
    end

    def move_to_table
      table_id = @destination[:table_id].to_i
      return fail_with(:invalid_input) if table_id.zero?
      return fail_with(:invalid_input) unless table_belongs_to_event?(table_id)

      table = @event.seating_tables.find(table_id)

      existing = SeatAssignment.where(rsvp_id: @rsvp_ids).to_a
      return fail_with(:source_locked) if existing.any?(&:locked)

      locked_positions = SeatAssignment
        .where(seating_table_id: table.id, locked: true)
        .pluck(:seat_position)
        .to_set
      others_positions = SeatAssignment
        .where(seating_table_id: table.id)
        .where.not(rsvp_id: @rsvp_ids)
        .pluck(:seat_position)
        .to_set

      free = (1..table.seat_count).reject { |p| locked_positions.include?(p) || others_positions.include?(p) }
      return fail_with(:not_enough_room) if free.size < @rsvp_ids.size

      snapshot = build_snapshot(@rsvp_ids)
      SeatAssignment.where(rsvp_id: @rsvp_ids).delete_all

      now = Time.current
      rows = @rsvp_ids.each_with_index.map do |rsvp_id, i|
        seat_row(rsvp_id, table.id, free[i], now)
      end
      SeatAssignment.insert_all!(rows)

      affected = (existing.map(&:seating_table_id) + [ table.id ]).uniq
      rail_changed = existing.size < @rsvp_ids.size

      success(affected_table_ids: affected, rail_changed: rail_changed, undo_snapshot: snapshot)
    end

    def move_to_unseated
      existing = SeatAssignment.where(rsvp_id: @rsvp_ids).to_a
      return fail_with(:source_locked) if existing.any?(&:locked)
      return success(affected_table_ids: [], rail_changed: false, undo_snapshot: []) if existing.empty?

      snapshot = build_snapshot(@rsvp_ids)
      SeatAssignment.where(rsvp_id: @rsvp_ids).delete_all

      success(
        affected_table_ids: existing.map(&:seating_table_id).uniq,
        rail_changed: true,
        undo_snapshot: snapshot
      )
    end

    def build_snapshot(rsvp_ids)
      rows = SeatAssignment.where(rsvp_id: rsvp_ids).index_by(&:rsvp_id)
      rsvp_ids.map do |id|
        a = rows[id]
        if a
          { "rsvp_id" => id, "seating_table_id" => a.seating_table_id, "seat_position" => a.seat_position, "locked" => a.locked }
        else
          { "rsvp_id" => id, "seating_table_id" => nil, "seat_position" => nil, "locked" => false }
        end
      end
    end

    def seat_row(rsvp_id, table_id, position, now)
      { rsvp_id: rsvp_id, seating_table_id: table_id, seat_position: position, locked: false, created_at: now, updated_at: now }
    end

    def table_belongs_to_event?(table_id)
      @event.seating_tables.where(id: table_id).exists?
    end

    def fail_with(code)
      Result.new(ok: false, error: code, affected_table_ids: [], rail_changed: false, undo_snapshot: nil)
    end

    def success(affected_table_ids:, rail_changed:, undo_snapshot:)
      Result.new(
        ok: true,
        error: nil,
        affected_table_ids: affected_table_ids,
        rail_changed: rail_changed,
        undo_snapshot: undo_snapshot
      )
    end
  end
end
