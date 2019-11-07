Backups::Plugin.hook helpers: %i[client_helper query_helper uid_helper] do
  def call(virtual_server)
    recovery_points =
      api_get(
        build_query(:vmrestorepoint, HierarchyObjRef: "\"#{virtual_server.metadata[:veeam_uid]}\"")
      ).dig(:QueryResult, :Entities, :VmRestorePoints, :VmRestorePoint)

    [recovery_points].flatten.compact.map do |recovery_point_hash|
      build_recovery_point(size: 0, # Unable to get size via EM API
                           created_at: Time.parse(recovery_point_hash[:CreationTimeUTC]),
                           updated_at: Time.parse(recovery_point_hash[:CreationTimeUTC]),
                           state: :built).tap do |rp|
        rp.metadata[:veeam_id] = uid_to_identifier(:VmRestorePoint, recovery_point_hash[:UID])
      end
    end
  end
end
