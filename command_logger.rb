class CommandLogger
  def initialize(log_file_path = "server_log.log")
    @logger = Logger.new(log_file_path, 10, 1024000)
    @logger.formatter = proc do |severity, datetime, progname, msg|
    "#{datetime}: #{severity} - #{msg}\n"
    end
  end

  def info(message)
    @logger.info(message)
  end

  def warn(message)
    @logger.warn(message)
  end

  def error(message)
    @logger.error(message)
  end
end
