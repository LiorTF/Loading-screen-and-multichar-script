--[[
    lt-inventory — server core
    Server-authoritative inventory for QBCore. All mutations happen here; the
    client only sends intents and renders the authoritative state we push back.
]]

local QBCore = exports['qb-core']:GetCoreObject()

LT = LT or {}
LT.Drops = {}            -- [dropId] = { items, coords, created, netHandle }
LT.Open  = {}            -- [src]    = { kind, id }  (currently open secondary container)
local dropCounter = 0

local function dbg(...) if Config.Debug then print('^5[lt-inventory]^7', ...) end end

-- ─────────────────────────────────────────────────────────────────
-- Item registry (prefers QBCore.Shared.Items, falls back to LTExtraItems)
-- ─────────────────────────────────────────────────────────────────
function LT.ItemData(name)
    if not name then return nil end
    local q = QBCore.Shared.Items[name]
    if q then return q end
    local f = LTExtraItems[name]
    if f then
        local copy = {}
        for k, v in pairs(f) do copy[k] = v end
        copy.name = name
        return copy
    end
    return nil
end

-- Build a normalized inventory entry for a slot.
local function makeEntry(name, amount, slot, info)
    local d = LT.ItemData(name); if not d then return nil end
    return {
        name = name, amount = amount, slot = slot, info = info or {},
        label = d.label, description = d.description or '', weight = d.weight or 0,
        type = d.type or 'item', unique = d.unique or false,
        useable = d.useable or false, image = d.image or (name .. '.png'),
        ammotype = d.ammotype
    }
end

function LT.weight(items)
    local w = 0
    for _, it in pairs(items or {}) do
        if it and it.amount then w = w + ((it.weight or 0) * it.amount) end
    end
    return w
end

local function firstEmptySlot(items, maxSlots)
    for i = 1, maxSlots do if not items[i] then return i end end
    return nil
end

local function countFree(items, maxSlots)
    local n = 0
    for i = 1, maxSlots do if not items[i] then n = n + 1 end end
    return n
end

-- ─────────────────────────────────────────────────────────────────
-- Container abstraction — the single place that knows every storage kind
-- getContainer -> { items, maxWeight, slots, kind, id, readonly, shop }
-- ─────────────────────────────────────────────────────────────────
function LT.getContainer(src, invId)
    if invId == 'player' or invId == nil then
        local P = QBCore.Functions.GetPlayer(src); if not P then return nil end
        return { items = P.PlayerData.items, maxWeight = Config.MaxWeight, slots = Config.MaxSlots, kind = 'player', id = src, player = P }
    end
    local kind, id = invId:match('^(%a+):(.+)$')
    if kind == 'ground' then
        local d = LT.Drops[id]; if not d then return nil end
        return { items = d.items, maxWeight = Config.MaxWeight, slots = Config.MaxSlots, kind = 'ground', id = id }
    elseif kind == 'shop' then
        return LT.getShopContainer(id)
    elseif kind == 'otherplayer' then
        local P = QBCore.Functions.GetPlayer(tonumber(id)); if not P then return nil end
        return { items = P.PlayerData.items, maxWeight = Config.MaxWeight, slots = Config.MaxSlots, kind = 'otherplayer', id = tonumber(id), player = P }
    else
        return LT.getStorageContainer(kind, id) -- stash / trunk / glovebox (containers.lua)
    end
end

-- Persist a container after mutation.
function LT.saveContainer(c)
    if not c then return end
    if c.kind == 'player' or c.kind == 'otherplayer' then
        if c.player then
            c.player.Functions.SetPlayerData('items', c.items)
            if LT.persistPlayer then LT.persistPlayer(c.player) end
        end
    elseif c.kind == 'ground' then
        -- kept in memory; nothing to persist
    else
        LT.persistStorage(c) -- stash/trunk/glovebox -> DB (containers.lua)
    end
end

-- Push authoritative state to a player's UI.
function LT.pushInventory(src)
    local c = LT.getContainer(src, 'player'); if not c then return end
    TriggerClientEvent('lt-inventory:client:setPlayer', src, {
        items = c.items, maxWeight = c.maxWeight, slots = c.slots,
        weight = LT.weight(c.items)
    })
end

local function serializeContainer(c, label)
    return {
        kind = c.kind, id = tostring(c.id), label = label or c.label,
        items = c.items, maxWeight = c.maxWeight, slots = c.slots,
        weight = LT.weight(c.items), readonly = c.readonly or false, shop = c.shop or false
    }
