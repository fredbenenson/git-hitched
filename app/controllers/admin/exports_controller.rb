module Admin
  class ExportsController < BaseController
    def guests_xlsx
      stream = Exports::GuestWorkbook.new.to_stream
      send_data stream.read,
                filename: "#{export_slug}-guests-#{Date.current.strftime('%Y-%m-%d')}.xlsx",
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end

    def seating_xlsx
      stream = Exports::SeatingWorkbook.new.to_stream
      send_data stream.read,
                filename: "#{export_slug}-seating-#{Date.current.strftime('%Y-%m-%d')}.xlsx",
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end

    private

    def export_slug
      WEDDING[:couple_names].parameterize.presence || "wedding"
    end
  end
end
