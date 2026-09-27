/* =========================================================
   LIOR TOOLS — Multicharacter + Spawn Selector logic
   ========================================================= */
(function () {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'lt-startscreen';
    const $  = (s, r = document) => r.querySelector(s);
    const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

    const S = {
        cfg: null,
        chars: [],
        slots: 3,
        spawns: [],
        selectedSpawn: null,
        lastPosition: null,
        enableLast: true,
        pendingDelete: null,
        createGender: 0,
        busy: false
    };

    // ---- NUI bridge -------------------------------------------------
    async function post(name, data = {}) {
        try {
            const r = await fetch(`https://${RES}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data)
            });
            return await r.json().catch(() => ({}));
        } catch (e) { return {}; }
    }

    // ---- Helpers ----------------------------------------------------
    function parseDate(ts) {
        if (!ts) return null;
        if (ts instanceof Date) return ts;
        let s = String(ts).trim().replace(' ', 'T');
        if (!/[zZ]|[+-]\d\d:?\d\d$/.test(s)) s += 'Z';
        const d = new Date(s);
        return isNaN(d.getTime()) ? null : d;
    }
    function fmtDate(ts) {
        const d = parseDate(ts); if (!d) return '—';
        const p = n => String(n).padStart(2, '0');
        return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()}`;
    }
    function timeAgo(ts) {
        const d = parseDate(ts); if (!d) return 'Never';
        let s = Math.max(0, (Date.now() - d.getTime()) / 1000);
        if (s < 60) return 'Just now';
        const m = s / 60; if (m < 60) return `${Math.floor(m)} min ago`;
        const h = m / 60; if (h < 24) return `${Math.floor(h)} hour${Math.floor(h) > 1 ? 's' : ''} ago`;
        const dd = h / 24; if (dd < 30) return `${Math.floor(dd)} day${Math.floor(dd) > 1 ? 's' : ''} ago`;
        const mo = dd / 30; if (mo < 12) return `${Math.floor(mo)} month${Math.floor(mo) > 1 ? 's' : ''} ago`;
        return `${Math.floor(mo / 12)} year${Math.floor(mo / 12) > 1 ? 's' : ''} ago`;
    }
    function hash(str) { let h = 0; for (let i = 0; i < str.length; i++) h = (h * 31 + str.charCodeAt(i)) | 0; return Math.abs(h); }
    function grayGradient(seed) {
        const a = 20 + (seed % 130);                 // gradient angle
        const l1 = 10 + (seed % 14);                 // dark stop
        const l2 = 26 + ((seed >> 3) % 20);          // lighter stop
        return `linear-gradient(${a}deg, rgb(${l1},${l1+1},${l1+3}) 0%, rgb(${l2},${l2+2},${l2+5}) 55%, rgb(${l1+4},${l1+5},${l1+8}) 100%)`;
    }
    function portraitFor(c, idx) {
        const P = (S.cfg && S.cfg.portraits) || {};
        const female = (c.gender === 1 || c.gender === '1' || c.gender === 'female');
        const list = female ? (P.female || []) : (P.male || []);
        if (!list.length) return null;
        return 'assets/' + list[idx % list.length];
    }
    function roleIcon(job) {
        const j = (job || '').toLowerCase();
        if (/police|sheriff|leo|cop|state/.test(j)) return '<path d="M10 2l6 2v5c0 4-2.7 7-6 9-3.3-2-6-5-6-9V4z"/><path d="M7.5 9.5l1.8 1.8L13 7.5"/>';
        if (/ambulance|ems|doctor|medic|ambo/.test(j)) return '<circle cx="10" cy="10" r="7"/><path d="M10 6v8M6 10h8"/>';
        if (/mechanic|tow/.test(j)) return '<path d="M13 5a3 3 0 0 0-4 4l-5 5 2 2 5-5a3 3 0 0 0 4-4l-2 2-2-2z"/>';
        if (/taxi|cab|bus|trucker|driver/.test(j)) return '<path d="M3 12l1.5-4h11L17 12v3h-2M3 15v-3M6 15a1.5 1.5 0 1 0 3 0M13 15a1.5 1.5 0 1 0 3 0"/>';
        return '<circle cx="10" cy="7" r="3.2"/><path d="M4 17a6 6 0 0 1 12 0"/>';
    }
    const CAL = '<rect x="3" y="4" width="14" height="13" rx="2"/><path d="M3 8h14M7 2v4M13 2v4"/>';
    const CLK = '<circle cx="10" cy="10" r="7"/><path d="M10 6v4l3 2"/>';

    // ---- Toasts -----------------------------------------------------
    function toast(type, message) {
        const el = document.createElement('div');
        el.className = `toast ${type || ''}`;
        el.innerHTML = `<span class="bar"></span><span>${message}</span>`;
        $('#toasts').appendChild(el);
        setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 400); }, 3200);
    }

    // ---- Branding ---------------------------------------------------
    function applyBrand() {
        const b = (S.cfg && S.cfg.brand) || {};
        if (b.name) $$('[data-brand-name]').forEach(e => e.textContent = b.name);
        if (b.signature) $$('[data-sig-name]').forEach(e => e.textContent = b.signature);
        if (b.signatureSub) $$('[data-sig-sub]').forEach(e => e.textContent = b.signatureSub);
        if (b.accent) document.documentElement.style.setProperty('--ink-accent', b.accent);
        if (b.online) document.documentElement.style.setProperty('--online', b.online);
        $('#guideMax').textContent = S.slots;
        // Disconnect visibility
        const dc = $('[data-nav="disconnect"]');
        if (dc) dc.classList.toggle('hidden', !(S.cfg && S.cfg.showDisconnect));
        // Nationalities
        const sel = $('#natSelect');
        if (sel && S.cfg && S.cfg.nationalities) {
            sel.innerHTML = S.cfg.nationalities.map(n => `<option value="${n}">${n}</option>`).join('');
        }
    }

    // ---- Multichar rendering ---------------------------------------
    function mostRecentId() {
        let best = null, bestT = -1;
        S.chars.forEach(c => { const d = parseDate(c.lastPlayed); const t = d ? d.getTime() : 0; if (t > bestT) { bestT = t; best = c.citizenid; } });
        return best;
    }

    function renderChars() {
        const host = $('#charCards');
        host.innerHTML = '';
        const recent = mostRecentId();

        for (let i = 0; i < S.slots; i++) {
            const c = S.chars[i];
            if (c) {
                host.appendChild(charCard(c, c.citizenid === recent, i));
            } else {
                host.appendChild(emptyCard(i));
            }
        }
    }

    function charCard(c, isRecent, idx) {
        const el = document.createElement('div');
        el.className = 'char-card';
        el.style.animationDelay = (idx * 0.08) + 's';
        el.dataset.cid = c.citizenid;
        const seed = hash(c.citizenid + c.firstname + c.lastname);
        const initials = ((c.firstname[0] || '') + (c.lastname[0] || '')).toUpperCase();
        const badge = isRecent
            ? `<div class="cc-badge"><span class="dot"></span>ACTIVE</div>`
            : `<div class="cc-badge off"><span class="dot"></span>SAVED</div>`;

        const portrait = portraitFor(c, idx);
        const portraitLayer = portrait
            ? `<div class="grad" style="background:${grayGradient(seed)}"></div><img class="cc-photo" src="${portrait}" onerror="this.remove()" />`
            : `<div class="grad" style="background:${grayGradient(seed)}"></div><div class="mono">${initials}</div>`;

        el.innerHTML = `
            <div class="cc-portrait">
                ${portraitLayer}
                <div class="wm"></div>
            </div>
            ${badge}
            <div class="cc-menu" title="Delete character">
                <svg viewBox="0 0 20 20"><path d="M4 6h12M8 6V4h4v2M6 6l1 10h6l1-10"/></svg>
            </div>
            <div class="cc-body">
                <div class="cc-name">${c.firstname} ${c.lastname}</div>
                <div class="cc-meta">
                    <div class="cc-line"><svg viewBox="0 0 20 20">${roleIcon(c.jobName)}</svg>${c.jobLabel || 'Civilian'}</div>
                    <div class="cc-line"><svg viewBox="0 0 20 20">${CAL}</svg>Created ${fmtDate(c.createdAt)}</div>
                    <div class="cc-line"><svg viewBox="0 0 20 20">${CLK}</svg>Last played ${timeAgo(c.lastPlayed)}</div>
                </div>
                <button class="cc-play"><svg viewBox="0 0 20 20"><path d="M6 4l10 6-10 6z"/></svg>Play</button>
            </div>`;

        el.addEventListener('click', () => selectCard(el));
        el.querySelector('.cc-menu').addEventListener('click', (e) => { e.stopPropagation(); openDelete(c); });
        el.querySelector('.cc-play').addEventListener('click', (e) => { e.stopPropagation(); playCharacter(c, el); });
        return el;
    }

    function emptyCard(idx) {
        const el = document.createElement('div');
        el.className = 'slot-empty';
        el.style.animationDelay = (idx * 0.08) + 's';
        el.innerHTML = `
            <div class="slot-plus"><svg viewBox="0 0 20 20"><path d="M10 4v12M4 10h12"/></svg></div>
            <div class="slot-label">Create Character</div>
            <div class="slot-hint">Empty slot ${idx + 1} of ${S.slots}</div>`;
        el.addEventListener('click', () => openCreate());
        return el;
    }

    function selectCard(el) {
        $$('.char-card').forEach(c => c.classList.remove('selected'));
        el.classList.add('selected');
    }

    function playCharacter(c, el) {
        if (S.busy) return; S.busy = true;
        selectCard(el);
        const btn = el.querySelector('.cc-play');
        btn.innerHTML = `<span class="mini-spin"></span>Loading...`;
        el.style.pointerEvents = 'none';
        post('selectCharacter', { citizenid: c.citizenid });
        // Lua will push the spawn screen next; release busy defensively.
        setTimeout(() => { S.busy = false; }, 4000);
    }

    // ---- Create / Delete -------------------------------------------
    function openCreate() {
        if (S.chars.length >= S.slots) { toast('error', 'Character limit reached.'); return; }
        showModal('#modalCreate');
        setTimeout(() => $('#createForm [name="firstname"]').focus(), 120);
    }
    function openDelete(c) {
        S.pendingDelete = c.citizenid;
        $('#delName').textContent = `${c.firstname} ${c.lastname}`;
        showModal('#modalDelete');
    }

    // ---- Spawn rendering -------------------------------------------
    const MAP_POS = { // approximate normalized positions on the stylized map
        downtown: { x: 62, y: 46 }, vespucci: { x: 34, y: 62 }, vinewood: { x: 58, y: 24 },
        richman: { x: 30, y: 40 }, airport: { x: 40, y: 82 }, port: { x: 78, y: 70 }, last: { x: 50, y: 50 }
    };
    const LOC_ICONS = {
        city:  '<path d="M4 16V7l6-4 6 4v9z"/><path d="M8 16v-3h4v3"/>',
        beach: '<path d="M10 3c3 0 5 2 5 5H5c0-3 2-5 5-5z"/><path d="M10 8v9M4 17h12"/>',
        hills: '<path d="M3 16l4-7 3 4 3-6 4 9z"/>',
        home:  '<path d="M4 9l6-5 6 5v7H4z"/>',
        plane: '<path d="M10 2l1 6 5 3v2l-5-1v3l2 1v1l-3-1-3 1v-1l2-1v-3l-5 1v-2l5-3 1-6z"/>',
        ship:  '<path d="M4 12h12l-2 4H6zM10 3v9M6 8h8"/>'
    };

    function spawnBokeh() {
        const host = $('#fx'); if (!host) return;
        for (let i = 0; i < 14; i++) {
            const b = document.createElement('span');
            b.className = 'b';
            const size = 3 + Math.random() * 9;
            b.style.width = size + 'px'; b.style.height = size + 'px';
            b.style.left = (Math.random() * 100) + 'vw';
            b.style.setProperty('--op', (0.12 + Math.random() * 0.32).toFixed(2));
            b.style.setProperty('--drift', (Math.random() * 70 - 35) + 'px');
            b.style.animationDuration = (16 + Math.random() * 16) + 's';
            b.style.animationDelay = (-Math.random() * 22) + 's';
            host.appendChild(b);
        }
    }

    function renderSpawns() {
        const host = $('#spawnCards');
        host.innerHTML = '';
        const list = [];
        if (S.enableLast && S.lastPosition) {
            list.push({ id: 'last', label: 'Last Location', desc: 'Pick up right where you left off.', icon: 'home',
                info: { safezone: false, vehicle: '—', jobs: true, popular: '—' }, blurb: 'Return to your last known position in the city.', last: true });
        }
        S.spawns.forEach(s => list.push(s));

        list.forEach((loc, i) => {
            const el = document.createElement('div');
            el.className = 'loc-card';
            el.style.animationDelay = (i * 0.05) + 's';
            el.dataset.id = loc.id;
            const ic = LOC_ICONS[loc.icon] || LOC_ICONS.city;
            const img = loc.last ? 'assets/car.jpg' : ('assets/loc/' + (loc.image || (loc.id + '.jpg')));
            el.innerHTML = `
                <div class="loc-bg" style="background:${grayGradient(hash(loc.id) + 40)}"><img src="${img}" onerror="this.remove()" /></div>
                ${loc.recommended ? '<div class="loc-rec">RECOMMENDED</div>' : ''}
                ${loc.last ? '<div class="loc-rec">LAST LOCATION</div>' : ''}
                <div class="loc-check"><svg viewBox="0 0 20 20"><path d="M5 10l3 3 7-7"/></svg></div>
                <div class="loc-body">
                    <div class="loc-title"><svg viewBox="0 0 20 20">${ic}</svg>${loc.label}</div>
                    <div class="loc-desc">${loc.desc || ''}</div>
                </div>`;
            el.addEventListener('click', () => selectSpawn(loc, el));
            host.appendChild(el);
        });

        // Auto-select: recommended, else last, else first.
        const pre = list.find(l => l.recommended) || list[0];
        if (pre) {
            const card = host.querySelector(`[data-id="${pre.id}"]`);
            if (card) selectSpawn(pre, card);
        }
    }

    function selectSpawn(loc, el) {
        S.selectedSpawn = loc.id;
        $$('.loc-card').forEach(c => c.classList.remove('selected'));
        el.classList.add('selected');
        // Info panel
        $('#infoName').textContent = loc.label;
        const info = loc.info || {};
        $('#infoSafe').textContent = info.safezone ? 'Yes' : 'No';
        $('#infoVehicle').textContent = info.vehicle || 'Nearby';
        $('#infoJobs').textContent = info.jobs ? 'Yes' : 'No';
        $('#infoPopular').textContent = info.popular || '—';
        $('#infoBlurb').textContent = loc.blurb || '';
        // Map pin
        const pos = MAP_POS[loc.id] || MAP_POS.last;
        const pin = $('#mapPin'); pin.style.left = pos.x + '%'; pin.style.top = pos.y + '%';
        // Enable confirm
        $('#spawnConfirm').disabled = false;
    }

    function confirmSpawn() {
        if (!S.selectedSpawn || S.busy) return;
        S.busy = true;
        $('#spawnConfirm').disabled = true;
        $('#screen-spawn').classList.add('leaving');
        setTimeout(() => {
            post('confirmSpawn', { id: S.selectedSpawn });
        }, 260);
    }

    // ---- Modals -----------------------------------------------------
    function showModal(sel) { $('#modalScrim').classList.remove('hidden'); $(sel).classList.remove('hidden'); }
    function closeModals() {
        $('#modalScrim').classList.add('hidden');
        $$('.modal').forEach(m => m.classList.add('hidden'));
        S.pendingDelete = null;
    }

    // ---- Screen switching ------------------------------------------
    function showScreen(name) {
        $('#screen-multichar').classList.toggle('hidden', name !== 'multichar');
        $('#screen-spawn').classList.toggle('hidden', name !== 'spawn');
    }

    // ---- Message handler -------------------------------------------
    window.addEventListener('message', (ev) => {
        const d = ev.data || {};
        switch (d.action) {
            case 'init':
                S.cfg = d.data;
                S.slots = d.data.maxSlots || 3;
                S.spawns = d.data.spawns || [];
                S.enableLast = d.data.enableLastLocation !== false;
                applyBrand();
                break;

            case 'show':
                document.body.classList.remove('hidden');
                if (d.data.screen === 'multichar') {
                    S.chars = d.data.chars || [];
                    S.slots = d.data.slots || S.slots;
                    S.busy = false;
                    renderChars();
                    showScreen('multichar');
                } else if (d.data.screen === 'spawn') {
                    S.lastPosition = d.data.lastPosition || null;
                    S.enableLast = d.data.enableLastLocation !== false;
                    S.selectedSpawn = null;
                    S.busy = false;
                    $('#screen-spawn').classList.remove('leaving');
                    $('#spawnConfirm').disabled = true;
                    renderSpawns();
                    showScreen('spawn');
                }
                break;

            case 'refresh':
                S.chars = d.data.chars || [];
                S.slots = d.data.slots || S.slots;
                S.busy = false;
                renderChars();
                break;

            case 'toast':
                toast(d.data.type, d.data.message);
                S.busy = false;
                // Re-enable any disabled play buttons
                $$('.char-card').forEach(c => { c.style.pointerEvents = ''; });
                renderChars();
                break;

            case 'hide':
                document.body.classList.add('hidden');
                closeModals();
                break;
        }
    });

    // ---- Static wiring ---------------------------------------------
    function wire() {
        // Nav
        $$('[data-nav]').forEach(btn => btn.addEventListener('click', () => {
            const nav = btn.dataset.nav;
            if (nav === 'create') { openCreate(); return; }
            if (nav === 'settings') { toast('', 'Settings — configure in config.lua.'); return; }
            if (nav === 'disconnect') { post('disconnect'); return; }
            $$('[data-nav]').forEach(b => b.classList.toggle('active', b === btn));
        }));

        // Guide
        $$('[data-open-guide]').forEach(b => b.addEventListener('click', () => showModal('#modalGuide')));

        // Modal close
        $$('[data-close-modal]').forEach(b => b.addEventListener('click', closeModals));
        $('#modalScrim').addEventListener('click', closeModals);

        // Gender segment
        $('#genderSeg').addEventListener('click', (e) => {
            const b = e.target.closest('.seg-btn'); if (!b) return;
            $$('#genderSeg .seg-btn').forEach(x => x.classList.toggle('active', x === b));
            S.createGender = parseInt(b.dataset.gender, 10) || 0;
        });

        // Create submit
        $('#createForm').addEventListener('submit', (e) => {
            e.preventDefault();
            if (S.busy) return;
            const f = e.target;
            const data = {
                firstname: f.firstname.value.trim(),
                lastname: f.lastname.value.trim(),
                dob: f.dob.value,
                nationality: f.nationality.value,
                gender: S.createGender
            };
            if (data.firstname.length < 2 || data.lastname.length < 2) { toast('error', 'Please enter a valid name.'); return; }
            if (!data.dob) { toast('error', 'Please choose a date of birth.'); return; }
            S.busy = true;
            closeModals();
            post('createCharacter', data);
            setTimeout(() => { S.busy = false; }, 4000);
        });

        // Delete hold-to-confirm
        setupHold($('#deleteConfirm'), () => {
            if (S.pendingDelete) post('deleteCharacter', { citizenid: S.pendingDelete });
            closeModals();
        });

        // Spawn confirm
        $('#spawnConfirm').addEventListener('click', confirmSpawn);

        // ESC closes modals only (never the whole menu).
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') { closeModals(); }
        });
    }

    // Hold-to-confirm interaction (press & hold ~1.1s).
    function setupHold(btn, done) {
        if (!btn) return;
        const fill = btn.querySelector('.hold-fill');
        let raf = null, start = 0; const DUR = 1100;
        const tick = (t) => {
            if (!start) start = t;
            const p = Math.min(1, (t - start) / DUR);
            fill.style.width = (p * 100) + '%';
            if (p >= 1) { cancel(); done(); return; }
            raf = requestAnimationFrame(tick);
        };
        const beginHold = (e) => { e.preventDefault(); start = 0; raf = requestAnimationFrame(tick); };
        const cancel = () => { if (raf) cancelAnimationFrame(raf); raf = null; start = 0; fill.style.width = '0%'; };
        btn.addEventListener('mousedown', beginHold);
        btn.addEventListener('mouseup', cancel);
        btn.addEventListener('mouseleave', cancel);
    }

    // ---- Boot -------------------------------------------------------
    wire();
    spawnBokeh();

    // Browser preview (no FiveM): seed demo data so the design renders.
    if (!window.invokeNative) {
        document.body.classList.add('solid-bg');
        document.body.classList.remove('hidden');
        S.cfg = {
            brand: { name: 'LIOR TOOLS', signature: 'Lior Tools', signatureSub: 'ROLEPLAY', online: '#38d66b' },
            maxSlots: 3, showDisconnect: false,
            portraits: { male: ['portraits/male_1.jpg', 'portraits/male_2.jpg'], female: ['portraits/female_1.jpg'] },
            nationalities: ['American', 'Mexican', 'British', 'Italian', 'Japanese', 'Other'],
            spawns: [
                { id: 'downtown', label: 'Downtown', desc: 'The heart of the city. Close to everything.', icon: 'city', recommended: true, info: { safezone: true, vehicle: 'Nearby', jobs: true, popular: 'High' }, blurb: 'A great place to start your journey in the city.' },
                { id: 'vespucci', label: 'Vespucci Beach', desc: 'Beaches, clubs and good vibes.', icon: 'beach', info: { safezone: true, vehicle: 'Nearby', jobs: true, popular: 'High' }, blurb: 'Sun, sand and nightlife on the west coast.' },
                { id: 'vinewood', label: 'Vinewood Hills', desc: 'Luxury, views and high life.', icon: 'hills', info: { safezone: false, vehicle: 'Nearby', jobs: false, popular: 'Medium' }, blurb: 'Live above the city where the elite reside.' },
                { id: 'richman', label: 'Richman', desc: 'Quiet, rich and peaceful.', icon: 'home', info: { safezone: true, vehicle: 'Nearby', jobs: false, popular: 'Low' }, blurb: 'A calm, upscale neighborhood.' },
                { id: 'airport', label: 'Los Santos Intl', desc: 'Perfect for pilots and travelers.', icon: 'plane', info: { safezone: true, vehicle: 'Nearby', jobs: true, popular: 'Medium' }, blurb: 'Wheels up. Your story starts at the gate.' },
                { id: 'port', label: 'Port of LS', desc: 'Work, business and opportunities.', icon: 'ship', info: { safezone: false, vehicle: 'Nearby', jobs: true, popular: 'Medium' }, blurb: 'Where the working city never sleeps.' }
            ],
            enableLastLocation: true
        };
        S.slots = 3; S.spawns = S.cfg.spawns; applyBrand();
        S.chars = [
            { citizenid: 'ABC12345', firstname: 'Jay', lastname: 'Walker', gender: 0, jobLabel: 'Civilian', jobName: 'unemployed', createdAt: '2025-05-12 10:00:00', lastPlayed: new Date(Date.now() - 2 * 3600e3).toISOString() },
            { citizenid: 'DEF67890', firstname: 'Michael', lastname: 'Carter', gender: 0, jobLabel: 'Police', jobName: 'police', createdAt: '2025-04-28 10:00:00', lastPlayed: new Date(Date.now() - 6 * 86400e3).toISOString() },
            { citizenid: 'GHI13579', firstname: 'Emily', lastname: 'Rose', gender: 1, jobLabel: 'Civilian', jobName: 'unemployed', createdAt: '2025-03-02 10:00:00', lastPlayed: new Date(Date.now() - 12 * 86400e3).toISOString() }
        ];
        if (location.hash === '#spawn') {
            S.lastPosition = { x: 0, y: 0, z: 0, a: 0 };
            renderSpawns(); showScreen('spawn');
        } else {
            renderChars(); showScreen('multichar');
        }
    }
})();
