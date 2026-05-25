puts "Seeding events..."

welcome = Event.find_or_create_by!(name: "Welcome Dinner")
welcome.update!(
  date: Date.new(2025, 9, 19),
  start_time: Time.zone.parse("17:00"),
  location: "Château de Flapjack",
  location_url: "#",
  address: "Route de Croissant, 13990 Buttersville, France",
  maps_url: "#",
  time_description: "5:00pm",
  attire: "Garden Elegance",
  attire_description: "Elegant, effortless summer attire in soft, warm-weather fabrics.",
  subtitle: "Friday, September 19",
  description: "Join us as we gather at the Château for a relaxed welcome — golden light across the vineyards, an aperitif in the gardens and a warm start to the celebrations.",
  sort_order: 1,
  image: "venue4.jpg"
)

ceremony = Event.find_or_create_by!(name: "Ceremony")
ceremony.update!(
  date: Date.new(2025, 9, 20),
  start_time: Time.zone.parse("17:00"),
  location: "Château de Flapjack",
  location_url: "#",
  address: "Route de Croissant, 13990 Buttersville, France",
  maps_url: "#",
  time_description: "Please arrive at 4:30pm for a 5:00pm Ceremony",
  attire: "Black Tie Optional",
  attire_description: nil,
  subtitle: "Saturday, September 20",
  description: "The wedding ceremony at Château de Flapjack.",
  sort_order: 2,
  image: "venue6.jpg"
)

reception = Event.find_or_create_by!(name: "Reception")
reception.update!(
  date: Date.new(2025, 9, 20),
  start_time: Time.zone.parse("19:00"),
  location: nil,
  location_url: nil,
  address: nil,
  maps_url: nil,
  time_description: "Following the Ceremony",
  attire: "Black Tie Optional",
  attire_description: nil,
  subtitle: "Saturday, September 20",
  description: "After the aperitif, guests will be invited to continue the evening at a second location, where the celebrations will unfold with dinner and dancing.",
  sort_order: 3,
  image: "reception.png"
)

recovery = Event.find_or_create_by!(name: "Recovery")
recovery.update!(
  date: Date.new(2025, 9, 21),
  start_time: Time.zone.parse("12:00"),
  location: nil,
  location_url: nil,
  address: nil,
  maps_url: nil,
  time_description: nil,
  attire: "Casual Elegance",
  attire_description: nil,
  subtitle: "Sunday, September 21",
  description: "A relaxed afternoon — slow, sunlit and celebratory. Details to follow.",
  sort_order: 4,
  image: "venue5.jpg"
)

puts "Seeding test invites and guests..."

taylor = Invite.find_or_create_by!(email: "taylor@example.com") do |i|
  i.name = "Taylor's Test Family"
end

Guest.find_or_create_by!(invite: taylor, first_name: "Taylor", last_name: "Pepperworth") do |g|
  g.is_primary = true
end

Guest.find_or_create_by!(invite: taylor, first_name: "Taylor's", last_name: "Guest")

[ welcome, ceremony, reception, recovery ].each do |event|
  EventInvite.find_or_create_by!(invite: taylor, event: event)
end

robin = Invite.find_or_create_by!(email: "robin@example.com") do |i|
  i.name = "Robin's Test Family"
end

Guest.find_or_create_by!(invite: robin, first_name: "Robin", last_name: "Snackwell") do |g|
  g.is_primary = true
end

Guest.find_or_create_by!(invite: robin, first_name: "Robin's", last_name: "Guest")

[ welcome, ceremony, reception, recovery ].each do |event|
  EventInvite.find_or_create_by!(invite: robin, event: event)
end

puts "Seeding seating tables..."

# Floorplan tables per event. Idempotent on the [event_id, name] unique index.
# top_seats/bottom_seats are the two long sides; has_left_end/has_right_end add
# a single seat at each rounded end (rect tables only).
seating_layout = {
  welcome => [
    { name: "T1", shape: "rect",  top_seats: 9, bottom_seats: 9, has_left_end: true,  has_right_end: true,  seat_count: 20, pos_x: 30, pos_y: 18, sort_order: 1 },
    { name: "T2", shape: "rect",  top_seats: 9, bottom_seats: 9, has_left_end: true,  has_right_end: true,  seat_count: 20, pos_x: 30, pos_y: 50, sort_order: 2 },
    { name: "T3", shape: "rect",  top_seats: 9, bottom_seats: 9, has_left_end: true,  has_right_end: true,  seat_count: 20, pos_x: 30, pos_y: 82, sort_order: 3 },
    { name: "T4", shape: "rect",  top_seats: 9, bottom_seats: 9, has_left_end: true,  has_right_end: true,  seat_count: 20, pos_x: 70, pos_y: 18, sort_order: 4 },
    { name: "T5", shape: "rect",  top_seats: 9, bottom_seats: 9, has_left_end: true,  has_right_end: true,  seat_count: 20, pos_x: 70, pos_y: 50, sort_order: 5 },
    { name: "T6", shape: "rect",  top_seats: 9, bottom_seats: 9, has_left_end: true,  has_right_end: true,  seat_count: 20, pos_x: 70, pos_y: 82, sort_order: 6 }
  ],
  reception => [
    { name: "T1", shape: "curve", top_seats: 10, bottom_seats: 10, has_left_end: false, has_right_end: false, seat_count: 20, pos_x: 50, pos_y: 50, sort_order: 1 },
    { name: "T2", shape: "rect",  top_seats: 10, bottom_seats: 10, has_left_end: false, has_right_end: false, seat_count: 20, pos_x: 80, pos_y: 18, sort_order: 2 },
    { name: "T3", shape: "rect",  top_seats: 10, bottom_seats: 10, has_left_end: false, has_right_end: false, seat_count: 20, pos_x: 80, pos_y: 50, sort_order: 3 },
    { name: "T4", shape: "rect",  top_seats: 10, bottom_seats: 10, has_left_end: false, has_right_end: false, seat_count: 20, pos_x: 80, pos_y: 82, sort_order: 4 },
    { name: "T5", shape: "rect",  top_seats: 10, bottom_seats: 10, has_left_end: false, has_right_end: false, seat_count: 20, pos_x: 20, pos_y: 18, sort_order: 5 },
    { name: "T6", shape: "rect",  top_seats: 10, bottom_seats: 10, has_left_end: false, has_right_end: false, seat_count: 20, pos_x: 20, pos_y: 50, sort_order: 6 },
    { name: "T7", shape: "rect",  top_seats: 10, bottom_seats: 10, has_left_end: false, has_right_end: false, seat_count: 20, pos_x: 20, pos_y: 82, sort_order: 7 }
  ]
}

seating_layout.each do |event, tables|
  tables.each do |attrs|
    table = SeatingTable.find_or_initialize_by(event: event, name: attrs[:name])
    table.assign_attributes(attrs)
    table.save!
  end
end

puts "Seed complete! #{Invite.count} invites, #{Guest.count} guests, #{Event.count} events."
