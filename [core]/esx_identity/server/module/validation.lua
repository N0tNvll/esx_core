-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Validation = {}

---@param year number Year
---@return boolean: true if the year is a leap year, false otherwise
local function isLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

---@param dob string Date of Birth in the format DD/MM/YYYY
---@return boolean: true if the date is valid, false otherwise
function Validation.CheckDOBFormat(dob)
    dob = tostring(dob)

    local dayStr, monthStr, yearStr = dob:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
    if not dayStr or not monthStr or not yearStr then
        return false
    end

    local day, month, year = tonumber(dayStr), tonumber(monthStr), tonumber(yearStr)
    if not day or not month or not year then
        return false
    end

    local currentYear = os.date("*t").year
    local minYear = currentYear - Config.MaxAge
    local maxYear = currentYear - 18

    if year < minYear or year > maxYear then return false end
    if month < 1 or month > 12 then return false end

    -- Days in each month (starting from January.)
    local daysInMonth = { 31, isLeapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    return day >= 1 and day <= daysInMonth[month]
end

function Validation.CheckNameFormat(name)
    if type(name) == "string" and ESX.IsValidLocaleString(name) then
        local stringLength = string.len(name)
        return stringLength > 0 and stringLength < Config.MaxNameLength
    end

    return false
end

function Validation.CheckSexFormat(sex)
    if not sex then
        return false
    end
    return sex == "m" or sex == "M" or sex == "f" or sex == "F"
end

function Validation.CheckHeightFormat(height)
    if type(height) ~= "number" and type(height) ~= "string" then
        return false
    end

    local numHeight = tonumber(height)

    return numHeight ~= nil
        and numHeight == numHeight
        and numHeight > -math.huge
        and numHeight < math.huge
        and numHeight >= Config.MinHeight
        and numHeight <= Config.MaxHeight
end

IdentityModules.Validation = Validation
