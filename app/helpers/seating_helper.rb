module SeatingHelper
  # "First L." formatted name for the guest sitting at this assignment, or nil
  # if the seat is empty.
  def seat_display_name(assignment)
    return nil unless assignment

    guest = assignment.rsvp.guest
    if guest.last_name.present?
      "#{guest.first_name} #{guest.last_name.first}."
    else
      guest.first_name.to_s
    end
  end

  # Two crossing arrows — universal "shuffle" glyph.
  def shuffle_icon_svg
    tag.svg(viewBox: "0 0 16 16", xmlns: "http://www.w3.org/2000/svg", fill: "none", stroke: "currentColor", "stroke-width": "1.5", "stroke-linecap": "round", "stroke-linejoin": "round") do
      safe_join([
        tag.path(d: "M2 4h2.5l7 8H14"),
        tag.path(d: "M2 12h2.5l7-8H14"),
        tag.path(d: "M12 2l2 2-2 2"),
        tag.path(d: "M12 10l2 2-2 2")
      ])
    end
  end

  # Tiny padlock glyph. Closed-shackle when locked, open-shackle when not.
  def lock_icon_svg(locked)
    if locked
      tag.svg(viewBox: "0 0 16 16", xmlns: "http://www.w3.org/2000/svg", fill: "currentColor") do
        tag.path(d: "M5 7V5a3 3 0 016 0v2h.5A1.5 1.5 0 0113 8.5v5A1.5 1.5 0 0111.5 15h-7A1.5 1.5 0 013 13.5v-5A1.5 1.5 0 014.5 7H5zm1 0h4V5a2 2 0 00-4 0v2z")
      end
    else
      tag.svg(viewBox: "0 0 16 16", xmlns: "http://www.w3.org/2000/svg", fill: "currentColor") do
        tag.path(d: "M11 5a3 3 0 00-6 0v2h-.5A1.5 1.5 0 003 8.5v5A1.5 1.5 0 004.5 15h7a1.5 1.5 0 001.5-1.5v-5A1.5 1.5 0 0011.5 7H6V5a2 2 0 014 0h1z")
      end
    end
  end
end
