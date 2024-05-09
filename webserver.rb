require 'webrick'
require 'json'
require 'tempfile'
require 'logger'
require 'fileutils'
require 'base64'
require 'digest/md5'
require_relative 'blacklist_checker' 
require_relative 'command_logger'
require_relative 'command_cache'
require_relative 'command_executor'

class Server < WEBrick::HTTPServlet::AbstractServlet
  # Define a global command timeout in seconds
  COMMAND_TIMEOUT = 30

  def initialize(server)
    super
    @logger = CommandLogger.new
    @logger.info "Server started"

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
    blacklist_checker = BlacklistChecker.new
    if blacklist_checker.blacklisted?(command)
      @logger.warn "Blocked blacklisted command: #{command}"
      format_blacklist_response(command, response)
      return
    end

    @logger.info "Executing command: #{command}"

    # cache = CommandCache.new
    # cached_response = cache.get(command)
    # if cached_response
    #   @logger.info "Cache hit: Using cached response for command: #{command}"
    #   format_response(cached_response['stdout'], cached_response['stderr'], cached_response['exit_code'], response)
    #   return
    # end
  
    executor = CommandExecutor.new(timeout: COMMAND_TIMEOUT)
    begin
      result = executor.execute(command)
      format_response(result.stdout, result.stderr, result.exit_code, response)
    rescue CommandTimeoutError => e
      format_timeout_response(response, command, e.stdout, e.stderr)
    rescue => e
      @logger.error "Exception caught: #{e.message}"
      format_error_response(e, response)
    end
  
    if response.status == 200
      # @logger.info "Caching response for command: #{command}"
      # cache.set(command, response.body)
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
      'suggestion' => "This may indicate the command is awaiting input, which is unsupported in this environment. But don't worry you can still achieve your goal without this command. Consider automating any required inputs or modifying the command to ensure it completes more rapidly or try scripting a solution. Otherwise, trying adjusting your command so it completes in a more timely manner."
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
      'suggestion' => "This may indicate the command is awaiting input, which is unsupported in this environment. But don't worry you can still achieve your goal without this command. Consider automating any required inputs or modifying the command to ensure it completes more rapidly or try scripting a solution. Otherwise, trying adjusting your command so it completes in a more timely manner."
    }
    response.status = 504
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

  def command_blacklisted?(command)
    normalized_command = normalize_command(command.strip)
    @blacklist.include?(normalized_command)
  end
end

server = WEBrick::HTTPServer.new(Port: 1977)
server.mount('/', Server)
trap('INT') { server.shutdown }
server.start
