Backups::Plugin.hook helpers: %i[client_helper task_helper query_helper session_helper] do
  RESTORE_RESULT_KEY_CHAIN = %i[QueryResult Entities RestoreSessions RestoreSession Result].freeze
  RESTORE_SESSION_REGEX = %r{restoreSessions\/(.*)}

  def call(recovery_point, _virtual_server)
    restore_path = "vmRestorePoints/#{recovery_point.metadata[:veeam_id]}?action=restore"

    restore_session_url = begin
      task_path = task_path(api_post(restore_path, restore_params.to_xml))

      task_poller(task_path).run

      links = api_get(task_path)[:Task][:Links][:Link]

      links.is_a?(Array) ? links.detect { |hash| hash[:Type] == 'RestoreSession' }[:Href] : nil
    end

    return error('Unable to start restore session') unless restore_session_url

    restore_session_uid =
      RESTORE_SESSION_REGEX.match(URI(restore_session_url).path)[1]

    session_poller(
      RESTORE_RESULT_KEY_CHAIN,
      build_query(:restoresession, uid: "\"#{restore_session_uid}\"")
    ).run
  rescue RestClient::ResourceNotFound
    error('Unable to find restore point')
  end

  private

  def restore_params
    Nokogiri::XML::Builder.new do |xml|
      xml.RestoreSpec(
        'xmlns' => 'http://www.veeam.com/ent/v1.0',
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
      ) do
        xml.VmRestoreSpec do
          xml.PowerOnAfterRestore !!backup_resource.advanced_options[:power_on_after_restore]
          xml.QuickRollback       !!backup_resource.advanced_options[:quick_rollback]
        end
      end
    end
  end
end
