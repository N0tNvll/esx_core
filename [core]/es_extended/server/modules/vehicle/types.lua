---@param model string|number
---@param player number
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

    xLib.callback("esx:GetVehicleType", player, function(vehicleType)
        Core.vehicleTypesByModel[model] = vehicleType
        resolve(vehicleType)
    end, model)

    if promise then
        return Citizen.Await(promise)
    end
end
