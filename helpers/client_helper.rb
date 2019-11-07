Backups::Plugin.helper do
  RETRIES = 5

  def api_get(path, headers = {})
    within_session do |auth_headers|
      Hash.from_xml(
        client[path].get(headers.merge(auth_headers))
      ).deep_symbolize_keys
    end
  end

  def api_post(path, payload = {}, headers = {})
    within_session do |auth_headers|
      Hash.from_xml(
        client[path].post(payload, headers.merge(auth_headers))
      ).deep_symbolize_keys
    end
  end

  def api_put(path, payload = {}, headers = {})
    within_session do |auth_headers|
      Hash.from_xml(
        client[path].put(payload, headers.merge(auth_headers))
      ).deep_symbolize_keys
    end
  end

  def api_delete(path, headers = {})
    within_session do |auth_headers|
      Hash.from_xml(
        client[path].delete(headers.merge(auth_headers))
      ).deep_symbolize_keys
    end
  end

  def client
    @client ||= RestClient::Resource.new("#{primary_host}/api")
  end

  def within_session
    tries ||= 0

    yield(session_headers)
  rescue RestClient::Unauthorized, SocketError
    @session_headers = nil

    tries += 1
    tries <= RETRIES ? retry : raise
  end

  def session_headers
    @session_headers ||=
      client['sessionMngr/?v=v1_4']
      .post(
        {},
        authorization: "Basic #{Base64.encode64("#{username}:#{password}")}".chomp
      )
      .headers
      .slice(:x_restsvcsessionid)
      .merge(content_type: :xml, accept: :xml)
  end
end
