-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Resource-local server modules share the registration cache.
IdentityModules = {
    state = { playerIdentity = {}, alreadyRegistered = {} },
}
