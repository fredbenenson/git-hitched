class AddSendReminderToInvites < ActiveRecord::Migration[8.0]
  def change
    add_column :invites, :send_reminder, :boolean, default: true, null: false
  end
end
