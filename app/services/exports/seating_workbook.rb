module Exports
  class SeatingWorkbook
    HEADERS = [
      "PAX",
      "Table #",
      "Position",
      "First Name",
      "Surname",
      "Adult",
      "U18",
      "Child",
      "Dietary Requirements"
    ].freeze

    ALPHA_HEADERS = [ "Last Name", "First Name", "Table No." ].freeze

    def to_stream
      package = Axlsx::Package.new
      workbook = package.workbook

      header_style = workbook.styles.add_style(b: true, bg_color: "EEEEEE", border: { style: :thin, color: "999999" })
      unseated_style = workbook.styles.add_style(b: true, bg_color: "FFF4D6")

      events.each do |event|
        seated = seated_rows_for(event)
        unseated = unseated_guests_for(event)

        workbook.add_worksheet(name: sheet_name(event)) do |sheet|
          sheet.add_row HEADERS, style: header_style

          pax = 0
          seated.each do |assignment|
            pax += 1
            guest = assignment.rsvp.guest
            sheet.add_row [
              pax,
              assignment.seating_table.name,
              assignment.seat_position,
              guest.first_name,
              guest.last_name,
              adult?(guest),
              under_18?(guest),
              child?(guest),
              guest.dietary_notes
            ]
          end

          if unseated.any?
            sheet.add_row [ "Unseated" ] + Array.new(HEADERS.length - 1), style: unseated_style
            unseated.each do |guest|
              pax += 1
              sheet.add_row [
                pax,
                nil,
                nil,
                guest.first_name,
                guest.last_name,
                adult?(guest),
                under_18?(guest),
                child?(guest),
                guest.dietary_notes
              ]
            end
          end

          sheet.column_widths 6, 14, 10, 18, 18, 8, 8, 8, 40
          sheet.sheet_view.pane do |pane|
            pane.state = :frozen
            pane.y_split = 1
            pane.active_pane = :bottom_left
          end
        end
      end

      events.each do |event|
        workbook.add_worksheet(name: alpha_sheet_name(event)) do |sheet|
          sheet.add_row ALPHA_HEADERS, style: header_style

          alpha_rows_for(event).each do |last_name, first_name, table_name|
            sheet.add_row [ last_name, first_name, table_name ]
          end

          sheet.column_widths 20, 20, 14
          sheet.sheet_view.pane do |pane|
            pane.state = :frozen
            pane.y_split = 1
            pane.active_pane = :bottom_left
          end
        end
      end

      package.to_stream
    end

    private

    def events
      event_ids = SeatingTable.distinct.pluck(:event_id)
      Event
        .where(id: event_ids)
        .order(Arel.sql("COALESCE(sort_order, 999999)"), :date, :id)
    end

    def seated_rows_for(event)
      SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: event.id })
        .includes(:seating_table, rsvp: :guest)
        .order("seating_tables.sort_order ASC, seating_tables.id ASC, seat_assignments.seat_position ASC")
    end

    def unseated_guests_for(event)
      seated_rsvp_ids = SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: event.id })
        .pluck(:rsvp_id)

      Guest
        .joins(:rsvps, :invite)
        .where(rsvps: { event_id: event.id, attending: true })
        .where.not(rsvps: { id: seated_rsvp_ids })
        .order("invites.name ASC, guests.is_primary DESC, guests.first_name ASC")
    end

    def adult?(guest)
      guest.age.present? ? guest.age >= 18 : !guest.is_child?
    end

    def under_18?(guest)
      guest.age.present? ? guest.age < 18 : guest.is_child?
    end

    def child?(guest)
      guest.age.present? && guest.age < 12
    end

    def sheet_name(event)
      raw = event.name.to_s.gsub(/[\[\]\*\/\\\?:]/, " ").strip
      raw = "Event #{event.id}" if raw.empty?
      raw.first(31)
    end

    def alpha_sheet_name(event)
      "#{sheet_name(event)} A-Z".first(31)
    end

    # Attending guests for the event, sorted by last name then first name.
    # Unseated guests appear with a blank table name.
    def alpha_rows_for(event)
      assignments_by_rsvp = SeatAssignment
        .joins(:seating_table)
        .where(seating_tables: { event_id: event.id })
        .includes(:seating_table)
        .index_by(&:rsvp_id)

      Guest
        .joins(:rsvps)
        .where(rsvps: { event_id: event.id, attending: true })
        .includes(:rsvps)
        .map do |guest|
          rsvp = guest.rsvps.find { |r| r.event_id == event.id }
          table_name = assignments_by_rsvp[rsvp.id]&.seating_table&.name
          [ guest.last_name.to_s, guest.first_name.to_s, table_name ]
        end
        .sort_by { |last, first, _| [ last.downcase, first.downcase ] }
    end
  end
end
