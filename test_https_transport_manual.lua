-- Manual test script to verify HTTPS transport functionality
-- This tests if SMODS.https can make HTTP requests independent of the full mod

print("=== MANUAL HTTPS TRANSPORT TEST ===")

-- Test if SMODS is available
if not SMODS then
    print("ERROR: SMODS not available")
    return
end

print("SMODS available")

-- Test if SMODS.https is available
local http_client = require("SMODS.https")
if not http_client then
    print("ERROR: SMODS.https not available")
    return
end

print("SMODS.https available")

-- Test basic HTTP request to localhost:8080/health
local test_url = "http://localhost:8080/health"
local options = {
    method = "GET",
    headers = {
        ["User-Agent"] = "BalatroMCP-Test/1.0"
    }
}

print("Testing HTTP GET to: " .. test_url)

local success, status_code, response_body, response_headers = pcall(http_client.request, test_url, options)

print("Request result:")
print("  success: " .. tostring(success))
print("  status_code: " .. tostring(status_code))
print("  response_body length: " .. tostring(response_body and #response_body or 0))

if success and status_code == 200 then
    print("*** HTTP TRANSPORT WORKING ***")
    
    -- Test POST request
    local post_url = "http://localhost:8080/game-data"
    local test_data = '{"test": "manual_transport_test", "timestamp": "' .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. '"}'
    local post_options = {
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "BalatroMCP-Test/1.0"
        },
        data = test_data
    }
    
    print("Testing HTTP POST to: " .. post_url)
    local post_success, post_status, post_response = pcall(http_client.request, post_url, post_options)
    
    print("POST result:")
    print("  success: " .. tostring(post_success))
    print("  status_code: " .. tostring(post_status))
    
    if post_success and post_status and post_status >= 200 and post_status < 300 then
        print("*** HTTP POST WORKING ***")
    else
        print("*** HTTP POST FAILED ***")
    end
else
    print("*** HTTP TRANSPORT FAILED ***")
end

print("=== TEST COMPLETED ===")