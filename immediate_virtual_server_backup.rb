Backups::Plugin.hook helpers: %i[client_helper query_helper task_helper uid_helper session_helper] do
  BACKUP_RESULT_KEY_CHAIN = %i[QueryResult Entities BackupJobSessions BackupJobSession Result].freeze

  def call(virtual_server)
    job_id = virtual_server.metadata[:veeam_related_job_ids]&.first

    return error('Unable to find jobs for %s' % virtual_server.label) unless job_id

    task_path = task_path(api_post("jobs/#{job_id}?action=start"))

    task_poller(task_path, interval: 15).run

    backup_session_uid = get_backup_session_uid(job_id)

    return error('Unable to start backup session') unless backup_session_uid

    session_poller(
      BACKUP_RESULT_KEY_CHAIN,
      build_query(:backupJobSession, uid: backup_session_uid)
    ).run
  end

  private

  def get_backup_session_uid(job_id)
    [
      api_get(
        build_query(:BackupJobSession, jobUid: identifier_to_uid(:Job, job_id), state: :Working)
      ).dig(:QueryResult, :Entities, :BackupJobSessions, :BackupJobSession)
    ]
      .flatten
      .compact
      .max_by { |hash| Time.parse(hash[:CreationTimeUTC]) }
      &.fetch(:UID)
  end
end