end
LT.serialize = serializeContainer

-- ─────────────────────────────────────────────────────────────────
-- Core add / remove (used by exports and by move logic)
-- ─────────────────────────────────────────────────────────────────
function LT.canCarry(items, maxWeight, itemName, amount)
    local d = LT.ItemData(itemName); if not d then return false end
    return (LT.weight(items) + (d.weight or 0) * amount) <= maxWeight
end

-- Add `amount` of `name` into a raw items table (respects unique/stack/weight/slots).
local function addToItems(items, maxSlots, maxWeight, name, amount, info, preferSlot)
    local d = LT.ItemData(name); if not d then return false end
    amount = math.floor(tonumber(amount) or 0); if amount <= 0 then return false end
    if (LT.weight(items) + (d.weight or 0) * amount) > maxWeight then return false end

    if d.unique or (info and next(info) ~= nil) then
        -- unique / metadata items: one per slot
        if countFree(items, maxSlots) < amount and not preferSlot then return false end
        for _ = 1, amount do
            local slot = (preferSlot and not items[preferSlot]) and preferSlot or firstEmptySlot(items, maxSlots)
            preferSlot = nil
            if not slot then return false end
            -- fresh copy of info per unit so metadata isn't shared by reference
            local infoCopy = info and json.decode(json.encode(info)) or {}
            items[slot] = makeEntry(name, 1, slot, infoCopy)
        end
        return true
    end

    -- stackable
    if preferSlot and items[preferSlot] and items[preferSlot].name == name then
        items[preferSlot].amount = items[preferSlot].amount + amount
        return true
    end
    for i = 1, maxSlots do
        if items[i] and items[i].name == name and not items[i].unique then
            items[i].amount = items[i].amount + amount
            return true
        end
    end
    local slot = preferSlot and not items[preferSlot] and preferSlot or firstEmptySlot(items, maxSlots)
    if not slot then return false end
    items[slot] = makeEntry(name, amount, slot, info)
    return true
end

local function removeFromItems(items, maxSlots, name, amount, slot)
    amount = math.floor(tonumber(amount) or 0); if amount <= 0 then return false end
    if slot and items[slot] and items[slot].name == name then
        if items[slot].amount > amount then
            items[slot].amount = items[slot].amount - amount
        elseif items[slot].amount == amount then
            items[slot] = nil
        else
            return false
        end
        return true
    end
    -- no slot: remove across stacks
    local total = 0
    for i = 1, maxSlots do if items[i] and items[i].name == name then total = total + items[i].amount end end
    if total < amount then return false end
    local left = amount
    for i = 1, maxSlots do
        if left <= 0 then break end
        if items[i] and items[i].name == name then
            if items[i].amount > left then items[i].amount = items[i].amount - left; left = 0
            else left = left - items[i].amount; items[i] = nil end
        end
    end
    return true
end

-- ─────────────────────────────────────────────────────────────────
-- Item box notification helper
-- ─────────────────────────────────────────────────────────────────
function LT.notify(src, name, amount, added)
    local d = LT.ItemData(name); if not d then return end
    TriggerClientEvent('lt-inventory:client:itemBox', src, {
        label = d.label, image = d.image or (name .. '.png'), amount = amount, added = added
    })
end

-- ─────────────────────────────────────────────────────────────────
-- EXPORTS  (QBCore-inventory compatible surface)
-- ─────────────────────────────────────────────────────────────────
function LT.AddItem(src, name, amount, slot, info)
    local P = QBCore.Functions.GetPlayer(src); if not P then return false end
    local ok = addToItems(P.PlayerData.items, Config.MaxSlots, Config.MaxWeight, name, amount, info, slot)
    if ok then
        P.Functions.SetPlayerData('items', P.PlayerData.items)
        P.Functions.Save()
        LT.notify(src, name, amount, true)
        LT.pushInventory(src)
    end
    return ok
end

function LT.RemoveItem(src, name, amount, slot)
    local P = QBCore.Functions.GetPlayer(src); if not P then return false end
    local ok = removeFromItems(P.PlayerData.items, Config.MaxSlots, name, amount, slot)
    if ok then
        P.Functions.SetPlayerData('items', P.PlayerData.items)
        P.Functions.Save()
        LT.notify(src, name, amount, false)
        LT.pushInventory(src)
    end
    return ok
end

