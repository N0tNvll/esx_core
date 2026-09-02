---@param owner string
---@param plate string
---@param coords vector4
---@return CExtendedVehicle?
function ESX.CreateExtendedVehicle(owner, plate, coords)
    return Core.vehicleClass.new(owner, plate, coords)
end

---@param plate string
---@return CExtendedVehicle?
function ESX.GetExtendedVehicleFromPlate(plate)
    return Core.vehicleClass.getFromPlate(plate)
end
