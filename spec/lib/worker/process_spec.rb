# frozen_string_literal: true

require "rails_helper"

module Worker

  RSpec.describe Process do
    subject(:process) { described_class.new(thread_count: 1) }

    before do
      # Each process registers its metrics so each example needs its own registry
      allow(Prometheus::Client).to receive(:registry).and_return(Prometheus::Client::Registry.new)

      # Errors are normally logged and swallowed, raise them so they fail the example instead
      allow(process).to receive(:capture_errors).and_yield
    end

    describe "#work" do
      it "runs each job and returns false when there was no work to do" do
        expect(process.send(:work, 0)).to be false
      end
    end

    describe "#run_task" do
      it "runs a task which is due and schedules its next run" do
        scheduled_task = ScheduledTask.create!(name: "PruneWebhookRequestsScheduledTask", next_run_after: 1.minute.ago)
        task = instance_double(PruneWebhookRequestsScheduledTask, call: nil)
        allow(PruneWebhookRequestsScheduledTask).to receive(:new).and_return(task)

        process.send(:run_task, PruneWebhookRequestsScheduledTask)

        expect(task).to have_received(:call)
        expect(scheduled_task.reload.next_run_after).to be > Time.current
      end
    end
  end

end