function LT.GetItemByName(src, name)
    local P = QBCore.Functions.GetPlayer(src); if not P then return nil end
    for i = 1, Config.MaxSlots do if P.PlayerData.items[i] and P.PlayerData.items[i].name == name then return P.PlayerData.items[i] end end
    return nil
end

function LT.GetItemBySlot(src, slot)
    local P = QBCore.Functions.GetPlayer(src); if not P then return nil end
    return P.PlayerData.items[slot]
end

function LT.GetItemCount(src, name)
    local P = QBCore.Functions.GetPlayer(src); if not P then return 0 end
    local n = 0
    for i = 1, Config.MaxSlots do if P.PlayerData.items[i] and P.PlayerData.items[i].name == name then n = n + P.PlayerData.items[i].amount end end
    return n
end

function LT.HasItem(src, items, amount)
    amount = amount or 1
    local need = {}
    if type(items) == 'table' then
        if items[1] then for _, n in ipairs(items) do need[n] = amount end
        else for n, a in pairs(items) do need[n] = a end end
    else need[items] = amount end
    for n, a in pairs(need) do if LT.GetItemCount(src, n) < a then return false end end
    return true
end

function LT.ClearInventory(src)
    local P = QBCore.Functions.GetPlayer(src); if not P then return end
    P.Functions.SetPlayerData('items', {})
    P.Functions.Save(); LT.pushInventory(src)
end

function LT.SetInventory(src, items)
    local P = QBCore.Functions.GetPlayer(src); if not P then return end
    P.Functions.SetPlayerData('items', items or {})
    P.Functions.Save(); LT.pushInventory(src)
end

function LT.GetItemsByName(src, name)
    local P = QBCore.Functions.GetPlayer(src); if not P then return {} end
    local out = {}
    for i = 1, Config.MaxSlots do if P.PlayerData.items[i] and P.PlayerData.items[i].name == name then out[#out + 1] = P.PlayerData.items[i] end end
    return out
end

function LT.GetSlotsByItem(src, name)
    local P = QBCore.Functions.GetPlayer(src); if not P then return {} end
    local out = {}
    for i = 1, Config.MaxSlots do if P.PlayerData.items[i] and P.PlayerData.items[i].name == name then out[#out + 1] = i end end
    return out
end

function LT.GetFreeSlot(src)
    local P = QBCore.Functions.GetPlayer(src); if not P then return nil end
    return firstEmptySlot(P.PlayerData.items, Config.MaxSlots)
end

function LT.CanAddItem(src, name, amount)
    local P = QBCore.Functions.GetPlayer(src); if not P then return false end
    if not LT.canCarry(P.PlayerData.items, Config.MaxWeight, name, amount or 1) then return false end
    local d = LT.ItemData(name); if not d then return false end
    if (d.unique or false) and countFree(P.PlayerData.items, Config.MaxSlots) < (amount or 1) then return false end
    return true
end

function LT.GetInventory(src)
    local P = QBCore.Functions.GetPlayer(src); if not P then return {} end
    return P.PlayerData.items
end

function LT.CloseInventory(src)
    TriggerClientEvent('lt-inventory:client:forceClose', src)
    local pc = LT.getContainer(src, 'player'); if pc then LT.saveContainer(pc) end
    LT.Open[src] = nil
end

function LT.UseItem(src, item)
    if not item then return end
    if QBCore.Functions.UseItem then QBCore.Functions.UseItem(src, item)
    else
        local cb = QBCore.Functions.CanUseItem and QBCore.Functions.CanUseItem(item.name)
        if type(cb) == 'table' and cb.func then cb.func(src, item)
        elseif type(cb) == 'function' then cb(src, item) end
    end
end

-- ─────────────────────────────────────────────────────────────────
-- MODERN qb-core lifecycle: qb-core calls these on the inventory resource
-- during player login / save / logout. Without them, logins crash.
-- ─────────────────────────────────────────────────────────────────

-- Write a player's items straight to the players.inventory column (light).
function LT.persistPlayer(P)
    if not P or not P.PlayerData or not P.PlayerData.citizenid then return end
    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?',
        { json.encode(P.PlayerData.items or {}), P.PlayerData.citizenid })
end

-- Read + normalize a character's inventory from the DB. qb-core assigns the
-- returned table to PlayerData.items on login.
function LT.LoadInventory(source, citizenid)
    local raw = MySQL.scalar.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local items = {}
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for k, v in pairs(decoded) do
                if v and v.name then
                    local slot = tonumber(v.slot) or tonumber(k)
                    local d = LT.ItemData(v.name)
                    if d and slot then
                        items[slot] = {
                            name = v.name, amount = v.amount or 1, slot = slot, info = v.info or {},
                            label = d.label, description = d.description or '', weight = d.weight or 0,
                            type = d.type or 'item', unique = d.unique or false,
                            useable = d.useable or false, image = d.image or (v.name .. '.png'),
                            ammotype = d.ammotype, created = v.created
                        }
                    end
                end
            end
        end
    end
    return items
end

-- Persist a player's inventory. Online: (source, false). Offline: (PlayerData, true).
function LT.SaveInventory(arg, offline)
    local items, citizenid
    if offline then
        local pd = arg
        if type(pd) ~= 'table' then return end
        pd = pd.PlayerData or pd
        items = pd.items or {}
        citizenid = pd.citizenid
    else
        local P = QBCore.Functions.GetPlayer(arg)
        if not P then return end
        items = P.PlayerData.items or {}
        citizenid = P.PlayerData.citizenid
    end
    if not citizenid then return end
    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(items), citizenid })
