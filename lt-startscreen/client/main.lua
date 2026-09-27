--[[
    lt-startscreen — client orchestrator
    Owns the state machine that carries the player, uninterrupted, from the
    loading screen into character selection, into the spawn selector, and
    finally into the world. No black flashes, no dead air.
]]

local State = {
    screen = 'boot',           -- boot -> multichar -> spawn -> ingame
    activeChar = nil,          -- citizenid currently selected
    isNew = false
}
_G.LT = State

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- One-time payload the UI needs to theme + populate everything.
local function brandPayload()
    return {
        brand   = Config.Brand,
        maxSlots = Config.Multichar.maxSlots,
        showDisconnect = Config.Multichar.showDisconnect,
        nationalities  = Config.Multichar.nationalities,
        portraits = Config.Multichar.portraits,
        spawns  = Config.Spawn.locations,
        enableLastLocation = Config.Spawn.enableLastLocation
    }
end

-- ─────────────────────────────────────────────────────────────────
-- Push branding/config into the loading screen ASAP so config.lua is the
-- single source of truth (no need to edit the HTML).
-- ─────────────────────────────────────────────────────────────────
CreateThread(function()
    local cfg = {
        action = 'ltcfg',
        cfg = {
            brand = {
                name        = Config.Brand.name,
                tagline     = Config.Brand.tagline,
                strapline   = Config.Brand.strapline,
                footerLeft  = Config.Brand.footerLeft,
                footerRight = Config.Brand.footerRight,
                online      = Config.Brand.online
            },
            loading = {
                background  = Config.Loading.background,
                tipRotateMs = Config.Loading.tipRotateMs,
                showPercent = Config.Loading.showPercent,
                tips        = Config.Loading.tips,
                steps       = Config.Loading.steps,
                flavor      = Config.Loading.flavor
            }
        }
    }
    -- Send a few times early on to beat any frame-init race.
    for _ = 1, 5 do
        SendLoadingScreenMessage(json.encode(cfg))
        Wait(200)
    end
end)

-- ─────────────────────────────────────────────────────────────────
-- BOOT: take over as soon as the session is live, before anything else
-- can spawn the player.
-- ─────────────────────────────────────────────────────────────────
CreateThread(function()
    -- Make sure nothing else auto-spawns us.
    exports.spawnmanager:setAutoSpawn(false)

    while not NetworkIsSessionStarted() do Wait(50) end
    -- Give qb-core a beat to finish its client init.
    while not (Bridge.Core() and LocalPlayer.state) do Wait(50) end
    Wait(250)

    DoScreenFadeOut(0)
    Utils.prepPlayerForMenu()
    Utils.setupCamera()

    OpenMultichar()
end)

-- ─────────────────────────────────────────────────────────────────
-- MULTICHAR
-- ─────────────────────────────────────────────────────────────────
function OpenMultichar()
    State.screen = 'multichar'
    QBCore = Bridge.Core()

    QBCore.Functions.TriggerCallback('lt-startscreen:server:getCharacters', function(result)
        send('init', brandPayload())
        send('show', {
            screen = 'multichar',
            chars  = result.chars or {},
            slots  = result.slots or Config.Multichar.maxSlots
        })
        SetNuiFocus(true, true)

        -- Hand off from the loading screen -> our menu with zero flash.
        if Config.KeepLoadscreenUntilUI then
            Wait(50)
            ShutdownLoadingScreenNui()
        end
    end)
end

-- Called by server once a character is logged in (existing OR new).
RegisterNetEvent('lt-startscreen:client:characterLoaded', function(payload)
    State.activeChar = payload.citizenid
    State.isNew = payload.isNew

    -- New character? Optionally kick off the appearance/clothing editor first.
    if payload.isNew and Config.Multichar.onCreateEvent then
        -- The editor runs "behind" our black screen; when it finishes the
        -- flow continues to spawn selection. We fire it and move on.
        TriggerEvent(Config.Multichar.onCreateEvent, payload.gender)
    end

    OpenSpawn(payload.position)
end)

RegisterNetEvent('lt-startscreen:client:createFailed', function(msg)
    send('toast', { type = 'error', message = msg or 'Something went wrong.' })
end)

RegisterNetEvent('lt-startscreen:client:characterDeleted', function(citizenid)
    -- Refresh the list after a delete.
    QBCore.Functions.TriggerCallback('lt-startscreen:server:getCharacters', function(result)
        send('refresh', { chars = result.chars or {}, slots = result.slots or Config.Multichar.maxSlots })
        send('toast', { type = 'success', message = 'Character deleted.' })
    end)
end)

-- ─────────────────────────────────────────────────────────────────
-- SPAWN
-- ─────────────────────────────────────────────────────────────────
function OpenSpawn(lastPosition)
    State.screen = 'spawn'
    send('show', {
        screen = 'spawn',
        lastPosition = lastPosition,
        enableLastLocation = Config.Spawn.enableLastLocation
    })
    -- focus already held from multichar
end

-- ─────────────────────────────────────────────────────────────────
-- NUI CALLBACKS
-- ─────────────────────────────────────────────────────────────────
RegisterNUICallback('selectCharacter', function(data, cb)
    if data and data.citizenid then
        TriggerServerEvent('lt-startscreen:server:selectCharacter', data.citizenid)
    end
    cb('ok')
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('lt-startscreen:server:createCharacter', data)
    cb('ok')
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    if data and data.citizenid then
        TriggerServerEvent('lt-startscreen:server:deleteCharacter', data.citizenid)
    end
    cb('ok')
end)

RegisterNUICallback('confirmSpawn', function(data, cb)
    cb('ok')
    FinalizeSpawn(data)
end)

-- Disconnect is hidden by default (Config.Multichar.showDisconnect = false).
-- Only honored if the buyer explicitly enables it.
RegisterNUICallback('disconnect', function(_, cb)
    if Config.Multichar.showDisconnect then
        TriggerServerEvent('lt-startscreen:server:playerDisconnect')
    end
    cb('ok')
end)

-- Small UX callbacks (hover sounds handled in JS; this just lets JS ping us).
RegisterNUICallback('ping', function(_, cb) cb('ok') end)
