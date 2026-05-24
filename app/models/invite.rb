class Invite < ApplicationRecord
  has_many :guests, dependent: :destroy
  has_many :event_invites, dependent: :destroy
  has_many :events, through: :event_invites
  has_many :hotel_bookings, dependent: :destroy
  belongs_to :linked_invite, class_name: "Invite", optional: true
  has_many :linked_invites, class_name: "Invite", foreign_key: :linked_invite_id, dependent: :nullify
  accepts_nested_attributes_for :guests, allow_destroy: true

  validates :name, presence: true
  validates :email, presence: true
  validate :linked_invite_is_not_self
  validate :linked_invite_is_not_chained

  after_create :assign_all_events

  def self.find_by_email(query)
    where("LOWER(email) = LOWER(?)", query.strip).first
  end

  def responded?
    responded_at.present?
  end

  def primary_guest
    guests.find_by(is_primary: true)
  end

  def children_preferences_token
    Rails.application.message_verifier(:children_preferences).generate(id, expires_in: 60.days)
  end

  private

  def assign_all_events
    Event.find_each do |event|
      event_invites.find_or_create_by!(event: event)
    end
  end

  def linked_invite_is_not_self
    errors.add(:linked_invite_id, "cannot link to itself") if linked_invite_id.present? && linked_invite_id == id
  end

  def linked_invite_is_not_chained
    return if linked_invite_id.blank?
    if linked_invite&.linked_invite_id.present?
      errors.add(:linked_invite_id, "cannot link to an invite that is already linked elsewhere")
    end
  end
end
