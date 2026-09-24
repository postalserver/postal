# frozen_string_literal: true

# == Schema Information
#
# Table name: acme_challenges
#
#  id         :integer          not null, primary key
#  content    :text(65535)
#  expires_at :datetime
#  token      :string(255)
#  created_at :datetime
#  updated_at :datetime
#
# Indexes
#
#  index_acme_challenges_on_token  (token) UNIQUE
#

# A response to an ACME HTTP-01 challenge which is waiting to be collected by the
# certificate authority. The responses are held in the database rather than in
# memory because the validation request may be served by any web worker.
class ACMEChallenge < ApplicationRecord

  validates :token, presence: true, uniqueness: true

  class << self

    # Store the response for a challenge so that it can be served when the
    # certificate authority requests it.
    #
    # @param token [String] the challenge token
    # @param content [String] the key authorization to serve
    # @param expires_at [Time] when the response may be discarded
    # @return [ACMEChallenge]
    def store!(token, content, expires_at: 1.hour.from_now)
      challenge = where(token: token).first_or_initialize
      challenge.content = content
      challenge.expires_at = expires_at
      challenge.save!
      challenge
    end

    # The content to serve for a token, or nil when there is nothing waiting.
    #
    # @param token [String]
    # @return [String, nil]
    def content_for(token)
      where(token: token).where("expires_at > ?", Time.now).pick(:content)
    end

    # Remove responses which are no longer needed.
    #
    # @return [Integer] the number of rows removed
    def prune!
      where("expires_at < ?", Time.now).delete_all
    end

  end

end
