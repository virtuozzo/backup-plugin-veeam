Backups::Plugin.helper do
  def build_query(type, params, entities: true)
    hash = { type: type }

    hash[:format] = 'entities' if entities

    hash[:filter] = params.map { |k, v| "#{k}==#{v}" }.join(';')

    'query?' + CGI.unescape(URI.encode_www_form(hash))
  end
end
