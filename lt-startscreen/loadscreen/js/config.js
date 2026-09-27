/* =========================================================
   Loading-screen fallback config.
   The live values come from config.lua (pushed at runtime), so you
   normally only edit config.lua. These defaults are used for
   browser previews and for the split-second before the push arrives.
   ========================================================= */
window.LT_LOAD_DEFAULTS = {
    brand: {
        name: 'LIOR TOOLS',
        tagline: 'PREMIUM ROLEPLAY EXPERIENCE',
        strapline: ['REAL PEOPLE', 'REAL STORIES', 'YOUR CITY'],
        footerLeft: 'CONNECTING YOU TO',
        footerRight: 'A BETTER ROLEPLAY EXPERIENCE',
        online: '#38d66b'
    },
    loading: {
        background: 'generated',
        tipRotateMs: 6500,
        showPercent: true,
        tips: [
            { title: 'QUICK TIP', body: 'Use /help in game if you need assistance. Our staff are always here to help!' },
            { title: 'STAY IN CHARACTER', body: 'Immersion is everything. Speak and act as your character would.' },
            { title: 'NEW HERE?', body: 'Press F1 for the interaction menu once you spawn into the city.' }
        ],
        steps: ['INITIALIZING CLIENT', 'LOADING RESOURCES', 'CONNECTING TO SERVER', 'PREPARING YOUR CHARACTER', 'ALMOST THERE...'],
        flavor: ['SAME CITY', 'NEW STORIES']
    }
};
