-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@param add boolean Whether the item is being added or removed
---@param item string The item to show
---@param count number How many of the item to show
---@return nil
function ESX.UI.ShowInventoryItemNotification(add, item, count)
    xLib.nui.send({
        action = "inventoryNotification",
        add = add,
        item = item,
        count = count,
    })
end
