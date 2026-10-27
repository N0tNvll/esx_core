-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Core.Migrations = Core.Migrations or {}
Core.Migrations['v1.17.1'] = Core.Migrations['v1.17.1'] or {}

-- Independently idempotent: older migration-version flags never skip this check.
Core.Migrations['v1.17.1'].nationality = function()
    return xLib.schema.ensureColumn('users', 'nationality', 'VARCHAR(52) NULL DEFAULT NULL')
end
