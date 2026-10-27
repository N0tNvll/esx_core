-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Country values originate from esx-framework/esx_core#1746.
local countries = assert(json.decode(assert(LoadResourceFile('esx_lib', 'imports/nationality/countries.json'))))
local canonical = {}
for _, country in ipairs(countries) do
    canonical[country.value:lower()] = country.value
end

local Nationality = {}

---@param value unknown
---@return string?
function Nationality.normalize(value)
    if type(value) ~= 'string' or #value > 52 then return nil end
    return canonical[value:match('^%s*(.-)%s*$'):lower()]
end

return Nationality
