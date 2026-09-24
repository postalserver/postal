# frozen_string_literal: true

#
# Streams the live metric changes as Server-Sent Events so a dashboard can
# react without polling. The events come from Postal::Metrics::Broadcaster,
# which the metrics write path publishes to.
#
class StatsController < ApplicationController

  include ActionController::Live

  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    Postal::Metrics::Stream.new(response.stream).run
  ensure
    response.stream.close
  end

end
