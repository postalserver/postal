# frozen_string_literal: true

class TestLogger

  def initialize
    @log_lines = []
    @group_set = Klogger::GroupSet.new
    @print = false
  end

  def print!
    @print = true
  end

  def add(level, message, **tags)
    @group_set.groups.each do |group|
      tags = group[:tags].merge(tags)
    end

    @log_lines << { level: level, message: message, tags: tags }
    puts message if @print
    true
  end

  [:info, :debug, :warn, :error].each do |level|
    define_method(level) do |message, **tags|
      add(level, message, **tags)
    end
  end

  def tagged(**tags, &block)
    @group_set.call_without_id(**tags, &block)
  end

  def log_line(match)
    @log_lines.reverse.each do |log_line|
      return log_line if match.is_a?(String) && log_line[:message] == match
      return log_line if match.is_a?(Regexp) && log_line[:message] =~ match
    end
    nil
  end

  def has_logged?(match)
    !!log_line(match)
  end

end
