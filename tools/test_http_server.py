#!/usr/bin/env python3
"""
Minimal HTTP server for testing Balatro MCP mod HTTP transport
"""

import http.server
import socketserver
import json
import urllib.parse
from datetime import datetime


def _summarize_value(value, max_items=3):
    """
    Helper function to create a concise summary of any value.
    Shows structure and sample content for complex types.
    """
    if value is None:
        return "null"
    elif isinstance(value, (str, int, float, bool)):
        return value
    elif isinstance(value, list):
        if len(value) == 0:
            return "[]"
        elif len(value) <= max_items:
            return [_summarize_value(item, max_items) for item in value]
        else:
            sample = [_summarize_value(item, max_items) for item in value[:max_items]]
            return {"type": "array", "length": len(value), "sample": sample}
    elif isinstance(value, dict):
        if len(value) == 0:
            return "{}"
        elif len(value) <= max_items:
            return {k: _summarize_value(v, max_items) for k, v in value.items()}
        else:
            sample_keys = list(value.keys())[:max_items]
            sample = {k: _summarize_value(value[k], max_items) for k in sample_keys}
            return {"type": "object", "keys": len(value), "sample": sample}
    else:
        return {"type": type(value).__name__, "value": str(value)[:100]}


def create_summarized_output(data):
    """
    Create a comprehensive but concise summary of game data for console output.
    Shows structure and sample content for complex data while maintaining readability.
    """
    if not isinstance(data, dict):
        return {"summary": "Invalid data format", "type": type(data).__name__}

    summary = {
        "timestamp": data.get("timestamp", "unknown"),
        "data_type": "game_data",
        "total_keys": len(data),
    }

    # Summarize deck information if present
    if "deck" in data:
        deck = data["deck"]
        if isinstance(deck, dict):
            deck_summary = {
                "card_count": len(deck.get("cards", [])),
                "joker_count": len(deck.get("jokers", [])),
                "consumable_count": len(deck.get("consumables", [])),
            }

            # Add sample cards if present
            if "cards" in deck and deck["cards"]:
                deck_summary["sample_cards"] = _summarize_value(deck["cards"], 2)

            # Add sample jokers if present
            if "jokers" in deck and deck["jokers"]:
                deck_summary["sample_jokers"] = _summarize_value(deck["jokers"], 2)

            # Add other deck properties
            deck_keys = [
                k for k in deck.keys() if k not in ["cards", "jokers", "consumables"]
            ]
            if deck_keys:
                deck_summary["other_properties"] = {
                    k: _summarize_value(deck[k]) for k in deck_keys[:3]
                }

            summary["deck"] = deck_summary

    # Summarize game state if present
    if "game_state" in data:
        state = data["game_state"]
        if isinstance(state, dict):
            state_summary = {
                "round": state.get("round", "unknown"),
                "ante": state.get("ante", "unknown"),
                "dollars": state.get("dollars", "unknown"),
                "hands": state.get("hands", "unknown"),
            }

            # Add other state properties
            state_keys = [
                k
                for k in state.keys()
                if k not in ["round", "ante", "dollars", "hands"]
            ]
            if state_keys:
                state_summary["other_properties"] = {
                    k: _summarize_value(state[k]) for k in state_keys[:4]
                }

            summary["game_state"] = state_summary

    # Summarize other top-level keys
    processed_keys = {"timestamp", "deck", "game_state"}
    other_keys = [k for k in data.keys() if k not in processed_keys]

    if other_keys:
        summary["other_data"] = {}
        for key in other_keys[:5]:  # Limit to first 5 other keys
            summary["other_data"][key] = _summarize_value(data[key])

    # Include metadata
    summary["data_keys"] = list(data.keys())
    summary["data_size_bytes"] = len(json.dumps(data).encode("utf-8"))

    return summary


class MCPTestHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        """Override to add timestamps to logs"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {format % args}")

    def _send_json_response(self, data, status_code=200):
        """Send JSON response with proper headers"""
        response_json = json.dumps(data, indent=2)
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response_json)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(response_json.encode("utf-8"))

    def do_OPTIONS(self):
        """Handle preflight CORS requests"""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        """Handle GET requests"""
        parsed_path = urllib.parse.urlparse(self.path)

        if parsed_path.path == "/health":
            self._send_json_response(
                {
                    "status": "ok",
                    "timestamp": datetime.now().isoformat(),
                    "message": "MCP test server is running",
                }
            )
        elif parsed_path.path == "/test":
            self._send_json_response(
                {
                    "jsonrpc": "2.0",
                    "result": {
                        "message": "Test response from server",
                        "timestamp": datetime.now().isoformat(),
                    },
                    "id": 1,
                }
            )
        else:
            self._send_json_response({"error": "Not found", "path": self.path}, 404)

    def do_POST(self):
        """Handle POST requests"""
        parsed_path = urllib.parse.urlparse(self.path)
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)

        # Handle /game-data endpoint for BalatroMCP
        if parsed_path.path == "/game-data":
            try:
                # Parse and echo the request data
                request_data = json.loads(post_data.decode("utf-8"))
                print(f"\n[GAME-DATA] Received POST to /game-data:")
                summarized_data = create_summarized_output(request_data)
                print(f"{json.dumps(summarized_data, indent=2)}")

                # Send simple success response
                response = {
                    "status": "success",
                    "message": "Game data received",
                    "timestamp": datetime.now().isoformat(),
                    "data_size": len(post_data),
                }
                self._send_json_response(response)

            except json.JSONDecodeError as e:
                print(f"\n[GAME-DATA] JSON parse error: {e}")
                print(f"Raw data: {post_data.decode('utf-8', errors='replace')}")
                error_response = {
                    "status": "error",
                    "message": "Invalid JSON data",
                    "error": str(e),
                }
                self._send_json_response(error_response, 400)
            except Exception as e:
                print(f"\n[GAME-DATA] Unexpected error: {e}")
                error_response = {
                    "status": "error",
                    "message": "Internal server error",
                    "error": str(e),
                }
                self._send_json_response(error_response, 500)
            return

        # Handle /actions endpoint for BalatroMCP
        if parsed_path.path == "/actions":
            try:
                # Return sample actions for testing
                response = {
                    "status": "success",
                    "sequence_id": 1,
                    "actions": [],
                    "timestamp": datetime.now().isoformat(),
                }
                self._send_json_response(response)

            except Exception as e:
                print(f"\n[ACTIONS] Error: {e}")
                error_response = {
                    "status": "error",
                    "message": "Internal server error",
                    "error": str(e),
                }
                self._send_json_response(error_response, 500)
            return

        # Handle JSON-RPC requests (original functionality)
        try:
            # Parse JSON request
            request_data = json.loads(post_data.decode("utf-8"))
            print(f"Received JSON-RPC request: {json.dumps(request_data, indent=2)}")

            # Handle different MCP request types
            if request_data.get("method") == "ping":
                response = {
                    "jsonrpc": "2.0",
                    "result": {
                        "message": "pong",
                        "timestamp": datetime.now().isoformat(),
                    },
                    "id": request_data.get("id", 1),
                }
            elif request_data.get("method") == "echo":
                response = {
                    "jsonrpc": "2.0",
                    "result": {
                        "echo": request_data.get("params", {}),
                        "timestamp": datetime.now().isoformat(),
                    },
                    "id": request_data.get("id", 1),
                }
            else:
                # Generic response for any other method
                response = {
                    "jsonrpc": "2.0",
                    "result": {
                        "status": "received",
                        "method": request_data.get("method", "unknown"),
                        "params": request_data.get("params", {}),
                        "timestamp": datetime.now().isoformat(),
                    },
                    "id": request_data.get("id", 1),
                }

            self._send_json_response(response)

        except json.JSONDecodeError as e:
            error_response = {
                "jsonrpc": "2.0",
                "error": {"code": -32700, "message": "Parse error", "data": str(e)},
                "id": None,
            }
            self._send_json_response(error_response, 400)
        except Exception as e:
            error_response = {
                "jsonrpc": "2.0",
                "error": {"code": -32603, "message": "Internal error", "data": str(e)},
                "id": None,
            }
            self._send_json_response(error_response, 500)


def run_server(port=8080):
    """Start the HTTP server"""
    handler = MCPTestHandler

    with socketserver.TCPServer(("", port), handler) as httpd:
        print(f"MCP Test Server starting on port {port}")
        print(f"Health check: http://localhost:{port}/health")
        print(f"Test endpoint: http://localhost:{port}/test")
        print(f"Game data endpoint: http://localhost:{port}/game-data (POST)")
        print(f"Actions endpoint: http://localhost:{port}/actions (POST)")
        print(f"JSON-RPC endpoint: http://localhost:{port}/ (POST)")
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
