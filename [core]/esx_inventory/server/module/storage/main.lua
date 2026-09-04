---@class InventoryStorageDefinition
---@field label string                                              # Display name of the storage.
---@field slots number                                              # Slot count shown by the UI.
---@field maxWeight number                                          # Capacity shown by the UI weight bar.
---@field canAccess fun(xPlayer: table): boolean                    # Synchronous access check, no awaits.
---@field getItems fun(xPlayer: table): table[]                     # Synchronous read of { name, label, count, weight? } entries.
---@field putItem fun(xPlayer: table, itemName: string, count: number): boolean   # Synchronous, must atomically add to the storage state.
---@field takeItem fun(xPlayer: table, itemName: string, count: number): boolean  # Synchronous, must atomically deduct from the storage state.
---@field coords vector3?                                          # Optional anchor, transfers are refused beyond distance.
---@field distance number?                                         # Range around coords, defaults to 5.0.

local MAX_TRANSFER_COUNT <const> = 1000000

local storages = {} ---@type table<string, InventoryStorageDefinition>
local openedStorage = {} ---@type table<number, string>
local lastActionAt = {} ---@type table<number, number>

---@param playerId number
---@param definition InventoryStorageDefinition
---@return boolean
local function isPlayerInRange(playerId, definition)
    if not definition.coords then
        return true
    end

    local ped = GetPlayerPed(playerId)

    if not ped or ped == 0 then
        return false
    end

    return #(GetEntityCoords(ped) - definition.coords) <= definition.distance
end

---@param source number
---@return boolean
local function isRateLimited(source)
    local now = GetGameTimer()

    if now - (lastActionAt[source] or 0) < Config.StorageActionCooldown then
        return true
    end

    lastActionAt[source] = now
    return false
end

---@param count any
---@return number?
local function getValidCount(count)
    count = tonumber(count)

    if not count or count ~= math.floor(count) or count < 1 or count > MAX_TRANSFER_COUNT then
        return nil
    end

    return count
end

---@param definition InventoryStorageDefinition
---@param xPlayer table
---@return table[]
local function buildStorageItems(definition, xPlayer)
    local items = {}
    local rawItems = definition.getItems(xPlayer)

    if type(rawItems) ~= "table" then
        return items
    end

    for i = 1, #rawItems do
        local item = rawItems[i]

        if type(item) == "table" and type(item.name) == "string" and type(item.count) == "number" and item.count > 0 then
            items[#items + 1] = {
                type = "item_standard",
                name = item.name,
                label = type(item.label) == "string" and item.label or item.name,
                count = math.floor(item.count),
                weight = type(item.weight) == "number" and item.weight or 0,
                usable = false,
                canRemove = true,
                image = Config.ItemImageUrl:format(item.name),
            }
        end
    end

    return items
end

---@param storageId string
---@param definition InventoryStorageDefinition
---@return boolean
local function registerStorage(storageId, definition)
    if type(storageId) ~= "string" or storageId == "" or type(definition) ~= "table" then
        return false
    end

    if storages[storageId] then
        print(("[^3WARNING^7] Storage ^5%s^7 is already registered"):format(storageId))
        return false
    end

    if type(definition.label) ~= "string"
        or not ESX.IsFunctionReference(definition.canAccess)
        or not ESX.IsFunctionReference(definition.getItems)
        or not ESX.IsFunctionReference(definition.putItem)
        or not ESX.IsFunctionReference(definition.takeItem) then
        print(("[^3WARNING^7] Storage ^5%s^7 has an invalid definition"):format(storageId))
        return false
    end

    storages[storageId] = {
        label = definition.label,
        slots = type(definition.slots) == "number" and math.floor(definition.slots) or 30,
        maxWeight = type(definition.maxWeight) == "number" and definition.maxWeight or 0,
        canAccess = definition.canAccess,
        getItems = definition.getItems,
        putItem = definition.putItem,
        takeItem = definition.takeItem,
        coords = type(definition.coords) == "vector3" and definition.coords or nil,
        distance = type(definition.distance) == "number" and definition.distance or 5.0,
    }

    return true
