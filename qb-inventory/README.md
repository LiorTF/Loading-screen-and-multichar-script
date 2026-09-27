<div align="center">

# LIOR TOOLS — Inventory

Cinematic monochrome inventory for **QBCore**. Same look and rules as the
Lior Tools start-screen suite. Server-authoritative, drag & drop, stashes,
trunk/glovebox, shops and ground drops.

</div>

---

## ✨ Features

- **Drag & drop** move / stack / **shift-drag split** across any two containers.
- **Right-click menu**: Use · Split · Give · Drop (Buy in shops).
- **Double-click** to use (or buy in a shop).
- **Hotbar** (slots 1–5) with number keys, plus a **peek** bar (`Z`).
- **Weight + slots** enforced **server-side** — every move is validated, no dupes.
- **Containers**: player, ground drops, **stash**, **trunk**, **glovebox**, **shops**.
- **Rarity rings**, hover tooltips, item-box notifications, subtle UI sfx.
- **Item images** from `html/images/` with an automatic monogram fallback, so
  it never looks broken even before you add art.
- Uses your server's `QBCore.Shared.Items`; ships fallback defs for the demo.

---

## 📦 Requirements

`qb-core` · `oxmysql`

## 🚀 Installation

```cfg
ensure oxmysql
ensure qb-core
ensure qb-inventory
```

- Tables `lt_inventory_stashes` and `lt_inventory_vehicles` are created on start.
- **This IS your `qb-inventory`.** The folder must be named `qb-inventory`
  because qb-core and scripts like qb-radio call `exports['qb-inventory']` by
  that exact name. **Delete/replace your stock `qb-inventory`** with this folder
  and keep a single `ensure qb-inventory` line. The UI stays Lior Tools branded.
- It exposes the standard qb-inventory export surface (client **and** server:
  `HasItem`, `AddItem`, `RemoveItem`, `GetItemByName`, `GetItemsByName`,
  `GetItemBySlot`, `GetItemCount`, `GetSlotsByItem`, `GetFreeSlot`, `CanAddItem`,
  `GetInventory`, `SetInventory`, `ClearInventory`, `CreateUsableItem`,
  `CloseInventory`, `UseItem`, `OpenShop`, `OpenStash`, `OpenInventory`), so
  qb-core, qb-radio and other scripts keep working unchanged.

### Item images
Drop your PNGs into `lt-inventory/html/images/` named to match each item's
`image` field (e.g. `water_bottle.png`). Missing images fall back to an
elegant monogram tile automatically. Point `Config.ImagePath` elsewhere if you
keep images in another resource.

---

## ⌨️ Default controls

| Key | Action |
|-----|--------|
| `TAB` | Open / close inventory |
| `1`–`5` | Use hotbar slot |
| `Z` | Peek hotbar |
| `/trunk`, `/glovebox` | Open nearest vehicle storage |

All rebindable in FiveM's keybind settings or via `config.lua`.

---

## 🔌 Exports (server)

```lua
local inv = exports['qb-inventory']

inv:AddItem(src, name, amount, slot, info)   -- returns bool
inv:RemoveItem(src, name, amount, slot)      -- returns bool
inv:HasItem(src, name|table, amount)         -- returns bool
inv:GetItemByName(src, name)
inv:GetItemBySlot(src, slot)
inv:GetItemCount(src, name)
inv:SetInventory(src, items)
inv:ClearInventory(src)
inv:CreateUsableItem(name, function(source, item) end)

-- Containers
inv:OpenShop(src, 'convenience')
inv:OpenStash(src, 'stash_id', slots, maxWeight, 'Label')
inv:RegisterStash('stash_id', slots, maxWeight, 'Label')
inv:OpenInventory(src, 'stash'|'trunk'|'glovebox', id, 'Label')
```

## 🔌 Exports (client)

```lua
exports['qb-inventory']:OpenStash('personal_'..citizenid, 50, 100000, 'Personal Stash')
exports['qb-inventory']:OpenShop('ammunation')
exports['qb-inventory']:IsOpen()   -- bool
```

Register a usable item exactly like qb:
```lua
exports['qb-inventory']:CreateUsableItem('bandage', function(source, item)
    -- heal logic…
    exports['qb-inventory']:RemoveItem(source, 'bandage', 1, item.slot)
end)
```

---

## 🛒 Shops

Defined in `config.lua` → `Config.Shops`. Open one from anywhere:
```lua
exports['qb-inventory']:OpenShop('convenience')  -- client
```

## 🗄️ Database

```sql
CREATE TABLE IF NOT EXISTS `lt_inventory_stashes` ( `stash` VARCHAR(120) PRIMARY KEY, `items` LONGTEXT );
CREATE TABLE IF NOT EXISTS `lt_inventory_vehicles` ( `plate` VARCHAR(20), `type` VARCHAR(12), `items` LONGTEXT, PRIMARY KEY(`plate`,`type`) );
```
Player inventory persists through QBCore's `players.inventory`.

---

## ⚠️ Scope (v1)

Covers the full everyday loop: carry, move, split, use, give, drop, stash,
vehicle storage and shops, server-authoritative. Not included yet: weapon
attachments/durability, crafting, and out-of-the-box `qb-target`/zone wiring
(use the exports above from your target script). These are easy to layer on.

---

<div align="center">Made by <b>Lior Tools</b></div>
