NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
echo -e "Make note of this url:\n"
echo ${NGROK_URL}
echo -e "\n\n"
cd ~/pwnbox && ruby webserver.rb