end

-- Usable items (kept locally so we work whether or not qb-core stores them).
LT.Usables = LT.Usables or {}
function LT.CreateUsableItem(name, data)
    LT.Usables[name] = data
    if QBCore.Functions.CreateUseableItem then QBCore.Functions.CreateUseableItem(name, data) end
end
function LT.GetUsableItem(name)
    if LT.Usables[name] ~= nil then return LT.Usables[name] end
    if QBCore.Functions.CanUseItem then return QBCore.Functions.CanUseItem(name) end
    return nil
end
function LT.UseItem(source, item)
    if not item then return end
    local data = LT.GetUsableItem(item.name)
    if type(data) == 'table' and data.func then data.func(source, item)
    elseif type(data) == 'function' then data(source, item)
    elseif QBCore.Functions.UseItem then QBCore.Functions.UseItem(source, item) end
end

-- Set arbitrary metadata on an item (some scripts rely on this).
function LT.SetItemData(source, itemName, key, val)
    local P = QBCore.Functions.GetPlayer(source); if not P then return false end
    for i = 1, Config.MaxSlots do
        local it = P.PlayerData.items[i]
        if it and it.name == itemName then
            it[key] = val
            P.Functions.SetPlayerData('items', P.PlayerData.items)
            LT.persistPlayer(P); LT.pushInventory(source)
            return true
        end
    end
    return false
end

-- Register the exports (qb-inventory-compatible surface).
exports('LoadInventory',  function(source, citizenid) return LT.LoadInventory(source, citizenid) end)
exports('SaveInventory',  function(arg, offline) return LT.SaveInventory(arg, offline) end)
exports('GetUsableItem',  function(name) return LT.GetUsableItem(name) end)
exports('UseItem',        function(source, item) return LT.UseItem(source, item) end)
exports('SetItemData',    function(source, name, key, val) return LT.SetItemData(source, name, key, val) end)
exports('AddItem',        function(src, ...) return LT.AddItem(src, ...) end)
exports('RemoveItem',     function(src, ...) return LT.RemoveItem(src, ...) end)
exports('GetItemByName',  function(src, ...) return LT.GetItemByName(src, ...) end)
exports('GetItemsByName', function(src, ...) return LT.GetItemsByName(src, ...) end)
exports('GetItemBySlot',  function(src, ...) return LT.GetItemBySlot(src, ...) end)
exports('GetItemCount',   function(src, ...) return LT.GetItemCount(src, ...) end)
exports('GetSlotsByItem', function(src, ...) return LT.GetSlotsByItem(src, ...) end)
exports('GetFreeSlot',    function(src) return LT.GetFreeSlot(src) end)
exports('CanAddItem',     function(src, name, amount) return LT.CanAddItem(src, name, amount) end)
exports('GetInventory',   function(src) return LT.GetInventory(src) end)
exports('HasItem',        function(src, ...) return LT.HasItem(src, ...) end)
exports('ClearInventory', function(src) return LT.ClearInventory(src) end)
exports('SetInventory',   function(src, items) return LT.SetInventory(src, items) end)
exports('CloseInventory', function(src) return LT.CloseInventory(src) end)
exports('CreateUsableItem', function(name, cb) return LT.CreateUsableItem(name, cb) end)

