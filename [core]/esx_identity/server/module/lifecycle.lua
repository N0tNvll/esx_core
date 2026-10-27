-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Lifecycle = {}
local playerIdentity = IdentityModules.state.playerIdentity
local alreadyRegistered = IdentityModules.state.alreadyRegistered

local multichar

---@param xPlayer StaticPlayer
local function setIdentity(xPlayer)
    local playerIdentifier = xPlayer.getIdentifier()
    if not alreadyRegistered[playerIdentifier] then
        return
    end
    local currentIdentity = playerIdentity[playerIdentifier]
    IdentityModules.Identity.SetPlayerData(xPlayer, currentIdentity)

    TriggerClientEvent("esx_identity:setPlayerData", xPlayer.src, currentIdentity)
    if currentIdentity.saveToDatabase then
        IdentityModules.Database.SaveIdentity(playerIdentifier, currentIdentity)
    end

    playerIdentity[playerIdentifier] = nil
end

---@param xPlayer StaticPlayer
local function checkIdentity(xPlayer)
    local playerIdentifier = xPlayer.getIdentifier()
    IdentityModules.Database.GetIdentity(playerIdentifier, function(result)
        if not result then
            return TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.src)
        end
        if not result.firstname then
            playerIdentity[playerIdentifier] = nil
            alreadyRegistered[playerIdentifier] = false
            return TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.src)
        end

        playerIdentity[playerIdentifier] = {
            firstName = result.firstname,
            lastName = result.lastname,
            dateOfBirth = result.dateofbirth,
            sex = result.sex,
            height = result.height,
        }

        alreadyRegistered[playerIdentifier] = true
        setIdentity(xPlayer)
    end)
end

function Lifecycle.RegisterHandlers()
    multichar = ESX.GetConfig().Multichar
    if multichar then return end
    AddEventHandler("playerConnecting", function(_, _, deferrals)
        deferrals.defer()
        local _, identifier = source, nil

        local correctLicense, _ = pcall(function()
            identifier = ESX.GetIdentifier(source)
        end)

        Wait(40)

        if not identifier or not correctLicense then
            return deferrals.done(TranslateCap("no_identifier"))
        end
        IdentityModules.Database.GetIdentity(identifier, function(result)
            if not result then
                playerIdentity[identifier] = nil
                alreadyRegistered[identifier] = false
                return deferrals.done()
            end
            if not result.firstname then
                playerIdentity[identifier] = nil
                alreadyRegistered[identifier] = false
                return deferrals.done()
            end

            playerIdentity[identifier] = {
                firstName = result.firstname,
                lastName = result.lastname,
                dateOfBirth = result.dateofbirth,
                sex = result.sex,
                height = result.height,
            }

            alreadyRegistered[identifier] = true

            deferrals.done()
        end)
    end)

    AddEventHandler("onResourceStart", function(resource)
        if resource ~= GetCurrentResourceName() then
            return
        end
        Wait(300)

        while not ESX do
            Wait(0)
        end

        local xPlayers = ESX.ExtendedPlayers() --[=[@as StaticPlayer[]]=]

        for i = 1, #xPlayers do
            if xPlayers[i] then
                checkIdentity(xPlayers[i])
            end
        end
    end)

    AddEventHandler("esx:playerLoaded", function(_, xPlayer)
        local currentIdentity = playerIdentity[xPlayer.identifier]

        if currentIdentity and alreadyRegistered[xPlayer.identifier] then
            IdentityModules.Identity.SetPlayerData(xPlayer, currentIdentity)

            TriggerClientEvent("esx_identity:setPlayerData", xPlayer.source, currentIdentity)
            if currentIdentity.saveToDatabase then
                IdentityModules.Database.SaveIdentity(xPlayer.identifier, currentIdentity)
            end

            Wait(0)

            TriggerClientEvent("esx_identity:alreadyRegistered", xPlayer.source)

            playerIdentity[xPlayer.identifier] = nil
        else
            TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.source)
        end
    end)
end

function Lifecycle.IsMultichar()
    return multichar
end

IdentityModules.Lifecycle = Lifecycle
