/* =========================================================
   LIOR TOOLS — Loading screen controller
   Drives branding, the progress bar, the synced step checklist
   and rotating tips from real FiveM load events.
   ========================================================= */
(function () {
    const $ = (id) => document.getElementById(id);

    // --- Inline line-icons for the step checklist ---
    const ICONS = [
        // cloud
        '<path d="M4 15a3.5 3.5 0 0 1 .5-7 5 5 0 0 1 9.6-1A3.5 3.5 0 0 1 16 15z"/>',
        // resources / grid
        '<rect x="2" y="2" width="6" height="6" rx="1"/><rect x="10" y="2" width="6" height="6" rx="1"/><rect x="2" y="10" width="6" height="6" rx="1"/><rect x="10" y="10" width="6" height="6" rx="1"/>',
        // connect / server
        '<rect x="2.5" y="3" width="13" height="4.5" rx="1"/><rect x="2.5" y="10.5" width="13" height="4.5" rx="1"/><circle cx="5.5" cy="5.2" r="0.8" fill="currentColor" stroke="none"/><circle cx="5.5" cy="12.7" r="0.8" fill="currentColor" stroke="none"/>',
        // user / character
        '<circle cx="9" cy="6" r="3"/><path d="M3.5 16a5.5 5.5 0 0 1 11 0"/>',
        // gear
        '<circle cx="9" cy="9" r="2.4"/><path d="M9 1.5v2M9 14.5v2M1.5 9h2M14.5 9h2M3.7 3.7l1.4 1.4M12.9 12.9l1.4 1.4M14.3 3.7l-1.4 1.4M5.1 12.9l-1.4 1.4"/>'
    ];
    const CHECK = '<polyline class="check" points="3.5,9.5 7.5,13.5 14.5,5" stroke-width="1.8"/>';

    let CFG = window.LT_LOAD_DEFAULTS;
    let tips = [], steps = [], tipTimer = null, tipIndex = 0;
    let targetPct = 0, shownPct = 0, currentStep = -1;

    // ---------------------------------------------------------------
    function applyConfig(cfg) {
        CFG = cfg;
        const b = cfg.brand || {};
        const l = cfg.loading || {};

        // Background mode (image is the default via CSS; video is opt-in)
        document.body.classList.remove('bg-video');
        if (l.background === 'video') {
            document.body.classList.add('bg-video');
            const v = $('bgVideo'); v.src = 'assets/bg.mp4'; v.play().catch(() => {});
        }

        // Branding text
        $('topName').textContent   = b.name || 'LIOR TOOLS';
        $('wordmark').textContent  = b.name || 'LIOR TOOLS';
        $('tagline').textContent   = b.tagline || '';
        $('footerLeft').textContent  = b.footerLeft || '';
        $('footerRight').textContent = b.footerRight || '';
        $('strapline').textContent = (b.strapline || []).join('  /  ');

        // Flavor line
        const flavor = l.flavor || [];
        $('flavor').innerHTML = flavor.map((f, i) =>
            (i ? '<span class="sep"></span>' : '') + '<span>' + f + '</span>'
        ).join('');

        // Percent visibility
        $('percent').style.display = (l.showPercent === false) ? 'none' : '';

        // Tips
        tips = (l.tips && l.tips.length) ? l.tips : [{ title: 'QUICK TIP', body: '' }];
        tipIndex = 0; renderTip(true);
        if (tipTimer) clearInterval(tipTimer);
        tipTimer = setInterval(rotateTip, l.tipRotateMs || 6500);

        // Steps
        buildSteps(l.steps || []);
    }

    // ---------------------------------------------------------------
    function buildSteps(labels) {
        steps = labels;
        const host = $('steps');
        host.innerHTML = '';
        labels.forEach((label, i) => {
            const el = document.createElement('div');
            el.className = 'step';
            el.style.animationDelay = (0.9 + i * 0.12) + 's';
            el.innerHTML =
                '<div class="ico">' +
                    '<span class="ring"></span>' +
                    '<svg viewBox="0 0 18 18">' + (ICONS[i % ICONS.length]) + '</svg>' +
                '</div>' +
                '<div class="label">' + label + '</div>';
            host.appendChild(el);
        });
        setStep(0);
    }

    function setStep(index) {
        if (index === currentStep) return;
        currentStep = index;
        const els = document.querySelectorAll('.step');
        els.forEach((el, i) => {
            const svg = el.querySelector('svg');
            el.classList.remove('active', 'done');
            if (i < index) {
                el.classList.add('done');
                svg.innerHTML = CHECK;
            } else {
                svg.innerHTML = ICONS[i % ICONS.length];
                if (i === index) el.classList.add('active');
            }
        });
    }

    function completeAllSteps() {
        const els = document.querySelectorAll('.step');
        els.forEach((el) => {
            el.classList.remove('active');
            el.classList.add('done');
            el.querySelector('svg').innerHTML = CHECK;
        });
        currentStep = steps.length;
    }

    // ---------------------------------------------------------------
    function renderTip(instant) {
        const tip = tips[tipIndex % tips.length] || {};
        const box = $('tip');
        const set = () => { $('tipTitle').textContent = tip.title || 'QUICK TIP'; $('tipBody').textContent = tip.body || ''; };
        if (instant) { set(); return; }
        box.classList.add('swap');
        setTimeout(() => { set(); box.classList.remove('swap'); }, 400);
    }
    function rotateTip() { tipIndex++; renderTip(false); }

    // ---------------------------------------------------------------
    function setProgress(fraction) {
        targetPct = Math.max(0, Math.min(1, fraction)) * 100;
    }

    // Smoothly ease the visible bar toward the target.
    function animatePct() {
        shownPct += (targetPct - shownPct) * 0.08;
        if (Math.abs(targetPct - shownPct) < 0.1) shownPct = targetPct;
        const p = Math.round(shownPct);
        $('progressFill').style.width = shownPct + '%';
        $('progressHead').style.left = shownPct + '%';
        $('percent').textContent = p + '%';

        // Sync steps to progress if events alone aren't advancing them.
        if (steps.length) {
            const idx = Math.min(steps.length - 1, Math.floor((shownPct / 100) * steps.length));
            if (idx > currentStep && currentStep < steps.length) setStep(idx);
            if (shownPct >= 99.5) completeAllSteps();
        }
        requestAnimationFrame(animatePct);
    }

    // ---------------------------------------------------------------
    // FiveM load events + our runtime config push.
    window.addEventListener('message', function (e) {
        const d = e.data || {};

        // Runtime branding push from config.lua
        if (d.action === 'ltcfg' && d.cfg) { applyConfig(d.cfg); return; }
        if (d.action === 'transition') { document.body.classList.add('leaving'); return; }

        switch (d.eventName) {
            case 'loadProgress':
                setProgress(typeof d.loadFraction === 'number' ? d.loadFraction : 0);
                break;
            case 'startInitFunctionOrder':
            case 'startDataFileEntries':
                setStep(Math.max(currentStep, 1));
                break;
            case 'onDataFileEntry':
                setStep(Math.max(currentStep, 1));
                break;
            case 'startInitFunction':
            case 'initFunctionInvoking':
                setStep(Math.max(currentStep, 2));
                break;
            case 'performMapLoadFunction':
                setStep(Math.max(currentStep, 3));
                break;
            case 'endDataFileEntries':
                setStep(Math.max(currentStep, 4));
                break;
        }
    });

    // ---------------------------------------------------------------
    // Soft bokeh particles (gentle upward drift — cinematic, not blocky)
    function spawnBokeh() {
        const host = $('fx'); if (!host) return;
        const N = 16;
        for (let i = 0; i < N; i++) {
            const b = document.createElement('span');
            b.className = 'b';
            const size = 3 + Math.random() * 10;
            b.style.width = size + 'px';
            b.style.height = size + 'px';
            b.style.left = (Math.random() * 100) + 'vw';
            b.style.setProperty('--op', (0.15 + Math.random() * 0.4).toFixed(2));
            b.style.setProperty('--drift', (Math.random() * 80 - 40) + 'px');
            b.style.animationDuration = (14 + Math.random() * 16) + 's';
            b.style.animationDelay = (-Math.random() * 20) + 's';
            host.appendChild(b);
        }
    }

    // ---------------------------------------------------------------
    // Boot
    applyConfig(CFG);
    spawnBokeh();
    animatePct();

    // In-browser preview (no FiveM): fake a load so the design is testable.
    if (!window.invokeNative) {
        let f = 0;
        const fake = setInterval(() => {
            f += Math.random() * 0.05;
            setProgress(f);
            if (f >= 1) { clearInterval(fake); }
        }, 220);
    }
})();