-- ─────────────────────────────────────────────────────────────────
-- MOVE  (the heart of drag & drop, works across any two containers)
-- ─────────────────────────────────────────────────────────────────
local function accessAllowed(src, invId)
    if invId == 'player' then return true end
    local open = LT.Open[src]
    if not open then return false end
    return (open.kind .. ':' .. tostring(open.id)) == invId
end

RegisterNetEvent('lt-inventory:server:move', function(data)
    local src = source
    local fromInv, toInv = data.fromInv, data.toInv
    local fromSlot, toSlot = tonumber(data.fromSlot), tonumber(data.toSlot)
    local amount = tonumber(data.amount)

    -- Security: a player may only touch 'player' and their currently-open container.
    if not accessAllowed(src, fromInv) or not accessAllowed(src, toInv) then
        LT.pushInventory(src); return
    end

    local from = LT.getContainer(src, fromInv)
    local to   = LT.getContainer(src, toInv)
    if not from or not to then LT.pushInventory(src); return end

    local srcItem = from.items[fromSlot]
    if not srcItem then LT.refresh(src); return end
    amount = math.min(amount or srcItem.amount, srcItem.amount)
    if amount <= 0 then LT.refresh(src); return end

    -- Shops: taking from a shop = purchase path (handled separately). Block direct move out.
    if from.shop then LT.refresh(src); return end

    local dest = to.items[toSlot]
    local d = LT.ItemData(srcItem.name)

    -- Weight check on destination (only if moving to a different container)
    if toInv ~= fromInv then
        if (LT.weight(to.items) + (srcItem.weight or 0) * amount) > to.maxWeight then
            TriggerClientEvent('lt-inventory:client:notifyText', src, 'Too heavy to carry.')
            LT.refresh(src); return
        end
    end

    if not dest then
        -- place into empty slot
        if toSlot < 1 or toSlot > to.slots then LT.refresh(src); return end
        if srcItem.amount > amount then
            srcItem.amount = srcItem.amount - amount
            to.items[toSlot] = makeEntry(srcItem.name, amount, toSlot, srcItem.info)
        else
            from.items[fromSlot] = nil
            srcItem.slot = toSlot
            to.items[toSlot] = srcItem
        end
    elseif dest.name == srcItem.name and not dest.unique and not d.unique then
        -- stack
        dest.amount = dest.amount + amount
        if srcItem.amount > amount then srcItem.amount = srcItem.amount - amount
        else from.items[fromSlot] = nil end
    else
        -- swap (only full-stack swaps)
        if amount ~= srcItem.amount then LT.refresh(src); return end
        dest.slot = fromSlot; srcItem.slot = toSlot
        from.items[fromSlot] = dest
        to.items[toSlot] = srcItem
    end

    LT.saveContainer(from); LT.saveContainer(to)
    LT.refresh(src)
end)

-- Push both the player inventory and any open secondary container.
function LT.refresh(src)
    LT.pushInventory(src)
    local open = LT.Open[src]
    if open then
        local c = LT.getContainer(src, open.kind .. ':' .. tostring(open.id))
        if c then TriggerClientEvent('lt-inventory:client:setSecondary', src, serializeContainer(c, open.label)) end
    end
end

-- ─────────────────────────────────────────────────────────────────
-- USE
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-inventory:server:use', function(slot)
    local src = source
    local P = QBCore.Functions.GetPlayer(src); if not P then return end
    local item = P.PlayerData.items[tonumber(slot)]
    if not item then return end
    local d = LT.ItemData(item.name); if not d then return end
    if not d.useable then return end
    LT.UseItem(src, item)
end)

-- ─────────────────────────────────────────────────────────────────
-- GIVE
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-inventory:server:give', function(data)
    local src = source
    local targetId = tonumber(data.targetId)
    local slot = tonumber(data.slot)
    local amount = tonumber(data.amount) or 1
    local P = QBCore.Functions.GetPlayer(src)
    local T = QBCore.Functions.GetPlayer(targetId)
    if not P or not T then return end
    if src == targetId then return end

    -- range check
    local ap, bp = GetEntityCoords(GetPlayerPed(src)), GetEntityCoords(GetPlayerPed(targetId))
    if #(ap - bp) > (Config.GiveRange + 1.0) then
        TriggerClientEvent('lt-inventory:client:notifyText', src, 'Player is too far away.'); return
    end

    local item = P.PlayerData.items[slot]
    if not item or item.amount < amount then return end
    if not LT.canCarry(T.PlayerData.items, Config.MaxWeight, item.name, amount) then
        TriggerClientEvent('lt-inventory:client:notifyText', src, 'They cannot carry that.'); return
    end

    if not removeFromItems(P.PlayerData.items, Config.MaxSlots, item.name, amount, slot) then return end
    addToItems(T.PlayerData.items, Config.MaxSlots, Config.MaxWeight, item.name, amount, item.info)
    P.Functions.SetPlayerData('items', P.PlayerData.items); P.Functions.Save()
    T.Functions.SetPlayerData('items', T.PlayerData.items); T.Functions.Save()

    LT.notify(src, item.name, amount, false)
    LT.notify(targetId, item.name, amount, true)
    LT.pushInventory(src); LT.pushInventory(targetId)
