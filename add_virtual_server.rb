Backups::Plugin.hook do
  # Veeam scans the host by itself, so there is no need to add a server to the plugin
  def call(_virtual_server); end
end
