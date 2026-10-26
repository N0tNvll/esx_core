-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@class xLibLogs
local logs = {}

---@param channel string
---@param entry LogEntry
---@param options? LogOptions
---@return boolean queued
function logs.send(channel, entry, options)
    return xLib.logs_send(channel, entry, options)
end

return logs
