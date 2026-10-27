-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Identity = {}
local playerIdentity = IdentityModules.state.playerIdentity
local alreadyRegistered = IdentityModules.state.alreadyRegistered

---@param xPlayer StaticPlayer|xPlayer
---@param data {firstName:string?, lastName:string?, dateOfBirth:string?, height:number?, nationality:string?, sex:"m"|"f"?}
function Identity.SetPlayerData(xPlayer, data)
    local name = ("%s %s"):format(data.firstName, data.lastName)
    xPlayer.setName(name)
    xPlayer.set("firstName", data.firstName)
    xPlayer.set("lastName", data.lastName)
    xPlayer.set("dateofbirth", data.dateOfBirth)
    xPlayer.set("sex", data.sex)
    xPlayer.set("height", data.height)
    xPlayer.setNationality(data.nationality)

    local state = Player(xPlayer.getSource()).state
    state:set("name", name, true)
    state:set("firstName", data.firstName, true)
    state:set("lastName", data.lastName, true)
    state:set("dateofbirth", data.dateOfBirth, true)
    state:set("sex", data.sex, true)
    state:set("height", data.height, true)
end

---@param xPlayer xPlayer
function Identity.DeleteIdentity(xPlayer)
    if not alreadyRegistered[xPlayer.identifier] then
        return
    end

    Identity.SetPlayerData(xPlayer, { firstName = nil, lastName = nil, dateOfBirth = nil, sex = nil, height = nil })
    IdentityModules.Database.DeleteIdentity(xPlayer)
end

-- Preserve the existing resource-global helper for custom server extensions.
SetPlayerData = Identity.SetPlayerData

IdentityModules.Identity = Identity
