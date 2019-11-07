# frozen_string_literal: true

Backups::Plugin.helper do
  SESSION_SUCCESS  = %w[Success Warning].freeze
  SESSION_PROGRESS = 'None'
  SESSION_FAILED   = 'Failed'

  SESSION_POLL_INTERVAL = 60 # seconds

  def session_poller(key_chain, query)
    poller.setup(
      interval: SESSION_POLL_INTERVAL,
      statuses: {
        success: SESSION_SUCCESS,
        progress: SESSION_PROGRESS,
        failed: SESSION_FAILED
      }
    ) do |p|
      p.handle_status(session_status(key_chain, query))
    end
  end

  def session_status(key_chain, query)
    api_get(query).dig(*key_chain)
  end
end
