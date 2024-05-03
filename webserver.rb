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
  
    md5_hash = Digest::MD5.hexdigest(command)
    cache_path = File.join('command_cache', md5_hash)
    
    @logger.info "Checking cache for response: #{cache_path}"
  
    if File.exist?(cache_path)
      @logger.info "Cache hit: #{cache_path}"
      cached_data = File.read(cache_path).split("\n\n", 2)
      if cached_data.size == 2
        @logger.info "Decoding cache response: #{cache_path}"
        begin
          cached_response_json = Base64.decode64(cached_data[1])
          cached_response = JSON.parse(cached_response_json)
          return format_response(cached_response['stdout'], cached_response['stderr'], cached_response['exit_code'], response)
        rescue JSON::ParserError => e
          @logger.error "Failed to parse JSON from cache: #{e.message}"
        end
      end
    else
      @logger.info "Cache miss: #{cache_path}"
    end
  
    stdout_file_path = "/tmp/stdout_#{md5_hash}"
    stderr_file_path = "/tmp/stderr_#{md5_hash}"
    File.write(stdout_file_path, "") # Ensure file is created
    File.write(stderr_file_path, "")
  
    out_file = File.open(stdout_file_path, 'w+')
    err_file = File.open(stderr_file_path, 'w+')
  
    begin
      # Use shell to handle redirection
      full_command = "#{command} 2>&1 | tee #{stdout_file_path}"
      pid = Process.spawn(full_command, out: out_file, err: err_file)
      Timeout.timeout(COMMAND_TIMEOUT) do
        Process.wait(pid)
      end
  
      out_file.rewind
      err_file.rewind
      stdout = out_file.read
      stderr = err_file.read
      exit_code = $?.exitstatus

      format_response(stdout, stderr, exit_code, response)
  
      if response.status == 200
        @logger.info "Saving command cache command: #{command}"
        @logger.info "Saving cache in: #{cache_path}"

        cache_content = Base64.encode64(command) + "\n" + Base64.encode64(response.body)
        File.write(cache_path, cache_content)
      end
    rescue Timeout::Error
      Process.kill('TERM', pid)
      Process.wait(pid)
      @logger.warn "Command timeout: #{command}"
      stdout = File.read(stdout_file_path) rescue ""
      stderr = File.read(stderr_file_path) rescue ""
      format_timeout_response(response, command, stdout, stderr)
    rescue => e
      @logger.error "Exception caught: #{e.message}"
      format_error_response(e, response)
    ensure
      out_file.close
      err_file.close
      File.delete(stdout_file_path) if File.exist?(stdout_file_path)
      File.delete(stderr_file_path) if File.exist?(stderr_file_path)
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

  def normalize_command(command)
    ip_regex = /\b\d{1,3}(\.\d{1,3}){3}\b/
    hostname_regex = /\b[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b/
    
    # Replace IPs and hostnames with <hostname>
    command.gsub(ip_regex, '<hostname>').gsub(hostname_regex, '<hostname>')
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

  def format_timeout_response(response, command, stdout, stderr)
    response_dict = {
      'attempted_command' => command,
      'stdout' => stdout,
      'stderr' => stderr,
      'exit_code' => -1,  # Indicative of a timeout
      'server_error' => "Command execution timed out after #{COMMAND_TIMEOUT} seconds.",
      'status' => 'fail',
      'suggestion' => "Consider modifying your command or increasing the timeout setting if consistently necessary."
    }
    response.status = 500
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
    if File.exist?(blacklist_path)
      File.readlines(blacklist_path).map(&:strip).reject { |line| line.start_with?('#') || line.empty? }
    else
      []
    end
  end
    
  def command_blacklisted?(command)
    normalized_command = normalize_command(command.strip)
    @blacklist.include?(normalized_command)
  end

  def log_command_execution(command, blacklisted)
    if blacklisted
      @logger.warn "Blocked blacklisted command: #{command}"
    else
      @logger.info "Executing command: #{command}"
    end
  end
end

server = WEBrick::HTTPServer.new(Port: 1977)
server.mount('/', Server)
trap('INT') { server.shutdown }
server.start
