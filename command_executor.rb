class CommandExecutor
  def initialize(timeout:)
    @timeout = timeout
  end

  def execute(command)
    stdout_file, stderr_file = create_temp_files(command)
    begin
      pid = spawn_command(command, stdout_file, stderr_file)
      wait_for_process(pid)

      stdout, stderr, exit_code = collect_results(stdout_file, stderr_file)
      CommandResult.new(stdout, stderr, exit_code)
    rescue Timeout::Error
      handle_timeout(pid, stdout_file, stderr_file)
    ensure
      cleanup_temp_files(stdout_file, stderr_file)
    end
  end

  private

  def create_temp_files(command)
    md5_hash = Digest::MD5.hexdigest(command)
    stdout_file = Tempfile.new(["stdout", ".#{md5_hash}"])
    stderr_file = Tempfile.new(["stderr", ".#{md5_hash}"])
    [stdout_file, stderr_file]
  end

  def spawn_command(command, stdout_file, stderr_file)
    full_command = "#{command} 2>&1 | tee #{stdout_file.path}"
    Process.spawn(command, chdir: "/root", out: stdout_file, err: stderr_file)
  end

  def wait_for_process(pid)
    Timeout.timeout(@timeout) do
      Process.wait(pid)
    end
  end

  def collect_results(stdout_file, stderr_file)
    stdout_file.rewind
    stderr_file.rewind
    [stdout_file.read, stderr_file.read, $?.exitstatus]
  end

  def handle_timeout(pid, stdout_file, stderr_file)
    Process.kill('TERM', pid)
    Process.wait(pid)
    stdout, stderr, _ = collect_results(stdout_file, stderr_file)
    raise CommandTimeoutError.new(stdout, stderr)
  end

  def cleanup_temp_files(stdout_file, stderr_file)
    stdout_file.close
    stderr_file.close
    stdout_file.unlink
    stderr_file.unlink
  end
end

# Additional class for command results
class CommandResult
  attr_reader :stdout, :stderr, :exit_code

  def initialize(stdout, stderr, exit_code)
    @stdout = stdout
    @stderr = stderr
    @exit_code = exit_code
  end
end

# Custom error class for timeouts
class CommandTimeoutError < StandardError
  attr_reader :stdout, :stderr

  def initialize(stdout, stderr)
    @stdout = stdout
    @stderr = stderr
    super("Command timed out")
  end
end