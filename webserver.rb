require 'webrick'
require 'json'
require 'open3'
require 'tempfile'

class Server < WEBrick::HTTPServlet::AbstractServlet
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
    stdout, stderr, status = Open3.capture3(command, binmode: true)
    format_response(stdout, stderr, status, response)
  end

  def execute_script(request, response)
    request_body = JSON.parse(request.body)
    file_contents = request_body['file_contents']
    execute_with = request_body['execute_with']

    Tempfile.create(['script', '.']) do |file|
      file.write(file_contents)
      file.close

      command = "#{execute_with} #{file.path}"
      stdout, stderr, status = Open3.capture3(command, binmode: true)
      format_response(stdout, stderr, status, response)
    end
  end

  def format_response(stdout, stderr, status, response)
    response_dict = if status.success?
                      { 'stdout' => stdout, 'stderr' => stderr, 'exit_code' => status.exitstatus }
                    else
                      { 'stdout' => '', 'stderr' => 'Command did not exit normally or failed.', 'exit_code' => status.exitstatus || -1 }
                    end

    response.status = 200
    response['Content-Type'] = 'application/json'
    response.body = JSON.generate(response_dict)
  end
end

server = WEBrick::HTTPServer.new(Port: 8000)
server.mount('/', Server)
trap('INT') { server.shutdown }
server.start
