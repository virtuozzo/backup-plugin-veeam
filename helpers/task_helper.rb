# frozen_string_literal: true

Backups::Plugin.helper do
  TRUE    = 'true'
  FALSE   = 'false'
  UNKNOWN = 'unknown'

  EMPTY_MESSAGE = ''

  TASK_POLL_INTERVAL = 5 # seconds

  def task_status(task_path)
    task = api_get(task_path)[:Task]

    task[:Result]&.values_at(:Success, :Message) || [UNKNOWN, EMPTY_MESSAGE]
  end

  def task_path(response)
    URI(response[:Task][:Links][:Link][:Href]).path.gsub('/api/', '')
  end

  def task_poller(task_path, interval: TASK_POLL_INTERVAL)
    poller.setup(
      interval: interval,
      statuses: {
        success: TRUE,
        progress: UNKNOWN,
        failure: FALSE
      }
    ) do |p|
      p.handle_status(*task_status(task_path))
    end
  end
end
