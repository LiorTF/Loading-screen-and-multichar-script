<div align="center">

# LIOR TOOLS — Roleplay Suite

**Loading Screen · Multicharacter · Spawn Selector · Inventory**
Built for **QBCore**. One cohesive look, zero external dependencies at runtime.

</div>

> This package ships **two resources** that share the exact same Lior Tools
> theme, fonts and conventions:
>
> | Resource | What it does | Docs |
> |----------|--------------|------|
> | **`lt-startscreen`** | Loading screen + Multicharacter + Spawn selector | *(below)* |
> | **`lt-inventory`** | Full cinematic inventory (grid, hotbar, stash, trunk, shops, drops) | [`lt-inventory/README.md`](lt-inventory/README.md) |
>
> They work independently — run one or both. Ensure order:
> `oxmysql` → `qb-core` → `lt-startscreen` → `lt-inventory`.

---

<div align="center">

## lt-startscreen

**Cinematic Loading Screen · Multicharacter · Spawn Selector**

</div>

---

`lt-startscreen` carries the player from the second they connect all the way
into the world without a single black flash or a moment of dead air:

1. **Loading Screen** — a cinematic, photographic Los Santos skyline with a
   slow Ken-Burns drift, drifting bokeh, film grain, live progress and a
   synced step checklist. **No music.** Pure motion.
2. **Multicharacter** — up to **3** characters, portrait cards, create &
   delete flows. **No disconnect button** (toggle in config).
3. **Spawn Selector** — six photographic locations + *Last Location*, a live
   info panel and a real city map, then a smooth cinematic hand-off into the
   world.

Everything is driven from **`config.lua`** — you never touch the HTML/JS to
rebrand it.

---

## ✨ Features

- **One cohesive design language** across all three screens (monochrome,
  glassmorphism, wide-tracked type).
- **Self-hosted fonts** (Oswald / Sora / Great Vibes) — works even if the
  server/client can't reach Google Fonts.
- **Self-hosted imagery** — real photographic backgrounds, location tiles,
  portraits and a city map are shipped in `assets/`. Swap any of them freely.
- **Config-first branding** — name, tagline, straplines, signature, accent
  colour, tips, steps, spawns, nationalities, portraits.
- **Non-invasive database** — a tiny `lt_characters_meta` side-table stores
  *created / last-played* timestamps. Your `players` table is never altered,
  and pre-existing characters self-heal on first view.
- **Server-authoritative** — slot cap, ownership checks and validation are all
  enforced server-side.
- **Runtime config push** — the loading screen is themed from `config.lua`
  via `SendLoadingScreenMessage`, so there's a single source of truth.

---

## 📦 Requirements

| Dependency | Notes |
|-----------|-------|
| [`qb-core`](https://github.com/qbcore-framework/qb-core) | Required |
| [`oxmysql`](https://github.com/overextended/oxmysql) | Required |

> The resource is standalone otherwise — no NUI framework, no build step.

---

## 🚀 Installation

1. Drop the `lt-startscreen` folder into your `resources/` (e.g.
   `resources/[lior]/lt-startscreen`).
2. In your `server.cfg`, **after** `qb-core` and `oxmysql`:
   ```cfg
   ensure oxmysql
   ensure qb-core
   ensure lt-startscreen
   ```
3. **Disable the default spawn/character flow** so it doesn't fight this one:
   ```cfg
   # remove or comment these out
   # ensure qb-multicharacter
   # ensure qb-spawn
   ```
4. Restart the server. The `lt_characters_meta` table is created
   automatically on first start.

That's it. Connect and you'll go: **loading → character select → spawn → world.**

---

## 🎨 Rebranding (the important part)

Open **`config.lua`**:

```lua
Config.Brand = {
    name        = 'LIOR TOOLS',                 -- big wordmark + corners
    tagline     = 'PREMIUM ROLEPLAY EXPERIENCE',
    strapline   = { 'REAL PEOPLE', 'REAL STORIES', 'YOUR CITY' },
    signature   = 'Lior Tools',                 -- cursive signature
    signatureSub= 'ROLEPLAY',
    accent      = '#ffffff',
    online      = '#38d66b',
    -- ...
}
```

- **Logo:** replace `ui/assets/logo.png` and `loadscreen/assets/logo.png`
  (white transparent mark) and `*/assets/icon.png` (tab icon).
- **Background:** replace `ui/assets/bg.jpg` and `loadscreen/assets/bg.jpg`
  with any 16:9 still. Prefer a video? Set
  `Config.Loading.background = 'video'` and drop `loadscreen/assets/bg.mp4`.
- **Location photos:** `ui/assets/loc/<id>.jpg` (match the `id` in
  `Config.Spawn.locations`, or set a per-location `image = 'file.jpg'`).
- **Portraits:** `ui/assets/portraits/` + `Config.Multichar.portraits`.
  If a character has no portrait, an elegant monogram avatar is used.

---

## ⚙️ Key config options

```lua
Config.Multichar.maxSlots       = 3       -- character cap (UI adapts)
Config.Multichar.showDisconnect = false   -- keep the disconnect button hidden
Config.Multichar.onCreateEvent  = 'qb-clothes:client:CreateFirstCharacter'
                                          -- your appearance editor (or false)
Config.Spawn.enableLastLocation = true    -- offer "Last Location" card
Config.Spawn.locations          = { ... } -- cards, coords, info, blurbs
```

### Hooking your appearance / clothing editor
After a **new** character is created, `Config.Multichar.onCreateEvent` is
triggered client-side. Point it at your creator of choice
(`illenium-appearance`, `qb-clothing`, `fivem-appearance`, …) or set it to
`false` to skip.

### Events you can hook
| Event | Side | When |
|-------|------|------|
| `lt-startscreen:client:spawned` | client | player is fully in the world (`citizenid`) |
| `lt-startscreen:server:playerFullyLoaded` | server | same moment, server-side |

---

## 🗄️ Database

Created automatically:

```sql
CREATE TABLE IF NOT EXISTS `lt_characters_meta` (
    `citizenid`  VARCHAR(50) NOT NULL,
    `license`    VARCHAR(60) DEFAULT NULL,
    `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_played` TIMESTAMP  NULL DEFAULT NULL,
    PRIMARY KEY (`citizenid`)
);
```

Character deletion cleans the standard qb tables (guarded — missing tables are
skipped). Override the list via `Config.Multichar.deleteFromTables`.

---

## 🧪 Previewing the UI in a browser

The NUI and loading screen render standalone for design tweaks:

- `loadscreen/index.html` — plays a fake progress loop.
- `ui/index.html` — seeds demo characters (multichar).
- `ui/index.html#spawn` — previews the spawn selector.

---

## 📁 Structure

```
lt-startscreen/
├── fxmanifest.lua
├── config.lua                 ← everything you edit
├── bridge/loader.lua          ← QBCore bridge (swap here to port frameworks)
├── client/                    ← flow, camera, spawn hand-off
├── server/main.lua            ← list / create / select / delete
├── loadscreen/                ← loading screen (html/css/js/fonts/assets)
└── ui/                        ← multichar + spawn NUI (html/css/js/fonts/assets)
```

---

<div align="center">
Made by <b>Lior Tools</b> · Same city. New stories.
</div>
