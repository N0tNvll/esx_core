local function updateHealthAndArmorInMetadata(xPlayer)
    local ped = GetPlayerPed(xPlayer.source)
    xPlayer.setMeta("health", GetEntityHealth(ped))
    xPlayer.setMeta("armor", GetPedArmour(ped))
    xPlayer.setMeta("lastPlaytime", xPlayer.getPlayTime())
end

---@param xPlayer table
---@param cb? function
---@return nil
function Core.SavePlayer(xPlayer, cb)
    if not xPlayer.spawned then
        return cb and cb()
    end

    updateHealthAndArmorInMetadata(xPlayer)
    local parameters <const> = {
        json.encode(xPlayer.getAccounts(true)),
        xPlayer.job.name,
        xPlayer.job.grade,
        xPlayer.group,
        json.encode(xPlayer.getCoords(false, true)),
        json.encode(xPlayer.getInventory(true)),
        json.encode(xPlayer.getLoadout(true)),
        json.encode(xPlayer.getMeta()),
        xPlayer.identifier,
    }

    MySQL.prepare(
        "UPDATE `users` SET `accounts` = ?, `job` = ?, `job_grade` = ?, `group` = ?, `position` = ?, `inventory` = ?, `loadout` = ?, `metadata` = ? WHERE `identifier` = ?",
        parameters,
        function(affectedRows)
            if affectedRows == 1 then
                print(('[^2INFO^7] Saved player ^5"%s^7"'):format(xPlayer.name))
                TriggerEvent("esx:playerSaved", xPlayer.playerId, xPlayer)
            end

            if cb then
                cb()
            end
        end
    )
end

---@param cb? function
---@return nil
function Core.SavePlayers(cb)
    local xPlayers <const> = ESX.Players or {}
    if not next(xPlayers) then
        return cb and cb()
    end

    local startTime <const> = GetGameTimer()
    local parameters = {}

    for _, xPlayer in pairs(xPlayers) do
        if xPlayer.spawned then
            updateHealthAndArmorInMetadata(xPlayer)
            parameters[#parameters + 1] = {
                json.encode(xPlayer.getAccounts(true)),
                xPlayer.job.name,
                xPlayer.job.grade,
                xPlayer.group,
                json.encode(xPlayer.getCoords(false, true)),
                json.encode(xPlayer.getInventory(true)),
                json.encode(xPlayer.getLoadout(true)),
                json.encode(xPlayer.getMeta()),
                xPlayer.identifier,
            }
        end
    end

    if not parameters[1] then
        return cb and cb()
    end

    MySQL.prepare(
        "UPDATE `users` SET `accounts` = ?, `job` = ?, `job_grade` = ?, `group` = ?, `position` = ?, `inventory` = ?, `loadout` = ?, `metadata` = ? WHERE `identifier` = ?",
        parameters,
        function(results)
            if not results then
                if type(cb) == "function" then
                    cb()
                end

                return
            end

            if type(cb) == "function" then
                return cb()
            end

            print(("[^2INFO^7] Saved ^5%s^7 %s over ^5%s^7 ms"):format(#parameters, #parameters > 1 and "players" or "player", GetGameTimer() - startTime))
        end
    )
end
