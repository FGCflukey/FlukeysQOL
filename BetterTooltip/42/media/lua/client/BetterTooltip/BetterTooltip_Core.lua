-- Better Tooltip: shared helpers + Mod Options.
-- Client-only, display-only: nothing here touches items or talks to the server.

BetterTooltip = BetterTooltip or {}
local BT = BetterTooltip

local DEBUG = true
function BT.dbg(...)
    if DEBUG then print("[BetterTooltip]", ...) end
end

---------------------------------------------------------
-- Safe method call. Item classes differ a lot between item
-- types and builds; a missing or throwing getter returns nil
-- instead of breaking the tooltip.
---------------------------------------------------------
-- A Java exception caught by pcall is STILL written to console.txt as a
-- full stack trace, and the tooltip draws every frame -- so a getter that
-- throws once is remembered (per item type + method) and never retried.
local badCalls = {}

function BT.call(obj, method, ...)
    if obj == nil then return nil end
    local f = obj[method]
    if type(f) ~= "function" then return nil end
    local key = nil
    local okT, ft = pcall(function() return obj.getFullType and obj:getFullType() end)
    key = tostring(okT and ft or "?") .. ":" .. method
    if badCalls[key] then return nil end
    local ok, result = pcall(f, obj, ...)
    if ok then return result end
    badCalls[key] = true
    print("[BetterTooltip] " .. method .. " failed on " .. tostring(okT and ft or "?") .. ", skipping it from now on: " .. tostring(result))
    return nil
end

function BT.num(v)
    if type(v) == "number" then return v end
    return tonumber(v)
end

-- Translation with a fallback, so a missing key never shows as "UI_BTT_..."
function BT.T(key, fallback, ...)
    local s = getText(key, ...)
    if s == nil or s == key then
        s = fallback or key
        local args = { ... }
        for i = 1, #args do
            s = s:gsub("%%" .. i, tostring(args[i]))
        end
    end
    return s
end

-- Number formatting: at most `dec` decimals, trailing zeros trimmed.
function BT.fmt(n, dec)
    n = BT.num(n)
    if not n then return "?" end
    dec = dec or 1
    local s = string.format("%." .. dec .. "f", n)
    if dec > 0 then
        s = s:gsub("0+$", ""):gsub("%.$", "")
    end
    if s == "-0" then s = "0" end
    return s
end

-- Signed value. Plain ASCII only: PZ's bitmap fonts may lack
-- typographic glyphs (true minus, en dash, multiplication sign).
function BT.signed(n, dec)
    n = BT.num(n)
    if not n then return "" end
    local s = BT.fmt(math.abs(n), dec)
    if n > 0 then return "+" .. s end
    if n < 0 then return "-" .. s end
    return s
end

-- Many stats come either as a 0..1 fraction or as 0..100. Show as percent.
function BT.pct(v)
    v = BT.num(v)
    if not v then return nil end
    if math.abs(v) <= 1 then v = v * 100 end
    return v
end

-- "UpperBody" / "base:UpperBody" -> "Upper Body"
function BT.pretty(s)
    if s == nil then return nil end
    s = tostring(s)
    s = s:gsub("^.*:", "")
    s = s:gsub("_", " ")
    s = s:gsub("(%l)(%u)", "%1 %2")
    return s
end

function BT.shiftHeld()
    return isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)
end

---------------------------------------------------------
-- Colours (r, g, b)
---------------------------------------------------------
BT.C = {
    bg      = { 0.082, 0.094, 0.114 },
    border  = { 0.176, 0.200, 0.235 },
    divider = { 0.122, 0.141, 0.169 },
    label   = { 0.663, 0.698, 0.737 },
    value   = { 0.933, 0.945, 0.957 },
    title   = { 0.957, 0.965, 0.973 },
    hint    = { 0.498, 0.533, 0.576 },
    chipBg  = { 0.145, 0.173, 0.208 },
    chipFg  = { 0.788, 0.820, 0.855 },
    iconBg  = { 0.125, 0.145, 0.176 },
    track   = { 0.149, 0.173, 0.204 },
    tileBg  = { 0.114, 0.133, 0.161 },
    good    = { 0.373, 0.761, 0.541 },
    bad     = { 0.910, 0.455, 0.424 },
    warn    = { 0.878, 0.639, 0.231 },
    barGood = { 0.310, 0.702, 0.478 },
    barWarn = { 0.878, 0.639, 0.231 },
    barBad  = { 0.851, 0.329, 0.302 },
    barFluid= { 0.357, 0.608, 0.835 },
}

-- Bar colour from a 0..1 "how good" fraction.
function BT.barColor(frac)
    if frac >= 0.6 then return BT.C.barGood end
    if frac >= 0.3 then return BT.C.barWarn end
    return BT.C.barBad
end

---------------------------------------------------------
-- Mod Options (PZAPI.ModOptions: the B42 API for mod settings)
---------------------------------------------------------
local OPT_ID = "BetterTooltip"
BT.opts = nil
BT.runtimeOff = false -- toggled by the hotkey, not saved

local function initOptions()
    if BT.opts or not (PZAPI and PZAPI.ModOptions) then return end
    local o = PZAPI.ModOptions:create(OPT_ID, "UI_BTT_ModName")
    BT.opts = {
        enabled   = o:addTickBox("enabled", "UI_BTT_Enabled", true, "UI_BTT_Enabled_Tip"),
        scale     = o:addSlider("scale", "UI_BTT_Scale", 0.6, 1.8, 0.05, 1.0, "UI_BTT_Scale_Tip"),
        sharp     = o:addTickBox("sharpText", "UI_BTT_SharpText", false, "UI_BTT_SharpText_Tip"),
        opacity   = o:addSlider("opacity", "UI_BTT_Opacity", 0.5, 1.0, 0.05, 0.95, "UI_BTT_Opacity_Tip"),
        accent    = o:addColorPicker("accent", "UI_BTT_Accent", 0.910, 0.639, 0.239, 1.0, "UI_BTT_Accent_Tip"),
        compare   = o:addTickBox("compare", "UI_BTT_Compare", true, "UI_BTT_Compare_Tip"),
        toggleKey = o:addKeyBind("toggleKey", "UI_BTT_ToggleKey", 0, "UI_BTT_ToggleKey_Tip"),
    }
end
initOptions()

local function optVal(name, fallback)
    local o = BT.opts and BT.opts[name]
    if not o then return fallback end
    local v = o:getValue()
    if v == nil then return fallback end
    return v
end

function BT.isEnabled()
    return optVal("enabled", true) and not BT.runtimeOff
end
function BT.scale()
    local s = BT.num(optVal("scale", 1.0)) or 1.0
    return math.max(0.5, math.min(2.0, s))
end
function BT.sharpText() return optVal("sharp", false) == true end
function BT.opacity() return BT.num(optVal("opacity", 0.95)) or 0.95 end
function BT.compareOn() return optVal("compare", true) == true end
function BT.accent()
    local c = optVal("accent", nil)
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    return { 0.910, 0.639, 0.239 }
end

local function onKeyPressed(key)
    local bind = optVal("toggleKey", 0)
    if bind and bind ~= 0 and key == bind then
        BT.runtimeOff = not BT.runtimeOff
        BT.dbg("Toggled, now " .. (BT.runtimeOff and "vanilla" or "Better Tooltip"))
    end
end

Events.OnGameBoot.Add(initOptions)
Events.OnKeyPressed.Add(onKeyPressed)
