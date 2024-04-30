from http.server import BaseHTTPRequestHandler, HTTPServer
import subprocess
import json

class CommandHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')  # Read the data sent by POST
        
        # Define a command timeout in seconds
        command_timeout = 60 # Timeout after 30 seconds

        # Execute the received command securely with a timeout
        try:
            result = subprocess.run(post_data, shell=True, text=True, capture_output=True, timeout=command_timeout)
            response_dict = {
                'stdout': result.stdout,
                'stderr': result.stderr,
                'exit_code': result.returncode
            }
        except subprocess.TimeoutExpired:
            response_dict = {
                'stdout': '',
                'stderr': 'Command timed out.',
                'exit_code': -1
            }
        except subprocess.CalledProcessError as e:
            response_dict = {
                'stdout': e.stdout,
                'stderr': e.stderr,
                'exit_code': e.returncode
            }

        # Send the response
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response_bytes = json.dumps(response_dict).encode('utf-8')
        self.wfile.write(response_bytes)

if __name__ == '__main__':
    server_address = ('localhost', 8000)
    httpd = HTTPServer(server_address, CommandHandler)
    httpd.serve_forever()
