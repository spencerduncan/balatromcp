#!/usr/bin/env python3
"""
Minimal HTTP server for testing Balatro MCP mod HTTP transport
"""

import http.server
import socketserver
import json
import urllib.parse
from datetime import datetime

class MCPTestHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Override to add timestamps to logs"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {format % args}")
    
    def _send_json_response(self, data, status_code=200):
        """Send JSON response with proper headers"""
        response_json = json.dumps(data, indent=2)
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response_json)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(response_json.encode('utf-8'))
    
    def do_OPTIONS(self):
        """Handle preflight CORS requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urllib.parse.urlparse(self.path)
        
        if parsed_path.path == '/health':
            self._send_json_response({
                "status": "ok",
                "timestamp": datetime.now().isoformat(),
                "message": "MCP test server is running"
            })
        elif parsed_path.path == '/test':
            self._send_json_response({
                "jsonrpc": "2.0",
                "result": {
                    "message": "Test response from server",
                    "timestamp": datetime.now().isoformat()
                },
                "id": 1
            })
        else:
            self._send_json_response({
                "error": "Not found",
                "path": self.path
            }, 404)
    
    def do_POST(self):
        """Handle POST requests (main MCP endpoint)"""
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        try:
            # Parse JSON request
            request_data = json.loads(post_data.decode('utf-8'))
            print(f"Received request: {json.dumps(request_data, indent=2)}")
            
            # Handle different MCP request types
            if request_data.get('method') == 'ping':
                response = {
                    "jsonrpc": "2.0",
                    "result": {
                        "message": "pong",
                        "timestamp": datetime.now().isoformat()
                    },
                    "id": request_data.get('id', 1)
                }
            elif request_data.get('method') == 'echo':
                response = {
                    "jsonrpc": "2.0",
                    "result": {
                        "echo": request_data.get('params', {}),
                        "timestamp": datetime.now().isoformat()
                    },
                    "id": request_data.get('id', 1)
                }
            else:
                # Generic response for any other method
                response = {
                    "jsonrpc": "2.0",
                    "result": {
                        "status": "received",
                        "method": request_data.get('method', 'unknown'),
                        "params": request_data.get('params', {}),
                        "timestamp": datetime.now().isoformat()
                    },
                    "id": request_data.get('id', 1)
                }
            
            self._send_json_response(response)
            
        except json.JSONDecodeError as e:
            error_response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32700,
                    "message": "Parse error",
                    "data": str(e)
                },
                "id": None
            }
            self._send_json_response(error_response, 400)
        except Exception as e:
            error_response = {
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": "Internal error",
                    "data": str(e)
                },
                "id": None
            }
            self._send_json_response(error_response, 500)

def run_server(port=8080):
    """Start the HTTP server"""
    handler = MCPTestHandler
    
    with socketserver.TCPServer(("", port), handler) as httpd:
        print(f"MCP Test Server starting on port {port}")
        print(f"Health check: http://localhost:{port}/health")
        print(f"Test endpoint: http://localhost:{port}/test")
        print(f"Main endpoint: http://localhost:{port}/ (POST)")
        print("Press Ctrl+C to stop the server")
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped by user")

if __name__ == "__main__":
    import sys
    
    port = 8080
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print("Invalid port number. Using default port 8080.")
    
    run_server(port)