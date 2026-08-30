# frozen_string_literal: true

class IdempotencyRecord < ApplicationRecord

  belongs_to :control_api_key

  validates :key, :request_method, :request_path, :payload_digest, presence: true

end
