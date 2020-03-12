Backups::Plugin.hook helpers: %i[client_helper task_helper query_helper uid_helper schedule_params_helper] do
  def call(schedule, virtual_server)
    new_name = "#{schedule.period.capitalize} #{schedule.id}@#{virtual_server.label}"

    # Find template job
    template_job_id = get_job_id(
      backup_resource.advanced_options[:vsphere_template_job_name]
    )

    unless template_job_id
      return error('Unable to find template job. Please check the correctness of Backup Resource options')
    end

    unless backup_repository_uid
      return error('Unable to find backup repository. Please check the correctness of Backup Resource options')
    end

    # Get target VM references
    vm_to_add_ref = vm_ref(virtual_server)

    return error('Unable to find the VM host in the Veeam infrastructure') unless vm_to_add_ref

    virtual_server.metadata[:veeam_uid] = vm_to_add_ref[:obj_ref]

    # Clone template job with a new name
    task_path =
      task_path(api_post("jobs/#{template_job_id}?action=clone", clone_params(new_name).to_xml))

    task_poller(task_path).run

    # Get cloned job ID
    job_id = get_job_id(new_name)

    return error('Clone job task has been failed') unless job_id

    virtual_server.metadata[:veeam_related_job_ids] ||= []

    virtual_server.metadata[:veeam_related_job_ids] << job_id

    # Get ID of VM which we have to delete
    vm_to_delete =
      api_get("jobs/#{job_id}/includes").dig(:ObjectsInJob, :ObjectInJob, :ObjectInJobId)

    # Add a target VM to the job
    task_path =
      task_path(
        api_post("jobs/#{job_id}/includes", add_vm_params(vm_to_add_ref).to_xml)
      )

    task_poller(task_path).run

    # Remove redundant VM
    task_path =
      task_path(api_delete("jobs/#{job_id}/includes/#{vm_to_delete}"))

    task_poller(task_path).run

    # Edit & enable schedule
    task_path =
      task_path(api_put("jobs/#{job_id}?action=edit", schedule_params(schedule).to_xml))

    task_poller(task_path).run
  end

  private

  def get_job_id(job_name)
    uid_to_identifier(
      :Job,
      api_get(build_query(:job, { name: "\"#{job_name}\"" }, entities: false))
        .dig(:QueryResult, :Refs, :Ref, :UID)
    )
  end

  def backup_repository_uid
    @backup_repository_uid ||=
      api_get(
        build_query(
          :repository,
          { name: "\"#{backup_resource.advanced_options[:backup_repository_name]}\"" },
          entities: false
        )
      )
      .dig(:QueryResult, :Refs, :Ref, :UID)
  end

  def backup_server_id
    backup_repository_ref =
      api_get("repositories/#{uid_to_identifier(:Repository, backup_repository_uid)}")
        .dig(:EntityRef, :Links, :Link)

    return unless backup_repository_ref

    backup_repository_ref.detect { |hash| hash[:Type] == 'BackupServerReference' }[:Href]
      .rpartition('/')[2] || ""
  end

  def vcenter_instance_uuid(virtual_server)
    if virtual_server.vcloud?
      virtual_server.vcenter
    else
      virtual_server.compute
    end.instance_uuid
  end

  def clone_params(name)
    Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.JobCloneSpec(
        'xmlns' => 'http://www.veeam.com/ent/v1.0',
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
      ) do
        xml.BackupJobCloneInfo do
          xml.JobName       name
          xml.FolderName    name
          xml.RepositoryUid backup_repository_uid
        end
      end
    end
  end

  def add_vm_params(vm_to_add_ref)
    Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.CreateObjectInJobSpec(
        'xmlns' => 'http://www.veeam.com/ent/v1.0',
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
      ) do
        xml.HierarchyObjRef  vm_to_add_ref[:obj_ref]
        xml.HierarchyObjName vm_to_add_ref[:obj_name]
      end
    end
  end

  def vm_ref(virtual_server)
    hierarchyroots =
      api_get(
        build_query(:hierarchyroot, { uniqueid: "\"#{vcenter_instance_uuid(virtual_server)}\"" }, entities: false)
      ).dig(:QueryResult, :Refs, :Ref)

    return unless hierarchyroots

    # Iterate over hierarchyroots to find proper VMware vCenter
    (hierarchyroots.is_a?(Hash) ? [hierarchyroots] : hierarchyroots).each do |hierarchyroot|
      hierarchy_root_id = uid_to_identifier(:HierarchyRoot, hierarchyroot[:UID])
      next unless hierarchy_root_id

      backup_server_href =
        api_get("hierarchyRoots/#{hierarchy_root_id}").dig(:EntityRef, :Links, :Link)
      next unless backup_server_href

      backup_server_url =
        backup_server_href.detect { |hash| hash[:Type] == 'BackupServerReference' }[:Href]
      next unless backup_server_url

      # BackupServer ID of VM hierarchyroot is equal to BackupServer ID of BackupRepository
      if backup_server_url
           .rpartition('/')[2]
           .eql? backup_server_id
        return {
                 obj_ref: "urn:VMware:Vm:#{hierarchy_root_id}.#{virtual_server.vcenter_moref}",
                 obj_name: virtual_server.label
               }
      end
    end

    return
  end
end
