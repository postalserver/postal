# frozen_string_literal: true

module ManagementAPI
  class StatisticsController < BaseController

    # GET /management/api/v1/servers/:server_id/statistics
    # Get server statistics
    #
    # Params:
    #   period - "hour", "day", "week", "month" (default: "day")
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "statistics": {
    #       "outgoing": { ... },
    #       "incoming": { ... }
    #     }
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      period = api_params[:period] || "day"

      case period
      when "hour"
        time_range = 1.hour.ago..Time.now
        group_by = :minute
      when "day"
        time_range = 24.hours.ago..Time.now
        group_by = :hour
      when "week"
        time_range = 7.days.ago..Time.now
        group_by = :day
      when "month"
        time_range = 30.days.ago..Time.now
        group_by = :day
      else
        render_error "InvalidPeriod", message: "Invalid period. Use: hour, day, week, month"
        return
      end

      outgoing_stats = get_message_stats(server, "outgoing", time_range, group_by)
      incoming_stats = get_message_stats(server, "incoming", time_range, group_by)

      render_success(
        period: period,
        time_range: {
          start: time_range.begin,
          end: time_range.end
        },
        statistics: {
          outgoing: outgoing_stats,
          incoming: incoming_stats
        }
      )
    end

    # GET /management/api/v1/servers/:server_id/statistics/summary
    # Get server statistics summary
    def summary
      server = find_server(params[:server_id])

      render_success(
        summary: {
          total_messages: {
            outgoing: server.message_db.messages_count(scope: "outgoing"),
            incoming: server.message_db.messages_count(scope: "incoming")
          },
          today: {
            outgoing: count_messages_since(server, "outgoing", Time.now.beginning_of_day),
            incoming: count_messages_since(server, "incoming", Time.now.beginning_of_day)
          },
          this_hour: {
            outgoing: count_messages_since(server, "outgoing", 1.hour.ago),
            incoming: count_messages_since(server, "incoming", 1.hour.ago)
          },
          held_messages: server.message_db.messages_count(where: { status: "Held" }),
          queued_messages: server.queued_messages.count,
          domains_count: server.domains.count,
          credentials_count: server.credentials.count,
          webhooks_count: server.webhooks.count
        }
      )
    end

    # GET /management/api/v1/servers/:server_id/statistics/by_status
    # Get message counts by status
    def by_status
      server = find_server(params[:server_id])
      scope = api_params[:scope] || "outgoing"

      statuses = %w[Pending Sent SoftFail HardFail Held Processed Bounced]

      counts = {}
      statuses.each do |status|
        counts[status.downcase] = server.message_db.messages_count(
          scope: scope,
          where: { status: status }
        )
      end

      render_success(
        scope: scope,
        by_status: counts
      )
    end

    # GET /management/api/v1/servers/:server_id/statistics/by_domain
    # Get message counts by domain
    def by_domain
      server = find_server(params[:server_id])

      domain_stats = server.domains.map do |domain|
        {
          domain: domain.name,
          uuid: domain.uuid,
          outgoing: server.message_db.messages_count(
            scope: "outgoing",
            where: { domain_id: domain.id }
          ),
          incoming: server.message_db.messages_count(
            scope: "incoming",
            where: { domain_id: domain.id }
          )
        }
      end

      render_success(by_domain: domain_stats)
    end

    # GET /management/api/v1/servers/:server_id/statistics/clicks_and_opens
    # Get click and open tracking statistics
    def clicks_and_opens
      server = find_server(params[:server_id])
      days = (api_params[:days] || 7).to_i

      # Get recent messages with tracking data
      messages = server.message_db.messages(
        scope: "outgoing",
        where: { timestamp: { greater_than: days.days.ago.to_f } },
        order: :timestamp,
        direction: "desc",
        limit: 1000
      )

      total_sent = messages.count
      total_opened = 0
      total_clicked = 0

      messages.each do |msg|
        total_opened += 1 if msg.loads.any?
        total_clicked += 1 if msg.clicks.any?
      end

      render_success(
        period_days: days,
        tracking: {
          total_sent: total_sent,
          total_opened: total_opened,
          total_clicked: total_clicked,
          open_rate: total_sent > 0 ? (total_opened.to_f / total_sent * 100).round(2) : 0,
          click_rate: total_sent > 0 ? (total_clicked.to_f / total_sent * 100).round(2) : 0
        }
      )
    end

    private

    def get_message_stats(server, scope, time_range, group_by)
      stats = {
        total: server.message_db.messages_count(
          scope: scope,
          where: { timestamp: { greater_than: time_range.begin.to_f, less_than: time_range.end.to_f } }
        ),
        sent: 0,
        soft_fail: 0,
        hard_fail: 0,
        bounced: 0
      }

      if scope == "outgoing"
        stats[:sent] = server.message_db.messages_count(
          scope: scope,
          where: { status: "Sent", timestamp: { greater_than: time_range.begin.to_f } }
        )
        stats[:soft_fail] = server.message_db.messages_count(
          scope: scope,
          where: { status: "SoftFail", timestamp: { greater_than: time_range.begin.to_f } }
        )
        stats[:hard_fail] = server.message_db.messages_count(
          scope: scope,
          where: { status: "HardFail", timestamp: { greater_than: time_range.begin.to_f } }
        )
        stats[:bounced] = server.message_db.messages_count(
          scope: scope,
          where: { status: "Bounced", timestamp: { greater_than: time_range.begin.to_f } }
        )
      end

      stats
    end

    def count_messages_since(server, scope, since)
      server.message_db.messages_count(
        scope: scope,
        where: { timestamp: { greater_than: since.to_f } }
      )
    end

  end
end
