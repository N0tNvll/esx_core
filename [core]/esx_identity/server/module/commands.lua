-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Commands = {}
local playerIdentity = IdentityModules.state.playerIdentity
local alreadyRegistered = IdentityModules.state.alreadyRegistered

function Commands.Register()
    if not Config.EnableCommands then return end
    ESX.RegisterCommand("char", "user", function(xPlayer)
        if xPlayer and xPlayer.getName() then
            xPlayer.showNotification(TranslateCap("active_character", xPlayer.getName()))
        else
            xPlayer.showNotification(TranslateCap("error_active_character"))
        end
    end, false, { help = TranslateCap("show_active_character") })

    ESX.RegisterCommand("chardel", "admin", function(xPlayer)
        if xPlayer and xPlayer.getName() then
            local identifier = xPlayer.getIdentifier()
            if Config.UseDeferrals then
                xPlayer.kick(TranslateCap("deleted_identity"))
                Wait(1500)
                IdentityModules.Identity.DeleteIdentity(xPlayer)
                xPlayer.showNotification(TranslateCap("deleted_character"))
                playerIdentity[identifier] = nil
                alreadyRegistered[identifier] = false
            else
                IdentityModules.Identity.DeleteIdentity(xPlayer)
                xPlayer.showNotification(TranslateCap("deleted_character"))
                playerIdentity[identifier] = nil
                alreadyRegistered[identifier] = false
                TriggerClientEvent("esx_identity:showRegisterIdentity", xPlayer.source)
            end
        else
            xPlayer.showNotification(TranslateCap("error_delete_character"))
        end
    end, false, { help = TranslateCap("delete_character") })
end

IdentityModules.Commands = Commands
