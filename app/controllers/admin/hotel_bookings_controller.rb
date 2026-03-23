module Admin
  class HotelBookingsController < BaseController
    def index
      @bookings = HotelBooking.includes(:invite).order(created_at: :desc)
      @total_rooms = HotelBooking.confirmed.sum(:rooms)
      @total_revenue = HotelBooking.confirmed.sum(:amount_cents)
      @confirmed_count = HotelBooking.confirmed.count
      @pending_count = HotelBooking.pending.count
      @refunded_count = HotelBooking.refunded.count
    end

    def refund
      booking = HotelBooking.find(params[:id])

      if booking.confirmed? && booking.stripe_payment_intent_id.present?
        Stripe::Refund.create(payment_intent: booking.stripe_payment_intent_id)
        booking.mark_refunded!
        HotelBookingMailer.refund_notification(booking).deliver_later
        redirect_to admin_hotel_bookings_path, notice: "Refund issued for #{booking.guest_name} (#{booking.amount_display}). Notification email sent."
      else
        redirect_to admin_hotel_bookings_path, alert: "Unable to refund this booking."
      end
    rescue Stripe::StripeError => e
      redirect_to admin_hotel_bookings_path, alert: "Refund failed: #{e.message}"
    end
  end
end
