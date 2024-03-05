# frozen_string_literal: true

require "konfig/exporters/abstract"

module Postal
  class HelmConfigExporter < Konfig::Exporters::Abstract

    def export
      contents = []

      path = []

      @schema.groups.each do |group_name, group|
        path << group_name
        group.attributes.each do |name, _|
          env_var = Konfig::Sources::Environment.path_to_env_var(path + [name])
          contents << <<~VAR.strip
            {{ include "app.envVar" (dict "name" "#{env_var}" "spec" .Values.postal.#{path.join('.')}.#{name} "root" . ) }}
          VAR
        end
        path.pop
      end

      contents.join("\n")
    end

  end
end
