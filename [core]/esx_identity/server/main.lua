-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ESXCatalog.awaitReady()

IdentityModules.Lifecycle.RegisterHandlers()

xLib.callback.registerCompat("esx_identity:registerIdentity", IdentityModules.Callback.RegisterIdentity)

IdentityModules.Commands.Register()
IdentityModules.Debugging.Register()
