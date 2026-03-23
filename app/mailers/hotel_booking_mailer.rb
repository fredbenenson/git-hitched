class HotelBookingMailer < ApplicationMailer
  def confirmation(booking)
    @booking = booking
    @invite = booking.invite
    mail(to: booking.email, subject: "Hotel Booking Confirmed — #{WEDDING[:couple_names_possessive]} Wedding")
  end

  def admin_notification(booking)
    @booking = booking
    admin_email = ENV.fetch("ADMIN_NOTIFICATION_EMAIL", WEDDING[:from_email].match(/<(.+)>/)[1])
    mail(to: admin_email, subject: "New Hotel Booking: #{booking.guest_name} (#{booking.rooms} room#{'s' if booking.rooms > 1})")
  end

  def refund_notification(booking)
    @booking = booking
    mail(to: booking.email, subject: "Hotel Booking Refund — #{WEDDING[:couple_names_possessive]} Wedding")
  end
end
