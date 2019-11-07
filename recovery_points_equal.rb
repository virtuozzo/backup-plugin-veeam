Backups::Plugin.hook do
  def call(local_recovery_point, remote_recovery_point)
    if local_recovery_point.metadata[:veeam_id] == remote_recovery_point.metadata[:veeam_id]
      success
    else
      error
    end
  end
end