end)

-- ─────────────────────────────────────────────────────────────────
-- DROP  (create a ground drop)
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-inventory:server:drop', function(data)
    local src = source
    local slot = tonumber(data.slot)
    local amount = tonumber(data.amount) or 1
    local P = QBCore.Functions.GetPlayer(src); if not P then return end
    local item = P.PlayerData.items[slot]
    if not item or item.amount < amount then return end

    if not removeFromItems(P.PlayerData.items, Config.MaxSlots, item.name, amount, slot) then return end
    P.Functions.SetPlayerData('items', P.PlayerData.items); P.Functions.Save()

    dropCounter = dropCounter + 1
    local dropId = tostring(dropCounter)
    local coords = data.coords or GetEntityCoords(GetPlayerPed(src))
    LT.Drops[dropId] = {
        items = { [1] = makeEntry(item.name, amount, 1, item.info) },
        coords = { x = coords.x, y = coords.y, z = coords.z },
        created = os.time()
    }
    TriggerClientEvent('lt-inventory:client:spawnDrop', -1, dropId, LT.Drops[dropId].coords)
    LT.notify(src, item.name, amount, false)
    LT.pushInventory(src)
end)

-- Client requests to open a nearby drop.
QBCore.Functions.CreateCallback('lt-inventory:server:openDrop', function(src, cb, dropId)
    local d = LT.Drops[dropId]; if not d then return cb(false) end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local dc = vector3(d.coords.x, d.coords.y, d.coords.z)
    if #(pc - dc) > (Config.DropRange + 1.5) then return cb(false) end
    LT.Open[src] = { kind = 'ground', id = dropId, label = 'Ground' }
    local c = LT.getContainer(src, 'ground:' .. dropId)
    cb(serializeContainer(c, 'Ground'))
end)

-- Expire empty / old drops.
CreateThread(function()
    while true do
        Wait(30000)
        for id, d in pairs(LT.Drops) do
            local empty = true
            for _, it in pairs(d.items) do if it then empty = false break end end
            local expired = Config.DropExpire > 0 and (os.time() - d.created) > (Config.DropExpire * 60)
            if empty or expired then
                LT.Drops[id] = nil
                TriggerClientEvent('lt-inventory:client:removeDrop', -1, id)
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────
-- CLOSE  (persist current container, clear open state)
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-inventory:server:close', function()
    local src = source
    local open = LT.Open[src]
    if open then
        local c = LT.getContainer(src, open.kind .. ':' .. tostring(open.id))
        if c then LT.saveContainer(c) end
        LT.Open[src] = nil
    end
    local pc = LT.getContainer(src, 'player'); if pc then LT.saveContainer(pc) end
end)

AddEventHandler('playerDropped', function() LT.Open[source] = nil end)

-- Send item/rarity metadata to a joining client so the UI can render labels
-- and rings without a round-trip per item.
-- Current player inventory (for opening self / hotbar peek). Does not alter
-- any open secondary container.
QBCore.Functions.CreateCallback('lt-inventory:server:getState', function(src, cb)
    local c = LT.getContainer(src, 'player')
    if not c then return cb(false) end
    cb({ player = { items = c.items, maxWeight = c.maxWeight, slots = c.slots, weight = LT.weight(c.items) } })
end)

QBCore.Functions.CreateCallback('lt-inventory:server:bootData', function(src, cb)
    cb({
        brand = Config.Brand,
        maxWeight = Config.MaxWeight, slots = Config.MaxSlots, hotbar = Config.HotbarSlots,
        imagePath = Config.ImagePath, rarity = Config.Rarity, sounds = Config.UiSounds
    })
end)
