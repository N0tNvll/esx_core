-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@class nuilib
xLib.nui = {}
xLib.nui.defer = {}

---@param message table|string
---@param data? any
function xLib.nui.send(message, data)
    if type(message) == "table" then
        SendNUIMessage(message)
        return
    end

    SendNUIMessage({
        action = message,
        data = data
    })
end

---@param hasFocus boolean
---@param hasCursor? boolean
---@param keepInput? boolean
function xLib.nui.focus(hasFocus, hasCursor, keepInput)
    SetNuiFocus(hasFocus, hasCursor == nil and hasFocus or hasCursor)

    if keepInput ~= nil then
        SetNuiFocusKeepInput(keepInput)
    end
end

---@param message? table|string
---@param focus? boolean
---@param cursor? boolean
---@param keepInput? boolean
function xLib.nui.open(message, focus, cursor, keepInput)
    if message then
        xLib.nui.send(message)
    end

    if focus ~= false then
        xLib.nui.focus(true, cursor, keepInput)
    end
end

---@param message? table|string
function xLib.nui.close(message)
    if message then
        xLib.nui.send(message)
    end

    xLib.nui.focus(false, false, false)
end

---@param data? any
---@return table
function xLib.nui.ok(data)
    return {
        ok = true,
        data = data
    }
end

---@param errorMessage string
---@param code? string|number
---@return table
function xLib.nui.fail(errorMessage, code)
    return {
        ok = false,
        error = errorMessage,
        code = code
    }
end

---@param name string
---@param handler fun(data: table, reply: fun(response?: any))
function xLib.nui.register(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local replied = false
        local info = debug and debug.getinfo and debug.getinfo(handler, "u")
        local canDefer = info and info.nparams and info.nparams >= 2

        local function reply(response)
            if replied then
                return
            end

            replied = true
            cb(response == nil and xLib.nui.ok() or response)
        end

        local ok, response = pcall(handler, data or {}, reply)

        if not ok then
            print(("[xLib:nui] Callback %s failed: %s"):format(name, response))
            reply(xLib.nui.fail(response))
            return
        end

        if response == xLib.nui.defer then
            return
        end

        if not replied and (response ~= nil or not canDefer) then
            reply(response)
        end
    end)
end

return xLib.nui
