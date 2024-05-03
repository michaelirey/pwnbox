class CacheReadError < StandardError; end

class CommandCache
  def initialize(cache_dir = "command_cache")
    @cache_dir = cache_dir
    FileUtils.mkdir_p(@cache_dir)
  end

  def md5_for(command)
    Digest::MD5.hexdigest(command)
  end

  def get(command)
    cache_path = cache_path_for(command)
    return nil unless File.exist?(cache_path)

    cached_data = read_cache_file(cache_path)
    return nil unless valid_cache_data?(cached_data)

    parse_cached_response(cached_data[1])
  end

  def set(command, response_body)
    cache_path = cache_path_for(command)
    cache_content = Base64.encode64(command) + "\n" + Base64.encode64(response_body)
    File.write(cache_path, cache_content)
  end

  private

  def cache_path_for(command)
    File.join(@cache_dir, md5_for(command))
  end

  def read_cache_file(cache_path)
    File.read(cache_path).split("\n\n", 2)
  end

  def valid_cache_data?(cached_data)
    cached_data.size == 2
  end

  def parse_cached_response(cached_response_json)
    decoded_json = Base64.decode64(cached_response_json)
    JSON.parse(decoded_json)
  rescue JSON::ParserError => e
    raise CacheReadError.new("Failed to parse JSON from cache: #{e.message}")
  end
end
