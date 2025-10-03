# frozen_string_literal: true

# == Schema Information
#
# Table name: webhooks
#
#  id           :integer          not null, primary key
#  server_id    :integer
#  uuid         :string(255)
#  name         :string(255)
#  url          :string(255)
#  last_used_at :datetime
#  all_events   :boolean          default(FALSE)
#  enabled      :boolean          default(TRUE)
#  output_style :string(255)      default("postal")
#  sign         :boolean          default(TRUE)
#  created_at   :datetime
#  updated_at   :datetime
#
# Indexes
#
#  index_webhooks_on_server_id  (server_id)
#

class Webhook < ApplicationRecord

  include HasUUID

  belongs_to :server
  has_many :webhook_events, dependent: :destroy
  has_many :webhook_requests

  validates :name, presence: true
  validates :url, presence: true, format: { with: /\Ahttps?:\/\/[a-z0-9\-._?=&\/+:%@]+\z/i, allow_blank: true }
  validates :output_style, inclusion: { in: %w[postal listmonk], message: "%{value} is not a valid output style" }

  scope :enabled, -> { where(enabled: true) }

  after_save :save_events
  after_save :destroy_events_when_all_events_enabled

  def events
    @events ||= webhook_events.map(&:event)
  end

  def events=(value)
    @events = value.map(&:to_s).select(&:present?)
  end

  private

  def save_events
    return unless @events

    @events.each do |event|
      webhook_events.where(event: event).first_or_create!
    end

    webhook_events.where.not(event: @events).destroy_all
  end

  def destroy_events_when_all_events_enabled
    return unless all_events

    webhook_events.destroy_all
  end

end
