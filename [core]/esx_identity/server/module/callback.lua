-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Callback = {}
local playerIdentity = IdentityModules.state.playerIdentity
local alreadyRegistered = IdentityModules.state.alreadyRegistered

function Callback.RegisterIdentity(source, cb, data)
    if type(data) ~= "table" then
        return cb(false)
    end

    local xPlayer = ESX.Player(source)

    if not IdentityModules.Validation.CheckNameFormat(data.firstname) then
        TriggerClientEvent("esx:showNotification", source, TranslateCap("invalid_firstname_format"), "error")
        return cb(false)
    end
    if not IdentityModules.Validation.CheckNameFormat(data.lastname) then
        TriggerClientEvent("esx:showNotification", source, TranslateCap("invalid_lastname_format"), "error")
        return cb(false)
    end
    if not IdentityModules.Validation.CheckSexFormat(data.sex) then
        TriggerClientEvent("esx:showNotification", source, TranslateCap("invalid_sex_format"), "error")
        return cb(false)
    end
    if type(data.dateofbirth) ~= "string" or not IdentityModules.Validation.CheckDOBFormat(data.dateofbirth) then
        TriggerClientEvent("esx:showNotification", source, TranslateCap("invalid_dob_format"), "error")
        return cb(false)
    end
    if not IdentityModules.Validation.CheckHeightFormat(data.height) then
        TriggerClientEvent("esx:showNotification", source, TranslateCap("invalid_height_format"), "error")
        return cb(false)
    end

    local nationality = xLib.nationality.normalize(data.nationality)
    if not nationality then
        TriggerClientEvent("esx:showNotification", source, TranslateCap("invalid_nationality_format"), "error")
        return cb(false)
    end

    data.sex = string.lower(data.sex)
    data.height = tonumber(data.height)
    data.nationality = nationality

    if xPlayer then
        local identifier = xPlayer.getIdentifier()
        if alreadyRegistered[identifier] then
            xPlayer.showNotification(TranslateCap("already_registered"), "error")
            return cb(false)
        end

        playerIdentity[identifier] = {
            firstName = IdentityModules.Util.FormatName(data.firstname),
            lastName = IdentityModules.Util.FormatName(data.lastname),
            dateOfBirth = IdentityModules.Util.FormatDate(data.dateofbirth),
            sex = data.sex,
            height = data.height,
            nationality = nationality,
        }

        local currentIdentity = playerIdentity[identifier]

        IdentityModules.Identity.SetPlayerData(xPlayer, currentIdentity)

        TriggerClientEvent("esx_identity:setPlayerData", xPlayer.src, currentIdentity)
        IdentityModules.Database.SaveIdentity(identifier, currentIdentity)
        alreadyRegistered[identifier] = true
        playerIdentity[identifier] = nil
        return cb(true)
    end

    if not IdentityModules.Lifecycle.IsMultichar() then
        TriggerClientEvent("esx:showNotification", source, TranslateCap("data_incorrect"), "error")
        return cb(false)
    end

    local formattedFirstName = IdentityModules.Util.FormatName(data.firstname)
    local formattedLastName = IdentityModules.Util.FormatName(data.lastname)
    local formattedDate = IdentityModules.Util.FormatDate(data.dateofbirth)

    data.firstname = formattedFirstName
    data.lastname = formattedLastName
    data.dateofbirth = formattedDate
    local Identity = {
        firstName = formattedFirstName,
        lastName = formattedLastName,
        dateOfBirth = formattedDate,
        sex = data.sex,
        height = data.height,
        nationality = nationality,
    }

    TriggerEvent("esx_identity:completedRegistration", source, data)
    TriggerClientEvent("esx_identity:setPlayerData", source, Identity)
    cb(true)
end

IdentityModules.Callback = Callback
