# frozen_string_literal: true

require "rails_helper"

module Worker
  module Jobs

    RSpec.describe ProcessWebhookRequestsJob do
      subject(:job) { described_class.new(logger: Postal.logger) }

      let(:mocked_service) { double("Service") }

      before do
        allow(WebhookDeliveryService).to receive(:new).and_return(mocked_service)
        allow(mocked_service).to receive(:call).with(no_args)
      end

      context "when there are no requests to process" do
        it "does nothing" do
          job.call
          expect(job.work_completed?).to be false
        end
      end

      context "when there is a unlocked request with no retry time" do
        it "delivers the request" do
          request = create(:webhook_request)
          job.call
          expect(WebhookDeliveryService).to have_received(:new).with(webhook_request: request)
          expect(job.work_completed?).to be true
        end
      end

      context "when there is an unlocked request with a retry time in the past" do
        it "delivers the request" do
          request = create(:webhook_request, retry_after: 1.minute.ago)
          job.call
          expect(WebhookDeliveryService).to have_received(:new).with(webhook_request: request)
          expect(job.work_completed?).to be true
        end
      end

      context "when there is an unlocked request with a retry time in the future" do
        it "does nothing" do
          create(:webhook_request, retry_after: 1.minute.from_now)
          job.call
          expect(job.work_completed?).to be false
        end
      end

      context "when there is a locked requested without a retry time" do
        it "does nothing" do
          create(:webhook_request, :locked)
          job.call
          expect(job.work_completed?).to be false
        end
      end
    end

  end
end
