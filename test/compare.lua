-- This script checks that the table returned by ltcn.parse() is
-- identical to the table returned by the Lua load() function when
-- both are given the same valid input.

local ltcn = require "ltcn"
local type, pairs, assert = type, pairs, assert
local open, stderr, exit = io.open, io.stderr, os.exit
local setmetatable, concat = setmetatable, table.concat
local load = loadstring or load
local verbose = os.getenv "VERBOSE"
local filename = assert(arg[1], "arg[1] is nil; expected filename")
local _ENV = nil

local Stack = {}
Stack.__index = Stack

function Stack.new()
    return setmetatable({length = 0}, Stack)
end

function Stack:push(v)
    local n = self.length + 1
    self.length = n
    self[n] = v
end

function Stack:pop()
    local n = self.length
    assert(n > 0)
    self[n] = nil
    self.length = n - 1
end

function Stack:tostring(k)
    local n, q, buf = self.length, "[%q]", {}
    for i = 1, n do
        buf[i] = q:format(self[i])
    end
    buf[n+1] = q:format(k)
    return concat(buf)
end

local keys = Stack.new()
local seen = {}

local function compare(t1, t2)
    for k, v1 in pairs(t1) do
        local v2 = t2[k]
        if type(v1) == "table" then
            assert(type(v2) == "table", "Not a table")
            keys:push(k)
            compare(v1, v2)
            keys:pop()
        elseif v1 ~= v2 then
            local index = keys:tostring(k)
            if not seen[index] then
                local msg = "%s: values at index %s not equal: (%s, %s)\n"
                stderr:write(msg:format(filename, index, v1, v2))
                seen[index] = true
            end
        elseif verbose then
            stderr:write(" OK: ", keys:tostring(k), "\n")
        end
    end
    return true
end

local file = assert(open(filename))
local text = assert(file:read("*a"))
file:close()

local t1 = assert(ltcn.parse(text, filename))
local fn = assert(load("return" .. text, "=" .. filename, "t"))
local t2 = assert(fn())

if verbose then
    stderr:write("\n", filename, "\n", ("-"):rep(#filename), "\n")
end

compare(t1, t2)
compare(t2, t1)
