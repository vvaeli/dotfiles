// MD3 Shell: recolors Steam to the md3 palette at runtime.
// Steam hardcodes its blue-grey colors in thousands of rules with hashed class names that change
// between updates. Instead of tracking them, every stylesheet is scanned once and each of those
// colors is rewritten to the md3 role with the closest meaning (surface levels, text, outline,
// primary). The override is inserted right after its source sheet, so equal specificity wins.
(() => {
    if (window.__md3Recolor) return;
    window.__md3Recolor = true;

    const PROPS = ['color', 'background-color', 'background-image', 'background', 'border-color', 'border-top-color',
        'border-bottom-color', 'border-left-color', 'border-right-color', 'outline-color', 'fill', 'stroke',
        'caret-color', 'text-decoration-color', 'column-rule-color'];
    const COLOR = /#[0-9a-fA-F]{3,8}\b|rgba?\([^()]*\)/g;
    const TEXT = new Set(['color', 'fill', 'stroke', 'caret-color', 'text-decoration-color']);

    function parse(token) {
        let r, g, b, a = 1;
        if (token[0] === '#') {
            let h = token.slice(1);
            if (h.length === 3 || h.length === 4) h = [...h].map(c => c + c).join('');
            if (h.length !== 6 && h.length !== 8) return null;
            r = parseInt(h.slice(0, 2), 16); g = parseInt(h.slice(2, 4), 16); b = parseInt(h.slice(4, 6), 16);
            if (h.length === 8) a = parseInt(h.slice(6, 8), 16) / 255;
        } else {
            const parts = token.slice(token.indexOf('(') + 1, -1).split(/[\s,/]+/).filter(Boolean);
            if (parts.length < 3 || parts.some(p => p.includes('var'))) return null;
            [r, g, b] = parts.slice(0, 3).map(p => p.endsWith('%') ? parseFloat(p) * 2.55 : parseFloat(p));
            if (parts[3] !== undefined) a = parts[3].endsWith('%') ? parseFloat(parts[3]) / 100 : parseFloat(parts[3]);
            if ([r, g, b, a].some(Number.isNaN)) return null;
        }
        return { r, g, b, a };
    }

    function hsl({ r, g, b }) {
        r /= 255; g /= 255; b /= 255;
        const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2, d = max - min;
        if (!d) return { h: 0, s: 0, l };
        const s = d / (1 - Math.abs(2 * l - 1));
        let h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
        return { h: (h * 60 + 360) % 360, s, l };
    }

    // Returns the md3 role for a Steam color, or null to keep it (greens, reds, artwork tints).
    function role(c, prop) {
        const { h, s, l } = hsl(c);
        const text = TEXT.has(prop);
        const bluish = h >= 185 && h <= 235;
        const neutral = s < 0.2 || (bluish && l < 0.5 && s < 0.75) || l > 0.93;
        if (neutral) {
            if (text) {
                if (l > 0.78) return 'on-surface';
                if (l > 0.5) return 'on-surface-variant';
                if (l > 0.3) return 'outline';
                return 'surface-container-highest';
            }
            if (l < 0.06) return 'surface-container-lowest';
            if (l < 0.1) return 'surface';
            if (l < 0.14) return 'surface-container-low';
            if (l < 0.19) return 'surface-container';
            if (l < 0.25) return 'surface-container-high';
            if (l < 0.4) return 'surface-container-highest';
            if (l < 0.62) return 'outline';
            if (l < 0.8) return 'on-surface-variant';
            return 'on-surface';
        }
        if (bluish && s >= 0.45) {
            if (text) return 'primary';
            return l > 0.42 ? 'primary' : 'primary-container';
        }
        return null;
    }

    function rewrite(value, prop) {
        let changed = false;
        const out = value.replace(COLOR, token => {
            const c = parse(token);
            if (!c) return token;
            const name = role(c, prop);
            if (!name) return token;
            changed = true;
            return c.a >= 1 ? `rgb(var(--md3-${name}))` : `rgba(var(--md3-${name}), ${+c.a.toFixed(3)})`;
        });
        return changed ? out : null;
    }

    function convert(rules) {
        let css = '';
        for (const rule of rules) {
            if (rule.cssRules && rule.media) {
                const inner = convert(rule.cssRules);
                if (inner) css += `@media ${rule.media.mediaText}{${inner}}`;
                continue;
            }
            if (rule.cssRules && rule.conditionText !== undefined) {
                const inner = convert(rule.cssRules);
                if (inner) css += `@supports ${rule.conditionText}{${inner}}`;
                continue;
            }
            if (!rule.style || !rule.selectorText) continue;
            let body = '';
            for (const prop of PROPS) {
                const value = rule.style.getPropertyValue(prop);
                if (!value) continue;
                const next = rewrite(value, prop);
                if (next) body += `${prop}:${next}${rule.style.getPropertyPriority(prop) ? ' !important' : ''};`;
            }
            // Custom properties hold colors too (gradients, accent variables).
            for (const prop of rule.style) {
                if (!prop.startsWith('--') || prop.startsWith('--md3-')) continue;
                const next = rewrite(rule.style.getPropertyValue(prop), 'background-color');
                if (next) body += `${prop}:${next};`;
            }
            if (body) css += `${rule.selectorText}{${body}}`;
        }
        return css;
    }

    const done = new WeakSet();
    function process(node) {
        if (done.has(node) || node.dataset?.md3) return;
        const sheet = node.sheet;
        if (!sheet) return;
        let rules;
        try { rules = sheet.cssRules; } catch { return; }
        done.add(node);
        const css = convert(rules);
        if (!css) return;
        const style = node.ownerDocument.createElement('style');
        style.dataset.md3 = 'recolor';
        style.textContent = css;
        node.after(style);
    }

    function scan(doc) {
        for (const node of doc.querySelectorAll('style:not([data-md3]), link[rel="stylesheet"]')) {
            if (node.sheet) process(node);
            else node.addEventListener('load', () => process(node), { once: true });
        }
    }

    function watch(doc) {
        scan(doc);
        new MutationObserver(mutations => {
            for (const m of mutations) for (const n of m.addedNodes) {
                if (n.nodeName === 'STYLE' || n.nodeName === 'LINK') {
                    if (n.sheet) process(n); else n.addEventListener('load', () => process(n), { once: true });
                }
            }
        }).observe(doc.head || doc.documentElement, { childList: true, subtree: true });
    }

    window.__md3Recolor = { watch, convert, role };
    watch(document);
})();

// Refresh only the palette stylesheet. Keep Steam pages and games running.
(() => {
    if (window.__md3PaletteLive) return;
    window.__md3PaletteLive = true;
    let current = null;
    let pending = false;
    let generation = 0;
    function refresh() {
        if (pending || document.visibilityState === 'hidden') return;
        pending = true;
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.dataset.md3 = 'palette';
        link.href = `https://millennium.host/v1/themes/md3/src/colors.css?md3=${Date.now()}-${++generation}`;
        let timeout;
        const finish = success => {
            clearTimeout(timeout);
            if (success) {
                const previous = current;
                current = link;
                previous?.remove();
            } else link.remove();
            pending = false;
        };
        link.onload = () => finish(true);
        link.onerror = () => finish(false);
        timeout = setTimeout(() => finish(false), 10000);
        (document.head || document.documentElement).appendChild(link);
    }
    refresh();
    setInterval(refresh, 2500);
    window.addEventListener('focus', refresh);
    document.addEventListener('visibilitychange', refresh);
})();
