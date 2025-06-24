# HTTPS Transport Documentation

## Table of Contents

1. [Overview](#overview)
2. [Configuration](#configuration)
3. [Integration Examples](#integration-examples)
4. [Server Endpoint Specifications](#server-endpoint-specifications)
5. [Testing and Debugging](#testing-and-debugging)
6. [Deployment Considerations](#deployment-considerations)

## Overview

The HTTPS Transport is a network-based implementation of the [`IMessageTransport`](../interfaces/message_transport.lua) interface that enables communication with remote servers over HTTPS. It provides a robust alternative to the local file-based [`FileTransport`](../transports/file_transport.lua) for scenarios requiring centralized message handling, multi-client coordination, or cloud-based game state management.

### Key Capabilities

- **Bidirectional Communication**: Sends game state data via POST requests and receives actions via GET requests
- **Sequence Tracking**: Prevents duplicate action processing using sequence IDs
- **Authentication Support**: Configurable HTTP headers for API authentication
- **Error Handling**: Comprehensive network error detection and logging
- **Fallback Mechanisms**: Graceful degradation when network libraries are unavailable

### Comparison with FileTransport

| Feature | HTTPS Transport | FileTransport |
|---------|----------------|---------------|
| **Storage Location** | Remote server | Local filesystem |
| **Message Persistence** | Server-managed | File-based with cleanup |
| **Multi-client Support** | Yes | No |
| **Authentication** | HTTP headers | File permissions |
| **Network Dependency** | Required | None |
| **Latency** | Network-dependent | Local I/O |
| **Reliability** | Depends on network/server | Depends on filesystem |

### Server Requirements

The HTTPS Transport requires a server implementation that provides:

- **Game Data Endpoint**: Accepts POST requests with game state data
- **Actions Endpoint**: Serves GET requests with pending actions
- **HTTPS/TLS Support**: Secure communication channel
- **JSON Processing**: Handles structured message payloads
- **Sequence Management**: Tracks message ordering and prevents duplicates

## Configuration

### Basic Configuration

```lua
local HttpsTransport = require('transports.https_transport')

local config = {
    base_url = "https://api.example.com",
    timeout = 10
}

local transport = HttpsTransport.new(config)
```

### Complete Configuration Options

```lua
local config = {
    -- Required: Base URL for the HTTPS server
    base_url = "https://api.example.com",
    
    -- Optional: Custom endpoint paths (defaults shown)
    game_data_endpoint = "/game-data",     -- POST endpoint for game state
    actions_endpoint = "/actions",         -- GET endpoint for actions
    
    -- Optional: Request timeout in seconds (default: 5)
    timeout = 10,
    
    -- Optional: HTTP headers for authentication and customization
    headers = {
        ["Authorization"] = "Bearer your-api-token",
        ["X-API-Key"] = "your-api-key",
        ["X-Client-ID"] = "balatro-client-001"
    }
}

local transport = HttpsTransport.new(config)
```

### Authentication Examples

#### Bearer Token Authentication
```lua
local config = {
    base_url = "https://api.example.com",
    headers = {
        ["Authorization"] = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
}
```

#### API Key Authentication
```lua
local config = {
    base_url = "https://api.example.com",
    headers = {
        ["X-API-Key"] = "sk-1234567890abcdef",
        ["X-Client-Version"] = "1.0.0"
    }
}
```

#### Basic Authentication
```lua
local config = {
    base_url = "https://api.example.com",
    headers = {
        ["Authorization"] = "Basic " .. base64.encode("username:password")
    }
}
```

### Network Timeout and Reliability

The timeout configuration affects all HTTP requests:

```lua
local config = {
    base_url = "https://api.example.com",
    timeout = 30  -- Longer timeout for slower networks
}
```

**Timeout Recommendations:**
- **Local Development**: 5-10 seconds
- **Production Networks**: 10-30 seconds
- **Mobile/Unstable Networks**: 30-60 seconds

## Integration Examples

### Replacing FileTransport with HttpsTransport

**Before (FileTransport):**
```lua
local FileTransport = require('transports.file_transport')
local MessageManager = require('message_manager')

-- File-based transport
local transport = FileTransport.new("shared")
local manager = MessageManager.new(transport)
```

**After (HttpsTransport):**
```lua
local HttpsTransport = require('transports.https_transport')
local MessageManager = require('message_manager')

-- HTTPS-based transport
local transport = HttpsTransport.new({
    base_url = "https://api.example.com",
    headers = {
        ["Authorization"] = "Bearer your-token"
    }
})
local manager = MessageManager.new(transport)
```

### MessageManager Integration Pattern

```lua
local HttpsTransport = require('transports.https_transport')
local MessageManager = require('message_manager')

-- Initialize transport with configuration
local transport = HttpsTransport.new({
    base_url = "https://your-game-server.com",
    game_data_endpoint = "/api/v1/game-data",
    actions_endpoint = "/api/v1/actions",
    timeout = 15,
    headers = {
        ["Authorization"] = "Bearer " .. get_auth_token(),
        ["X-Game-Version"] = "1.0.0"
    }
})

-- Check availability before use
if not transport:is_available() then
    error("Server is not available - check network connection")
end

-- Create message manager with HTTPS transport
local manager = MessageManager.new(transport)

-- Use normally - same interface as FileTransport
manager:send_game_state(game_state_data)
local actions = manager:get_pending_actions()
```

### Error Handling Best Practices

```lua
local function create_robust_transport(config)
    local transport = HttpsTransport.new(config)
    
    -- Test connectivity
    local available = transport:is_available()
    if not available then
        error("Server unavailable: " .. config.base_url)
    end
    
    return transport
end

local function send_with_retry(transport, message_data, message_type, max_retries)
    max_retries = max_retries or 3
    
    for attempt = 1, max_retries do
        local success = transport:write_message(message_data, message_type)
        if success then
            return true
        end
        
        -- Exponential backoff
        if attempt < max_retries then
            local delay = 2 ^ attempt
            love.timer.sleep(delay)
        end
    end
    
    return false
end

-- Usage
local transport = create_robust_transport({
    base_url = "https://api.example.com",
    timeout = 10
})

local success = send_with_retry(transport, game_data, "game_state", 3)
if not success then
    -- Fall back to FileTransport or queue for later
    handle_network_failure(game_data)
end
```

## Server Endpoint Specifications

### Game Data Endpoint (POST)

**Endpoint:** `POST {base_url}{game_data_endpoint}`  
**Default:** `POST https://api.example.com/game-data`

#### Request Format

```json
{
    "message_type": "game_state",
    "timestamp": "2024-01-01T00:00:00Z",
    "sequence_id": 42,
    "data": {
        "phase": "SELECTING_HAND",
        "dollars": 100,
        "hands_left": 3,
        "ante": 1,
        "round": 1
    },
    "result": {
        "action": "play_hand",
        "success": true,
        "cards_played": ["AS", "KS", "QS", "JS", "TS"]
    },
    "last_sequence_id": 41
}
```

#### Request Headers

```
Content-Type: application/json
User-Agent: BalatroMCP/1.0
Authorization: Bearer your-token (if configured)
X-API-Key: your-key (if configured)
```

#### Expected Response

**Success (200 OK):**
```json
{
    "received": true,
    "timestamp": "2024-01-01T00:00:01Z",
    "sequence_id": 42
}
```

**Error (400 Bad Request):**
```json
{
    "error": "Invalid message format",
    "details": "Missing required field: message_type"
}
```

**Error (401 Unauthorized):**
```json
{
    "error": "Authentication required",
    "details": "Invalid or missing authorization token"
}
```

### Actions Endpoint (GET)

**Endpoint:** `GET {base_url}{actions_endpoint}`  
**Default:** `GET https://api.example.com/actions`

#### Request Headers

```
Accept: application/json
User-Agent: BalatroMCP/1.0
Authorization: Bearer your-token (if configured)
```

#### Response Format

**Success (200 OK):**
```json
{
    "timestamp": "2024-01-01T00:00:02Z",
    "sequence_id": 43,
    "data": {
        "action_type": "play_hand",
        "cards": ["AS", "KS", "QS", "JS", "TS"],
        "target": "opponent",
        "metadata": {
            "hand_type": "royal_flush",
            "multiplier": 1000
        }
    }
}
```

**No Actions Available (200 OK):**
```json
{
    "message": "No actions available",
    "timestamp": "2024-01-01T00:00:02Z"
}
```

**Error (404 Not Found):**
```json
{
    "error": "Actions endpoint not found"
}
```

### Message Structure Documentation

#### Core Fields

- **`message_type`** (string): Type of message ("game_state", "deck_state", "action_result", etc.)
- **`timestamp`** (string): ISO 8601 timestamp when message was created
- **`sequence_id`** (number): Unique identifier for message ordering and deduplication
- **`data`** (object): The actual message payload containing game state or action data

#### Optional Fields

- **`result`** (object): Result of the last executed action (included in game state updates)
- **`last_sequence_id`** (number): Sequence ID of the last processed action (for server synchronization)

#### Sequence ID Processing

The transport uses sequence IDs to prevent duplicate processing:

1. **Outgoing Messages**: Include current sequence ID in all POST requests
2. **Incoming Actions**: Only process actions with sequence IDs higher than the last processed
3. **Server Synchronization**: Include `last_sequence_id` to help server track client state

### HTTP Status Codes and Error Handling

| Status Code | Meaning | Transport Behavior |
|-------------|---------|-------------------|
| **200 OK** | Success | Process response normally |
| **201 Created** | Resource created | Treat as success |
| **400 Bad Request** | Invalid request | Log error, return failure |
| **401 Unauthorized** | Authentication failed | Log error, return failure |
| **403 Forbidden** | Access denied | Log error, return failure |
| **404 Not Found** | Endpoint not found | For `/health` endpoint, treat as available |
| **500 Internal Server Error** | Server error | Log error, return failure |
| **503 Service Unavailable** | Server overloaded | Log error, return failure |
| **Network Error** | Connection failed | Log error, return failure |

## Testing and Debugging

### Running Unit Tests

```bash
# Run all HTTPS transport tests
lua tests/run_luaunit_tests.lua test_https_transport_luaunit

# Run specific test function
lua tests/run_luaunit_tests.lua test_https_transport_luaunit TestHttpsTransportWriteMessageSuccess
```

### Test Coverage

The test suite covers:
- **Initialization**: Configuration validation and library loading
- **Interface Compliance**: IMessageTransport contract adherence
- **Network Operations**: HTTP request/response handling
- **Error Handling**: Network failures and invalid responses
- **Sequence Tracking**: Duplicate prevention and ordering
- **Integration**: Message structure compatibility with FileTransport

### Common Troubleshooting Scenarios

#### 1. Server Not Available

**Symptoms:**
- `transport:is_available()` returns `false`
- Write operations fail with network errors

**Diagnosis:**
```lua
local transport = HttpsTransport.new(config)
local available = transport:is_available()

if not available then
    print("Server not available. Check:")
    print("1. Network connection")
    print("2. Server URL: " .. config.base_url)
    print("3. Server status")
    print("4. Firewall settings")
end
```

**Solutions:**
1. Verify server URL is correct and accessible
2. Check network connectivity
3. Confirm server is running and healthy
4. Test with curl: `curl -I https://api.example.com/health`

#### 2. Authentication Errors

**Symptoms:**
- HTTP 401 or 403 responses
- Write operations fail with authorization errors

**Diagnosis:**
```lua
local config = {
    base_url = "https://api.example.com",
    headers = {
        ["Authorization"] = "Bearer " .. token
    }
}

local transport = HttpsTransport.new(config)
local success = transport:write_message(test_data, "test")

if not success then
    print("Authentication failed. Check:")
    print("1. Token validity")
    print("2. Token format")
    print("3. Server authentication requirements")
end
```

**Solutions:**
1. Verify authentication token is valid and not expired
2. Check token format (Bearer, API key, etc.)
3. Confirm server authentication requirements
4. Test authentication manually with curl

#### 3. Network Timeout Issues

**Symptoms:**
- Requests timeout frequently
- Intermittent connection failures

**Diagnosis:**
```lua
local config = {
    base_url = "https://api.example.com",
    timeout = 30  -- Increase timeout
}

-- Monitor request duration
local start_time = os.clock()
local success = transport:write_message(data, "test")
local duration = os.clock() - start_time

print("Request duration: " .. duration .. " seconds")
```

**Solutions:**
1. Increase timeout value in configuration
2. Check network latency to server
3. Optimize server response time
4. Consider connection pooling

#### 4. JSON Parsing Errors

**Symptoms:**
- Actions not processed
- Invalid JSON error messages

**Diagnosis:**
```lua
-- Check server response format
local response = transport:read_message("actions")
if response then
    print("Raw response: " .. response)
    
    local success, data = pcall(transport.json.decode, response)
    if not success then
        print("JSON parse error: " .. data)
    end
end
```

**Solutions:**
1. Verify server returns valid JSON
2. Check JSON structure matches expected format
3. Validate sequence_id field presence
4. Test with JSON validator tools

### Network Connectivity Validation

```lua
local function validate_connectivity(config)
    local transport = HttpsTransport.new(config)
    
    -- Test basic connectivity
    print("Testing connectivity to: " .. config.base_url)
    local available = transport:is_available()
    print("Available: " .. tostring(available))
    
    if not available then
        return false
    end
    
    -- Test write operation
    local test_data = {
        timestamp = os.date("%Y-%m-%dT%H:%M:%SZ"),
        sequence_id = 1,
        data = {test = "connectivity"}
    }
    
    local write_success = transport:write_message(test_data, "test")
    print("Write test: " .. tostring(write_success))
    
    -- Test read operation
    local read_result = transport:read_message("actions")
    print("Read test: " .. tostring(read_result ~= nil))
    
    return write_success
end

-- Usage
local config = {
    base_url = "https://api.example.com",
    timeout = 10
}

local connectivity_ok = validate_connectivity(config)
if not connectivity_ok then
    print("Connectivity validation failed")
end
```

### Logging and Diagnostic Information

The HTTPS transport provides comprehensive logging:

```lua
-- Enable debug logging (automatic)
local transport = HttpsTransport.new(config)

-- Logs are written to:
-- Console: All operations and errors
-- File: shared/https_transport_debug.log (if filesystem available)
```

**Log Format:**
```
BalatroMCP [HTTPS_TRANSPORT]: Making POST request #1 to: https://api.example.com/game-data
BalatroMCP [HTTPS_TRANSPORT]: Request #1 completed in 0.234s, status: 200
BalatroMCP [HTTPS_TRANSPORT]: Message written successfully to: https://api.example.com/game-data
```

**Key Diagnostic Information:**
- Request/response timing
- HTTP status codes
- Request/response body sizes
- Sequence ID tracking
- Error details and context

## Deployment Considerations

### HTTPS/TLS Requirements

**Client Requirements:**
- Lua environment with `socket.http` support (luasocket)
- SSL/TLS certificate validation support
- Modern TLS version support (1.2+)

**Server Requirements:**
- Valid SSL/TLS certificate from trusted CA
- TLS 1.2 or higher
- Proper certificate chain configuration
- HTTPS-only endpoints (no HTTP fallback)

**Certificate Validation:**
```lua
-- The transport relies on luasocket's built-in certificate validation
-- Ensure your server certificate is valid and trusted
```

### Performance Implications vs FileTransport

| Aspect | HTTPS Transport | FileTransport |
|--------|----------------|---------------|
| **Latency** | Network RTT + processing | Local I/O (ms) |
| **Throughput** | Network bandwidth limited | Disk I/O limited |
| **CPU Usage** | JSON + HTTP overhead | JSON + file I/O |
| **Memory Usage** | HTTP buffers + JSON | File buffers + JSON |
| **Scalability** | Server-dependent | Single client only |

**Performance Optimization Tips:**
1. **Minimize Request Size**: Send only necessary data
2. **Batch Operations**: Combine multiple updates when possible
3. **Connection Reuse**: Configure keep-alive headers
4. **Compression**: Enable gzip compression on server
5. **Caching**: Implement client-side caching for read operations

### Network Reliability and Retry Strategies

```lua
local function create_reliable_transport(config)
    local transport = HttpsTransport.new(config)
    
    -- Wrapper with retry logic
    local original_write = transport.write_message
    transport.write_message = function(self, message_data, message_type)
        local max_retries = 3
        local base_delay = 1
        
        for attempt = 1, max_retries do
            local success = original_write(self, message_data, message_type)
            if success then
                return true
            end
            
            if attempt < max_retries then
                -- Exponential backoff with jitter
                local delay = base_delay * (2 ^ (attempt - 1))
                local jitter = math.random() * 0.5
                love.timer.sleep(delay + jitter)
            end
        end
        
        return false
    end
    
    return transport
end
```

**Retry Strategy Recommendations:**
- **Exponential Backoff**: Increase delay between retries
- **Jitter**: Add randomization to prevent thundering herd
- **Maximum Retries**: Limit attempts (3-5 retries)
- **Circuit Breaker**: Temporarily stop retries after repeated failures

### Security Considerations for Authentication

#### Token Management
```lua
local function get_secure_token()
    -- Read token from secure storage
    local token_file = "secure/auth_token.txt"
    local token = love.filesystem.read(token_file)
    
    if not token then
        error("Authentication token not found")
    end
    
    return token:gsub("%s", "") -- Remove whitespace
end

local config = {
    base_url = "https://api.example.com",
    headers = {
        ["Authorization"] = "Bearer " .. get_secure_token()
    }
}
```

#### Security Best Practices

1. **Token Storage**: Store tokens securely, not in code
2. **Token Rotation**: Implement token refresh mechanisms
3. **HTTPS Only**: Never use HTTP for production
4. **Input Validation**: Sanitize all data before transmission
5. **Rate Limiting**: Respect server rate limits
6. **Error Handling**: Don't expose sensitive information in errors

```lua
-- Secure error handling
local function safe_error_handler(error_msg)
    -- Log full error securely
    log_to_secure_file(error_msg)
    
    -- Return sanitized error to user
    return "Network operation failed - check connection"
end
```

#### API Key Security
```lua
-- Environment-based configuration
local function load_secure_config()
    return {
        base_url = os.getenv("BALATRO_API_URL") or "https://api.example.com",
        headers = {
            ["X-API-Key"] = os.getenv("BALATRO_API_KEY") or error("API key not set")
        }
    }
end
```

### Production Deployment Checklist

- [ ] **SSL Certificate**: Valid, trusted certificate installed
- [ ] **Authentication**: Secure token/key management implemented
- [ ] **Rate Limiting**: Server-side rate limits configured
- [ ] **Monitoring**: Request/response logging enabled
- [ ] **Error Handling**: Comprehensive error scenarios covered
- [ ] **Fallback**: Graceful degradation to FileTransport if needed
- [ ] **Testing**: End-to-end connectivity validation
- [ ] **Documentation**: Server API documentation updated
- [ ] **Security**: Penetration testing completed
- [ ] **Performance**: Load testing under expected traffic

The HTTPS Transport provides a robust foundation for networked Balatro gameplay, enabling features like multiplayer coordination, centralized game state management, and cloud-based action processing while maintaining compatibility with existing FileTransport-based code.