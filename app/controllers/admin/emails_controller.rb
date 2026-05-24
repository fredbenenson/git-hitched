module Admin
  class EmailsController < BaseController
    def index
      @reminder_targets = reminder_scope
        .includes(:guests, :events)
        .order(:name)
      @skipped_no_email = Invite.where(responded_at: nil)
        .where(attending: [ nil, true ])
        .where(email: [ nil, "" ]).count
      @skipped_declined = Invite.where(attending: false).count
      @skipped_responded = Invite.where.not(responded_at: nil).count
      @skipped_send_reminder_off = Invite.where(responded_at: nil)
        .where(attending: [ nil, true ])
        .where(linked_invite_id: nil)
        .where(send_reminder: false)
        .where.not(email: [ nil, "" ])
        .joins(:event_invites)
        .distinct
        .count

      @children_targets = children_preferences_scope
        .includes(:guests)
        .order(:name)
      @children_skipped_no_email = Invite.where(children_attending: true, attending: true)
        .where(linked_invite_id: nil)
        .where(email: [ nil, "" ])
        .count
    end

    def export
      redirect_to admin_emails_path, notice: "Google Sheets export is not yet configured. Set up credentials in config/google_sheets.yml."
    end

    def send_invitations
      invites = Invite.where.not(email: nil)
      invites.each { |i| RsvpMailer.invitation(i).deliver_later }
      redirect_to admin_emails_path, notice: "Invitations sent to #{invites.count} invites."
    end

    def send_reminders
      invites = reminder_scope
      invites.each { |i| RsvpMailer.reminder(i).deliver_later }
      redirect_to admin_emails_path, notice: "Reminders sent to #{invites.count} invites."
    end

    def send_children_preferences
      invites = children_preferences_scope
      invites.each { |i| RsvpMailer.children_preferences(i).deliver_later }
      redirect_to admin_emails_path, notice: "Children's nanny service email sent to #{invites.count} invite#{'s' unless invites.count == 1}."
    end

    def send_test_email
      test_address = ENV.fetch("TEST_EMAIL_ADDRESS", "test@example.wedding")
      invite = Invite.joins(:event_invites).distinct.first

      unless invite
        redirect_to admin_emails_path, alert: "No invite with events found to use as test data."
        return
      end

      email_type = params[:email_type]
      mail = case email_type
      when "invitation"           then RsvpMailer.invitation(invite)
      when "confirmation"         then RsvpMailer.confirmation(invite)
      when "update_notification"  then RsvpMailer.update_notification(invite)
      when "reminder"             then RsvpMailer.reminder(invite)
      when "children_preferences"
                children_invite = Invite.where(children_attending: true).where.not(email: [ nil, "" ]).first || invite
                RsvpMailer.children_preferences(children_invite)
      else
               redirect_to admin_emails_path, alert: "Unknown email type: #{email_type}"
               return
      end

      mail.to = [ test_address ]
      mail.deliver_now

      redirect_to admin_emails_path, notice: "Test #{email_type.humanize} email sent to #{test_address}."
    end

    private

    def reminder_scope
      Invite.where(responded_at: nil)
            .where(attending: [ nil, true ])
            .where(linked_invite_id: nil)
            .where(send_reminder: true)
            .where.not(email: [ nil, "" ])
            .joins(:event_invites)
            .distinct
    end

    def children_preferences_scope
      Invite.where(children_attending: true, attending: true)
            .where(linked_invite_id: nil)
            .where.not(email: [ nil, "" ])
    end
  end
end
