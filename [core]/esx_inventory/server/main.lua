-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

if not ESX.GetConfig('EnableDefaultInventory') then
    return
end

---@class ESXInventoryServer
ESXInventory = {}
