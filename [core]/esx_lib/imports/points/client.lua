-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@class pointslib
xLib.points = {}

local points = {}
local insidePoints = {}
local handleCount = 0
local loopStarted = false

---@param coords vector3
---@param distance number
---@param hidden? boolean
---@param enter function
---@param leave function
---@param inside? function
---@return integer handle
function xLib.points.create(coords, distance, hidden, enter, leave, inside)
    handleCount = handleCount + 1
    local handle = handleCount

    points[handle] = {
        coords = coords,
        distance = distance,
        hidden = hidden,
        enter = enter,
        leave = leave,
        inside = inside,
        resource = GetInvokingResource()
    }

    xLib.points.startLoop()

    return handle
end

---@param handle integer
function xLib.points.remove(handle)
    points[handle] = nil
    insidePoints[handle] = nil
end

---@param handle integer
---@param hidden boolean
function xLib.points.hide(handle, hidden)
    if points[handle] then
        points[handle].hidden = hidden
    end
end

function xLib.points.startLoop()
    if loopStarted then
        return
    end

    loopStarted = true

    CreateThread(function()
        local lastScan = 0

        while next(points) do
            local coords = GetEntityCoords(PlayerPedId())

            for handle, point in pairs(insidePoints) do
                if not pcall(point.inside, #(coords - point.coords)) then
                    insidePoints[handle] = nil
                    print(("[^1ERROR^7] point ^5%s^7 from ^5%s^7 errored on inside"):format(handle, point.resource))
                end
            end

            local now = GetGameTimer()
            if now - lastScan >= 500 then
                lastScan = now

                for handle, point in pairs(points) do
                    if not point.hidden and #(coords - point.coords) <= point.distance then
                        if not point.nearby then
                            point.nearby = true

                            if point.enter and not pcall(point.enter) then
                                print(("[^1ERROR^7] point ^5%s^7 from ^5%s^7 errored on enter"):format(handle, point.resource))
                            end

                            if point.inside then
                                insidePoints[handle] = point
                            end
                        end
                    elseif point.nearby then
                        point.nearby = false

                        if point.leave and not pcall(point.leave) then
                            print(("[^1ERROR^7] point ^5%s^7 from ^5%s^7 errored on leave"):format(handle, point.resource))
                        end

                        insidePoints[handle] = nil
                    end
                end
            end

            Wait(next(insidePoints) and 0 or 500)
        end

        loopStarted = false
    end)
end

AddEventHandler("onResourceStop", function(resource)
    for handle, point in pairs(points) do
        if point.resource == resource then
            points[handle] = nil
            insidePoints[handle] = nil
        end
    end
end)

-- Object API from esx-framework/esx_core#1755. The numeric-handle API above
-- remains available to ESX.CreatePointInternal, xLib.point and markerZone.
do
    local objectPoints = {}
    local nearbyPoints = {}
    local closestPoint
    local nextId = 0
    local scanning = false
    local ticking = false

    local function invoke(point, name)
        if point[name] then
            local ok, err = pcall(point[name], point)
            if not ok then
                print(("[^1ERROR^7] point ^5%s^7 from ^5%s^7 on %s: %s"):format(point.id, point.resource, name, err))
            end
        end
    end

    local function removePoint(point)
        if objectPoints[point.id] ~= point then return end
        objectPoints[point.id] = nil
        xLib.grid.removeEntry(point)
        if closestPoint == point then closestPoint = nil end
        for i = #nearbyPoints, 1, -1 do
            if nearbyPoints[i] == point then table.remove(nearbyPoints, i) end
        end
        point.inside, point.currentDistance, point.isClosest = nil, nil, nil
    end

    local function startObjectLoop()
        if scanning then return end
        scanning = true
        CreateThread(function()
            while next(objectPoints) do
                local coords = GetEntityCoords(PlayerPedId())
                local previousPoints = { table.unpack(nearbyPoints) }
                for _, point in ipairs(previousPoints) do
                    point.isClosest = nil
                    if point.inside and (point.hidden or #(coords - point.coords) > point.radius) then
                        point.inside, point.currentDistance = nil, nil
                        invoke(point, 'onExit')
                    end
                end
                table.wipe(nearbyPoints)
                closestPoint = nil
                local candidates = xLib.grid.getNearbyEntries(coords, function(point)
                    return objectPoints[point.id] == point and not point.hidden
                end)
                for i = 1, #candidates do
                    local point = candidates[i]
                    if objectPoints[point.id] == point then
                        local distance = #(coords - point.coords)
                        if distance <= point.radius then
                            point.currentDistance = distance
                            if not point.inside then
                                point.inside = true
                                invoke(point, 'onEnter')
                            end
                            if objectPoints[point.id] == point and not point.hidden then
                                nearbyPoints[#nearbyPoints + 1] = point
                                if not closestPoint or distance < closestPoint.currentDistance then
                                    closestPoint = point
                                end
                            end
                        end
                    end
                end
                if closestPoint then closestPoint.isClosest = true end
                if not ticking and #nearbyPoints > 0 then
                    ticking = true
                    CreateThread(function()
                        while #nearbyPoints > 0 do
                            local currentCoords = GetEntityCoords(PlayerPedId())
                            -- A callback may remove another point from the live list.
                            local framePoints = { table.unpack(nearbyPoints) }
                            for i = #framePoints, 1, -1 do
                                local point = framePoints[i]
                                if point and objectPoints[point.id] == point and not point.hidden then
                                    point.currentDistance = #(currentCoords - point.coords)
                                    if point.currentDistance <= point.radius then invoke(point, 'nearby') end
                                end
                            end
                            Wait(0)
                        end
                        ticking = false
                    end)
                end
                Wait(300)
            end
            scanning = false
        end)
    end

    ---@overload fun(data: table): table
    ---@param coords vector3
    ---@param distance number
    ---@param data? table
    ---@return table
    function xLib.points.new(coords, distance, data)
        local point = {}
        if type(coords) == 'table' and coords.coords then
            for key, value in pairs(coords) do point[key] = value end
        else
            for key, value in pairs(data or {}) do point[key] = value end
            point.coords = coords
            point.distance = distance
        end
        assert(type(point.distance) == 'number' and point.distance >= 0, 'point distance must be non-negative')
        local c = point.coords
        if type(c) ~= 'vector3' then
            assert(type(c) == 'table' or type(c) == 'vector4', 'point coords must be a vector or table')
            point.coords = vec3(c.x or c[1], c.y or c[2], c.z or c[3])
        end
        nextId = nextId + 1
        point.id, point.radius = nextId, point.distance
        point.resource = GetInvokingResource() or GetCurrentResourceName()
        point.remove = function() removePoint(point) end
        objectPoints[point.id] = point
        xLib.grid.addEntry(point)
        startObjectLoop()
        return point
    end

    function xLib.points.getAllPoints() return objectPoints end
    function xLib.points.getNearbyPoints() return nearbyPoints end
    function xLib.points.getClosestPoint() return closestPoint end
    xLib.points.closest = xLib.points.getClosestPoint

    AddEventHandler('onResourceStop', function(resource)
        for _, point in pairs(objectPoints) do
            if point.resource == resource then removePoint(point) end
        end
    end)
end

return xLib.points
