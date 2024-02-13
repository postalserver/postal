# frozen_string_literal: true

# == Schema Information
#
# Table name: statistics
#
#  id             :integer          not null, primary key
#  total_incoming :bigint           default(0)
#  total_messages :bigint           default(0)
#  total_outgoing :bigint           default(0)
#

class Statistic < ApplicationRecord

  def self.global
    Statistic.first || Statistic.create
  end

end
