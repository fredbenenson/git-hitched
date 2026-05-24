module Admin
  class SeatingController < BaseController
    before_action :set_event, only: [ :show, :randomize, :move, :undo, :lock_all, :unlock_all, :clear ]

    # Canvas aspect ratios approximating each room's seating area.
    # Rehearsal floorplan is wider than tall; reception is much wider still.
    CANVAS_ASPECTS = {
      "Welcome Dinner" => "5 / 2",
      "Reception"      => "5 / 2"
    }.freeze

    def index
      event_ids = SeatingTable.distinct.pluck(:event_id)
      @events = Event
        .where(id: event_ids)
        .order(Arel.sql("COALESCE(sort_order, 999999)"), :date, :id)
    end

    def show
      # On every visit, start from a clean slate: only locked seats persist.
      # Randomize sets flash[:keep_seating] so its work survives the redirect.
      unless flash[:keep_seating]
        clear_unlocked_assignments
        session.delete(:seating_undo)
      end

      @tables = @event.seating_tables.ordered
      @attending_count = @event.rsvps.where(attending: true).count
      @canvas_aspect = CANVAS_ASPECTS[@event.name] || "16 / 10"
      @assignments = load_assignments
      @unseated_groups = load_unseated_groups
      @can_undo = undo_snapshot_for_event.present?
    end

    def randomize
      result = Seating::AutoAssigner.new(@event).call
      session.delete(:seating_undo)
      flash[:keep_seating] = true
      flash[:notice] = if result.unseated.any?
        "Seated #{result.assigned_count} guests. #{result.unseated.size} could not be placed — add table capacity."
      else
        "Seated #{result.assigned_count} guests."
      end
      redirect_to admin_event_seating_path(@event)
    end

    def lock_all
      count = event_assignments_scope.update_all(locked: true, updated_at: Time.current)
      flash[:keep_seating] = true
      flash[:notice] = "Locked #{count} seat#{'s' unless count == 1}."
      redirect_to admin_event_seating_path(@event)
    end

    def unlock_all
      count = event_assignments_scope.update_all(locked: false, updated_at: Time.current)
      flash[:keep_seating] = true
      flash[:notice] = "Unlocked #{count} seat#{'s' unless count == 1}."
      redirect_to admin_event_seating_path(@event)
    end

    def clear
      count = event_assignments_scope.where(locked: false).delete_all
      session.delete(:seating_undo)
      flash[:keep_seating] = true
      flash[:notice] = "Returned #{count} guest#{'s' unless count == 1} to the rail."
      redirect_to admin_event_seating_path(@event)
    end

    def move
      rsvp_ids = Array(params[:rsvp_ids])
      destination = params.require(:destination).permit(:type, :table_id, :position).to_h

      result = Seating::Mover.new(@event, rsvp_ids: rsvp_ids, destination: destination).call

      unless result.ok?
        return render(json: { error: result.error }, status: :unprocessable_entity)
      end

      if result.undo_snapshot.present?
        session[:seating_undo] = { event_id: @event.id, snapshot: result.undo_snapshot }
      end

      @assignments = load_assignments
      @affected_tables = @event.seating_tables.where(id: result.affected_table_ids).to_a
      @unseated_groups = result.rail_changed ? load_unseated_groups : nil

      respond_to do |format|
        format.turbo_stream { render :move }
      end
    end

    def undo
      snapshot = undo_snapshot_for_event
      return head(:no_content) if snapshot.blank?

      affected_table_ids = []
      rail_changed = false

      ApplicationRecord.transaction do
        rsvp_ids = snapshot.map { |e| e["rsvp_id"] }
        current = SeatAssignment.where(rsvp_id: rsvp_ids).index_by(&:rsvp_id)
        SeatAssignment.where(rsvp_id: rsvp_ids).delete_all

        now = Time.current
        rows = snapshot.filter_map do |entry|
          next unless entry["seating_table_id"]
          affected_table_ids << entry["seating_table_id"]
          { rsvp_id: entry["rsvp_id"], seating_table_id: entry["seating_table_id"], seat_position: entry["seat_position"], locked: entry["locked"], created_at: now, updated_at: now }
        end
        SeatAssignment.insert_all!(rows) if rows.any?

        snapshot.each do |entry|
          was_seated = entry["seating_table_id"].present?
          is_seated_now = current[entry["rsvp_id"]].present?
          rail_changed ||= (was_seated != is_seated_now)
          affected_table_ids << current[entry["rsvp_id"]].seating_table_id if current[entry["rsvp_id"]]
        end
      end

      session.delete(:seating_undo)

      @assignments = load_assignments
      @affected_tables = @event.seating_tables.where(id: affected_table_ids.uniq).to_a
      @unseated_groups = rail_changed ? load_unseated_groups : nil

      respond_to do |format|
        format.turbo_stream { render :move }
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def clear_unlocked_assignments
      SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: @event.id }, locked: false)
        .delete_all
    end

    def event_assignments_scope
      SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: @event.id })
    end

    # Returns the stored undo snapshot for the current event, or nil if the
    # session is empty or the snapshot belongs to a different event.
    def undo_snapshot_for_event
      state = session[:seating_undo]
      return nil if state.blank?
      state_event_id = state["event_id"] || state[:event_id]
      return nil unless state_event_id == @event.id
      state["snapshot"] || state[:snapshot]
    end

    # Map of [table_id, position] => SeatAssignment (with guest preloaded).
    def load_assignments
      SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: @event.id })
        .includes(rsvp: { guest: :invite })
        .each_with_object({}) do |assignment, hash|
          hash[[ assignment.seating_table_id, assignment.seat_position ]] = assignment
        end
    end

    # Attending RSVPs without a seat, grouped by linked-invite key (same key the
    # AutoAssigner uses), sorted by primary guest first.
    # Returns array of { id:, invite_name:, rsvps: [...] } hashes.
    def load_unseated_groups
      seated_rsvp_ids = SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: @event.id })
        .pluck(:rsvp_id)

      rsvps = @event.rsvps
        .where(attending: true)
        .where.not(id: seated_rsvp_ids)
        .includes(guest: :invite)
        .to_a

      rsvps
        .group_by { |r| r.guest.invite.linked_invite_id || r.guest.invite_id }
        .map do |group_id, members|
          {
            id: group_id,
            invite_name: members.first.guest.invite.name,
            rsvps: members.sort_by { |r| [ r.guest.is_primary ? 0 : 1, r.guest.first_name.to_s ] }
          }
        end
        .sort_by { |g| g[:invite_name].to_s.downcase }
    end
  end
end
