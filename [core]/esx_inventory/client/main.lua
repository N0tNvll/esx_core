if not ESX.GetConfig("EnableDefaultInventory") then
    error("ESX Default Inventory is disabled in config, please enable it to use this resource.")
end

---@class NuiInventoryItem
---@field type "item_standard" | "item_account" | "item_weapon"
---@field name string
---@field label string
---@field count number
---@field weight number
---@field usable boolean
---@field canRemove boolean
---@field image string
---@field slot number?

---@class ESXInventoryClient
---@field isOpen boolean
---@field currentStorage table?
ESXInventory = {
    isOpen = false,
    currentStorage = nil,
    ITEM_TYPES = {
        item_standard = true,
        item_account = true,
        item_weapon = true,
    },
}
