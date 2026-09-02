if Config.CustomInventory then
    return
end

RegisterNetEvent("esx:updateWeaponAmmo", function(weaponName, ammoCount)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer then
        xPlayer.updateWeaponAmmo(weaponName, ammoCount)
    end
end)