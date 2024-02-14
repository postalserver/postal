# frozen_string_literal: true

# == Schema Information
#
# Table name: scheduled_tasks
#
#  id             :bigint           not null, primary key
#  name           :string(255)
#  next_run_after :datetime
#
# Indexes
#
#  index_scheduled_tasks_on_name  (name) UNIQUE
#
class ScheduledTask < ApplicationRecord
end
