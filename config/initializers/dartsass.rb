# frozen_string_literal: true

# Dart Sass entry points. The stylesheet source lives at
# app/assets/stylesheets/application/application.scss (nested, not the
# default flat application.scss), so the mapping names it explicitly. Output
# lands in app/assets/builds/application/application.css, which the manifest's
# link_tree picks up -- the layout's `stylesheet_link_tag
# 'application/application'` keeps resolving unchanged. The manifest must NOT
# link the stylesheets directory itself, or Sprockets would try (and fail) to
# compile the SCSS sources directly.
Rails.application.config.dartsass.builds = {
  "application/application.scss" => "application/application.css"
}
