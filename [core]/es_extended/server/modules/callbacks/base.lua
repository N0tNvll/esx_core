local function buildPlayerData(xPlayer)
    return {
        identifier = xPlayer.identifier,
        accounts = xPlayer.getAccounts(),
        inventory = xPlayer.getInventory(),
        job = xPlayer.getJob(),
        loadout = xPlayer.getLoadout(),
        money = xPlayer.getMoney(),
        position = xPlayer.getCoords(true),
        metadata = xPlayer.getMeta(),
    }
end

ESX.RegisterServerCallback("esx:getPlayerData", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return
    end

    cb(buildPlayerData(xPlayer))
end)

ESX.RegisterServerCallback("esx:isUserAdmin", function(source, cb)
    cb(Core.IsPlayerAdmin(source))
end)

ESX.RegisterServerCallback("esx:getGameBuild", function(_, cb)
    cb(tonumber(GetConvar("sv_enforceGameBuild", "1604")))
end)

ESX.RegisterServerCallback("esx:getOtherPlayerData", function(_, cb, target)
    local xPlayer = ESX.GetPlayerFromId(target)

    if not xPlayer then
        return
    end

    cb(buildPlayerData(xPlayer))
end)

ESX.RegisterServerCallback("esx:getPlayerNames", function(source, cb, players)
    if type(players) ~= "table" then
        return cb({})
    end

    players[source] = nil

    for playerId in pairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        players[playerId] = xPlayer and xPlayer.getName() or nil
    end

    cb(players)
end)

ESX.RegisterServerCallback("esx:spawnVehicle", function(source, cb, vehData)
    vehData = type(vehData) == "table" and vehData or {}

    local ped = GetPlayerPed(source)
    local coords = vehData.coords or GetEntityCoords(ped)
    local heading = vehData.heading or coords.w or coords.heading or GetEntityHeading(ped) or 0.0

    ESX.OneSync.SpawnVehicle(vehData.model or `ADDER`, coords, heading, vehData.props or {}, function(id)
        if vehData.warp and id then
            local vehicle = NetworkGetEntityFromNetworkId(id)
            local timeout = 0

            while GetVehiclePedIsIn(ped, false) ~= vehicle and timeout <= 15 do
                Wait(0)
                TaskWarpPedIntoVehicle(ped, vehicle, -1)
                timeout += 1
            end
        end

        cb(id)
    end)
end)
