local Inventory = ESXInventory

---@param storage table
local function applyStorageSlots(storage)
    local items = storage.items or {}

    for i = 1, #items do
        items[i].slot = i - 1
    end

    storage.items = items
end

RegisterNetEvent("esx_inventory:openStorage", function(storage)
    if type(storage) ~= "table" or type(storage.id) ~= "string" then
        return
    end

    applyStorageSlots(storage)
    Inventory.currentStorage = storage

    if Inventory.isOpen then
        Inventory.pushState()
    else
        Inventory.open()

        if not Inventory.isOpen then
            Inventory.currentStorage = nil
            TriggerServerEvent("esx_inventory:storageClosed")
        end
    end
end)

RegisterNetEvent("esx_inventory:refreshStorage", function(storage)
    if not Inventory.isOpen or not Inventory.currentStorage or type(storage) ~= "table" or storage.id ~= Inventory.currentStorage.id then
        return
    end

    applyStorageSlots(storage)
    Inventory.currentStorage = storage
    Inventory.pushState()
end)

RegisterNetEvent("esx_inventory:closeStorage", function()
    if not Inventory.currentStorage then
        return
    end

    Inventory.currentStorage = nil

    if Inventory.isOpen then
        Inventory.pushState()
    end
end)
