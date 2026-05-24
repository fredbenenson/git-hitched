class Event < ApplicationRecord
  has_many :event_invites, dependent: :destroy
  has_many :invites, through: :event_invites
  has_many :rsvps, dependent: :destroy
  has_many :seating_tables, dependent: :destroy

  validates :name, presence: true

  after_create :assign_to_all_invites

  def attending_count
    rsvps.where(attending: true).count
  end

  def declined_count
    rsvps.where(attending: false).count
  end

  def pending_count
    rsvps.where(attending: nil).count
  end

  private

  def assign_to_all_invites
    Invite.find_each do |invite|
      event_invites.find_or_create_by!(invite: invite)
    end
  end
end
