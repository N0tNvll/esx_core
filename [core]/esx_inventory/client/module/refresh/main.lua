-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Inventory = ESXInventory

local lastCounts = {} ---@type table<string, number>
local hasCountSnapshot = false
local refreshScheduled = false

local function ensureInventory()
    if type(ESX.PlayerData.inventory) ~= "table" then
        ESX.PlayerData.inventory = {}
    end

    return ESX.PlayerData.inventory
end

local function buildEntry(name, count, itemData)
    itemData = type(itemData) == "table" and itemData or {}

    return {
        name = name,
        count = count,
        label = itemData.label or name,
        weight = itemData.weight or 0,
        usable = itemData.usable == true,
        rare = itemData.rare == true,
        canRemove = itemData.canRemove ~= false,
    }
end

local function setInventoryItem(name, count, itemData)
    if type(name) ~= "string" or type(count) ~= "number" then
        return
    end

    local inventory = ensureInventory()

    for i = 1, #inventory do
        if inventory[i].name == name then
            if count > 0 then
                inventory[i].count = count

                if type(itemData) == "table" then
                    inventory[i].label = itemData.label or inventory[i].label
                    inventory[i].weight = itemData.weight or inventory[i].weight
                    inventory[i].usable = itemData.usable == true
                    inventory[i].rare = itemData.rare == true
                    inventory[i].canRemove = itemData.canRemove ~= false
                end
            else
                table.remove(inventory, i)
            end

            return
        end
    end

    if count > 0 then
        inventory[#inventory + 1] = buildEntry(name, count, itemData)
    end
end

local function getInventoryItemCount(name)
    local inventory = ensureInventory()

    for i = 1, #inventory do
        if inventory[i].name == name then
            return inventory[i].count or 0
        end
    end

    return 0
end

local function replaceInventory(newInventory)
    ESX.PlayerData.inventory = type(newInventory) == "table" and newInventory or {}
end

---@return table<string, number>
local function snapshotCounts()
    local counts = {}

    for i = 1, #(ESX.PlayerData.inventory or {}) do
        local item = ESX.PlayerData.inventory[i]

        if item.count > 0 then
            counts[item.name] = item.count
        end
    end

    return counts
end

---@param name string
---@param delta number
---@param added boolean
local function notifyItemChange(name, delta, added)
    for i = 1, #ESX.PlayerData.inventory do
        local item = ESX.PlayerData.inventory[i]

        if item.name == name then
            xLib.nui.send({
                action = "notify",
                added = added,
                amount = delta,
                item = {
                    name = item.name,
                    label = item.label,
                    image = Config.ItemImageUrl:format(item.name),
                },
            })
            return
        end
    end
end

local function refreshAndNotify()
    local newCounts = snapshotCounts()

    if not hasCountSnapshot then
        hasCountSnapshot = true
        lastCounts = newCounts
    else
        for name, count in pairs(newCounts) do
            local previous = lastCounts[name] or 0

            if count > previous then
                notifyItemChange(name, count - previous, true)
            end
        end

        for name, previous in pairs(lastCounts) do
            local count = newCounts[name] or 0

            if count < previous then
                notifyItemChange(name, previous - count, false)
            end
        end

        lastCounts = newCounts
    end

    if Inventory.isOpen then
        Inventory.pushState()
    end
end

local function scheduleRefresh()
    if refreshScheduled then
        return
    end

    refreshScheduled = true

    SetTimeout(0, function()
        refreshScheduled = false
        refreshAndNotify()
    end)
end

RegisterNetEvent("esx:setInventory", function(newInventory)
    replaceInventory(newInventory)
    scheduleRefresh()
end)

RegisterNetEvent("esx:addInventoryItem", function(item, count, _, itemData)
    local previous = getInventoryItemCount(item)

    setInventoryItem(item, count, itemData)

    if count > previous then
        notifyItemChange(item, count - previous, true)
    end

    hasCountSnapshot = true
    lastCounts = snapshotCounts()

    if Inventory.isOpen then
        Inventory.pushState()
    end
end)

RegisterNetEvent("esx:removeInventoryItem", function(item, count)
    local previous = getInventoryItemCount(item)

    setInventoryItem(item, count)

    if count < previous then
        notifyItemChange(item, previous - count, false)
    end

    hasCountSnapshot = true
    lastCounts = snapshotCounts()

    if Inventory.isOpen then
        Inventory.pushState()
    end
end)

RegisterNetEvent("esx:addLoadoutItem", scheduleRefresh)
RegisterNetEvent("esx:removeLoadoutItem", scheduleRefresh)

RegisterNetEvent("esx:setAccountMoney", function(account)
    if type(account) ~= "table" or type(account.name) ~= "string" then
        return
    end

    for i = 1, #(ESX.PlayerData.accounts or {}) do
        if ESX.PlayerData.accounts[i].name == account.name then
            ESX.PlayerData.accounts[i].money = account.money
            break
        end
    end

    if Inventory.isOpen then
        Inventory.pushState()
    end
end)

OnPlayerData = function(key)
    if key == "inventory" or key == "loadout" then
        scheduleRefresh()
    elseif Inventory.isOpen and key == "accounts" then
        Inventory.pushState()
    end
end

RegisterNetEvent("esx:playerLoaded", function()
    Wait(0)
    hasCountSnapshot = true
    lastCounts = snapshotCounts()
end)

RegisterNetEvent("esx:onPlayerDeath", function()
    Inventory.close(false)
end)

CreateThread(function()
    while not ESX.PlayerLoaded do
        Wait(500)
    end

    if not hasCountSnapshot then
        hasCountSnapshot = true
        lastCounts = snapshotCounts()
    end
end)
