package.cpath = "./?.so;" .. package.cpath
local cjson = require "cjson"
cjson.encode_empty_table_as_array(true)
local vscaux = require "vscaux"

local skynet_dir = ""
local config_path = ""
local open_debug = true

local reqfuncs = {}
local breakpoints = {}

function reqfuncs.initialize(req)
    vscaux.send_response(req.command, req.seq, {
        supportsConfigurationDoneRequest = true,
        supportsSetVariable = false,
        supportsConditionalBreakpoints = true,
        supportsHitConditionalBreakpoints = true,
    })
    vscaux.send_event("initialized")
    vscaux.send_event("output", {
        category = "console",
        output = "skynet debugger start!\n",
    })
end

local function calc_hitcount(hitexpr)
    if not hitexpr then return 0 end
    
    local f, msg = load("return " .. hitexpr, "=hitexpr")
    if not f then return 0 end
    
    local ok, ret = pcall(f)
    if not ok then return 0 end
    
    return tonumber(ret) or 0
end

function reqfuncs.setBreakpoints(req)
    local args = req.arguments
    local src = args.source.path
    local bpinfos = {}
    local bps = {}
    for _, bp in ipairs(args.breakpoints) do
        local logmsg
        if bp.logMessage and bp.logMessage ~= "" then
            logmsg = bp.logMessage .. '\n'
        end
        bpinfos[#bpinfos+1] = {
            source = {path = src},
            line = bp.line,
            logMessage = logmsg,
            condition = bp.condition,
            hitCount = calc_hitcount(bp.hitCondition),
            currHitCount = 0,
        }
        bps[#bps+1] = {
            verified = true,
            source = {path = src},
            line = bp.line,
        }
    end
    breakpoints[src] = bpinfos
    vscaux.send_response(req.command, req.seq, {
        breakpoints = bps,
    })
end

function reqfuncs.setExceptionBreakpoints(req)
    vscaux.send_response(req.command, req.seq)
end

function reqfuncs.configurationDone(req)
    vscaux.send_response(req.command, req.seq)
end

function reqfuncs.launch(req)
    skynet_dir = req.arguments.program
    if skynet_dir:sub(-1) == "/" then
        skynet_dir = skynet_dir:sub(1, -2)
    end
    config_path = req.arguments.config
    open_debug = not req.arguments.noDebug
    return true
end

function handle_request()
    while true do
        local req = vscaux.recv_request()
        if not req or not req.command then
            return false
        end
        local func = reqfuncs[req.command]
        if func and func(req) then
            break
        elseif not func then
            vscaux.send_error_response(req.command, req.seq, string.format("%s not yet implemented", req.command))
        end
    end
    return true
end

if handle_request() then
    return skynet_dir, config_path, open_debug, cjson.encode(breakpoints)
else
    error("launch error")
end
