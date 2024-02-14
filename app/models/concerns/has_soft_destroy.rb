# frozen_string_literal: true

module HasSoftDestroy

  def self.included(base)
    base.define_callbacks :soft_destroy
    base.class_eval do
      scope :deleted, -> { where.not(deleted_at: nil) }
      scope :present, -> { where(deleted_at: nil) }
    end
  end

  def soft_destroy
    run_callbacks :soft_destroy do
      self.deleted_at = Time.now
      save!
    end
  end

end
