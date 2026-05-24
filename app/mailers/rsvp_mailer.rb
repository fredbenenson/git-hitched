class RsvpMailer < ApplicationMailer
  def invitation(invite)
    @invite = invite
    @events = invite.events.order(:date, :start_time)
    @manage_url = rsvp_manage_url(token: signed_token(invite))
    mail(to: invite.email, subject: "You're Invited — #{WEDDING[:couple_names_possessive]} Wedding")
  end

  def confirmation(invite)
    @invite = invite
    @guests = invite.guests.order(is_primary: :desc, first_name: :asc)
    @events = invite.events.order(:date, :start_time)
    @manage_url = rsvp_manage_url(token: signed_token(invite))
    mail(to: invite.email, subject: "RSVP Confirmation — #{WEDDING[:couple_names_possessive]} Wedding")
  end

  def update_notification(invite)
    @invite = invite
    @guests = invite.guests.order(is_primary: :desc, first_name: :asc)
    @events = invite.events.order(:date, :start_time)
    @manage_url = rsvp_manage_url(token: signed_token(invite))
    mail(to: invite.email, subject: "RSVP Updated — #{WEDDING[:couple_names_possessive]} Wedding")
  end

  def reminder(invite)
    @invite = invite
    @events = invite.events.order(:date, :start_time)
    @manage_url = rsvp_manage_url(token: signed_token(invite))
    mail(to: invite.email, subject: "We'd love to hear from you — #{WEDDING[:couple_names_possessive]} Wedding")
  end

  def admin_notification(invite)
    @invite = invite
    @guests = invite.guests.order(is_primary: :desc, first_name: :asc)
    @events = invite.events.order(:date, :start_time)
    status = invite.attending? ? "Attending" : "Declined"
    mail(to: admin_notification_email, subject: "RSVP #{status}: #{invite.name} (#{@guests.size} guest#{'s' if @guests.size != 1})")
  end

  def children_preferences(invite)
    @invite = invite
    @children = invite.guests.children.order(:first_name)
    @children_names = @children.map(&:first_name).to_sentence(two_words_connector: " & ", last_word_connector: " & ")
    @preferences_url = children_preferences_url(token: invite.children_preferences_token)
    mail(to: invite.email, subject: "A little something for #{@children_names} — #{WEDDING[:couple_names_possessive]} Wedding")
  end

  def children_preferences_notification(invite)
    @invite = invite
    @children = invite.guests.children.order(:first_name)
    @children_names = @children.map(&:first_name).to_sentence(two_words_connector: " & ", last_word_connector: " & ")
    mail(to: admin_notification_email, subject: "Children's preferences: #{invite.name} (#{@children_names})")
  end

  private

  def signed_token(invite)
    Rails.application.message_verifier(:rsvp_management).generate(
      invite.id, expires_in: 30.days
    )
  end

  def admin_notification_email
    ENV.fetch("ADMIN_NOTIFICATION_EMAIL", WEDDING[:from_email].match(/<(.+)>/)[1])
  end
end
