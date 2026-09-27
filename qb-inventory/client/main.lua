--[[ lt-inventory — client ]]

local QBCore = exports['qb-core']:GetCoreObject()

local BOOT = nil          -- cached boot data (brand, image path, rarity…)
local uiOpen = false
local loggedIn = false
local Drops = {}          -- [id] = { coords, obj }

local function dbg(...) if Config.Debug then print('^5[lt-inventory]^7', ...) end end

-- ─────────────────────────────────────────────────────────────────
-- Boot
-- ─────────────────────────────────────────────────────────────────
CreateThread(function()
    while not QBCore do Wait(100) end
    QBCore.Functions.TriggerCallback('lt-inventory:server:bootData', function(data)
        BOOT = data
        SendNUIMessage({ action = 'boot', data = data })
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() loggedIn = true end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() loggedIn = false end)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state and LocalPlayer.state.isLoggedIn then loggedIn = true end
end)

-- Robust readiness: trust the login flag, the state bag, OR a valid PlayerData.
-- (Covers the case where this resource missed the OnPlayerLoaded event.)
local function isReady()
    if loggedIn then return true end
    if LocalPlayer.state and LocalPlayer.state.isLoggedIn then loggedIn = true; return true end
    local pd = QBCore.Functions.GetPlayerData()
    if pd and pd.citizenid then loggedIn = true; return true end
    return false
end

-- ─────────────────────────────────────────────────────────────────
-- Open / close
-- ─────────────────────────────────────────────────────────────────
local function openSelf()
    if uiOpen then return closeUI() end
    if IsPauseMenuActive() then dbg('open blocked: pause menu'); return end
    if not isReady() then dbg('open blocked: player not loaded yet'); return end
    QBCore.Functions.TriggerCallback('lt-inventory:server:getState', function(state)
        if not state then dbg('open blocked: server returned no state'); return end
        uiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = { player = state.player, secondary = false, boot = BOOT } })
        dbg('inventory opened')
    end)
end

function closeUI()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('lt-inventory:server:close')
end

-- Secondary container opened by the server (stash/trunk/shop/drop).
RegisterNetEvent('lt-inventory:client:openUI', function(payload)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = { player = payload.player, secondary = payload.secondary, boot = BOOT } })
end)

RegisterNetEvent('lt-inventory:client:forceClose', function() closeUI() end)

RegisterNetEvent('lt-inventory:client:setPlayer', function(data)
    SendNUIMessage({ action = 'updatePlayer', data = data })
end)
RegisterNetEvent('lt-inventory:client:setSecondary', function(data)
    SendNUIMessage({ action = 'updateSecondary', data = data })
end)

-- ─────────────────────────────────────────────────────────────────
-- Notifications
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-inventory:client:itemBox', function(data)
    SendNUIMessage({ action = 'itemBox', data = data })
end)
RegisterNetEvent('lt-inventory:client:notifyText', function(text)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(text, 'error')
    else
        SendNUIMessage({ action = 'toast', data = { message = text } })
    end
end)

-- ─────────────────────────────────────────────────────────────────
-- NUI callbacks
-- ─────────────────────────────────────────────────────────────────
RegisterNUICallback('move', function(data, cb) TriggerServerEvent('lt-inventory:server:move', data); cb('ok') end)
RegisterNUICallback('buy',  function(data, cb) TriggerServerEvent('lt-inventory:server:buy', data);  cb('ok') end)

RegisterNUICallback('use', function(data, cb)
    TriggerServerEvent('lt-inventory:server:use', data.slot)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('drop', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('lt-inventory:server:drop', { slot = data.slot, amount = data.amount,
        coords = { x = coords.x, y = coords.y, z = coords.z } })
    cb('ok')
end)

RegisterNUICallback('give', function(data, cb)
    local target = closestPlayer(Config.GiveRange)
    if not target then
        SendNUIMessage({ action = 'toast', data = { message = 'No one nearby.' } })
        return cb('ok')
    end
    TriggerServerEvent('lt-inventory:server:give', { slot = data.slot, amount = data.amount, targetId = target })
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb) closeUI(); cb('ok') end)

-- ─────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────
function closestPlayer(maxDist)
    local me = PlayerId(); local mc = GetEntityCoords(PlayerPedId())
    local best, bestId = (maxDist or 3.0) + 0.5, nil
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local d = #(mc - GetEntityCoords(GetPlayerPed(pid)))
            if d < best then best = d; bestId = GetPlayerServerId(pid) end
        end
    end
    return bestId
end

-- ─────────────────────────────────────────────────────────────────
-- Hotbar (number keys) + peek
-- ─────────────────────────────────────────────────────────────────
local function useHotbar(slot)
    if uiOpen or not loggedIn then return end
    TriggerServerEvent('lt-inventory:server:use', slot)
end

for i = 1, (Config.HotbarSlots or 5) do
    RegisterCommand('lt_hotbar_' .. i, function() useHotbar(i) end, false)
    RegisterKeyMapping('lt_hotbar_' .. i, 'Use hotbar slot ' .. i, 'keyboard', tostring(i))
end

RegisterCommand('lt_hotbar_peek', function()
    if uiOpen or not loggedIn then return end
    QBCore.Functions.TriggerCallback('lt-inventory:server:getState', function(state)
        if state then SendNUIMessage({ action = 'peekHotbar', data = { player = state.player } }) end
    end)
end, false)
RegisterKeyMapping('lt_hotbar_peek', 'Peek hotbar', 'keyboard', Config.HotbarKey or 'Z')

-- ─────────────────────────────────────────────────────────────────
-- Open keybind + commands
-- ─────────────────────────────────────────────────────────────────
RegisterCommand('lt_openinv', openSelf, false)
RegisterKeyMapping('lt_openinv', 'Open inventory', 'keyboard', Config.OpenKey or 'TAB')
RegisterCommand('inventory', openSelf, false)

