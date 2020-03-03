Backups::Plugin.hook helpers: %i[client_helper query_helper uid_helper] do
  def call(virtual_server)

    # Get VmRestorePoint for Virtual Server
    vm_recovery_points = get_vm_recovery_points(virtual_server.metadata[:veeam_uid])

    # Iterate over Jobs => Backup => restorePoints => vmRestorePoints
    virtual_server.metadata[:veeam_related_job_ids].flat_map do |job_id|

      # Get Job's name by its ID
      unless job_name = api_get("jobs/#{job_id}")
                          .dig(:EntityRef, :Name)
        logger.error("Unable to get Name of Job by ID: '#{job_id}'")
        next
      end

      # Find Backup which name matches Job's name
      unless backup_id = get_backup_id(job_name)
        logger.error("Unable to find Backup for Job named '#{job_name}'")
        next
      end

      # Get restorePoints for Backup
      get_recovery_points("backups", backup_id, "restorePoints")
        .uniq { |r| r[:UID] }
        .flat_map do |restore_point_hash|
        unless rp_id = uid_to_identifier("RestorePoint", restore_point_hash[:UID])
          logger.error("Unable to get RestorePoint ID")
          next
        end

        # Get vmRestorePoints for restorePoints
        get_recovery_points("restorePoints", rp_id, "vmRestorePoints")
          .flatten
          .compact.map do |vm_restore_point_hash|

          # Skip vmRestorePoint if it isn't in VmRestorePoint for Virtual Server
          next unless vm_recovery_points.any? {|vm_rp| vm_rp[:UID].eql? vm_restore_point_hash[:UID]}

          # Restore point date is right after '@' rightmost occurrence
          vm_restore_point_date = vm_restore_point_hash[:Name].rpartition('@')[2]

          build_recovery_point(size: 0, # Unable to get size via EM API
                           created_at: vm_restore_point_date,
                           updated_at: vm_restore_point_date,
                           state: :built).tap do |rp|
            rp.metadata[:veeam_id] = uid_to_identifier("VmRestorePoint", vm_restore_point_hash[:UID])
          end
        end
      end
    end.compact
  end

  private

  def get_backup_id(backup_name)
    uid_to_identifier(
      :Backup,
      api_get(build_query(:backup, { name: "\"#{backup_name}\"" }, entities: false))
        .dig(:QueryResult, :Refs, :Ref, :UID)
    )
  end

  def get_recovery_points(resource_type, resource_id, points_type)
      points = api_get("/#{resource_type}/#{resource_id}/#{points_type}")
                 .dig(:EntityReferences, :Ref)

      return unless points

      points.is_a?(Hash) ? [points] : points
  end

  def get_vm_recovery_points(resource_id)
    vm_points = api_get(build_query(:vmrestorepoint, HierarchyObjRef: "\"#{resource_id}\""))
                  .dig(:QueryResult, :Entities, :VmRestorePoints, :VmRestorePoint)

    return unless vm_points

    vm_points.is_a?(Hash) ? [vm_points] : vm_points
  end

end
