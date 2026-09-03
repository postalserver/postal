# frozen_string_literal: true

class AuditEvent < ApplicationRecord

  serialize :before_metadata, type: Hash
  serialize :after_metadata, type: Hash

  validates :resource_type, :action, :occurred_at, presence: true

end
