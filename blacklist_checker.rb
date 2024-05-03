class BlacklistChecker
  def initialize(blacklist_path = "blacklist.txt")
    @blacklist = load_blacklist(blacklist_path)
  end

  def blacklisted?(command)
    normalized_command = normalize_command(command)
    @blacklist.include?(normalized_command)
  end

  private

  def load_blacklist(path)
    if File.exist?(path)
      File.readlines(path).map(&:strip).reject { |line| line.start_with?('#') || line.empty? }
    else
      []
    end
  end

  def normalize_command(command)
    ip_regex = /\b\d{1,3}(\.\d{1,3}){3}\b/
    hostname_regex = /\b[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b/
    
    # Replace IPs and hostnames with <hostname>
    command.gsub(ip_regex, '<hostname>').gsub(hostname_regex, '<hostname>')
  end
end
