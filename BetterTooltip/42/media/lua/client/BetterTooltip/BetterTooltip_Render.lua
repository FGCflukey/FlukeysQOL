-- Better Tooltip: draws a card model (see BetterTooltip_Data.lua) inside the
-- vanilla ISToolTipInv panel, and hooks ISToolTipInv:render to use it.
--
-- Scaling: PZ draws text from a handful of real font sizes. For a given
-- scale we pick the largest real font that is not bigger than the target
-- size, then zoom only the small remainder (drawTextZoomed) so the text
-- stays crisp. "Sharp text only" skips the zoom entirely. Everything else
-- (icon, bars, spacing) scales freely.

require "ISUI/ISToolTipInv"
require "BetterTooltip/BetterTooltip_Core"
require "BetterTooltip/BetterTooltip_Data"

local BT = BetterTooltip
local C = BT.C

---------------------------------------------------------
-- Fonts
---------------------------------------------------------
local fontList = nil -- { {font=, h=}, ... } sorted by height

local function buildFontList()
    local tm = getTextManager()
    local candidates = { UIFont.NewSmall, UIFont.NewMedium, UIFont.NewLarge }
    if not candidates[1] then candidates = { UIFont.Small, UIFont.Medium, UIFont.Large } end
    local list = {}
    for _, f in ipairs(candidates) do
        if f then
            local h = tonumber(tm:getFontHeight(f)) or 0
            if h > 0 then table.insert(list, { font = f, h = h }) end
        end
    end
    table.sort(list, function(a, b) return a.h < b.h end)
    return list
end

-- Returns { font, zoom, h } drawing text at about `target` px tall.
local function pickFont(target, sharp)
    local best = fontList[1]
    for _, f in ipairs(fontList) do
        if f.h <= target * 1.04 then best = f end
    end
    local zoom = 1
    if not sharp then
        zoom = math.max(0.7, math.min(1.8, target / best.h))
        if math.abs(zoom - 1) < 0.04 then zoom = 1 end
    end
    return { font = best.font, zoom = zoom, h = math.floor(best.h * zoom + 0.5) }
end

local function measure(f, s)
    return (tonumber(getTextManager():MeasureStringX(f.font, s)) or 0) * f.zoom
end

local function drawStr(ui, f, s, x, y, c, a)
    if f.zoom == 1 then
        ui:drawText(s, x, y, c[1], c[2], c[3], a or 1, f.font)
    else
        ui:drawTextZoomed(s, x, y, f.zoom, c[1], c[2], c[3], a or 1, f.font)
    end
end

