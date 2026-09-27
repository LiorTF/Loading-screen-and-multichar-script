--[[
    ╦  ╦╔═╗╦═╗  ╔╦╗╔═╗╔═╗╦  ╔═╗
    ║  ║║ ║╠╦╝   ║ ║ ║║ ║║  ╚═╗
    ╩═╝╩╚═╝╩╚═   ╩ ╚═╝╚═╝╩═╝╚═╝
    LIOR TOOLS — START SCREEN SUITE
    Loading Screen · Multicharacter · Spawn Selector
    Framework: QBCore

    Everything the buyer needs to rebrand and tune lives here.
    You should never have to touch the HTML/JS to make it yours.
]]

Config = {}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  BRANDING                                                     ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Brand = {
    -- The name shown in the corners / signature. This replaces "LOS SANTOS".
    name        = 'LIOR TOOLS',
    -- Sub-line under the big wordmark (loading screen).
    tagline     = 'PREMIUM ROLEPLAY EXPERIENCE',
    -- Small strapline (top-left of loading screen).
    strapline   = { 'REAL PEOPLE', 'REAL STORIES', 'YOUR CITY' },
    -- Signature wordmark shown bottom-left (like the "Los Santos" script text).
    signature   = 'Lior Tools',
    signatureSub= 'ROLEPLAY',
    -- Footer line, bottom-right of the loading screen.
    footerLeft  = 'CONNECTING YOU TO',
    footerRight = 'A BETTER ROLEPLAY EXPERIENCE',
    -- Accent color used across all three UIs. Keep it subtle for the
    -- monochrome look, or push a brand color for a signature vibe.
    accent      = '#ffffff',
    -- A secondary glow used on hovers / highlights.
    glow        = 'rgba(255,255,255,0.14)',
    -- Status dot color for "online / active".
    online      = '#38d66b'
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  LOADING SCREEN                                               ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Loading = {
    -- Background style:
    --   'image' -> loadscreen/assets/bg.jpg  (shipped cinematic skyline, Ken-Burns motion)
    --   'video' -> loadscreen/assets/bg.mp4  (drop in your own looping clip)
    -- Swap bg.jpg for any 16:9 still to rebrand the whole screen.
    background      = 'image',       -- 'image' | 'video'

    -- Rotating quick tips (kept fresh so players read while they wait).
    tipRotateMs     = 6500,
    tips = {
        { title = 'QUICK TIP',      body = 'Use /help in game if you need assistance. Our staff are always here to help!' },
        { title = 'STAY IN CHARACTER', body = 'Immersion is everything. Speak and act as your character would.' },
        { title = 'NEW HERE?',      body = 'Press F1 for the interaction menu once you spawn into the city.' },
        { title = 'REPORT ISSUES',  body = 'Use /report to reach an admin instantly — no need to leave the server.' },
        { title = 'DRIVE SAFE',     body = 'Value your life. Reckless driving breaks immersion for everyone.' },
        { title = 'MAKE FRIENDS',   body = 'The best stories come from the people you meet. Say hi.' }
    },

    -- The animated "steps" checklist on the right of the loading screen.
    -- These are cosmetic-but-synced: they tick off as real load progress
    -- streams in, so it always feels honest and alive.
    steps = {
        'INITIALIZING CLIENT',
        'LOADING RESOURCES',
        'CONNECTING TO SERVER',
        'PREPARING YOUR CHARACTER',
        'ALMOST THERE...'
    },

    -- Bottom-right rotating "same city / new stories" style flavor text.
    flavor          = { 'SAME CITY', 'NEW STORIES' },

    -- Show the live progress percentage next to the bar.
    showPercent     = true
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  MULTICHARACTER                                               ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Multichar = {
    -- Hard cap on characters. The whole UI adapts to this number.
    maxSlots        = 3,

    -- NO disconnect button (by request). Leave false to keep it hidden.
    showDisconnect  = false,

    -- Cinematic in-world camera used behind the menu. Purely visual — the
    -- player is invisible & frozen here until they choose a spawn.
    camera = {
        cam    = vector3(-1035.5, -2732.2, 30.0),  -- camera position
        point  = vector3(-1039.5, -2735.0, 15.0),  -- look-at point
        fov    = 42.0
    },

    -- Coords the (invisible) player is parked at during selection.
    hiddenCoords    = vector4(-1041.0, -2745.0, 21.3, 330.0),

    -- After creating a NEW character, fire this so your appearance/clothing
    -- editor opens. Set to false to skip. The event is a CLIENT event and
    -- receives (citizenid). Wire it to illenium-appearance / qb-clothing /
    -- fivem-appearance / your creator of choice.
    onCreateEvent   = 'qb-clothes:client:CreateFirstCharacter',

    -- Nationalities offered in the create form.
    nationalities = {
        'American', 'Mexican', 'Canadian', 'British', 'Irish', 'Italian',
        'German', 'French', 'Spanish', 'Russian', 'Japanese', 'Korean',
        'Chinese', 'Brazilian', 'Australian', 'Nigerian', 'Other'
    },

    -- Default ped models applied to a freshly created character (before the
    -- clothing editor runs). Just a sensible starting body.
    defaultModel = {
        male   = 'mp_m_freemode_01',
        female = 'mp_f_freemode_01'
    },

    -- Card portraits. The UI picks one by gender (cycled across slots). Drop
    -- your own photos in ui/assets/portraits/ and list them here. If a
    -- character has no portrait, an elegant monogram avatar is used instead.
    portraits = {
        male   = { 'portraits/male_1.jpg', 'portraits/male_2.jpg' },
        female = { 'portraits/female_1.jpg' }
    }
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  SPAWN SELECTOR                                               ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Spawn = {
    -- Offer "Last Location" as the first option when the character has a
    -- saved position. Falls through to the recommended spawn if none.
    enableLastLocation = true,

    -- Fade timings (ms) for the cinematic hand-off into the world.
    fadeOut         = 600,
    fadeIn          = 800,

    -- The selectable spawn points shown as cards. `recommended = true`
    -- highlights one. `image` is a file under ui/assets (optional — a
    -- generated gradient is used if missing).
    locations = {
        {
            id          = 'downtown',
            label       = 'Downtown',
            desc        = 'The heart of the city. Close to everything.',
            icon        = 'city',
            recommended = true,
            coords      = vector4(195.17, -933.77, 30.69, 143.0),
            info        = { safezone = true, vehicle = 'Nearby', jobs = true, popular = 'High' },
            blurb       = 'A great place to start your journey in the city.'
        },
        {
            id          = 'vespucci',
            label       = 'Vespucci Beach',
            desc        = 'Beaches, clubs and good vibes.',
            icon        = 'beach',
            coords      = vector4(-1223.5, -1497.0, 4.35, 130.0),
            info        = { safezone = true, vehicle = 'Nearby', jobs = true, popular = 'High' },
            blurb       = 'Sun, sand and nightlife on the west coast.'
        },
        {
            id          = 'vinewood',
            label       = 'Vinewood Hills',
            desc        = 'Luxury, views and high life.',
            icon        = 'hills',
            coords      = vector4(-174.0, 502.0, 137.42, 340.0),
            info        = { safezone = false, vehicle = 'Nearby', jobs = false, popular = 'Medium' },
            blurb       = 'Live above the city where the elite reside.'
        },
        {
            id          = 'richman',
            label       = 'Richman',
            desc        = 'Quiet, rich and peaceful.',
            icon        = 'home',
            coords      = vector4(-1289.0, 440.0, 97.0, 180.0),
            info        = { safezone = true, vehicle = 'Nearby', jobs = false, popular = 'Low' },
            blurb       = 'A calm, upscale neighborhood to call home.'
        },
        {
            id          = 'airport',
            label       = 'Los Santos International',
            desc        = 'Perfect for pilots and travelers.',
            icon        = 'plane',
            coords      = vector4(-1037.0, -2737.0, 20.17, 240.0),
            info        = { safezone = true, vehicle = 'Nearby', jobs = true, popular = 'Medium' },
            blurb       = 'Wheels up. Your story starts at the gate.'
        },
        {
            id          = 'port',
            label       = 'Port of Los Santos',
            desc        = 'Work, business and opportunities.',
            icon        = 'ship',
            coords      = vector4(1208.0, -3115.0, 5.54, 180.0),
            info        = { safezone = false, vehicle = 'Nearby', jobs = true, popular = 'Medium' },
            blurb       = 'Where the working city never sleeps.'
        }
    }
}

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  ADVANCED                                                     ║
-- ╚══════════════════════════════════════════════════════════════╝
Config.Debug = false            -- verbose prints in F8/console
Config.KeepLoadscreenUntilUI = true -- hand off loadscreen -> menu with no flash
