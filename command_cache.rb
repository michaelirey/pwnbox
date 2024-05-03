class CommandCache
  def initialize(cache_dir = "command_cache")
    @cache_dir = cache_dir
    FileUtils.mkdir_p(@cache_dir)
  end

  def md5_for(command)
    Digest::MD5.hexdigest(command)
  end
  
  def get(command)
    md5_hash = Digest::MD5.hexdigest(command)
    cache_path = File.join(@cache_dir, md5_hash)
    if File.exist?(cache_path)
      cached_data = File.read(cache_path).split("\n\n", 2)
      if cached_data.size == 2
        begin
          cached_response_json = Base64.decode64(cached_data[1])
          JSON.parse(cached_response_json)
        rescue JSON::ParserError => e
          @logger.error "Failed to parse JSON from cache: #{e.message}"
          nil
        end
      end
    else
      nil
    end
  end

  def set(command, response_body)
    md5_hash = Digest::MD5.hexdigest(command)
    cache_path = File.join(@cache_dir, md5_hash)
    cache_content = Base64.encode64(command) + "\n" + Base64.encode64(response_body)
    File.write(cache_path, cache_content)
  end
end