local function fit(f, s, maxW)
    if measure(f, s) <= maxW then return s end
    local ell = "..."
    while #s > 1 and measure(f, s .. ell) > maxW do
        s = s:sub(1, #s - 1)
    end
    return s .. ell
end

local function wrap(f, text, maxW)
    local lines, cur = {}, ""
    for word in text:gmatch("%S+") do
        local test = cur == "" and word or (cur .. " " .. word)
        if measure(f, test) <= maxW or cur == "" then
            cur = test
        else
            table.insert(lines, cur)
            cur = word
        end
    end
    if cur ~= "" then table.insert(lines, cur) end
    return lines
end

---------------------------------------------------------
-- Layout metrics for the current scale
---------------------------------------------------------
local function metrics()
    -- cheap (3 font-height lookups); rebuilt each time so a font-size
    -- change in the game's Options takes effect immediately
    fontList = buildFontList()
    local S = BT.scale()
    local sharp = BT.sharpText()
    local base = fontList[1].h -- the game's smallest UI font, already honours the player's font-size setting
    local function u(v) return math.max(1, math.floor(v * S + 0.5)) end
    return {
        S = S, u = u,
        body  = pickFont(base * S, sharp),
        small = pickFont(base * S * 0.86, sharp),
        title = pickFont(base * S * 1.3, sharp),
        tileV = pickFont(base * S * 1.1, sharp),
        pad = u(12), gap = u(10), icon = u(48), barH = math.max(3, u(6)),
        minW = u(300), maxW = u(540),
    }
end

---------------------------------------------------------
-- One walk of the card: measures (draw=false) or draws (draw=true).
-- Returns the total height. `w` is the card width.
---------------------------------------------------------
local function walk(ui, model, L, w, draw, shift)
    local u, pad, gap = L.u, L.pad, L.gap
    local cw = w - pad * 2
    local y = pad
    local accent = BT.accent()

    -- Header: icon + title + chips/weight
    local iconX, iconY = pad, pad
    local tx = pad + L.icon + gap
    local tw = w - tx - pad
    local title = fit(L.title, model.title, tw)
    local chipH = L.small.h + u(4)
    local headH = math.max(L.icon, L.title.h + u(6) + chipH)
    if draw then
        ui:drawRect(iconX, iconY, L.icon, L.icon, 1, C.iconBg[1], C.iconBg[2], C.iconBg[3])
        ui:drawRectBorder(iconX, iconY, L.icon, L.icon, 1, C.border[1], C.border[2], C.border[3])
        if model.icon then
            local inset = u(5)
            ui:drawTextureScaledAspect(model.icon, iconX + inset, iconY + inset, L.icon - inset * 2, L.icon - inset * 2, 1, 1, 1, 1)
        end
        drawStr(ui, L.title, title, tx, y, C.title)
    end
    local chipY = y + L.title.h + u(6)
    local cx = tx
    local weightW = 0
    if model.weight then
        local lbl = BT.T("UI_BTT_Weight", "Weight") .. " "
        weightW = measure(L.small, lbl) + measure(L.small, model.weight)
        if draw then
            local wx = w - pad - weightW
            local ty = chipY + u(2)
            drawStr(ui, L.small, lbl, wx, ty, C.label)
            drawStr(ui, L.small, model.weight, wx + measure(L.small, lbl), ty, C.value)
        end
    end
    local chipLimit = w - pad - weightW - u(8)
    for _, chip in ipairs(model.chips) do
        local cwid = measure(L.small, chip) + u(12)
        if cx + cwid > chipLimit then break end
        if draw then
            ui:drawRect(cx, chipY, cwid, chipH, 1, C.chipBg[1], C.chipBg[2], C.chipBg[3])
            drawStr(ui, L.small, chip, cx + u(6), chipY + u(2), C.chipFg)
        end
        cx = cx + cwid + u(5)
    end
    y = y + headH

    -- Main bar (condition / freshness / contents / fluid)
    if model.bar then
        local b = model.bar
        y = y + gap
        if draw then
            drawStr(ui, L.small, b.label, pad, y, C.label)
            local tw2 = measure(L.small, b.text)
            drawStr(ui, L.small, b.text, w - pad - tw2, y, b.textColor or C.value)
        end
        y = y + L.small.h + u(4)
        if draw then
            ui:drawRect(pad, y, cw, L.barH, 1, C.track[1], C.track[2], C.track[3])
            local fw = math.floor(cw * math.max(0, math.min(1, b.frac)) + 0.5)
            if fw > 0 then ui:drawRect(pad, y, fw, L.barH, 1, b.color[1], b.color[2], b.color[3]) end
        end
        y = y + L.barH
    end

    local rowH = L.body.h + u(5)
    local function drawRows(rows)
        for i, r in ipairs(rows) do
            if draw then
                local ty = y + math.floor((rowH - L.body.h) / 2)
                local vw = measure(L.body, r.value)
                local vx = w - pad - vw
                drawStr(ui, L.body, r.value, vx, ty, r.color or C.value)
                local leftMax = vx - pad - u(10)
                if r.delta then
                    local dw = measure(L.small, r.delta)
                    local dx = vx - u(8) - dw
                    drawStr(ui, L.small, r.delta, dx, ty + (L.body.h - L.small.h), r.deltaColor or C.label)
                    leftMax = dx - pad - u(8)
                end
                drawStr(ui, L.body, fit(L.body, r.label, math.max(u(40), leftMax)), pad, ty, C.label)
                if i < #rows then
                    ui:drawRect(pad, y + rowH - 1, cw, 1, 1, C.divider[1], C.divider[2], C.divider[3])
                end
            end
            y = y + rowH
        end
    end

    local function header(text)
        y = y + gap
        if draw then drawStr(ui, L.small, text, pad, y, accent) end
        y = y + L.small.h + u(3)
    end

    for _, s in ipairs(model.sections) do
        header(s.title)
        if s.rows then
            drawRows(s.rows)
        elseif s.tiles then
            local n = #s.tiles
            local tg = u(6)
            local tileW = math.floor((cw - tg * (n - 1)) / n)
            local tileH = L.tileV.h + L.small.h + u(10)
            if draw then
                for i, t in ipairs(s.tiles) do
                    local x = pad + (i - 1) * (tileW + tg)
                    ui:drawRect(x, y, tileW, tileH, 1, C.tileBg[1], C.tileBg[2], C.tileBg[3])
                    local v = fit(L.tileV, t.value, tileW - u(4))
                    drawStr(ui, L.tileV, v, x + (tileW - measure(L.tileV, v)) / 2, y + u(4), C.value)
                    local l = fit(L.small, t.label, tileW - u(4))
                    drawStr(ui, L.small, l, x + (tileW - measure(L.small, l)) / 2, y + u(5) + L.tileV.h, C.label)
                end
            end
            y = y + tileH
        elseif s.icons then
            -- icon grid that wraps; repeats get a small "x2" in the corner
            local size, ig = u(30), u(4)
            local perRow = math.max(1, math.floor((cw + ig) / (size + ig)))
            for i, ic in ipairs(s.icons) do
                local col = (i - 1) % perRow
                local x = pad + col * (size + ig)
                if draw then
                    ui:drawRect(x, y, size, size, 1, C.tileBg[1], C.tileBg[2], C.tileBg[3])
                    ui:drawTextureScaledAspect(ic.tex, x + u(2), y + u(2), size - u(4), size - u(4), 1, 1, 1, 1)
                    if ic.count > 1 then
                        local c = "x" .. ic.count
                        drawStr(ui, L.small, c, x + size - measure(L.small, c) - u(1), y + size - L.small.h, C.value)
                    end
                end
                if col == perRow - 1 or i == #s.icons then y = y + size + ig end
            end
            y = y - ig
        elseif s.list then
            local colGap = u(12)
            local colW = math.floor((cw - colGap) / 2)
            local lineH = L.body.h + u(3)
            for i, e in ipairs(s.list) do
                local col = (i - 1) % 2
                local x = pad + col * (colW + colGap)
                if draw then
                    local countW = e.count ~= "" and measure(L.body, e.count) or 0
                    drawStr(ui, L.body, fit(L.body, e.name, colW - countW - u(6)), x, y, C.value)
                    if countW > 0 then drawStr(ui, L.body, e.count, x + colW - countW, y, C.label) end
                end
                if col == 1 or i == #s.list then y = y + lineH end
            end
        end
    end

    -- Shift for more
    if shift and #model.more > 0 then
        header(BT.T("UI_BTT_Sec_More", "MORE"))
        drawRows(model.more)
    end

    -- Description
    if model.desc and model.desc ~= "" then
        y = y + gap
        if draw then ui:drawRect(pad, y, cw, 1, 1, C.divider[1], C.divider[2], C.divider[3]) end
        y = y + u(8)
        for _, line in ipairs(wrap(L.body, model.desc, cw)) do
            if draw then drawStr(ui, L.body, line, pad, y, C.label) end
            y = y + L.body.h + u(2)
        end
    end

    if not shift and #model.more > 0 then
        y = y + u(8)
        if draw then drawStr(ui, L.small, BT.T("UI_BTT_HoldShift", "Hold Shift for more detail"), pad, y, C.hint) end
        y = y + L.small.h
    end

    return y + pad
end

-- Width the card needs so nothing important gets cut off.
local function neededWidth(model, L, shift)
    local u, pad = L.u, L.pad
    local need = pad + L.icon + L.gap + measure(L.title, model.title) + pad
    local function rowsW(rows)
        for _, r in ipairs(rows) do
            local wv = measure(L.body, r.label) + u(24) + measure(L.body, r.value)
            if r.delta then wv = wv + measure(L.small, r.delta) + u(8) end
            need = math.max(need, pad * 2 + wv)
        end
    end
    for _, s in ipairs(model.sections) do
        if s.rows then rowsW(s.rows) end
        if s.tiles then
            local widest = 0
            for _, t in ipairs(s.tiles) do
                widest = math.max(widest, measure(L.tileV, t.value), measure(L.small, t.label))
            end
            need = math.max(need, pad * 2 + #s.tiles * (widest + u(12)))
        end
    end
    if shift then rowsW(model.more) end
    if model.bar then
        need = math.max(need, pad * 2 + measure(L.small, model.bar.label) + u(24) + measure(L.small, model.bar.text))
    end
    return math.max(L.minW, math.min(L.maxW, math.ceil(need)))
end

---------------------------------------------------------
-- Positioning: same rules as vanilla ISToolTipInv:render
---------------------------------------------------------
local function place(self, w, h)
    local core = getCore()
    local mx, my = getMouseX() + 24, getMouseY() + 24
    if not self.followMouse then
        mx, my = self:getX(), self:getY()
        if self.anchorBottomLeft then mx, my = self.anchorBottomLeft.x, self.anchorBottomLeft.y end
    end
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    local x = math.max(0, math.min(mx, sw - w - 1))
    local y
    if not self.followMouse and self.anchorBottomLeft then
        y = math.max(0, math.min(my - h, sh - h - 1))
    else
        y = math.max(0, math.min(my, sh - h - 1))
    end
    self.tooltip:setX(x)
    self.tooltip:setY(y)
    self:setX(x)
    self:setY(y)
    self:setWidth(w)
    self:setHeight(h)

    if self.contextMenu and self.contextMenu.joyfocus then
        local pn = self.contextMenu.player
        self:setX(getPlayerScreenLeft(pn) + 60)
        self:setY(getPlayerScreenTop(pn) + 60)
    elseif self.contextMenu and self.contextMenu.currentOptionRect then
        if self.contextMenu.currentOptionRect.height > 32 then
            self:setY(my + self.contextMenu.currentOptionRect.height)
        end
        self:adjustPositionToAvoidOverlap(self.contextMenu.currentOptionRect)
    elseif self.followMouse and self.contextMenu == nil then
        self:adjustPositionToAvoidOverlap({ x = mx - 48, y = my - 48, width = 48, height = 48 })
    end
end

---------------------------------------------------------
-- Model cache: the tooltip renders every frame; rebuilding the
-- model (e.g. counting a full backpack) every frame is wasteful.
---------------------------------------------------------
local cache = { item = nil, shift = nil, at = 0, model = nil }
local CACHE_MS = 250

local function now()
    if getTimestampMs then return getTimestampMs() end
    return 0
end

local function getModel(item, player, shift)
    local t = now()
    if cache.item == item and cache.shift == shift and t ~= 0 and t - cache.at < CACHE_MS then
        return cache.model
    end
    local model = BT.Data.build(item, player)
    cache.item, cache.shift, cache.at, cache.model = item, shift, t, model
    return model
end

---------------------------------------------------------
-- Hook
---------------------------------------------------------
local failedTypes = {} -- fullType -> true after an error, so it falls back quietly

local originalRender = ISToolTipInv.render

local function drawBetter(self)
    local item = self.item
    local player = (self.tooltip and BT.call(self.tooltip, "getCharacter")) or getSpecificPlayer(0)
    local shift = BT.shiftHeld()
    local model = getModel(item, player, shift)
    if not model then return false end

    local L = metrics()
    local w = neededWidth(model, L, shift)
    local h = walk(self, model, L, w, false, shift)
    place(self, w, h)

    local bg = C.bg
    self:drawRect(0, 0, w, h, BT.opacity(), bg[1], bg[2], bg[3])
    self:drawRectBorder(0, 0, w, h, 1, C.border[1], C.border[2], C.border[3])
    walk(self, model, L, w, true, shift)
    return true
end

function ISToolTipInv:render()
    -- vanilla draws nothing while a context menu is open; keep that
    if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then
        return originalRender(self)
    end
    local item = self.item
    if not item or not BT.isEnabled() then return originalRender(self) end

    local ft = BT.call(item, "getFullType") or "?"
    if failedTypes[ft] then return originalRender(self) end

    local ok, drewOrErr = pcall(drawBetter, self)
    if ok and drewOrErr then return end
    if not ok then
        failedTypes[ft] = true
        print("[BetterTooltip] error on " .. tostring(ft) .. ", using vanilla tooltip for it: " .. tostring(drewOrErr))
    end
    return originalRender(self)
end

BT.dbg("render hook installed")
