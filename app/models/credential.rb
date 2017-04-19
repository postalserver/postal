# == Schema Information
#
# Table name: credentials
#
#  id           :integer          not null, primary key
#  server_id    :integer
#  key          :string(255)
#  type         :string(255)
#  name         :string(255)
#  options      :text(65535)
#  last_used_at :datetime
#  created_at   :datetime
#  updated_at   :datetime
#  hold         :boolean          default(FALSE)
#

class Credential < ApplicationRecord

  belongs_to :server

  TYPES = ['SMTP', 'API']

  validates :key, :presence => true, :uniqueness => true
  validates :type, :inclusion => {:in => TYPES}
  validates :name, :presence => true

  random_string :key, :type => :chars, :length => 24, :unique => true

  serialize :options, Hash

  def to_param
    key
  end

  def use
    update_column(:last_used_at, Time.now)
  end

  def usage_type
    if last_used_at.nil?
      'Unused'
    elsif last_used_at < 1.year.ago
      'Inactive'
    elsif last_used_at < 6.months.ago
      'Dormant'
    elsif last_used_at < 1.month.ago
      'Quiet'
    else
      'Active'
    end
  end

  def to_smtp_plain
    Base64.encode64("\0XX\0#{self.key}").strip
  end

end
