# MD3 Shell palette refresh

Matugen writes `src/colors.css` using the selected shell light/dark palette.
`src/md3.js` includes `palette-live.js`, which updates only the palette stylesheet
with a fresh URL every 2.5 seconds while a Steam document is visible. The old
stylesheet stays until the new one has loaded. On failure it keeps the last
working palette. Hidden documents refresh when shown or focused.

After first installing this script, Steam must load the updated theme JavaScript
once (reopen Steam when convenient). Subsequent wallpaper palette changes do
not need client restarts. Pages that block theme JavaScript with their CSP,
such as some Store pages, pick up the generated CSS when reloaded/navigated.
No browser security settings or Steam game processes are changed.
