-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Core.CommandPermissions = Config.CommandPermissions or {}

function Core.FilterCommandGroups(groups)
    return (groups and #groups > 0) and groups or { "user" }
end