end

exports("RegisterStorage", registerStorage)

---@param storageId string
---@return boolean
local function unregisterStorage(storageId)
    if not storages[storageId] then
        return false
    end

    storages[storageId] = nil

    for playerId, openedId in pairs(openedStorage) do
        if openedId == storageId then
            openedStorage[playerId] = nil
            TriggerClientEvent("esx_inventory:closeStorage", playerId)
        end
    end

    return true
end

exports("UnregisterStorage", unregisterStorage)

---@param playerId number
---@param storageId string
---@return boolean
local function openStorage(playerId, storageId)
    local definition = storages[storageId]
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not definition or not xPlayer or not isPlayerInRange(playerId, definition) or not definition.canAccess(xPlayer) then
        return false
    end

    openedStorage[playerId] = storageId

    TriggerClientEvent("esx_inventory:openStorage", playerId, {
        id = storageId,
        label = definition.label,
        slots = definition.slots,
        maxWeight = definition.maxWeight,
        items = buildStorageItems(definition, xPlayer),
    })

    return true
end

exports("OpenStorage", openStorage)
AddEventHandler("esx_inventory:openStorage", openStorage)

---@param storageId string
---@param definition InventoryStorageDefinition
local function refreshStorageViewers(storageId, definition)
    for playerId, openedId in pairs(openedStorage) do
        if openedId == storageId then
            local viewer = ESX.GetPlayerFromId(playerId)

            if viewer then
                TriggerClientEvent("esx_inventory:refreshStorage", playerId, {
                    id = storageId,
                    label = definition.label,
                    slots = definition.slots,
                    maxWeight = definition.maxWeight,
                    items = buildStorageItems(definition, viewer),
                })
            end
        end
    end
end

---@param source number
---@param itemName any
---@param count any
---@return table?, string?, InventoryStorageDefinition?, number?
local function validateStorageAction(source, itemName, count)
    if isRateLimited(source) then
        return nil
    end

    local storageId = openedStorage[source]
    local definition = storageId and storages[storageId] or nil
    local xPlayer = ESX.GetPlayerFromId(source)
    count = getValidCount(count)

    if not definition or not xPlayer or type(itemName) ~= "string" or not count then
        return nil
    end

    if not isPlayerInRange(source, definition) then
        return nil
    end

    if not definition.canAccess(xPlayer) then
        return nil
    end

    return xPlayer, storageId, definition, count
end

RegisterNetEvent("esx_inventory:storagePut", function(itemName, count)
    local source = source

    local xPlayer, storageId, definition
    xPlayer, storageId, definition, count = validateStorageAction(source, itemName, count)

    if not xPlayer then
        return
    end

    local item = xPlayer.getInventoryItem(itemName)

    if not item or item.count < count then
        return
    end

    if xPlayer.removeInventoryItem(itemName, count) == false then
        return
    end

    if not definition.putItem(xPlayer, itemName, count) then
        xPlayer.addInventoryItem(itemName, count)
        return
    end

    refreshStorageViewers(storageId, definition)
end)

RegisterNetEvent("esx_inventory:storageTake", function(itemName, count)
    local source = source

    local xPlayer, storageId, definition
    xPlayer, storageId, definition, count = validateStorageAction(source, itemName, count)

    if not xPlayer then
        return
    end

    if not xPlayer.canCarryItem(itemName, count) then
        xPlayer.showNotification(TranslateCap("ex_inv_lim", xPlayer.getMaxWeight()))
        return
    end

    if not definition.takeItem(xPlayer, itemName, count) then
        return
    end

    xPlayer.addInventoryItem(itemName, count)
    refreshStorageViewers(storageId, definition)
end)

RegisterNetEvent("esx_inventory:storageClosed", function()
    openedStorage[source] = nil
end)

AddEventHandler("playerDropped", function()
    openedStorage[source] = nil
    lastActionAt[source] = nil
end)
