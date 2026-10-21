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
