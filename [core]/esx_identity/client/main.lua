-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local loadingScreenFinished = false
local ready = false
local guiEnabled = false
local timecycleModifier = "hud_def_blur"

ESX.SecureNetEvent("esx_identity:alreadyRegistered", function()
    while not loadingScreenFinished do
        Wait(100)
    end
    TriggerEvent("esx_skin:playerRegistered")
end)

ESX.SecureNetEvent("esx_identity:setPlayerData", function(data)
    SetTimeout(1, function()
        ESX.SetPlayerData("name", ("%s %s"):format(data.firstName, data.lastName))
        ESX.SetPlayerData("firstName", data.firstName)
        ESX.SetPlayerData("lastName", data.lastName)
        ESX.SetPlayerData("dateofbirth", data.dateOfBirth)
        ESX.SetPlayerData("sex", data.sex)
        ESX.SetPlayerData("height", data.height)
    end)
end)

AddEventHandler("esx:loadingScreenOff", function()
    loadingScreenFinished = true
end)

xLib.nui.register("ready", function()
    ready = true
    return 1
end)

function setGuiState(state)
        xLib.nui.focus(state, state)
        guiEnabled = state

        if state then
            SetTimecycleModifier(timecycleModifier)
        else
            ClearTimecycleModifier()
        end

        xLib.nui.send({ type = "enableui", enable = state })
end

RegisterNetEvent("esx_identity:showRegisterIdentity", function()
        TriggerEvent("esx_skin:resetFirstSpawn")
        while not (ready and loadingScreenFinished) do
            print("Waiting for esx_identity NUI..")
            Wait(100)
        end
        if not ESX.PlayerData.dead then
            setGuiState(true)
        end
end)

xLib.nui.register("register", function(data, reply)
        if not guiEnabled then
            return
        end

        xLib.callback("esx_identity:registerIdentity", false, function(callback)
            if not callback then
                return
            end

            ESX.ShowNotification(TranslateCap("thank_you_for_registering"))
            setGuiState(false)

            if not ESX.GetConfig().Multichar then
                TriggerEvent("esx_skin:playerRegistered")
            end
        end, data)
        reply(1)
        return xLib.nui.defer
end)
