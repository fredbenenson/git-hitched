class AddLinkedInviteToInvites < ActiveRecord::Migration[8.0]
  def change
    add_reference :invites, :linked_invite, foreign_key: { to_table: :invites }, null: true, index: true
  end
end
