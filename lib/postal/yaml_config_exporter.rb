# frozen_string_literal: true

require "konfig/exporters/abstract"

module Postal
  class YamlConfigExporter < Konfig::Exporters::Abstract

    def export
      contents = []
      contents << "version: 2"
      contents << ""

      @schema.groups.each do |group_name, group|
        contents << "#{group_name}:"
        group.attributes.each do |name, attr|
          contents << "  # #{attr.description}"
          if attr.array?
            if attr.default.blank?
              contents << "  #{name}: []"
            else
              contents << "  #{name}:"
              attr.transform(attr.default).each do |d|
                contents << "    - #{d}"
              end
            end
          else
            contents << "  #{name}: #{attr.default}"
          end
        end
        contents << ""
      end

      contents.join("\n")
    end

  end
end
