# == Schema Information
#
# Table name: statistics
#
#  id             :integer          not null, primary key
#  total_messages :integer          default(0)
#  total_outgoing :integer          default(0)
#  total_incoming :integer          default(0)
#

class Statistic < ApplicationRecord

  def self.global
    Statistic.first || Statistic.create
  end

end
