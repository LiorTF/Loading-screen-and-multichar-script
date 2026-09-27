/* =========================================================
   LIOR TOOLS — Inventory NUI logic
   ========================================================= */
(function () {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'lt-inventory';
    const $ = (s, r = document) => r.querySelector(s);
    const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

    const S = {
        boot: { imagePath: 'images/%s', rarity: {}, hotbar: 5, sounds: true, brand: { name: 'LIOR TOOLS' } },
        player: null,      // {items, maxWeight, slots, weight}
        secondary: null,   // {kind,id,label,items,maxWeight,slots,weight,shop,readonly}
        open: false,
        drag: null         // {inv, slot, item}
    };

    async function post(name, data = {}) {
        try {
            const r = await fetch(`https://${RES}/${name}`, {
                method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data)
            });
            return await r.json().catch(() => ({}));
        } catch (e) { return {}; }
    }

    // ---- audio (tiny WebAudio blips, no assets) ----
    let actx = null;
    function beep(freq, dur, vol) {
        if (!S.boot.sounds) return;
        try {
            actx = actx || new (window.AudioContext || window.webkitAudioContext)();
            const o = actx.createOscillator(), g = actx.createGain();
            o.frequency.value = freq; o.type = 'sine';
            g.gain.value = vol || 0.03; o.connect(g); g.connect(actx.destination);
            o.start(); o.stop(actx.currentTime + (dur || 0.05));
        } catch (e) {}
    }

    // ---- helpers ----
    const kg = g => ((g || 0) / 1000).toFixed(1);
    function imageUrl(item) { return (S.boot.imagePath || 'images/%s').replace('%s', item.image || (item.name + '.png')); }
    function rarityOf(item) {
        const R = S.boot.rarity || {};
        return R[item.name] || R[item.type] || 1;
    }
    function monogram(item) {
        const l = (item.label || item.name || '?').replace(/[^A-Za-z0-9]/g, '');
        return (l.substring(0, 2) || '?').toUpperCase();
    }
    function invId(which) {
        if (which === 'player') return 'player';
        if (S.secondary) return S.secondary.kind + ':' + S.secondary.id;
        return null;
    }

    // ---- rendering ----
    function slotHTML(item, index, isHot, shop) {
        if (!item) {
            return `<div class="slot empty${isHot ? ' hot' : ''}" data-slot="${index}">${isHot ? `<span class="num">${index}</span>` : ''}</div>`;
        }
        const r = rarityOf(item);
        const amt = item.amount > 1 ? `<span class="amt">${item.amount}</span>` : '';
        const price = shop ? `<span class="price">$${item.price}</span>` : '';
        return `
          <div class="slot${isHot ? ' hot' : ''}" data-slot="${index}" data-r="${r}" draggable="${shop ? 'false' : 'true'}">
            ${isHot ? `<span class="num">${index}</span>` : ''}
            <div class="item">
              <div class="mono">${monogram(item)}</div>
              <img src="${imageUrl(item)}" onload="this.previousElementSibling.style.display='none'" onerror="this.remove()" />
              ${amt}
              <span class="lbl">${item.label || item.name}</span>
              ${price}
            </div>
          </div>`;
    }

    function renderGrid(host, data, opts) {
        opts = opts || {};
        const items = data.items || {};
        let html = '';
        for (let i = 1; i <= data.slots; i++) {
            const isHot = opts.hotbar && i <= (S.boot.hotbar || 0);
            html += slotHTML(items[i], i, isHot, opts.shop);
        }
        host.innerHTML = html;
    }

    function renderWeight(prefix, data) {
        const pct = Math.min(100, (data.weight / data.maxWeight) * 100);
        $('#' + prefix + 'Weight').textContent = kg(data.weight);
        $('#' + prefix + 'Max').textContent = kg(data.maxWeight);
        const fill = $('#' + prefix + 'WeightFill');
        fill.style.width = pct + '%';
        fill.classList.toggle('warn', pct >= 70 && pct < 92);
        fill.classList.toggle('full', pct >= 92);
    }

    function render() {
        if (S.player) { renderGrid($('#playerGrid'), S.player, { hotbar: true }); renderWeight('p', S.player); }
        const secPanel = $('#secPanel');
        if (S.secondary) {
            secPanel.classList.remove('hidden');
            $('#secLabel').textContent = S.secondary.label || 'Container';
            renderGrid($('#secGrid'), S.secondary, { shop: S.secondary.shop });
            const ww = $('#secWeightWrap');
            if (S.secondary.shop) { ww.style.visibility = 'hidden'; } else { ww.style.visibility = 'visible'; renderWeight('s', S.secondary); }
        } else {
            secPanel.classList.add('hidden');
        }
        wireSlots();
    }

    // ---- slot wiring (drag, click, ctx, tooltip) ----
    function slotData(el) {
        const grid = el.closest('.grid');
        const which = grid === $('#playerGrid') ? 'player' : 'secondary';
        const slot = parseInt(el.dataset.slot, 10);
        const source = which === 'player' ? S.player : S.secondary;
        return { which, slot, item: source && source.items ? source.items[slot] : null, source };
    }

    function wireSlots() {
        $$('.slot').forEach(el => {
            el.addEventListener('dragstart', onDragStart);
            el.addEventListener('dragover', onDragOver);
            el.addEventListener('dragleave', () => el.classList.remove('drag-over'));
            el.addEventListener('drop', onDrop);
            el.addEventListener('dragend', () => { $$('.slot').forEach(s => s.classList.remove('dragging', 'drag-over')); });
            el.addEventListener('contextmenu', onContext);
            el.addEventListener('dblclick', onDblClick);
            el.addEventListener('mouseenter', onHover);
            el.addEventListener('mousemove', moveTooltip);
            el.addEventListener('mouseleave', hideTooltip);
        });
    }

    function onDragStart(e) {
        const d = slotData(e.currentTarget);
        if (!d.item) { e.preventDefault(); return; }
        S.drag = { inv: invId(d.which), slot: d.slot, item: d.item, shift: e.shiftKey };
        e.currentTarget.classList.add('dragging');
        try { e.dataTransfer.setData('text/plain', '1'); e.dataTransfer.effectAllowed = 'move'; } catch (x) {}
    }
    function onDragOver(e) { e.preventDefault(); e.currentTarget.classList.add('drag-over'); }
    function onDrop(e) {
        e.preventDefault();
        e.currentTarget.classList.remove('drag-over');
        if (!S.drag) return;
        const d = slotData(e.currentTarget);
        const toInv = invId(d.which);
        const fromInv = S.drag.inv;
        if (fromInv === toInv && S.drag.slot === d.slot) { S.drag = null; return; }
        // shop items can't be dragged out (buy via dblclick/ctx); block dropping into shop
        if (S.secondary && S.secondary.shop && d.which === 'secondary') { S.drag = null; return; }

        const full = S.drag.item.amount;
        const doMove = (amount) => {
            post('move', { fromInv, fromSlot: S.drag.slot, toInv, toSlot: d.slot, amount });
            beep(320, 0.04);
            S.drag = null;
        };
        if ((e.shiftKey || S.drag.shift) && full > 1) {
            openAmount('Split — how many?', full, doMove);
        } else {
            doMove(full);
        }
    }

    function onDblClick(e) {
        const d = slotData(e.currentTarget);
        if (!d.item) return;
        if (d.which === 'secondary' && S.secondary && S.secondary.shop) {
            post('buy', { slot: d.slot, amount: 1 }); beep(520, 0.05); return;
        }
        if (d.which === 'player' && d.item.useable) { post('use', { slot: d.slot }); beep(440, 0.05); }
    }

    // ---- context menu ----
    function onContext(e) {
        e.preventDefault();
        hideTooltip();
        const d = slotData(e.currentTarget);
        if (!d.item) return hideCtx();
        const items = [];
        if (d.which === 'secondary' && S.secondary && S.secondary.shop) {
            items.push({ label: 'Buy 1', ico: '<path d="M4 6h12l-1 9H5z"/><path d="M8 6a2 2 0 0 1 4 0"/>', fn: () => post('buy', { slot: d.slot, amount: 1 }) });
            items.push({ label: 'Buy amount…', ico: '<path d="M10 4v12M4 10h12"/>', fn: () => openAmount('Buy — how many?', 999, a => post('buy', { slot: d.slot, amount: a })) });
        } else {
            if (d.which === 'player' && d.item.useable)
                items.push({ label: 'Use', ico: '<path d="M5 10l3 3 7-7"/>', fn: () => post('use', { slot: d.slot }) });
            if (d.item.amount > 1)
                items.push({ label: 'Split…', ico: '<path d="M10 3v14M3 10h14"/>', fn: () => splitItem(d) });
            if (d.which === 'player') {
                items.push({ label: 'Give', ico: '<circle cx="10" cy="7" r="3"/><path d="M4 17a6 6 0 0 1 12 0"/>', fn: () => amtOrOne(d, a => post('give', { slot: d.slot, amount: a })) });
                items.push({ sep: true });
                items.push({ label: 'Drop', danger: true, ico: '<path d="M4 6h12M8 6V4h4v2M6 6l1 10h6l1-10"/>', fn: () => amtOrOne(d, a => post('drop', { slot: d.slot, amount: a })) });
            }
        }
        showCtx(e.clientX, e.clientY, items);
    }
    function amtOrOne(d, cb) { if (d.item.amount > 1) openAmount('How many?', d.item.amount, cb); else cb(1); }
    function splitItem(d) {
        openAmount('Split — how many?', d.item.amount, amount => {
            // move to first empty slot in same inventory
            const src = d.which === 'player' ? S.player : S.secondary;
            let empty = null;
            for (let i = 1; i <= src.slots; i++) { if (!src.items[i]) { empty = i; break; } }
            if (!empty) return;
            post('move', { fromInv: invId(d.which), fromSlot: d.slot, toInv: invId(d.which), toSlot: empty, amount });
        });
    }

    function showCtx(x, y, items) {
        const ctx = $('#ctx');
        ctx.innerHTML = items.map(it => it.sep ? '<div class="ctx-sep"></div>' :
            `<div class="ctx-item ${it.danger ? 'danger' : ''}"><svg viewBox="0 0 20 20">${it.ico}</svg>${it.label}</div>`).join('');
        ctx.classList.remove('hidden');
        const w = ctx.offsetWidth, h = ctx.offsetHeight;
        ctx.style.left = Math.min(x, window.innerWidth - w - 8) + 'px';
        ctx.style.top = Math.min(y, window.innerHeight - h - 8) + 'px';
        let idx = 0;
        $$('.ctx-item', ctx).forEach(el => {
            const item = items.filter(i => !i.sep)[idx++];
            el.addEventListener('click', () => { hideCtx(); beep(360, 0.04); item.fn(); });
        });
    }
    function hideCtx() { $('#ctx').classList.add('hidden'); }

    // ---- amount modal ----
    let amountCb = null;
    function openAmount(title, max, cb) {
        amountCb = cb;
        $('#amTitle').textContent = title;
        const inp = $('#amInput'), rng = $('#amRange');
        inp.max = max; rng.max = max; inp.value = 1; rng.value = 1;
        $('#amountScrim').classList.remove('hidden'); $('#amountModal').classList.remove('hidden');
        inp.focus(); inp.select();
    }
    function closeAmount() { $('#amountScrim').classList.add('hidden'); $('#amountModal').classList.add('hidden'); amountCb = null; }

    // ---- tooltip ----
    function onHover(e) {
        if (!$('#ctx').classList.contains('hidden')) return; // don't show over an open menu
        const d = slotData(e.currentTarget);
        if (!d.item) return hideTooltip();
        const t = $('#tooltip');
        const tags = [];
        tags.push(`${kg(d.item.weight)} kg`);
        if (d.item.type === 'weapon') tags.push('Weapon');
        if (d.item.unique) tags.push('Unique');
        if (d.item.useable) tags.push('Usable');
        if (d.item.price != null) tags.push('$' + d.item.price);
        t.innerHTML = `
          <div class="tt-name">${d.item.label || d.item.name}</div>
          <div class="tt-meta">${(d.item.name || '').toUpperCase()}${d.item.amount > 1 ? ' · x' + d.item.amount : ''}</div>
          ${d.item.description ? `<div class="tt-desc">${d.item.description}</div>` : ''}
          <div class="tt-tags">${tags.map(x => `<span class="tt-tag">${x}</span>`).join('')}</div>`;
        t.classList.remove('hidden');
        moveTooltip(e);
    }
    function moveTooltip(e) {
        const t = $('#tooltip'); if (t.classList.contains('hidden')) return;
        const x = e.clientX + 16, y = e.clientY + 16;
        t.style.left = Math.min(x, window.innerWidth - t.offsetWidth - 10) + 'px';
        t.style.top = Math.min(y, window.innerHeight - t.offsetHeight - 10) + 'px';
    }
    function hideTooltip() { $('#tooltip').classList.add('hidden'); }

    // ---- itembox + toast ----
    function itemBox(data) {
        const wrap = $('#itemBoxes');
        const el = document.createElement('div');
        el.className = 'itembox';
        el.innerHTML = `
          <div class="ib-img"><div class="mono">${monogram({ label: data.label })}</div>
            <img src="${(S.boot.imagePath || 'images/%s').replace('%s', data.image)}" onload="this.previousElementSibling.style.display='none'" onerror="this.remove()"/></div>
          <div class="ib-text"><span class="ib-amt ${data.added ? 'add' : 'rem'}">${data.added ? '+' : '−'}${data.amount}</span>
            <span class="ib-label">${data.label}</span></div>`;
        wrap.appendChild(el);
        beep(data.added ? 560 : 300, 0.05);
        setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 400); }, 2600);
    }
    function toast(msg) {
        const el = document.createElement('div'); el.className = 'toast-mini'; el.textContent = msg;
        document.body.appendChild(el);
        setTimeout(() => el.remove(), 2200);
    }

    // ---- hotbar peek ----
    let peekTimer = null;
    function peekHotbar(player) {
        const host = $('#hotbarPeek');
        let html = '';
        for (let i = 1; i <= (S.boot.hotbar || 5); i++) {
            const item = player.items[i];
            html += slotHTML(item, i, true, false);
        }
        host.innerHTML = html; host.classList.remove('hidden', 'out');
        if (peekTimer) clearTimeout(peekTimer);
        peekTimer = setTimeout(() => { host.classList.add('out'); setTimeout(() => host.classList.add('hidden'), 400); }, 3000);
    }

    // ---- open / close ----
    function openUI(data) {
        S.player = data.player;
        S.secondary = data.secondary || null;
        if (data.boot) S.boot = Object.assign(S.boot, data.boot);
        S.open = true;
        $('#inv').classList.remove('hidden');
        render();
        beep(480, 0.06);
    }
    function closeUI() {
        S.open = false;
        $('#inv').classList.add('hidden');
        hideCtx(); hideTooltip(); closeAmount();
    }

    // ---- messages ----
    window.addEventListener('message', (ev) => {
        const d = ev.data || {};
        switch (d.action) {
            case 'boot': S.boot = Object.assign(S.boot, d.data || {}); if (d.data && d.data.brand && d.data.brand.name) $$('[data-brand-name]').forEach(e => e.textContent = d.data.brand.name); break;
            case 'open': openUI(d.data); break;
            case 'close': closeUI(); break;
            case 'updatePlayer': S.player = d.data; if (S.open) render(); break;
            case 'updateSecondary': S.secondary = d.data; if (S.open) render(); break;
            case 'itemBox': itemBox(d.data); break;
            case 'toast': toast(d.data.message); break;
            case 'peekHotbar': peekHotbar(d.data.player); break;
        }
    });

    // ---- global input ----
    document.addEventListener('keydown', (e) => {
        if (!S.open) return;
        if (e.key === 'Escape' || e.key === 'Tab') { e.preventDefault(); post('close'); closeUI(); }
    });
    document.addEventListener('click', (e) => { if (!$('#ctx').contains(e.target)) hideCtx(); });
    document.addEventListener('contextmenu', (e) => { if (!e.target.closest('.slot')) e.preventDefault(); });

    // Drop onto the scrim = drop item on the ground
    $('.scrim').addEventListener('dragover', e => e.preventDefault());
    $('.scrim').addEventListener('drop', e => {
        e.preventDefault();
        if (!S.drag || S.drag.inv !== 'player') { S.drag = null; return; }
        const full = S.drag.item.amount, slot = S.drag.slot;
        const drop = a => { post('drop', { slot, amount: a }); S.drag = null; };
        if (full > 1) openAmount('Drop — how many?', full, drop); else drop(1);
    });

    // amount modal wiring
    $('#amInput').addEventListener('input', e => { $('#amRange').value = Math.min(+e.target.value || 1, +e.target.max); });
    $('#amRange').addEventListener('input', e => { $('#amInput').value = e.target.value; });
    $$('.am-step').forEach(b => b.addEventListener('click', () => {
        const inp = $('#amInput'); let v = (+inp.value || 1) + (+b.dataset.step);
        v = Math.max(1, Math.min(v, +inp.max || 1)); inp.value = v; $('#amRange').value = v;
    }));
    $('#amCancel').addEventListener('click', closeAmount);
    $('#amConfirm').addEventListener('click', () => {
        const v = Math.max(1, Math.min(+$('#amInput').value || 1, +$('#amInput').max || 1));
        const cb = amountCb; closeAmount(); if (cb) cb(v);
    });

    // ---- browser preview ----
    if (!window.invokeNative) {
        S.boot = { imagePath: 'images/%s', hotbar: 5, sounds: false, brand: { name: 'LIOR TOOLS' },
            rarity: { weapon: 4, goldbar: 5, lockpick: 2, radio: 2, diamond: 5 } };
        const mk = (name, label, amount, extra) => Object.assign({ name, label, amount, weight: 200, type: 'item', useable: true, image: name + '.png', info: {}, description: label + '.' }, extra || {});
        S.player = { slots: 25, maxWeight: 120000, weight: 14300, items: {
            1: mk('water_bottle', 'Water', 4), 2: mk('sandwich', 'Sandwich', 2),
            3: mk('lockpick', 'Lockpick', 3, { weight: 160 }), 4: mk('phone', 'Phone', 1, { weight: 190 }),
            5: mk('radio', 'Radio', 1, { weight: 1000 }),
            7: mk('bandage', 'Bandage', 6), 8: mk('armor', 'Armor', 1, { weight: 3000 }),
            11: mk('goldbar', 'Gold Bar', 2, { weight: 7000, useable: false }),
            12: mk('weapon_pistol', 'Pistol', 1, { type: 'weapon', unique: true, weight: 1000 }),
            13: mk('diamond', 'Diamond', 5, { weight: 100, useable: false }),
            18: mk('markedbills', 'Marked Bills', 1, { unique: true, useable: false })
        } };
        S.secondary = { kind: 'stash', id: 'demo', label: 'Stash', slots: 30, maxWeight: 100000, weight: 8000, items: {
            1: mk('goldbar', 'Gold Bar', 1, { weight: 7000, useable: false }),
            2: mk('bandage', 'Bandage', 10), 5: mk('lockpick', 'Lockpick', 6, { weight: 160 })
        } };
        S.open = true; $('#inv').classList.remove('hidden'); render();
        // demo a notification
        setTimeout(() => itemBox({ label: 'Water', image: 'water_bottle.png', amount: 2, added: true }), 600);
    }
})();
