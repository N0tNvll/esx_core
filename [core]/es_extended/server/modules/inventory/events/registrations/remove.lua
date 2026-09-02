if Config.CustomInventory then
    return
end

RegisterNetEvent("esx:removeInventoryItem", function(itemType, itemName, itemCount)
    local playerId = source
    local xPlayer = ESX.GetPlayerFromId(playerId)

    if not xPlayer then
        return
    end

    if itemType == "item_standard" then
        local count = Core.InventoryEvents.GetPositiveCount(itemCount)

        if not count then
            return xPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
        end

        local xItem = xPlayer.getInventoryItem(itemName)
        if not xItem then
            return
        end

        if count > xItem.count or xItem.count < 1 then
            return xPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
        end

        xPlayer.removeInventoryItem(itemName, count)
        local pickupLabel = ("%s [%s]"):format(xItem.label, count)
        ESX.CreatePickup("item_standard", itemName, count, pickupLabel, playerId)
        xPlayer.showNotification(TranslateCap("threw_standard", count, xItem.label))
    elseif itemType == "item_account" then
        local count = Core.InventoryEvents.GetPositiveCount(itemCount)

        if not count then
            return xPlayer.showNotification(TranslateCap("imp_invalid_amount"))
        end

        local account = xPlayer.getAccount(itemName)
        if not account then
            return
        end

        if count > account.money or account.money < 1 then
            return xPlayer.showNotification(TranslateCap("imp_invalid_amount"))
        end

        xPlayer.removeAccountMoney(itemName, count, "Threw away")
        local pickupLabel = ("%s [%s]"):format(account.label, TranslateCap("locale_currency", ESX.Math.GroupDigits(count)))
        ESX.CreatePickup("item_account", itemName, count, pickupLabel, playerId)
        xPlayer.showNotification(TranslateCap("threw_account", ESX.Math.GroupDigits(count), string.lower(account.label)))
    elseif itemType == "item_weapon" then
        if type(itemName) ~= "string" then
            return
        end

        itemName = string.upper(itemName)

        if not xPlayer.hasWeapon(itemName) then
            return
        end

        local _, weapon = xPlayer.getWeapon(itemName)
        if not weapon then
            return
        end

        local _, weaponObject = ESX.GetWeapon(itemName)
        local weaponPickupLabel = ""
        local components = xLib.table.clone(weapon.components)

        xPlayer.removeWeapon(itemName)

        if weaponObject.ammo and weapon.ammo > 0 then
            local ammoLabel = weaponObject.ammo.label
            weaponPickupLabel = ("%s [%s %s]"):format(weapon.label, weapon.ammo, ammoLabel)
            xPlayer.showNotification(TranslateCap("threw_weapon_ammo", weapon.label, weapon.ammo, ammoLabel))
        else
            weaponPickupLabel = ("%s"):format(weapon.label)
            xPlayer.showNotification(TranslateCap("threw_weapon", weapon.label))
        end

        ESX.CreatePickup("item_weapon", itemName, weapon.ammo, weaponPickupLabel, playerId, components, weapon.tintIndex)
    end
end)