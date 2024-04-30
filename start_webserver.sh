NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo "Make note of this url:"
echo ${NGROK_URL}
echo "\n\n"
cd ~/pwnbox && python shell_server.py
