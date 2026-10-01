# frozen_string_literal: true

class AddPrioritySubjectsToServers < ActiveRecord::Migration[7.0]
  def change
    add_column :servers, :priority_subjects, :text
  end
end
