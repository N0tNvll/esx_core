if not Config.CustomInventory then
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

        TriggerClientEvent("esx:createPickup", -1, pickupId, label, coords, itemType, name, components, tintIndex)
        Core.PickupId = pickupId
    end
end
