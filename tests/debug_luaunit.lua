local luaunit = require('lib.luaunit')

function testSimple()
    print("Simple test executing")
    return true
end

-- Check what functions are global
print("Global test functions:")
for k, v in pairs(_G) do
    if type(v) == "function" and string.match(k, "^test") then
        print("  " .. k)
    end
end

print("Running LuaUnit...")
os.exit(luaunit.Run())