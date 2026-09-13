# frozen_string_literal: true

module ControlPlane
  class UsageReport

    MAX_RANGE = 93.days
    GRANULARITIES = %w[hourly daily monthly].freeze

    def initialize(servers:, from:, to:, granularity:)
      @servers = servers
      @from = from
      @to = to
      @granularity = granularity
    end

    def call
      validate!
      series = {}
      totals = Hash.new(0)
      @servers.each do |server|
        server.message_db.statistics.get(@granularity.to_sym, metrics, @to, periods).each do |time, values|
          bucket = (series[time.iso8601] ||= Hash.new(0))
          metrics.each do |metric|
            bucket[metric] += values[metric].to_i
            totals[metric] += values[metric].to_i
          end
        end
      end
      { totals: totals, series: series.map { |time, values| values.merge(time: time) }, rolling: rolling }
    end

    private

    def metrics
      [:outgoing, :incoming, :bounces, :held, :spam]
    end

    def periods
      case @granularity
      when "hourly" then ((@to - @from) / 1.hour).ceil
      when "daily" then ((@to - @from) / 1.day).ceil
      else (((@to.to_date.year * 12) + @to.to_date.month) - ((@from.to_date.year * 12) + @from.to_date.month) + 1)
      end
    end

    def rolling
      outgoing = @servers.sum { |server| server.message_db.live_stats.total(60, types: [:outgoing]) }
      limit = @servers.sum { |server| server.send_limit.to_i }
      { outgoing: outgoing, limit: limit.positive? ? limit : nil, percent_used: limit.positive? ? (outgoing / limit.to_f * 100).round(2) : nil }
    end

    def validate!
      raise ArgumentError, "granularity is invalid" unless GRANULARITIES.include?(@granularity)
      raise ArgumentError, "from must be before to" if @from >= @to
      raise ArgumentError, "date range is too large" if @to - @from > MAX_RANGE
    end

  end
end
