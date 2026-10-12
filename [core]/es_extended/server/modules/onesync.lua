-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESX.OneSync = {}

---@param vehicle integer
---@param properties table?
local function applyServerProperties(vehicle, properties)
    if type(properties) ~= "table" then
        return
    end

    if type(properties.plate) == "string" and properties.plate ~= "" then
        SetVehicleNumberPlateText(vehicle, properties.plate)
    end

    local color1, color2 = properties.color1, properties.color2

    if type(color1) == "table" then
        SetVehicleCustomPrimaryColour(vehicle, tonumber(color1[1]) or 0, tonumber(color1[2]) or 0, tonumber(color1[3]) or 0)
    end

    if type(color2) == "table" then
        SetVehicleCustomSecondaryColour(vehicle, tonumber(color2[1]) or 0, tonumber(color2[2]) or 0, tonumber(color2[3]) or 0)
    end

    if math.type(color1) == "integer" and math.type(color2) == "integer" then
        SetVehicleColours(vehicle, color1, color2)
    end
end

---@param vehicleModel number|string
---@param coords vector3|table
---@param heading number
---@param vehicleProperties table
---@param cb? fun(netId: number|false)
---@param vehicleType string?
---@return number? netId
function ESX.OneSync.SpawnVehicle(vehicleModel, coords, heading, vehicleProperties, cb, vehicleType)
    if cb and not ESX.IsFunctionReference(cb) then
        if vehicleType == nil and type(cb) == "string" then
            vehicleType = cb
            cb = nil
        elseif cb == false then
            cb = nil
        else
            cb = nil
        end
    end

    vehicleModel = joaat(vehicleModel)

    local promise = not cb and promise.new()

    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end

        return result
    end

    local function reject(err)
        if promise then
            return promise:reject(err)
        end

        if cb then
            return cb(false)
        end

        error(err)
    end

    CreateThread(function()
        if not vehicleType then
            vehicleType = ESX.GetVehicleType(vehicleModel, next(ESX.Players))
        end

        if not vehicleType then
            return reject(("Could not resolve the type of vehicle ^5%s^7! The model is unknown and no player is online to check it, you can also specify the vehicle type manually."):format(vehicleModel))
        end

        local createdVehicle = CreateVehicleServerSetter(vehicleModel, vehicleType, coords.x, coords.y, coords.z, heading)

        if not createdVehicle or createdVehicle == 0 then
            return reject(("Could not spawn vehicle - ^5%s^7!"):format(vehicleModel))
        end

        -- the server owns the entity right after creation regardless of players
        -- in scope, so a plain existence check is enough to know it is ready
        local tries = 0
        while not DoesEntityExist(createdVehicle) do
            Wait(50)
            tries = tries + 1
            if tries > 40 then
                return reject(("Could not spawn vehicle - ^5%s^7!"):format(vehicleModel))
            end
        end

        -- luacheck: ignore
        SetEntityOrphanMode(createdVehicle, 2)
        local networkId = NetworkGetNetworkIdFromEntity(createdVehicle)
        applyServerProperties(createdVehicle, vehicleProperties)
        Entity(createdVehicle).state:set("VehicleProperties", vehicleProperties, true)

        resolve(networkId)
    end)

    if promise then
        return Citizen.Await(promise)
    end
end

---@param model number|string
---@param coords vector3|table
---@param heading number
---@param cb? fun(netId: number|false)
---@return number? netId
function ESX.OneSync.SpawnObject(model, coords, heading, cb)
    if type(model) == "string" then
        model = joaat(model)
    end

    local promise = not cb and promise.new()
    local objectCoords = type(coords) == "vector3" and coords or vector3(coords.x, coords.y, coords.z)

    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end
    end

    local function reject(err)
        if promise then
            return promise:reject(err)
        end

        if cb then
            return cb(false)
        end

        error(err)
    end

    CreateThread(function()
        local entity = CreateObject(model, objectCoords.x, objectCoords.y, objectCoords.z, true, true, false)
        local tries = 0

        while not DoesEntityExist(entity) do
            Wait(200)
            
            tries = tries + 1

            if tries > 40 then
                return reject(("Could not spawn object - ^5%s^7!"):format(entity))
            end
        end

        local networkId = NetworkGetNetworkIdFromEntity(entity)

        SetEntityHeading(entity, heading)
        resolve(networkId)
    end)

    if promise then
        return Citizen.Await(promise)
    end
end

---@param model number|string
---@param coords vector3|table
---@param heading number
---@param cb? fun(netId: number|false)
---@return number? netId
function ESX.OneSync.SpawnPed(model, coords, heading, cb)
    if type(model) == "string" then
        model = joaat(model)
    end

    local promise = not cb and promise.new()

    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end
    end

    local function reject(err)
        if promise then
            return promise:reject(err)
        end

        if cb then
            return cb(false)
        end

        error(err)
    end

    CreateThread(function()
        local entity = CreatePed(0, model, coords.x, coords.y, coords.z, heading, true, true)
        local tries = 0

        while not DoesEntityExist(entity) do
            Wait(200)

            tries = tries + 1

            if tries > 40 then
                return reject(("Could not spawn ped - ^5%s^7!"):format(model))
            end
        end

        local networkId = NetworkGetNetworkIdFromEntity(entity)
        resolve(networkId)
    end)

    if promise then
        return Citizen.Await(promise)
    end
end

---@param model number|string
---@param vehicle number entityId
---@param seat number
---@param cb? fun(netId: number|false)
---@return number? netId
function ESX.OneSync.SpawnPedInVehicle(model, vehicle, seat, cb)
    if type(model) == "string" then
        model = joaat(model)
    end

    local promise = not cb and promise.new()

    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end
    end

    local function reject(err)
        if promise then
            return promise:reject(err)
        end

        if cb then
            return cb(false)
        end

        error(err)
    end

    CreateThread(function()
        local entity = CreatePedInsideVehicle(vehicle, 1, model, seat, true, true)
        local tries = 0

        while not DoesEntityExist(entity) do
            Wait(200)

            tries = tries + 1

            if tries > 40 then
                return reject(("Could not spawn ped - ^5%s^7!"):format(model))
            end
        end

        local networkId = NetworkGetNetworkIdFromEntity(entity)
        resolve(networkId)
    end)

    if promise then
        return Citizen.Await(promise)
    end
end
