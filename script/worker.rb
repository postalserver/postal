#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"
Postal::Worker.new([:main]).work
