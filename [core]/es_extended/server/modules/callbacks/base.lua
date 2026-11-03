-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function getPlayerData(xPlayer)
    return {
        identifier = xPlayer.identifier,
        accounts = xPlayer.getAccounts(),
        inventory = xPlayer.getInventory(),
        job = xPlayer.getJob(),
        loadout = xPlayer.getLoadout(),
        money = xPlayer.getMoney(),
        position = xPlayer.getCoords(true),
        metadata = xPlayer.getMeta(),
        nationality = xPlayer.nationality,
    }
end

xLib.callback.registerCompat('esx:getPlayerData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return cb(nil)
    end

    cb(getPlayerData(xPlayer))
end)

xLib.callback.registerCompat('esx:isUserAdmin', function(source, cb)
    cb(Core.IsPlayerAdmin(source))
end)

xLib.callback.registerCompat('esx:getGameBuild', function(_, cb)
    cb(tonumber(GetConvar('sv_enforceGameBuild', '1604')))
end)

xLib.callback.registerCompat('esx:getOtherPlayerData', function(source, cb, target)
    if not Core.IsPlayerAdmin(source) then
        return cb(nil)
    end

    local xPlayer = ESX.GetPlayerFromId(target)

    if not xPlayer then
        return cb(nil)
    end

    cb(getPlayerData(xPlayer))
end)

xLib.callback.registerCompat('esx:getPlayerNames', function(source, cb, players)
    if type(players) ~= 'table' then
        return cb({})
    end

    players[source] = nil

    for playerId in pairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)

        players[playerId] = xPlayer and xPlayer.getName() or nil
    end

    cb(players)
end)

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function isWithinCoordinateLimit(x, y, z)
    local limit = Config.PlayerCoordinateLimit

    if not isFiniteNumber(limit) or limit <= 0 then
        limit = 10000.0
    end

    return isFiniteNumber(x) and isFiniteNumber(y) and isFiniteNumber(z) and math.abs(x) <= limit and math.abs(y) <= limit and math.abs(z) <= limit
end

local function getHeadingFromCoords(coords, coordinateType)
    if coordinateType == 'vector4' then
        return coords.w
    elseif coordinateType == 'table' then
        if coords.w ~= nil then
            return coords.w
        end

        if coords.heading ~= nil then
            return coords.heading
        end
    end

    return nil
end

xLib.callback.registerCompat('esx:spawnVehicle', function(source, cb, vehData)
    print('[^3WARNING^7] esx:spawnVehicle callback is deprecated and will be removed in a future update.')

    if not Core.IsPlayerAdmin(source) then
        return cb(false)
    end

    vehData = type(vehData) == 'table' and vehData or {}

    local ped = GetPlayerPed(source)

    if ped == 0 or not DoesEntityExist(ped) then
        return cb(false)
    end

    local model = vehData.model

    if (type(model) ~= 'string' or model == '') and (not isFiniteNumber(model) or model ~= math.floor(model)) then
        model = `ADDER`
    end

    local coords = vehData.coords
    local coordinateType = type(coords)
    local coordsValid = false

    if (coordinateType == 'table' or coordinateType == 'vector3' or coordinateType == 'vector4') and isWithinCoordinateLimit(coords.x, coords.y, coords.z) then
        coordsValid = true
    end

    if not coordsValid then
        coords = GetEntityCoords(ped)
        coordinateType = type(coords)
    end

    local heading = tonumber(vehData.heading)

    if not isFiniteNumber(heading) then
        local headingFromCoords = getHeadingFromCoords(coords, coordinateType)
        heading = tonumber(headingFromCoords)
    end

    if not isFiniteNumber(heading) then
        heading = GetEntityHeading(ped)
    end

    local props = type(vehData.props) == 'table' and vehData.props or {}

    ESX.OneSync.SpawnVehicle(model, coords, heading, props, function(id)
        if vehData.warp and id then
            local vehicle = NetworkGetEntityFromNetworkId(id)
            local timeout = 0

            while vehicle ~= 0 and DoesEntityExist(vehicle) and GetPlayerPed(source) == ped and DoesEntityExist(ped) and GetVehiclePedIsIn(ped, false) ~= vehicle and timeout <= 15 do
                TaskWarpPedIntoVehicle(ped, vehicle, -1)
                timeout += 1
                Wait(0)
            end
        end

        cb(id)
    end)
end)
