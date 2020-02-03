Backups::Plugin.hook helpers: %i[client_helper] do
  def call(virtual_server)
    virtual_server.metadata[:veeam_related_job_ids]&.each do |job_id|
      begin
          api_put("jobs/#{job_id}", disable_schedule_params.to_xml)
      rescue RestClient::BadRequest => err
          logger.error("Job #{job_id} doesn't exist on third-party: " + err.message)
      end
    end

    success
  end

  private

  def disable_schedule_params
    Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.Job(
        'xmlns' => 'http://www.veeam.com/ent/v1.0',
        'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
      ) do
        xml.Description "Disabled by OnApp at #{Time.now.utc.strftime('%m/%d/%Y %I:%M %p %Z')}"
        xml.ScheduleConfigured false
        xml.ScheduleEnabled    false
      end
    end
  end
end
