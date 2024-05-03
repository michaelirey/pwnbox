require 'net/http'
require 'uri'
require 'json'

describe 'Server' do
  let(:url) { ENV['NGROK_PROXY'] }

  it 'executes a non-blacklisted command with "date"' do
    uri = URI("#{url}/command")
    res = Net::HTTP.post(uri, 'whoami')
    expect(res.code).to eq "200"
    response_body = JSON.parse(res.body)
    expect(response_body).to include(
      'stdout' => "root\n",
      'stderr' => "",
      'exit_code' => 0
    )
  end

  it 'executes a non-blacklisted command with "ftp -h"' do
    uri = URI("#{url}/command")
    res = Net::HTTP.post(uri, 'ftp -h')
    expect(res.code).to eq "200"
    response_body = JSON.parse(res.body)
    expect(response_body).to include(
      'stdout' => "\n\tUsage: { ftp | pftp } [-46pinegvtd] [hostname]\n\t   -4: use IPv4 addresses only\n\t   -6: use IPv6, nothing else\n\t   -p: enable passive mode (default for pftp)\n\t   -i: turn off prompting during mget\n\t   -n: inhibit auto-login\n\t   -e: disable readline support, if present\n\t   -g: disable filename globbing\n\t   -v: verbose mode\n\t   -t: enable packet tracing [nonfunctional]\n\t   -d: enable debugging\n\n",
      'stderr' => "",
      'exit_code' => 0
    )
  end

  it 'returns an error for a blacklisted command' do
    uri = URI("#{url}/command")
    res = Net::HTTP.post(uri, 'telnet 192.168.1.1')
    expect(res.code).to eq "403"
  
    response_body = JSON.parse(res.body)
    expect(response_body).to include(
      'attempted_command' => 'telnet 192.168.1.1',
      'server_error' => "Command not allowed and is blacklisted.",
      'status' => 'fail',
      'suggestion' => "This may indicate the command is awaiting input, which is unsupported in this environment. But don't worry you can still achieve your goal without this command. Consider automating any required inputs or modifying the command to ensure it completes more rapidly or try scripting a solution. Otherwise, trying adjusting your command so it completes in a more timely manner." 
    )
  end

  it 'test the cache' do
    uri = URI("#{url}/command")
    res1 = Net::HTTP.post(uri, 'date')
    expect(res1.code).to eq "200"
    response_body1 = JSON.parse(res1.body)

    sleep 1

    res2 = Net::HTTP.post(uri, 'date')
    expect(res2.code).to eq "200"
    response_body2 = JSON.parse(res2.body)

    expect(response_body1['stdout']).to eq(response_body2['stdout'])
  end
end
