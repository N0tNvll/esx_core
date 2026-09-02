---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("VehicleProperties", nil, function(bagName, _, value)
    if not value then
        return
    end

    bagName = bagName:gsub("entity:", "")
    local netId = tonumber(bagName)
    if not netId then
        error("Tried to set vehicle properties with invalid netId")
        return
    end

    local tries = 0

    while not NetworkDoesEntityExistWithNetworkId(netId) do
        Wait(200)
        tries += 1
        if tries > 20 then
            return error(("Invalid entity - ^5%s^7!"):format(netId))
        end
    end

    local vehicle = NetToVeh(netId)

    if NetworkGetEntityOwner(vehicle) ~= ESX.playerId then
        return
    end

    ESX.Game.SetVehicleProperties(vehicle, value)
end)

ESX.RegisterClientCallback("esx:GetVehicleType", function(cb, model)
    cb(ESX.GetVehicleTypeClient(model))
end)
