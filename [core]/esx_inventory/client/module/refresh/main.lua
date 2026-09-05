local Inventory = ESXInventory

local lastCounts = {} ---@type table<string, number>
local hasCountSnapshot = false
local refreshScheduled = false

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
            SendNUIMessage({
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

RegisterNetEvent("esx:addInventoryItem", scheduleRefresh)
RegisterNetEvent("esx:removeInventoryItem", scheduleRefresh)
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
