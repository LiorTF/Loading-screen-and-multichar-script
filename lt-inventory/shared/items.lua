--[[
    Fallback item definitions.

    lt-inventory always prefers your server's QBCore.Shared.Items. These are
    only used to fill gaps so the demo shops / examples work out of the box on
    a fresh install. Add real items to qb-core/shared/items.lua as usual.

    Fields: label, weight (grams), type ('item'|'weapon'), image, unique,
            useable, description
]]

LTExtraItems = {
    water_bottle = { label = 'Water',     weight = 500,  type = 'item', image = 'water_bottle.png', unique = false, useable = true,  description = 'Stay hydrated.' },
    sandwich     = { label = 'Sandwich',  weight = 200,  type = 'item', image = 'sandwich.png',     unique = false, useable = true,  description = 'A quick bite.' },
    bandage      = { label = 'Bandage',   weight = 100,  type = 'item', image = 'bandage.png',      unique = false, useable = true,  description = 'Patch yourself up.' },
    phone        = { label = 'Phone',     weight = 190,  type = 'item', image = 'phone.png',        unique = false, useable = true,  description = 'Stay connected.' },
    lockpick     = { label = 'Lockpick',  weight = 160,  type = 'item', image = 'lockpick.png',     unique = false, useable = true,  description = 'For persuading locks.' },
    armor        = { label = 'Armor',     weight = 3000, type = 'item', image = 'armor.png',        unique = false, useable = true,  description = 'Body armor vest.' },
    radio        = { label = 'Radio',     weight = 1000, type = 'item', image = 'radio.png',        unique = false, useable = true,  description = 'Talk on frequencies.' },
    money        = { label = 'Cash',      weight = 0,    type = 'item', image = 'cash.png',         unique = false, useable = false, description = 'Cold hard cash.' },
    goldbar      = { label = 'Gold Bar',  weight = 7000, type = 'item', image = 'goldbar.png',      unique = false, useable = false, description = 'Shiny and valuable.' },
    diamond      = { label = 'Diamond',   weight = 100,  type = 'item', image = 'diamond.png',      unique = false, useable = false, description = 'A flawless gem.' },
    markedbills  = { label = 'Marked Bills', weight = 100, type = 'item', image = 'markedbills.png', unique = true, useable = false, description = 'Dirty money.' },
    pistol_ammo  = { label = 'Pistol Ammo', weight = 40, type = 'item', image = 'pistol_ammo.png',  unique = false, useable = true,  description = '9mm rounds.' },

    weapon_pistol = { label = 'Pistol', weight = 1000, type = 'weapon', image = 'weapon_pistol.png', unique = true, useable = true, description = 'A reliable sidearm.', ammotype = 'pistol_ammo' }
}
