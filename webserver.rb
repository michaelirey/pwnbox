require 'webrick'
require 'json'
require 'tempfile'
require 'logger'
require 'fileutils'
require 'base64'
require 'digest/md5'


class Server < WEBrick::HTTPServlet::AbstractServlet
  # Define a global command timeout in seconds
  COMMAND_TIMEOUT = 60

  def initialize(server)
    super
    @logger = Logger.new('server_log.log', 10, 1024000)
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime}: #{severity} - #{msg}\n"
    end
    @logger.info "Server started"
    @blacklist = load_blacklist
  
    # Ensure command cache directory exists
    FileUtils.mkdir_p('command_cache')
  end
  
  def do_POST(request, response)
    route = request.path

    case route
    when '/command'
      # Direct command execution
      execute_command(request.body, response)
    when '/execute'
      # Execute from script content
      execute_script(request, response)
    else
      # Unsupported endpoint
      response.status = 404
      response.body = 'Not found'
    end
  end

  private
  
  def execute_command(command, response)
    if command_blacklisted?(command)
      log_command_execution(command, true)
      format_blacklist_response(command, response)
      return
    end
  
    log_command_execution(command, false)
  
    # Use MD5 hash of the command as the cache key
    md5_hash = Digest::MD5.hexdigest(command)
    cache_path = File.join('command_cache', md5_hash)
  
    @logger.info "Checking cached for response: #{cache_path}"

    # Check if the response is cached
    if File.exist?(cache_path)
      @logger.info "Cache for response found: #{cache_path}"
      cached_data = File.read(cache_path).split("\n\n", 2)
      if cached_data.size == 2
        @logger.info "Decoding cache response: #{cache_path}"

        # Decoding and parsing inside a begin-rescue block
        begin
          cached_response_json = Base64.decode64(cached_data[1])
          cached_response = JSON.parse(cached_response_json)
        rescue JSON::ParserError => e
          @logger.error "Failed to parse JSON from cache: #{e.message}"
          @logger.error "Failed to parse JSON cached_data: #{cached_data}"
          @logger.error "Base64 decode part 1: #{Base64.decode64(cached_data[0])}"
          @logger.error "Base64 decode part 2: #{Base64.decode64(cached_data[1])}"

          @logger.info "Invalid JSON content: #{cached_response_json}"
          # Handle error, e.g., by ignoring the cache and re-executing the command
        end

        # Extract components from the parsed JSON
        stdout = cached_response['stdout'] || ""
        stderr = cached_response['stderr'] || ""
        exit_code = cached_response['exit_code'] || -1

        @logger.info "Returning cached response for command: #{command}"
        # Pass the decoded and parsed data to format_response
        return format_response(stdout, stderr, exit_code, response)
      else
        @logger.info "Cache was found but not decoded: #{cache_path}"
      end
    else
      @logger.info "Cache for response NOT found: #{cache_path}"
    end

    begin
      out_file = Tempfile.new('stdout')
      err_file = Tempfile.new('stderr')
      pid = Process.spawn(command, out: out_file, err: err_file)
      Timeout.timeout(COMMAND_TIMEOUT) do
        Process.wait(pid)
      end
      out_file.rewind
      err_file.rewind
      stdout = out_file.read
      stderr = err_file.read
      exit_code = $?.exitstatus
  
      format_response(stdout, stderr, exit_code, response)

      # Cache the response if it's successful
      if response.status == 200
        @logger.info "Saving command cache command: #{command}"
        @logger.info "Saving cache in: #{cache_path}"

        cache_content = Base64.encode64(command) + "\n" + Base64.encode64(response.body)
        File.write(cache_path, cache_content)
      end

    rescue Timeout::Error
      Process.kill('TERM', pid)
      Process.wait(pid)
      format_timeout_response(response, command)
    rescue => e
      @logger.error "Exception caught: #{e.message}"
      format_error_response(e, response)
    ensure
      out_file.close
      out_file.unlink
      err_file.close
      err_file.unlink
    end
  end
        
  def execute_script(request, response)
    request_body = JSON.parse(request.body)
    file_contents = request_body['file_contents']
    execute_with = request_body['execute_with']

    Tempfile.create(['script', '.']) do |file|
      file.write(file_contents)
      file.close

      command = "#{execute_with} #{file.path}"
      execute_command(command, response)
    end
  end

  def format_response(stdout, stderr, exit_code, response)
    response_dict = {
      'stdout' => stdout,
      'stderr' => stderr,
      'exit_code' => exit_code || -1
    }

    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(response_dict)
  end

  def format_blacklist_response(command, response)
    response_dict = {
      'attempted_command' => command,
      'server_error' => "Command not allowed and is blacklisted.",
      'status' => 'fail',
      'suggestion' => "This may indicate the command is awaiting input, which is unsupported in this environment. Consider automating any required inputs or modifying the command to ensure it completes more rapidly or try scripting a solution. Otherwise, trying adjusting your command so it completes in a more timely manner."
    }
    response.status = 403
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(response_dict)
  end

  def format_timeout_response(response, command)
    response_dict = {
      'attempted_command' => command,
      'server_error' => "Command execution timed out after #{COMMAND_TIMEOUT} seconds.",
      'status' => 'fail',
      'suggestion' => "This may indicate the command is awaiting input, which is unsupported in this environment. Consider automating any required inputs or modifying the command to ensure it completes more rapidly or try scripting a solution. Otherwise, trying adjusting your command so it completes in a more timely manner."
    }
    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(response_dict)
  end

  def format_error_response(error, response)
    response_dict = {
      'stdout' => '',
      'stderr' => error.message,
      'exit_code' => -1
    }
    response.status = 500
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(response_dict)
  end

  def load_blacklist
    blacklist_path = 'blacklist.txt'
    File.exist?(blacklist_path) ? File.readlines(blacklist_path).map(&:strip) : []
  end
  
  def command_blacklisted?(command)
    # Sanitize the command by removing outputs piped from it
    sanitized_command = command.gsub(/<<.*$/, '').strip
  
    # Split the command into parts for structured matching
    command_parts = sanitized_command.split
  
    # Iterate over each blacklisted command pattern
    @blacklist.any? do |bl_command|
      bl_parts = bl_command.split
      # Check if the initial parts of the command match the blacklisted command parts
      next false if bl_parts.size > command_parts.size
      bl_parts.each_with_index.all? { |part, index| part == command_parts[index] }
    end
  end
  

  def log_command_execution(command, blacklisted)
    if blacklisted
      @logger.warn "Blocked blacklisted command: #{command}"
    else
      @logger.info "Executing command: #{command}"
    end
  end
  
end

server = WEBrick::HTTPServer.new(Port: 8000)
server.mount('/', Server)
trap('INT') { server.shutdown }
server.start
