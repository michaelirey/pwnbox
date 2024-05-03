NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo -e "Set the proxy:\n"
echo "export NGROK_PROXY='${NGROK_URL}'"
echo -e "\n"
cd ~/pwnbox
sudo cp -a port_scanner.sh /root
sudo cp -a system_report.sh /root
sudo ruby webserver.rb
