local Inventory = ESXInventory

---@return nil
function Inventory.pushState()
    local items = Inventory.buildItems()

    SendNUIMessage({
        action = "state",
        items = items,
        slotCount = Inventory.computeSlotCount(items),
        maxWeight = ESX.PlayerData.maxWeight or 0,
        storage = Inventory.currentStorage,
    })
end

---@return nil
function Inventory.open()
    if Inventory.isOpen or not ESX.PlayerLoaded or ESX.PlayerData.dead or IsPauseMenuActive() then
        return
    end

    Inventory.isOpen = true

    SendNUIMessage({
        action = "open",
        locale = Inventory.buildLocale(),
        theme = Inventory.buildTheme(),
        hotbarSlots = Config.HotbarSlots,
    })
    Inventory.pushState()
    SetNuiFocus(true, true)
end

---@param fromNui boolean?
---@return nil
function Inventory.close(fromNui)
    if not Inventory.isOpen then
        return
    end

    Inventory.isOpen = false
    local hadStorage = Inventory.currentStorage ~= nil
    Inventory.currentStorage = nil

    SetNuiFocus(false, false)

    if not fromNui then
        SendNUIMessage({ action = "close" })
    end

    if hadStorage then
        TriggerServerEvent("esx_inventory:storageClosed")
    end
end

exports("ShowInventory", Inventory.open)

RegisterNUICallback("close", function(_, cb)
    Inventory.close(true)
    cb({})
end)

RegisterNUICallback("saveSlots", function(data, cb)
    cb({})

    if type(data) ~= "table" or type(data.slots) ~= "table" then
        return
    end

    for key, slot in pairs(data.slots) do
        if type(key) == "string" and type(slot) == "number" and slot >= 0 then
            Inventory.setSlot(key, math.floor(slot))
        end
    end

    Inventory.saveSlotMap()
end)

RegisterNUICallback("useItem", function(data, cb)
    cb({})

    if type(data) ~= "table" or type(data.name) ~= "string" or data.type ~= "item_standard" then
        return
    end

    TriggerServerEvent("esx:useItem", data.name)
end)

RegisterNUICallback("giveItem", function(data, cb)
    cb({})

    if type(data) ~= "table" or type(data.name) ~= "string" or not Inventory.ITEM_TYPES[data.type] then
        return
    end

    local target = tonumber(data.target)
    local count = tonumber(data.count)

    if not target or not count or count < 1 then
        return
    end

    TriggerServerEvent("esx:giveInventoryItem", math.floor(target), data.type, data.name, math.floor(count))
end)

RegisterNUICallback("dropItem", function(data, cb)
    cb({})

    if type(data) ~= "table" or type(data.name) ~= "string" or not Inventory.ITEM_TYPES[data.type] then
        return
    end

    local count = tonumber(data.count)

    if not count or count < 1 then
        return
    end

    TriggerServerEvent("esx:removeInventoryItem", data.type, data.name, math.floor(count))
end)

RegisterNUICallback("getNearbyPlayers", function(_, cb)
    local players = {}
    local myId = PlayerId()
    local myCoords = GetEntityCoords(PlayerPedId())

    for _, playerId in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(playerId)

        if playerId ~= myId and ped ~= 0 then
            local distance = #(myCoords - GetEntityCoords(ped))

            if distance <= Config.NearbyPlayerDistance then
                players[#players + 1] = {
                    id = GetPlayerServerId(playerId),
                    name = GetPlayerName(playerId),
                    distance = math.floor(distance * 10) / 10,
                }
            end
        end
    end

    table.sort(players, function(a, b)
        return a.distance < b.distance
    end)

    cb(players)
end)

RegisterNUICallback("storagePut", function(data, cb)
    cb({})

    if not Inventory.currentStorage or type(data) ~= "table" or type(data.name) ~= "string" or data.type ~= "item_standard" then
        return
    end

    local count = tonumber(data.count)

    if not count or count < 1 then
        return
    end

    TriggerServerEvent("esx_inventory:storagePut", data.name, math.floor(count))
end)

RegisterNUICallback("storageTake", function(data, cb)
    cb({})

    if not Inventory.currentStorage or type(data) ~= "table" or type(data.name) ~= "string" then
        return
    end

    local count = tonumber(data.count)

    if not count or count < 1 then
        return
    end

    TriggerServerEvent("esx_inventory:storageTake", data.name, math.floor(count))
end)

RegisterNUICallback("uiError", function(data, cb)
    cb({})
    print("^1[esx_inventory:ui]^7", json.encode(data or {}))
end)
