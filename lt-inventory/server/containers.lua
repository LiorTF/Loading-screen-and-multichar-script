--[[
    lt-inventory — containers
    Stashes, vehicle trunk/glovebox and shops, with DB persistence and the
    open/buy flows. Relies on helpers defined in server/main.lua (LT.*).
]]

local QBCore = exports['qb-core']:GetCoreObject()

LT = LT or {}
LT.Stashes  = {}          -- [id] = { items, maxWeight, slots, label }
LT.Vehicles = {}          -- [plate..':'..type] = { items, maxWeight, slots }
LT.RegisteredStashes = {} -- [id] = { slots, maxWeight, label }

-- ─────────────────────────────────────────────────────────────────
-- Schema
-- ─────────────────────────────────────────────────────────────────
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `lt_inventory_stashes` (
            `stash` VARCHAR(120) NOT NULL,
            `items` LONGTEXT DEFAULT NULL,
            PRIMARY KEY (`stash`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `lt_inventory_vehicles` (
            `plate` VARCHAR(20) NOT NULL,
            `type`  VARCHAR(12) NOT NULL,
            `items` LONGTEXT DEFAULT NULL,
            PRIMARY KEY (`plate`, `type`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

local function decodeItems(raw)
    if not raw or raw == '' then return {} end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' then
        -- normalize numeric keys
        local out = {}
        for k, v in pairs(t) do out[tonumber(k) or k] = v end
        return out
    end
    return {}
end

-- ─────────────────────────────────────────────────────────────────
-- SHOP container (read-only pseudo inventory)
-- ─────────────────────────────────────────────────────────────────
function LT.getShopContainer(name)
    local shop = Config.Shops[name]; if not shop then return nil end
    local items = {}
    for i, entry in ipairs(shop.items) do
        local d = LT.ItemData(entry.name)
        if d then
            items[i] = {
                name = entry.name, amount = entry.amount or 1, slot = i, info = {},
                label = d.label, description = d.description or '', weight = d.weight or 0,
                type = d.type or 'item', unique = d.unique or false, useable = d.useable or false,
                image = d.image or (entry.name .. '.png'), price = entry.price or 0
            }
        end
    end
    return { items = items, maxWeight = 999999999, slots = #shop.items, kind = 'shop', id = name,
             label = shop.label or 'Shop', shop = true, readonly = true }
end

-- ─────────────────────────────────────────────────────────────────
-- STORAGE container (stash / trunk / glovebox) — loaded lazily
-- ─────────────────────────────────────────────────────────────────
function LT.getStorageContainer(kind, id)
    if kind == 'stash' then
        local reg = LT.RegisteredStashes[id] or { slots = 50, maxWeight = 100000, label = 'Stash' }
        if not LT.Stashes[id] then
            local raw = MySQL.scalar.await('SELECT items FROM lt_inventory_stashes WHERE stash = ?', { id })
            LT.Stashes[id] = { items = decodeItems(raw), maxWeight = reg.maxWeight, slots = reg.slots, label = reg.label }
        end
        local s = LT.Stashes[id]
        return { items = s.items, maxWeight = s.maxWeight, slots = s.slots, kind = 'stash', id = id, label = s.label }

    elseif kind == 'trunk' or kind == 'glovebox' then
        local key = id .. ':' .. kind
        local def = (kind == 'glovebox') and Config.Glovebox or Config.Trunk
        if not LT.Vehicles[key] then
            local raw = MySQL.scalar.await('SELECT items FROM lt_inventory_vehicles WHERE plate = ? AND type = ?', { id, kind })
            LT.Vehicles[key] = { items = decodeItems(raw), maxWeight = def.maxWeight, slots = def.slots }
        end
        local v = LT.Vehicles[key]
        return { items = v.items, maxWeight = v.maxWeight, slots = v.slots, kind = kind, id = id,
                 label = (kind == 'glovebox') and 'Glovebox' or 'Trunk' }
    end
    return nil
end

function LT.persistStorage(c)
    if not c then return end
    local raw = json.encode(c.items or {})
    if c.kind == 'stash' then
        MySQL.insert('INSERT INTO lt_inventory_stashes (stash, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { c.id, raw, raw })
    elseif c.kind == 'trunk' or c.kind == 'glovebox' then
        MySQL.insert('INSERT INTO lt_inventory_vehicles (plate, type, items) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE items = ?', { c.id, c.kind, raw, raw })
    end
end

-- ─────────────────────────────────────────────────────────────────
-- OPEN helpers
-- ─────────────────────────────────────────────────────────────────
local function openSecondary(src, kind, id, label)
    LT.Open[src] = { kind = kind, id = id, label = label }
    local c = LT.getContainer(src, kind .. ':' .. tostring(id))
    if not c then return end
    local player = LT.getContainer(src, 'player')
    TriggerClientEvent('lt-inventory:client:openUI', src, {
        player = { items = player.items, maxWeight = player.maxWeight, slots = player.slots, weight = LT.weight(player.items) },
        secondary = LT.serialize(c, label)
    })
end
LT.openSecondary = openSecondary

-- Trust-but-verify trunk/glovebox: client provides plate + net id; verify distance.
local function vehicleClose(src, netId)
    if not netId then return true end -- best-effort
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return true end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local vc = GetEntityCoords(veh)
    return #(pc - vc) < 5.0
end

RegisterNetEvent('lt-inventory:server:openStash', function(id, slots, maxWeight, label)
    local src = source
    if id and (slots or maxWeight) then
        LT.RegisteredStashes[id] = { slots = slots or 50, maxWeight = maxWeight or 100000, label = label or 'Stash' }
    end
    openSecondary(src, 'stash', id, (LT.RegisteredStashes[id] and LT.RegisteredStashes[id].label) or 'Stash')
end)

RegisterNetEvent('lt-inventory:server:openTrunk', function(plate, netId)
    local src = source
    if not plate then return end
    if not vehicleClose(src, netId) then return end
    openSecondary(src, 'trunk', plate:gsub('%s+', ''), 'Trunk')
end)

RegisterNetEvent('lt-inventory:server:openGlovebox', function(plate, netId)
    local src = source
    if not plate then return end
    if not vehicleClose(src, netId) then return end
    openSecondary(src, 'glovebox', plate:gsub('%s+', ''), 'Glovebox')
end)

RegisterNetEvent('lt-inventory:server:openShop', function(shop)
    local src = source
    if not Config.Shops[shop] then return end
    openSecondary(src, 'shop', shop, Config.Shops[shop].label)
end)

-- ─────────────────────────────────────────────────────────────────
-- BUY  (from a shop)
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-inventory:server:buy', function(data)
    local src = source
    local open = LT.Open[src]
    if not open or open.kind ~= 'shop' then return end
    local shop = Config.Shops[open.id]; if not shop then return end
    local entry = shop.items[tonumber(data.slot)]; if not entry then return end
    local amount = math.max(1, math.floor(tonumber(data.amount) or 1))
    local price = (entry.price or 0) * amount

    local P = QBCore.Functions.GetPlayer(src); if not P then return end
    if not LT.canCarry(P.PlayerData.items, Config.MaxWeight, entry.name, amount) then
        TriggerClientEvent('lt-inventory:client:notifyText', src, 'Too heavy to carry.'); return
    end

    -- pay: cash first, then bank
    local paid = false
    if P.Functions.GetMoney('cash') >= price then
        paid = P.Functions.RemoveMoney('cash', price, 'lt-inventory-shop')
    elseif P.Functions.GetMoney('bank') >= price then
        paid = P.Functions.RemoveMoney('bank', price, 'lt-inventory-shop')
    end
    if not paid then
        TriggerClientEvent('lt-inventory:client:notifyText', src, 'Not enough money.'); return
    end

    LT.AddItem(src, entry.name, amount)
    TriggerClientEvent('lt-inventory:client:notifyText', src, ('Bought %dx %s'):format(amount, LT.ItemData(entry.name).label))
    LT.refresh(src)
end)

-- ─────────────────────────────────────────────────────────────────
-- Public open exports
-- ─────────────────────────────────────────────────────────────────
exports('OpenShop',  function(src, shop) if Config.Shops[shop] then openSecondary(src, 'shop', shop, Config.Shops[shop].label) end end)
exports('OpenStash', function(src, id, slots, maxWeight, label)
    LT.RegisteredStashes[id] = { slots = slots or 50, maxWeight = maxWeight or 100000, label = label or 'Stash' }
    openSecondary(src, 'stash', id, label or 'Stash')
end)
exports('RegisterStash', function(id, slots, maxWeight, label)
    LT.RegisteredStashes[id] = { slots = slots or 50, maxWeight = maxWeight or 100000, label = label or 'Stash' }
end)
exports('OpenInventory', function(src, kind, id, label) openSecondary(src, kind, id, label) end)

-- Persist all open containers on shutdown.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id, s in pairs(LT.Stashes) do LT.persistStorage({ kind = 'stash', id = id, items = s.items }) end
    for key, v in pairs(LT.Vehicles) do
        local plate, kind = key:match('^(.+):(%a+)$')
        if plate then LT.persistStorage({ kind = kind, id = plate, items = v.items }) end
    end
end)
