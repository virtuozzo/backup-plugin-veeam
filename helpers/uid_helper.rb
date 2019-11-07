Backups::Plugin.helper do
  URN = 'urn:veeam:%s:%s'.freeze

  def identifier_to_uid(object_type, identifier)
    return unless identifier

    URN.format(object_type, identifier)
  end

  def uid_to_identifier(object_type, uid)
    return unless uid

    uid.gsub("urn:veeam:#{object_type}:", '')
  end
end
