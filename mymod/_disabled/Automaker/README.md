# Automaker (temporarily disabled)

Pulled out of `mymod/42/media/...` on 2026-09-18 to try the Workshop mod at
https://steamcommunity.com/sharedfiles/filedetails/?id=3631390083 instead.
Moved here (outside `media/`) rather than deleted, so it's inert but not lost.

Left in place and unaffected (harmless if Automaker never loads):
- `mymod/42/media/sandbox-options.txt` — `Automaker.fullbuild` option
- `mymod/42/media/lua/shared/Translate/EN/Sandbox.json` — its translation strings
- `mymod/42/media/lua/shared/Translate/EN/Tooltip.json` — the 3 magazine tooltips

## To restore

```
git mv mymod/_disabled/Automaker/client/Automaker        mymod/42/media/lua/client/Automaker
git mv mymod/_disabled/Automaker/server/Automaker         mymod/42/media/lua/server/Automaker
git mv mymod/_disabled/Automaker/server/Automaker_Distributions.lua mymod/42/media/lua/server/items/Automaker_Distributions.lua
git mv mymod/_disabled/Automaker/shared/Automaker         mymod/42/media/lua/shared/Automaker
git mv mymod/_disabled/Automaker/scripts/Automaker_Items.txt mymod/42/media/scripts/items/Automaker_Items.txt
git rm mymod/_disabled/Automaker/README.md
```

Porting history and confirmation it worked (as of 2026-09-12) is recorded in
Claude's memory under `project_automaker_port`.
