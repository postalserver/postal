# == Schema Information
#
# Table name: statistics
#
#  id             :integer          not null, primary key
#  total_messages :bigint(8)        default(0)
#  total_outgoing :bigint(8)        default(0)
#  total_incoming :bigint(8)        default(0)
#

class Statistic < ApplicationRecord

  def self.global
    Statistic.first || Statistic.create
  end

end
