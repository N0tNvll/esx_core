-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local Database = {}

function Database.DeleteIdentity(xPlayer)
    MySQL.query.await("UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ?, skin = ?, nationality = NULL WHERE identifier = ?", { nil, nil, nil, nil, nil, nil, xPlayer.identifier })

    if Config.FullCharDelete then
        MySQL.update.await("UPDATE addon_account_data SET money = 0 WHERE account_name IN (?) AND owner = ?", { { "bank_savings", "caution" }, xPlayer.identifier })

        MySQL.prepare.await("UPDATE datastore_data SET data = ? WHERE name IN (?) AND owner = ?", { "{}", { "user_ears", "user_glasses", "user_helmet", "user_mask" }, xPlayer.identifier })
    end
end

function Database.SaveIdentity(identifier, identity)
    MySQL.update.await("UPDATE users SET firstname = ?, lastname = ?, dateofbirth = ?, sex = ?, height = ?, nationality = NULLIF(?, '') WHERE identifier = ?", { identity.firstName, identity.lastName, identity.dateOfBirth, identity.sex, identity.height, xLib.nationality.normalize(identity.nationality) or '', identifier })
end

function Database.GetIdentity(identifier, cb)
    return MySQL.single("SELECT firstname, lastname, dateofbirth, sex, height, nationality FROM users WHERE identifier = ?", { identifier }, cb)
end

IdentityModules.Database = Database
