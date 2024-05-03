require 'net/http'
require 'uri'
require 'json'

describe 'Server' do
  let(:url) { ENV['NGROK_PROXY'] }

  it 'executes a non-blacklisted command with "date"' do
    uri = URI("#{url}/command")
    res = Net::HTTP.post(uri, 'date')
    expect(res.code).to eq "200"
    response_body = JSON.parse(res.body)
    expect(response_body['stdout']).not_to be_empty
  end

  it 'executes a non-blacklisted command with "ftp -h"' do
    uri = URI("#{url}/command")
    res = Net::HTTP.post(uri, 'ftp -h')
    expect(res.code).to eq "200"
    response_body = JSON.parse(res.body)
    expect(response_body['stdout']).not_to be_empty
  end

  it 'returns an error for a blacklisted command' do
    uri = URI("#{url}/command")
    res = Net::HTTP.post(uri, 'telnet 192.168.1.1')
    expect(res.code).to eq "403"
    response_body = JSON.parse(res.body)
    expect(response_body['server_error']).to match(/Command not allowed/)
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
