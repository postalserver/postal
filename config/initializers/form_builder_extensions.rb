# frozen_string_literal: true

# Provides `f.error_messages` on form builders. This used to come from the
# dynamic_form gem - see ErrorMessagesHelper for why that was removed.
ActiveSupport.on_load(:action_view) do
  ActionView::Helpers::FormBuilder.class_eval do
    def error_messages
      @template.error_messages_for(@object)
    end
  end
end
