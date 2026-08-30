# frozen_string_literal: true

class UsageRollup < ApplicationRecord

  belongs_to :organization
  belongs_to :server, optional: true

  validates :period_start, :granularity, :metric, presence: true
  validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

end
