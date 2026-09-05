if not Config.CustomInventory then
    local STREAM_DISTANCE <const> = 150.0
    local CELL_SIZE <const> = 100.0
    local CELL_RANGE <const> = math.ceil(STREAM_DISTANCE / CELL_SIZE)

    local PICKUP_TTL_MS <const> = 30 * 60 * 1000
    local MAX_ACTIVE_PER_PLAYER <const> = 50
    local MAX_ACTIVE_PER_CELL <const> = 25
    local MAX_ACTIVE_GLOBAL <const> = 5000

    ---@type table<number, table<string, { [number]: true, count: number }>>
    local pickupGrid = {}
    ---@type table<number, table<number, true>>
    local playerPickups = {}
    ---@type table<number, number>
    local playerPickupCounts = {}
    local activePickupCount = 0

    ---@param coords vector3
    ---@param bucket? number
    ---@return number[]
    local function getPlayersInStreamRange(coords, bucket)
        local nearby = xLib.onesync.getPlayersInArea(coords, STREAM_DISTANCE)
        local targets = {}

        for i = 1, #nearby do
            local id = nearby[i].id

            if not bucket or GetPlayerRoutingBucket(id) == bucket then
                targets[#targets + 1] = id
            end
        end

        return targets
    end

    Core.PickupStreamDistance = STREAM_DISTANCE
    Core.GetPickupTargets = getPlayersInStreamRange

    ---@param coords vector3|table
    ---@return string
    local function getCellKey(coords)
        local cx = math.floor(coords.x / CELL_SIZE)
        local cy = math.floor(coords.y / CELL_SIZE)

        return ("%d:%d"):format(cx, cy)
    end

    ---@param coords vector3|table
    ---@return string[]
    local function getCellKeysAround(coords)
        local cx = math.floor(coords.x / CELL_SIZE)
        local cy = math.floor(coords.y / CELL_SIZE)
        local keys = {}

        for dx = -CELL_RANGE, CELL_RANGE do
            for dy = -CELL_RANGE, CELL_RANGE do
                keys[#keys + 1] = ("%d:%d"):format(cx + dx, cy + dy)
            end
        end

        return keys
    end

    ---@param pickupId number
    ---@param pickup table
    local function addPickupToGrid(pickupId, pickup)
        local bucketGrid = pickupGrid[pickup.bucket]

        if not bucketGrid then
            bucketGrid = {}
            pickupGrid[pickup.bucket] = bucketGrid
        end

        local cell = bucketGrid[pickup.cellKey]

        if not cell then
            cell = { entries = {}, count = 0 }
            bucketGrid[pickup.cellKey] = cell
        end

        cell.entries[pickupId] = true
        cell.count = cell.count + 1
    end

    ---@param pickupId number
    ---@param pickup table
    local function removePickupFromGrid(pickupId, pickup)
        local bucketGrid = pickupGrid[pickup.bucket]

        if not bucketGrid then
            return
        end

        local cell = bucketGrid[pickup.cellKey]

        if not cell then
            return
        end

        if cell.entries[pickupId] then
            cell.entries[pickupId] = nil
            cell.count = cell.count - 1
        end

        if cell.count <= 0 then
            bucketGrid[pickup.cellKey] = nil
        end

        if not next(bucketGrid) then
            pickupGrid[pickup.bucket] = nil
        end
    end

    ---@param pickupId number
    ---@param targets? number[]
    local function destroyPickup(pickupId, targets)
        local pickup = Core.Pickups[pickupId]

        if not pickup then
            return
        end

        Core.Pickups[pickupId] = nil
        removePickupFromGrid(pickupId, pickup)

        if pickup.playerId then
            playerPickupCounts[pickup.playerId] = (playerPickupCounts[pickup.playerId] or 1) - 1

            if playerPickupCounts[pickup.playerId] <= 0 then
                playerPickupCounts[pickup.playerId] = nil
            end

            local playerIds = playerPickups[pickup.playerId]

            if playerIds then
                playerIds[pickupId] = nil

                if not next(playerIds) then
                    playerPickups[pickup.playerId] = nil
                end
            end
        end

        activePickupCount = activePickupCount - 1

        if targets and #targets > 0 then
            xLib.triggerClientEvent("esx:removePickup", targets, pickupId)
        end
    end

    ---@param pickupId number
    ---@param notify? boolean | number[]
    Core.RemovePickup = function(pickupId, notify)
        local pickup = Core.Pickups[pickupId]

        if not pickup then
            return
        end

        local targets

        if type(notify) == "table" then
            targets = notify
        elseif notify then
            targets = getPlayersInStreamRange(pickup.coords, pickup.bucket)
        end

        destroyPickup(pickupId, targets)
    end

    ---@param itemType string
    ---@param name string
    ---@param count integer
    ---@param label string
    ---@param playerId number
    ---@param components? string | table
    ---@param tintIndex? integer
    ---@param coords? table | vector3
    ---@return number? pickupId
    function ESX.CreatePickup(itemType, name, count, label, playerId, components, tintIndex, coords)
        local xPlayer = ESX.GetPlayerFromId(playerId)

        if not xPlayer then
            return nil
        end

        coords = ((type(coords) == "vector3" or type(coords) == "vector4") and coords.xyz or xPlayer.getCoords(true))

        local cellKey = getCellKey(coords)
        local bucket = GetPlayerRoutingBucket(playerId)

        local bucketGrid = pickupGrid[bucket]
        local cell = bucketGrid and bucketGrid[cellKey] or nil

        if cell and cell.count >= MAX_ACTIVE_PER_CELL then
            return nil
        end

        if activePickupCount >= MAX_ACTIVE_GLOBAL then
            return nil
        end

        local playerCount = playerPickupCounts[playerId] or 0

        if playerCount >= MAX_ACTIVE_PER_PLAYER then
            return nil
        end

        local pickupId = (Core.PickupId == 65635 and 0 or Core.PickupId + 1)

        Core.Pickups[pickupId] = {
            type = itemType,
            name = name,
            count = count,
            label = label,
            coords = coords,
            bucket = bucket,
            cellKey = cellKey,
            createdAt = GetGameTimer(),
            playerId = playerId,
        }

        if itemType == "item_weapon" then
            Core.Pickups[pickupId].components = components
            Core.Pickups[pickupId].tintIndex = tintIndex
        end

        addPickupToGrid(pickupId, Core.Pickups[pickupId])
        activePickupCount = activePickupCount + 1

        local playerIds = playerPickups[playerId]

        if not playerIds then
            playerIds = {}
            playerPickups[playerId] = playerIds
        end

        playerIds[pickupId] = true
        playerPickupCounts[playerId] = (playerPickupCounts[playerId] or 0) + 1

        xLib.triggerClientEvent("esx:createPickup", getPlayersInStreamRange(coords, bucket), pickupId, label, coords, itemType, name, components, tintIndex)
        Core.PickupId = pickupId

        return pickupId
    end

    RegisterNetEvent("esx:requestPickups", function()
        local playerId = source

        if not Core.InventoryEvents.ConsumeRate("pickup", playerId) then
            return
        end

        local ped = GetPlayerPed(playerId)

        if ped == 0 then
            return
        end

        local playerCoords = GetEntityCoords(ped)
        local bucket = GetPlayerRoutingBucket(playerId)
        local nearbyPickups = {}
        local cellKeys = getCellKeysAround(playerCoords)
        local bucketGrid = pickupGrid[bucket]

        for i = 1, #cellKeys do
            local cell = bucketGrid and bucketGrid[cellKeys[i]] or nil

            if cell then
                for pickupId in pairs(cell.entries) do
                    local pickup = Core.Pickups[pickupId]

                    if pickup and #(playerCoords - pickup.coords) <= STREAM_DISTANCE then
                        nearbyPickups[pickupId] = pickup
                    end
                end
            end
        end

        TriggerClientEvent("esx:createMissingPickups", playerId, nearbyPickups)
    end)

    CreateThread(function()
        while true do
            Wait(60000)

            local now = GetGameTimer()

            for pickupId, pickup in pairs(Core.Pickups) do
                if now - (pickup.createdAt or now) > PICKUP_TTL_MS then
                    destroyPickup(pickupId, getPlayersInStreamRange(pickup.coords, pickup.bucket))
                end
            end
        end
    end)
end