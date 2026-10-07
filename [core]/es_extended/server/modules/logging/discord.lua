-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@param name string
---@param color string
---@return string? webhook
---@return integer color
local function resolveLegacyConfig(name, color)
    local webhooks = Config.DiscordLogs.Webhooks
    local colors = Config.DiscordLogs.Colors

    return webhooks[name] or webhooks.default, colors[color] or colors.default
end

---@param name string
---@param title string
---@param color string
---@param message string
---@return nil
function ESX.DiscordLog(name, title, color, message)
    local webhook, colorValue = resolveLegacyConfig(name, color)

    xLib.logs.send(name, {
        title = title,
        message = message,
        color = colorValue,
    }, { webhook = webhook })
end

---@param name string
---@param title string
---@param color string
---@param fields table
---@return nil
function ESX.DiscordLogFields(name, title, color, fields)
    local webhook, colorValue = resolveLegacyConfig(name, color)

    xLib.logs.send(name, {
        title = title,
        fields = fields,
        color = colorValue,
    }, { webhook = webhook })
end
