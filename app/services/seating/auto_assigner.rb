module Seating
  # Assigns attending RSVPs to seats for one event.
  #
  # Strategy:
  #   - Groups guests by invite (linked invites travel together).
  #   - Places largest groups first (size-descending).
  #   - Picks the table with the most free seats for each group (worst-fit),
  #     leaving smaller tables intact for smaller groups.
  #   - Fills seat positions in numerical order within the chosen table.
  #   - Preserves any seat_assignment whose `locked` flag is true; only
  #     unlocked rows are cleared and re-assigned.
  class AutoAssigner
    Result = Struct.new(:assigned_count, :unseated, keyword_init: true)

    def initialize(event)
      @event = event
    end

    def call
      ApplicationRecord.transaction do
        locked = locked_assignments
        clear_unlocked_assignments
        free_positions = build_free_positions(locked)
        groups = build_groups(locked_rsvp_ids: locked.map(&:rsvp_id))
        place_groups(groups, free_positions)
      end
    end

    private

    def locked_assignments
      SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: @event.id }, locked: true)
        .to_a
    end

    def clear_unlocked_assignments
      SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: @event.id }, locked: false)
        .delete_all
    end

    # { table_id => [free positions in numerical order] }
    def build_free_positions(locked)
      taken_by_table = locked.group_by(&:seating_table_id).transform_values { |list| list.map(&:seat_position).to_set }
      @event.seating_tables.ordered.each_with_object({}) do |table, hash|
        taken = taken_by_table[table.id] || Set.new
        hash[table.id] = (1..table.seat_count).reject { |p| taken.include?(p) }
      end
    end

    # Returns groups (arrays of RSVPs) sorted by size descending.
    def build_groups(locked_rsvp_ids:)
      rsvps = @event.rsvps
        .where(attending: true)
        .where.not(id: locked_rsvp_ids)
        .includes(guest: :invite)
        .to_a

      rsvps
        .group_by { |rsvp| rsvp.guest.invite.linked_invite_id || rsvp.guest.invite_id }
        .values
        .sort_by { |members| -members.size }
    end

    def place_groups(groups, free_positions)
      assigned = 0
      unseated = []

      groups.each do |group|
        remaining = group.dup
        while remaining.any?
          target_id, positions = free_positions.max_by { |_, ps| ps.size }
          if target_id.nil? || positions.empty?
            unseated.concat(remaining)
            break
          end

          take = [ remaining.size, positions.size ].min
          chosen = positions.first(take)

          rows = chosen.map.with_index do |position, i|
            {
              rsvp_id: remaining[i].id,
              seating_table_id: target_id,
              seat_position: position,
              locked: false,
              created_at: Time.current,
              updated_at: Time.current
            }
          end
          SeatAssignment.insert_all!(rows)

          free_positions[target_id] = positions.drop(take)
          remaining = remaining.drop(take)
          assigned += take
        end
      end

      Result.new(assigned_count: assigned, unseated: unseated)
    end
  end
end
