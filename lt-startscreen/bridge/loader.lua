--[[
    Framework bridge — QBCore.
    Kept in one tiny file so a future port (ESX/standalone) only needs the
    getters below re-implemented. The rest of the resource never calls
    exports['qb-core'] directly.
]]

Bridge = {}

local QBCore = nil

--- Lazily resolve the QBCore core object.
function Bridge.Core()
    if QBCore then return QBCore end
    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok and core then
        QBCore = core
    end
    return QBCore
end

--- Unified debug print.
function Bridge.dbg(...)
    if Config and Config.Debug then
        print('^5[lt-startscreen]^7', ...)
    end
end

-- Resolve once on load so downstream files can assume it's ready.
CreateThread(function()
    local tries = 0
    while not Bridge.Core() and tries < 100 do
        Wait(50)
        tries = tries + 1
    end
    if Bridge.Core() then
        Bridge.dbg('QBCore bridge ready.')
    else
        print('^1[lt-startscreen] Could not resolve qb-core. Is it started before lt-startscreen?^7')
    end
end)
