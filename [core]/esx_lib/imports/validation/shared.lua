-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

---@class validationlib
xLib.validation = {}

local function isFinite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

---@param value any
---@param min? number
---@param max? number
---@param round? boolean
---@return number|nil
function xLib.validation.number(value, min, max, round)
    local number = tonumber(value)

    if not number or not isFinite(number) then
        return
    end

    if round then
        number = number >= 0 and math.floor(number + 0.5) or math.ceil(number - 0.5)
    end

    if min and number < min then
        return
    end

    if max and number > max then
        return
    end

    return number
end

---@param value any
---@param min? number
---@param max? number
---@param mode? "round"|"floor"|"ceil"
---@return number|nil
function xLib.validation.integer(value, min, max, mode)
    local number = tonumber(value)

    if not number or not isFinite(number) then
        return
    end

    if mode == "ceil" then
        number = math.ceil(number)
    elseif mode == "floor" then
        number = math.floor(number)
    else
        number = number >= 0 and math.floor(number + 0.5) or math.ceil(number - 0.5)
    end

    if min and number < min then
        return
    end

    if max and number > max then
        return
    end

    return number
end

---@param value any
---@param max? number
---@return number|nil
function xLib.validation.count(value, max)
    return xLib.validation.integer(value, 1, max, "round")
end

---@param value any
---@param min? number
---@param max? number
---@return number|nil
function xLib.validation.money(value, min, max)
    return xLib.validation.integer(value, min or 0, max, "round")
end

---@param value any
---@param options? table
---@return string|nil
function xLib.validation.string(value, options)
    if type(value) ~= "string" then
        return
    end

    options = options or {}

    if options.trim ~= false then
        value = value:gsub("^%s*(.-)%s*$", "%1")
    end

    if value == "" and not options.allowEmpty then
        return
    end

    if options.minLength and #value < options.minLength then
        return
    end

    if options.maxLength and #value > options.maxLength then
        return
    end

    if options.pattern and not value:match(options.pattern) then
        return
    end

    return value
end

---@param value any
---@param values table
---@return boolean
function xLib.validation.oneOf(value, values)
    if type(values) ~= "table" then
        return false
    end

    for i = 1, #values do
        if values[i] == value then
            return true
        end
    end

    return false
end
