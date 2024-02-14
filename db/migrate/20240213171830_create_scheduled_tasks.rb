# frozen_string_literal: true

class CreateScheduledTasks < ActiveRecord::Migration[6.1]

  def change
    create_table :scheduled_tasks do |t|
      t.string :name
      t.datetime :next_run_after
      t.index :name, unique: true
    end
  end

end
