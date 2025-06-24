# MCP Test HTTP Server Usage

## Quick Start

### Windows
```bat
run_test_server.bat
```

### Direct Python
```bash
python test_http_server.py
```

### Custom Port
```bash
python test_http_server.py 9000
```

## Testing Endpoints

### Health Check
```bash
curl http://localhost:8080/health
```

### Simple Test
```bash
curl http://localhost:8080/test
```

### MCP JSON-RPC Request
```bash
curl -X POST http://localhost:8080/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"ping","id":1}'
```

### Echo Test
```bash
curl -X POST http://localhost:8080/ \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"echo","params":{"test":"data"},"id":2}'
```

## Server Features

- **Timestamped logs** - All requests logged with timestamps
- **CORS enabled** - Cross-origin requests allowed
- **JSON-RPC 2.0** - Proper error handling and response format
- **Error handling** - Parse errors and internal errors handled gracefully

## Expected Server Output

```
MCP Test Server starting on port 8080
Health check: http://localhost:8080/health
Test endpoint: http://localhost:8080/test
Main endpoint: http://localhost:8080/ (POST)
Press Ctrl+C to stop the server
```

## Testing Your Mod

1. Start the server: `run_test_server.bat`
2. Configure your mod to use `http://localhost:8080/`
3. Monitor server console for incoming requests
4. Verify JSON-RPC responses are properly formatted

The server will echo all received requests to the console for debugging.