if not Config.CustomInventory then
    local STREAM_DISTANCE <const> = 150.0

    ---@param coords vector3
    ---@return number[]
    local function getPlayersInStreamRange(coords)
        local nearby = xLib.onesync.getPlayersInArea(coords, STREAM_DISTANCE)
        local targets = {}

        for i = 1, #nearby do
            targets[i] = nearby[i].id
        end

        return targets
    end

    Core.PickupStreamDistance = STREAM_DISTANCE
    Core.GetPickupTargets = getPlayersInStreamRange

    ---@param itemType string
    ---@param name string
    ---@param count integer
    ---@param label string
    ---@param playerId number
    ---@param components? string | table
    ---@param tintIndex? integer
    ---@param coords? table | vector3
    ---@return nil
    function ESX.CreatePickup(itemType, name, count, label, playerId, components, tintIndex, coords)
        local pickupId = (Core.PickupId == 65635 and 0 or Core.PickupId + 1)
        local xPlayer = ESX.GetPlayerFromId(playerId)

        if not xPlayer then
            return
        end

        coords = ((type(coords) == "vector3" or type(coords) == "vector4") and coords.xyz or xPlayer.getCoords(true))

        Core.Pickups[pickupId] = { type = itemType, name = name, count = count, label = label, coords = coords }

        if itemType == "item_weapon" then
            Core.Pickups[pickupId].components = components
            Core.Pickups[pickupId].tintIndex = tintIndex
        end

        xLib.triggerClientEvent("esx:createPickup", getPlayersInStreamRange(coords), pickupId, label, coords, itemType, name, components, tintIndex)
        Core.PickupId = pickupId
    end

    RegisterNetEvent("esx:requestPickups", function()
        local playerId = source

        if not Core.InventoryEvents.ConsumeRate("pickup", playerId) then
            return
        end

        local ped = GetPlayerPed(playerId)

        if ped == 0 then
            return
        end

        local playerCoords = GetEntityCoords(ped)
        local nearbyPickups = {}

        for pickupId, pickup in pairs(Core.Pickups) do
            if #(playerCoords - pickup.coords) <= STREAM_DISTANCE then
                nearbyPickups[pickupId] = pickup
            end
        end

        TriggerClientEvent("esx:createMissingPickups", playerId, nearbyPickups)
    end)
end
