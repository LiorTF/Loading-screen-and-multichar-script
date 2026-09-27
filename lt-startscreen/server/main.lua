--[[
    lt-startscreen — server
    QBCore character lifecycle: list / create / select / delete.

    We never touch qb-core's `players` schema. A tiny side table
    (`lt_characters_meta`) records created / last-played timestamps so the
    UI can show them, and it self-heals for characters that pre-date install.
]]

local QBCore = Bridge.Core()

-- Tables wiped when a character is deleted. Buyer-overridable via
-- Config.Multichar.deleteFromTables. Each runs guarded — missing tables are
-- silently skipped so this works on any qb schema.
local DEFAULT_DELETE_TABLES = {
    { name = 'players',              column = 'citizenid' },
    { name = 'apartments',           column = 'citizenid' },
    { name = 'bank_accounts',        column = 'id' }, -- shared accounts keyed loosely; guarded
    { name = 'crypto_transactions',  column = 'citizenid' },
    { name = 'phone_invoices',       column = 'citizenid' },
    { name = 'phone_messages',       column = 'citizenid' },
    { name = 'playerskins',          column = 'citizenid' },
    { name = 'player_contacts',      column = 'citizenid' },
    { name = 'player_houses',        column = 'citizenid' },
    { name = 'player_mails',         column = 'citizenid' },
    { name = 'player_outfits',       column = 'citizenid' },
    { name = 'player_vehicles',      column = 'citizenid' }
}

local function getLicense(src)
    if QBCore and QBCore.Functions and QBCore.Functions.GetIdentifier then
        return QBCore.Functions.GetIdentifier(src, 'license')
    end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function safeDecode(v, fallback)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return fallback end
    local ok, res = pcall(json.decode, v)
    if ok and res ~= nil then return res end
    return fallback
end

-- ─────────────────────────────────────────────────────────────────
-- Schema: metadata side-table
-- ─────────────────────────────────────────────────────────────────
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `lt_characters_meta` (
            `citizenid`  VARCHAR(50) NOT NULL,
            `license`    VARCHAR(60) DEFAULT NULL,
            `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `last_played` TIMESTAMP  NULL DEFAULT NULL,
            PRIMARY KEY (`citizenid`),
            KEY `license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    Bridge.dbg('meta table ensured')
end)

local function touchMeta(citizenid, license, isCreate)
    if isCreate then
        MySQL.insert(
            'INSERT INTO lt_characters_meta (citizenid, license, created_at, last_played) VALUES (?, ?, NOW(), NOW()) ' ..
            'ON DUPLICATE KEY UPDATE last_played = NOW()',
            { citizenid, license }
        )
    else
        MySQL.update(
            'INSERT INTO lt_characters_meta (citizenid, license, created_at, last_played) VALUES (?, ?, NOW(), NOW()) ' ..
            'ON DUPLICATE KEY UPDATE last_played = NOW(), license = VALUES(license)',
            { citizenid, license }
        )
    end
end

-- ─────────────────────────────────────────────────────────────────
-- LIST characters
-- ─────────────────────────────────────────────────────────────────
QBCore.Functions.CreateCallback('lt-startscreen:server:getCharacters', function(source, cb)
    local src = source
    local license = getLicense(src)
    if not license then return cb({ slots = Config.Multichar.maxSlots, chars = {} }) end

    local rows = MySQL.query.await(
        'SELECT p.citizenid, p.cid, p.name, p.money, p.charinfo, p.job, p.position, ' ..
        'm.created_at, m.last_played ' ..
        'FROM players p LEFT JOIN lt_characters_meta m ON m.citizenid = p.citizenid ' ..
        'WHERE p.license = ? ORDER BY p.cid ASC',
        { license }
    ) or {}

    local chars = {}
    for _, row in ipairs(rows) do
        local charinfo = safeDecode(row.charinfo, {})
        local money    = safeDecode(row.money, {})
        local job      = safeDecode(row.job, {})
        local pos      = safeDecode(row.position, nil)

        chars[#chars + 1] = {
            citizenid   = row.citizenid,
            slot        = row.cid,
            firstname   = charinfo.firstname or 'Unknown',
            lastname    = charinfo.lastname or '',
            gender      = charinfo.gender,               -- 0 male / 1 female
            nationality = charinfo.nationality or '—',
            dob         = charinfo.birthdate or charinfo.dob or '—',
            phone       = charinfo.phone or '—',
            jobLabel    = (job and job.label) or 'Unemployed',
            jobName     = (job and job.name) or 'unemployed',
            grade       = (job and job.grade and (job.grade.name or job.grade.level)) or nil,
            cash        = money.cash or 0,
            bank        = money.bank or 0,
            createdAt   = row.created_at,                -- may be nil for legacy chars
            lastPlayed  = row.last_played,
            hasPosition = pos ~= nil
        }

        -- Self-heal metadata for characters created before install.
        if not row.created_at then
            MySQL.insert(
                'INSERT IGNORE INTO lt_characters_meta (citizenid, license, created_at, last_played) VALUES (?, ?, NOW(), NULL)',
                { row.citizenid, license }
            )
        end
    end

    cb({ slots = Config.Multichar.maxSlots, chars = chars })
end)

