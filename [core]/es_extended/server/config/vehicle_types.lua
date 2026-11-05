-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Complete allowlist of vehicle types supported by your FiveM server build.
-- Add a type with true to enable it; remove it or set false to disable it.
-- This does not add native support to FiveM. Restart es_extended after editing.
-- Remove/update any VehicleTypeOverrides that use a disabled type.
Config.ValidVehicleTypes = {
    automobile = true,
    bike = true,
    boat = true,
    heli = true,
    plane = true,
    submarine = true,
    trailer = true,
    train = true,
}

-- Authoritative model/type mappings from your vehicles.meta files.
-- These override client reports and persisted consensus, and work with no players online.
-- Use model names or numeric hashes. Restart es_extended after editing.
Config.VehicleTypeOverrides = {
    -- adder = 'automobile',
    -- seasparrow = 'heli',
}