-- Vehicle storage (simple commands; wire to your target/zones as you like)
local function nearestVehicle()
    local ped = PlayerPedId(); local coords = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = GetClosestVehicle(coords.x, coords.y, coords.z, 4.0, 0, 71) end
    return veh
end

RegisterCommand('trunk', function()
    local veh = nearestVehicle()
    if veh == 0 then return end
    local plate = QBCore.Functions.GetPlate(veh)
    TriggerServerEvent('lt-inventory:server:openTrunk', plate, VehToNet(veh))
end, false)

RegisterCommand('glovebox', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end
    local plate = QBCore.Functions.GetPlate(veh)
    TriggerServerEvent('lt-inventory:server:openGlovebox', plate, VehToNet(veh))
end, false)

-- Exports so other resources can open things.
exports('OpenStash', function(id, slots, maxWeight, label) TriggerServerEvent('lt-inventory:server:openStash', id, slots, maxWeight, label) end)
exports('OpenShop',  function(shop) TriggerServerEvent('lt-inventory:server:openShop', shop) end)
exports('IsOpen',    function() return uiOpen end)
exports('CloseInventory', function() closeUI() end)

-- Generic open used by some scripts: OpenInventory('stash'|'trunk'|'glovebox'|'shop', id, data)
exports('OpenInventory', function(kind, id, data)
    data = data or {}
    if kind == 'stash' then TriggerServerEvent('lt-inventory:server:openStash', id, data.slots, data.maxweight or data.maxWeight, data.label)
    elseif kind == 'shop' then TriggerServerEvent('lt-inventory:server:openShop', id)
    elseif kind == 'trunk' then TriggerServerEvent('lt-inventory:server:openTrunk', id)
    elseif kind == 'glovebox' then TriggerServerEvent('lt-inventory:server:openGlovebox', id) end
end)

-- ─────────────────────────────────────────────────────────────────
-- CLIENT item queries  (qb-core & many scripts call these by name).
-- Reads the local, qb-core-maintained PlayerData.items.
-- ─────────────────────────────────────────────────────────────────
local function localItems()
    local pd = QBCore.Functions.GetPlayerData()
    return (pd and pd.items) or {}
end

local function localCount(name)
    local n = 0
    for _, it in pairs(localItems()) do
        if it and it.name == name then n = n + (it.amount or 0) end
    end
    return n
end

local function clientHasItem(items, amount)
    amount = amount or 1
    local need = {}
    if type(items) == 'table' then
        if items[1] then for _, n in ipairs(items) do need[n] = amount end
        else for n, a in pairs(items) do need[n] = a end end
    else need[items] = amount end
    for n, a in pairs(need) do if localCount(n) < a then return false end end
    return true
end

exports('HasItem', clientHasItem)
exports('GetItemCount', function(name) return localCount(name) end)
exports('GetPlayerItems', function() return localItems() end)
exports('GetItemByName', function(name)
    for _, it in pairs(localItems()) do if it and it.name == name then return it end end
    return nil
end)
exports('GetItemsByName', function(name)
    local out = {}
    for _, it in pairs(localItems()) do if it and it.name == name then out[#out + 1] = it end end
    return out
end)

-- ─────────────────────────────────────────────────────────────────
-- Ground drops (marker + [E] pickup, optional visible prop)
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-inventory:client:spawnDrop', function(id, coords)
    if Drops[id] then return end
    local obj = nil
    if Config.DropObject then
        local model = joaat(Config.DropObject)
        RequestModel(model)
        local t = 0; while not HasModelLoaded(model) and t < 100 do Wait(10); t = t + 1 end
        if HasModelLoaded(model) then
            obj = CreateObject(model, coords.x, coords.y, coords.z - 0.9, false, false, false)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(model)
        end
    end
    Drops[id] = { coords = coords, obj = obj }
end)

RegisterNetEvent('lt-inventory:client:removeDrop', function(id)
    local d = Drops[id]
    if d and d.obj and DoesEntityExist(d.obj) then DeleteObject(d.obj) end
    Drops[id] = nil
end)

CreateThread(function()
    while true do
        local wait = 800
        if loggedIn and not uiOpen then
            local pc = GetEntityCoords(PlayerPedId())
            local nearId, nearDist = nil, 3.0
            for id, d in pairs(Drops) do
                local dc = vector3(d.coords.x, d.coords.y, d.coords.z)
                local dist = #(pc - dc)
                if dist < 12.0 then
                    wait = 0
                    DrawMarker(27, dc.x, dc.y, dc.z - 0.95, 0,0,0, 0,0,0, 0.35,0.35,0.35, 255,255,255,120, false,false,2,false)
                    if dist < nearDist then nearId = id; nearDist = dist end
                end
            end
            if nearId then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Press ~INPUT_PICKUP~ to open the ground stash')
                EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustReleased(0, 38) then -- E
                    QBCore.Functions.TriggerCallback('lt-inventory:server:openDrop', function(container)
                        if container then
                            uiOpen = true; SetNuiFocus(true, true)
                            QBCore.Functions.TriggerCallback('lt-inventory:server:getState', function(state)
                                SendNUIMessage({ action = 'open', data = { player = state.player, secondary = container, boot = BOOT } })
                            end)
                        end
                    end, nearId)
                end
            end
        end
        Wait(wait)
    end
end)

-- Safety: close UI on death / cuff etc.
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' and uiOpen then
        local victim = args[1]
        if victim == PlayerPedId() and IsEntityDead(PlayerPedId()) then closeUI() end
    end
end)
