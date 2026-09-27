--[[
    ╦  ╦╔═╗╦═╗  ╔╦╗╔═╗╔═╗╦  ╔═╗
    ║  ║║ ║╠╦╝   ║ ║ ║║ ║║  ╚═╗
    ╩═╝╩╚═╝╩╚═   ╩ ╚═╝╚═╝╩═╝╚═╝
    LIOR TOOLS — INVENTORY  (QBCore)

    Same look, same rules as the start-screen suite. Everything you'd want to
    tune lives here — you should never have to open the HTML/JS to rebrand.
]]

Config = {}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  BRANDING (kept in sync with lt-startscreen)                  ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Brand = {
    name   = 'LIOR TOOLS',
    sub    = 'INVENTORY',
    accent = '#ffffff',
    online = '#38d66b'
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  CORE                                                         ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.MaxWeight   = 120000    -- grams (120.0 kg) — matches QBCore convention
Config.MaxSlots    = 41        -- player inventory slots
Config.HotbarSlots = 5         -- quick-use slots (number keys 1..5)

Config.OpenKey     = 'TAB'     -- open/close inventory
Config.HotbarKey   = 'Z'       -- peek the hotbar without opening the menu

Config.GiveRange   = 3.0       -- max distance to give an item to another player
Config.DropRange   = 2.5       -- max distance to pick a ground drop back up
Config.DropExpire  = 0         -- minutes before a ground drop despawns (0 = never)
Config.DropObject  = 'prop_cs_heist_bag_01' -- prop spawned for visible drops (or false)

-- Item image path (relative to html/). Drop your PNGs into html/images/.
-- If an image is missing, a generic default icon is shown, then a monogram
-- tile — so the UI never looks broken.
Config.ImagePath   = 'images/%s'

-- Items granted ONCE to each newly created character (tracked via metadata,
-- so dropping everything won't re-grant them). Set to {} to disable.
Config.StartingItems = {
    { name = 'phone',        amount = 1 },
    { name = 'water_bottle', amount = 2 },
    { name = 'sandwich',     amount = 1 },
    { name = 'bandage',      amount = 2 }
}

-- Play a subtle click/hover sfx in the UI (bundled-free; uses tiny WebAudio beeps).
Config.UiSounds    = true

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  RARITY (purely cosmetic — colors the slot ring)              ║
-- ║  Map item names (or types) to a tier. Anything unlisted = 1.  ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Rarity = {
    -- tiers: 1 common, 2 uncommon, 3 rare, 4 epic, 5 legendary
    ['weapon']      = 4,   -- matches by item.type == 'weapon'
    ['goldbar']     = 5,
    ['diamond']     = 5,
    ['rolex']       = 4,
    ['markedbills'] = 3,
    ['lockpick']    = 2,
    ['radio']       = 2
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  SHOPS  (open with exports['lt-inventory']:OpenShop(name))    ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Shops = {
    ['convenience'] = {
        label = '24/7 Store',
        items = {
            { name = 'water_bottle', price = 5,  amount = 50 },
            { name = 'sandwich',     price = 8,  amount = 50 },
            { name = 'phone',        price = 250, amount = 10 },
            { name = 'lockpick',     price = 45, amount = 25 },
            { name = 'bandage',      price = 15, amount = 30 }
        }
    },
    ['ammunation'] = {
        label = 'Ammu-Nation',
        items = {
            { name = 'weapon_pistol', price = 2500, amount = 5 },
            { name = 'pistol_ammo',   price = 120,  amount = 100 },
            { name = 'armor',         price = 500,  amount = 20 }
        }
    }
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  VEHICLE STORAGE                                              ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Trunk = {
    maxWeight = 120000, slots = 35,
    byClass = {            -- optional per-class overrides (GetVehicleClass)
        [0] = { maxWeight = 38000,  slots = 15 }, -- compacts
        [1] = { maxWeight = 50000,  slots = 20 }, -- sedans
        [2] = { maxWeight = 75000,  slots = 25 }, -- SUVs
        [8] = { maxWeight = 15000,  slots = 8  }, -- motorcycles
        [12]= { maxWeight = 240000, slots = 45 }  -- vans
    }
}
Config.Glovebox = { maxWeight = 10000, slots = 5 }

Config.Debug = false
