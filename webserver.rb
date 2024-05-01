require 'webrick'
require 'json'
require 'tempfile'
require 'logger'

class Server < WEBrick::HTTPServlet::AbstractServlet
  # Define a global command timeout in seconds
  COMMAND_TIMEOUT = 60

  # Initialize Logger
  def initialize(server)
    super
    # Logger now logs to both STDOUT and a file
    @logger = Logger.new('server_log.log', 10, 1024000)
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime}: #{severity} - #{msg}\n"
    end
    @logger.info "Server started"
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
    rescue Timeout::Error
      Process.kill('TERM', pid)
      Process.wait(pid)
      @logger.error "Command timed out: #{command}"
      format_timeout_response(response)
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

  def format_timeout_response(response)
    response_dict = {
      'stdout' => '',
      'stderr' => 'Command timed out.',
      'exit_code' => -1
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
end

server = WEBrick::HTTPServer.new(Port: 8000)
server.mount('/', Server)
trap('INT') { server.shutdown }
server.start
