-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local KVP_KEY <const> = "esx_vehicleTypes"
local KVP_VERSION <const> = 1

local validTypes <const> = {
    automobile = true,
    bike = true,
    boat = true,
    heli = true,
    plane = true,
    submarine = true,
    trailer = true,
    train = true,
}

local storedTypes = {}
local persistQueued = false

local function persistVehicleTypes()
    if persistQueued then
        return
    end

    persistQueued = true

    SetTimeout(1000, function()
        persistQueued = false

        if not next(storedTypes) then
            return DeleteResourceKvp(KVP_KEY)
        end

        SetResourceKvp(KVP_KEY, json.encode({ version = KVP_VERSION, types = storedTypes }))
    end)
end

---@param model string|number
---@param vehicleType string|false|nil
---@return nil
function Core.CacheVehicleType(model, vehicleType)
    model = type(model) == "string" and joaat(model) or model

    if type(model) ~= "number" or not validTypes[vehicleType] then
        return
    end

    Core.vehicleTypesByModel[model] = vehicleType
    storedTypes[tostring(model)] = vehicleType

    persistVehicleTypes()
end

local function restoreVehicleTypes()
    local stored = GetResourceKvpString(KVP_KEY)

    if not stored then
        return
    end

    local ok, decoded = pcall(json.decode, stored)

    if not ok or type(decoded) ~= "table" or decoded.version ~= KVP_VERSION or type(decoded.types) ~= "table" then
        return DeleteResourceKvp(KVP_KEY)
    end

    for model, vehicleType in pairs(decoded.types) do
        model = tonumber(model)

        if model and validTypes[vehicleType] then
            Core.vehicleTypesByModel[model] = vehicleType
            storedTypes[tostring(model)] = vehicleType
        end
    end
end

---@param model string|number
---@param player? number
---@param cb function?
---@return string?
---@diagnostic disable-next-line: duplicate-set-field
function ESX.GetVehicleType(model, player, cb)
    if cb and not ESX.IsFunctionReference(cb) then
        error("Invalid callback function")
    end

    local promise = not cb and promise.new()
    local function resolve(result)
        if promise then
            promise:resolve(result)
        elseif cb then
            cb(result)
        end

        return result
    end

    model = type(model) == "string" and joaat(model) or model

    if Core.vehicleTypesByModel[model] then
        return resolve(Core.vehicleTypesByModel[model])
    end

    if not player then
        return resolve(nil)
    end

    xLib.callback("esx:GetVehicleType", player, function(vehicleType)
        Core.CacheVehicleType(model, vehicleType)
        resolve(vehicleType)
    end, model)

    if promise then
        return Citizen.Await(promise)
    end
end

restoreVehicleTypes()
