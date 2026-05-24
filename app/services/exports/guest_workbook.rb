module Exports
  class GuestWorkbook
    HEADERS = [
      "PAX",
      "Table #",
      "Position #",
      "First Name",
      "Sur Name",
      "Invite",
      "Adult",
      "Under 18",
      "Child",
      "Age",
      "Meal Choice",
      "Dietary Requirements"
    ].freeze

    def to_stream
      package = Axlsx::Package.new
      workbook = package.workbook

      header_style = workbook.styles.add_style(b: true, bg_color: "EEEEEE", border: { style: :thin, color: "999999" })
      label_style  = workbook.styles.add_style(b: true)
      count_style  = workbook.styles.add_style(alignment: { horizontal: :right })

      events.each do |event|
        guests = attending_guests_for(event).to_a

        counts = {
          "Adults"           => guests.count { |g| adult?(g) },
          "12-18 Year Olds"  => guests.count { |g| age_between?(g, 12, 18) },
          "2-12 Year Olds"   => guests.count { |g| age_between?(g, 2, 12) },
          "0-2 Year Olds"    => guests.count { |g| age_between?(g, 0, 2) }
        }

        workbook.add_worksheet(name: sheet_name(event)) do |sheet|
          header_row = sheet.add_row HEADERS, style: header_style
          header_row.add_cell nil
          header_row.add_cell "Summary", style: header_style

          total_rows = [ guests.length, counts.length + 1 ].max

          total_rows.times do |i|
            guest = guests[i]
            row_data = if guest
              [
                i + 1,
                nil,
                nil,
                guest.first_name,
                guest.last_name,
                guest.invite.name,
                adult?(guest),
                under_18?(guest),
                child?(guest),
                guest.age,
                guest.meal_choice&.titleize,
                guest.dietary_notes
              ]
            else
              Array.new(HEADERS.length)
            end
            sheet.add_row row_data
          end

          counts.each_with_index do |(label, count), i|
            row = sheet.rows[i + 1]
            row.add_cell nil
            row.add_cell label, style: label_style
            row.add_cell count, style: count_style
          end

          total_row = sheet.rows[counts.length + 1]
          total_row.add_cell nil
          total_row.add_cell "Total", style: label_style
          total_row.add_cell counts.values.sum, style: label_style

          sheet.column_widths 6, 8, 10, 18, 18, 22, 8, 9, 8, 6, 14, 40, 4, 12, 8
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
      Event.order(Arel.sql("COALESCE(sort_order, 999999)"), :date, :id)
    end

    def attending_guests_for(event)
      Guest
        .joins(:rsvps, :invite)
        .where(rsvps: { event_id: event.id, attending: true })
        .order("invites.name ASC, guests.is_primary DESC, guests.first_name ASC")
        .includes(:invite)
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

    def infant?(guest)
      guest.age.present? && guest.age < 2
    end

    def age_between?(guest, min, max)
      guest.age.present? && guest.age >= min && guest.age < max
    end

    def sheet_name(event)
      raw = event.name.to_s.gsub(/[\[\]\*\/\\\?:]/, " ").strip
      raw = "Event #{event.id}" if raw.empty?
      raw.first(31)
    end
  end
end
