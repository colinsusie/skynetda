--[[
    与VSCode通讯的模块
    by colin
]]
local cjson = require "cjson"
local vscaux = {}
local seq = 0

-- 发送消息
function vscaux.send(msg)
    local output = io.stdout
    local ok, content = pcall(cjson.encode, msg)
    if ok then
        local data = string.format("Content-Length: %s\r\n\r\n%s\n", #content, content)
        if output:write(data) then
            output:flush()
            return true
        end
    end
end

-- 发送事件
function vscaux.send_event(event, body)
    seq = seq + 1
    local res = {
        seq = seq,
        type = "event",
        event = event,
        body = body,
    }
    return vscaux.send(res)
end

-- 获得请求
function vscaux.recv_request()
    local input = io.stdin
    -- -- TODO 测试
    -- local msg = input:read()
    -- local ok, req = pcall(cjson.decode, msg)
    -- if ok then
    --     return req
    -- else
    --     print(req)
    -- end
    -- do return end

    local header = input:read()
    if header:find("Content-Length: ", 1, true) then
        local rd = input:read()
        if rd then
            local len = tonumber(header:match("(%d+)"))
            local sreq = input:read(len)
            if sreq then
                local ok, req = pcall(cjson.decode, sreq)
                if ok then
                    return req
                end
            end
        end
    end
end

-- 发送响应
function vscaux.send_response(cmd, rseq, body)
    seq = seq + 1
    local res = {
        seq = seq,
        type = "response",
        success = true,
        request_seq = rseq,
        command = cmd,
        body = body,
    }
    vscaux.send(res)
end

-- 错误响应
function vscaux.send_error_response(cmd, rseq, msg)
    seq = seq + 1
    local res = {
        seq = seq,
        type = "response",
        success = false,
        request_seq = rseq,
        command = cmd,
        message = msg,
    }
    vscaux.send(res)
end

return vscaux