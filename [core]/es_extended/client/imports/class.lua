-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local class = {}

class.__index = class

function class:new(...)
    local instance = setmetatable({}, self)

    if instance.constructor then
        local ret = instance:constructor(...)

        if type(ret) == 'table' then
            return ret
        end
    end
    return instance
end

local function Class(body, heritage)
    local prototype = body or {}

    prototype.__index = prototype
    return setmetatable(prototype, heritage or class)
end

if rawget(_ENV, 'Class') == nil then
    rawset(_ENV, 'Class', Class)
end

return Class