-- ─────────────────────────────────────────────────────────────────
-- SELECT (log in) an existing character
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-startscreen:server:selectCharacter', function(citizenid)
    local src = source
    local license = getLicense(src)
    if not license or not citizenid then return end

    -- Ownership check.
    local owner = MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ?', { citizenid })
    if owner ~= license then
        Bridge.dbg(('select denied: %s does not own %s'):format(license, citizenid))
        return
    end

    local Player = QBCore.Player.Login(src, citizenid)
    if not Player then return end

    touchMeta(citizenid, license, false)

    -- Hand the last saved position back so the spawn selector can offer it.
    local pos = Player.PlayerData.position
    TriggerClientEvent('lt-startscreen:client:characterLoaded', src, {
        citizenid = citizenid,
        isNew     = false,
        position  = pos and { x = pos.x, y = pos.y, z = pos.z, a = pos.a or pos.w or 0.0 } or nil
    })
    Bridge.dbg(('character %s loaded for %s'):format(citizenid, GetPlayerName(src)))
end)

-- ─────────────────────────────────────────────────────────────────
-- CREATE a new character
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-startscreen:server:createCharacter', function(data)
    local src = source
    local license = getLicense(src)
    if not license then return end

    -- Enforce the slot cap server-side (never trust the client).
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE license = ?', { license }) or 0
    if count >= Config.Multichar.maxSlots then
        Bridge.dbg('create denied: slot cap reached for ' .. license)
        TriggerClientEvent('lt-startscreen:client:createFailed', src, 'Character limit reached.')
        return
    end

    -- Basic validation / sanitization.
    local firstname = tostring(data.firstname or ''):gsub('%s+$', ''):gsub('^%s+', '')
    local lastname  = tostring(data.lastname  or ''):gsub('%s+$', ''):gsub('^%s+', '')
    if #firstname < 2 or #lastname < 2 then
        TriggerClientEvent('lt-startscreen:client:createFailed', src, 'Please enter a valid name.')
        return
    end

    local gender = (data.gender == 1 or data.gender == '1' or data.gender == 'female') and 1 or 0

    local newData = {
        cid = count + 1,
        charinfo = {
            firstname   = firstname,
            lastname    = lastname,
            birthdate   = data.dob or '2000-01-01',
            gender      = gender,
            nationality = data.nationality or 'American',
            phone       = nil,
            account     = nil
        }
    }

    local Player = QBCore.Player.Login(src, false, newData)
    if not Player then
        TriggerClientEvent('lt-startscreen:client:createFailed', src, 'Could not create character.')
        return
    end

    local citizenid = Player.PlayerData.citizenid
    touchMeta(citizenid, license, true)
    Player.Functions.Save()

    TriggerClientEvent('lt-startscreen:client:characterLoaded', src, {
        citizenid = citizenid,
        isNew     = true,
        gender    = gender,
        position  = nil
    })
    Bridge.dbg(('character %s CREATED for %s'):format(citizenid, GetPlayerName(src)))
end)

-- ─────────────────────────────────────────────────────────────────
-- DELETE a character
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-startscreen:server:deleteCharacter', function(citizenid)
    local src = source
    local license = getLicense(src)
    if not license or not citizenid then return end

    local owner = MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ?', { citizenid })
    if owner ~= license then
        Bridge.dbg('delete denied: ownership mismatch')
        return
    end

    local tables = (Config.Multichar and Config.Multichar.deleteFromTables) or DEFAULT_DELETE_TABLES
    for _, t in ipairs(tables) do
        local col = t.column or 'citizenid'
        -- Only run on the citizenid column to avoid nuking unrelated rows.
        if col == 'citizenid' then
            pcall(function()
                MySQL.query.await(('DELETE FROM `%s` WHERE `citizenid` = ?'):format(t.name), { citizenid })
            end)
        end
    end
    pcall(function()
        MySQL.query.await('DELETE FROM `lt_characters_meta` WHERE `citizenid` = ?', { citizenid })
    end)

    TriggerClientEvent('lt-startscreen:client:characterDeleted', src, citizenid)
    Bridge.dbg(('character %s DELETED by %s'):format(citizenid, GetPlayerName(src)))
end)

-- ─────────────────────────────────────────────────────────────────
-- Persist the chosen spawn as the player's position (so "Last Location"
-- works next session) and finalize the loaded player.
-- ─────────────────────────────────────────────────────────────────
RegisterNetEvent('lt-startscreen:server:setSpawn', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not coords then return end
    Player.Functions.SetMetaData('lt_lastspawn', coords)
    -- position is saved automatically by QBCore on save; nudge a save.
    Player.Functions.Save()
end)

-- Optional disconnect (hidden by default; enable via Config.Multichar.showDisconnect).
RegisterNetEvent('lt-startscreen:server:playerDisconnect', function()
    local src = source
    if not Config.Multichar.showDisconnect then return end
    DropPlayer(src, 'You left the city.')
end)

-- Fired when the player is fully in the world. Hook other resources here.
RegisterNetEvent('lt-startscreen:server:playerFullyLoaded', function()
    local src = source
    Bridge.dbg(('%s is fully loaded and in the world'):format(GetPlayerName(src) or src))
    -- e.g. TriggerClientEvent('your-hud:client:show', src)
end)
