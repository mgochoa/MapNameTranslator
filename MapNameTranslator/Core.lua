local ADDON, ns = ...
local Data = ns.Data

local LOCALES = { "enUS", "esES", "esMX", "frFR", "deDE", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local LOCALE_NAMES = {
    enUS = "English (US)",     esES = "Spanish (Spain)",  esMX = "Spanish (Latin America)",
    frFR = "French",           deDE = "German",           itIT = "Italian",
    ptBR = "Portuguese (Brazil)", ruRU = "Russian",      koKR = "Korean",
    zhCN = "Chinese (Simplified)", zhTW = "Chinese (Traditional)",
}
local CONTINENT_TYPE = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local ACCENT_R, ACCENT_G, ACCENT_B = 12/255, 210/255, 157/255  -- Ellesmere "Forever" green #0CD29D
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local DB

local function Translations(mapID)
    local t = mapID and Data[mapID]
    if not t then return nil end
    local out = {}
    for _, loc in ipairs(LOCALES) do
        if DB.languages[loc] and t[loc] and t[loc] ~= "" then
            out[#out + 1] = { loc = loc, name = t[loc] }
        end
    end
    return (#out > 0) and out or nil
end

-- A stack of lines under an anchor FontString/frame, built lazily as entries arrive.
local function Surface(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetFrameStrata("HIGH")
    local texts = {}
    local font, size, flags
    return {
        holder = holder,
        SetFont = function(f, s, fl) font, size, flags = f, s, fl or "" end,
        Render = function(entries, anchor, dy)
            for i = 1, #texts do texts[i]:Hide() end
            if not entries then return end
            local prefix = (#entries > 1)
            for i, e in ipairs(entries) do
                local t = texts[i]
                if not t then
                    t = holder:CreateFontString(nil, "OVERLAY", "SubZoneTextFont")
                    t:SetFont(font, size, flags)
                    t:SetTextColor(1, 1, 1, 1)
                    t:SetShadowColor(0, 0, 0, 1)
                    t:SetShadowOffset(1, -1)
                    texts[i] = t
                end
                t:SetText(prefix and (e.loc .. "   " .. e.name) or e.name)
                t:ClearAllPoints()
                if i == 1 then
                    t:SetPoint("TOP", anchor, "BOTTOM", 0, dy or -6)
                else
                    t:SetPoint("TOP", texts[i - 1], "BOTTOM", 0, -2)
                end
                t:Show()
            end
        end,
    }
end

-- ---------- surfaces ----------
local underSurface, hoverSurface, minimapSurface
local title, hoverBtn
local areaName, byEN
local lastHoverName
local OpenOptions  -- forward-declared; defined in the options section

local function BuildReverse()
    if byEN then return end
    byEN = {}
    for id in pairs(Data) do
        local info = C_Map.GetMapInfo(id)
        if info and info.name and info.name ~= "" then
            byEN[info.name] = id
        end
    end
end

-- Under the big world-map title.
local function UpdateUnder()
    if not (underSurface and title) then return end
    local entries
    if DB.enabled and DB.showUnder then
        local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
        entries = mapID and Translations(mapID)
    end
    underSurface.Render(entries, title, -6)
end

-- Under the hovered zone's name inside the open map (continent view only).
local function UpdateHover()
    if not hoverSurface then return end
    local entries
    if DB.enabled and DB.showMapHover and lastHoverName and lastHoverName ~= "" then
        local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
        local info = mapID and C_Map.GetMapInfo(mapID)
        if info and info.mapType == CONTINENT_TYPE then
            BuildReverse()
            local id = byEN[lastHoverName]
            entries = id and Translations(id)
        end
    end
    hoverSurface.Render(entries, areaName, -6)
end

-- Current zone's uiMapID. pcall: C_Map.GetBestMapForUnit can crash the client in rare spots.
local function CurrentMapID()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    if ok and type(id) == "number" and id > 0 then return id end
    return nil
end

-- Under the minimap.
local function UpdateMinimap()
    if not (minimapSurface and Minimap) then return end
    local entries
    if DB.enabled and DB.showMinimap then
        entries = Translations(CurrentMapID())
    end
    minimapSurface.Render(entries, Minimap, -4)
end

local function RefreshAll()
    UpdateUnder()
    UpdateHover()
    UpdateMinimap()
end

-- ---------- world-map title tooltip ----------
local function ShowTooltip()
    if not (DB.enabled and DB.showTooltip) then return end
    if not hoverBtn then return end
    local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
    local entries = mapID and Translations(mapID)
    if not entries then return end
    GameTooltip:SetOwner(hoverBtn, "ANCHOR_BOTTOM", 0, -8)
    GameTooltip:AddLine("Map names", 1, 1, 1)
    for _, e in ipairs(entries) do
        GameTooltip:AddLine(e.loc .. "  " .. e.name, 1, 0.82, 0)
    end
    GameTooltip:Show()
end

-- ---------- lazy build of the world-map surfaces ----------
local builtTitle, builtHover = false, false

local function AreaLabel()
    for provider in pairs(WorldMapFrame.dataProviders or {}) do
        local label = provider.Label
        if label and label.Name and label.labelInfoByType then return label end
    end
end

local function BuildTitle()
    if builtTitle then return true end
    if not (WorldMapFrame and WorldMapFrame.BorderFrame) then return false end
    local t = _G.WorldMapFrameTitleText or WorldMapFrame.BorderFrame.TitleText
    if not t then return false end
    builtTitle = true
    title = t
    underSurface = Surface(WorldMapFrame.BorderFrame)
    local f, s, fl = title:GetFont()
    underSurface.SetFont(f or FALLBACK_FONT, math.max(10, math.floor((s or 16) * 0.7 + 0.5)), fl or "")
    hoverBtn = CreateFrame("Button", nil, WorldMapFrame.BorderFrame)
    hoverBtn:SetFrameStrata("HIGH")
    hoverBtn:SetFrameLevel(501)
    hoverBtn:EnableMouse(true)
    hoverBtn:SetPoint("TOPLEFT", title, "TOPLEFT", -8, 8)
    hoverBtn:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 8, -8)
    hoverBtn:SetScript("OnEnter", ShowTooltip)
    hoverBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hooksecurefunc(title, "SetText", UpdateUnder)
    UpdateUnder()
    return true
end

local function BuildHover()
    if builtHover then return true end
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return false end
    local label = AreaLabel()
    if not label then return false end
    builtHover = true
    areaName = label.Name
    hoverSurface = Surface(WorldMapFrame.ScrollContainer)
    hoverSurface.holder:SetAllPoints()
    local f, s, fl = areaName:GetFont()
    hoverSurface.SetFont(f or FALLBACK_FONT, math.max(9, math.floor((s or 16) * 0.55 + 0.5)), fl or "")
    hooksecurefunc(label.Name, "SetText", function(_, name)
        lastHoverName = name
        UpdateHover()
    end)
    return true
end

local function Build()
    local t = BuildTitle()
    local h = BuildHover()
    return t and h
end

local waiter
local retries = 0
local function EnsureBuilt()
    if Build() then return end
    if C_AddOns.IsAddOnLoaded("Blizzard_WorldMap") then
        if retries < 200 then
            retries = retries + 1
            C_Timer.After(0.1, EnsureBuilt)
        end
        return
    end
    if waiter then return end
    waiter = CreateFrame("Frame")
    waiter:SetScript("OnEvent", function(_, _, name)
        if name ~= "Blizzard_WorldMap" then return end
        waiter:UnregisterEvent("ADDON_LOADED")
        waiter = nil
        EnsureBuilt()
    end)
    waiter:RegisterEvent("ADDON_LOADED")
end

-- ---------- minimap surface ----------
local function SetupMinimap()
    if minimapSurface or not Minimap then return end
    minimapSurface = Surface(Minimap)
    local f, s, fl
    if MinimapZoneText then f, s, fl = MinimapZoneText:GetFont() end
    minimapSurface.SetFont(f or FALLBACK_FONT, math.max(9, math.floor((s or 12) * 0.8 + 0.5)), fl or "")
    UpdateMinimap()
end

-- ---------------- options (shared by /mnt config popup and Esc > Options > AddOns) ----------------
local function MakeCheck(parent, label, get, set, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb._get = get
    cb:SetChecked(get() and true or false)
    cb:SetScript("OnClick", function()
        set(cb:GetChecked())
        RefreshAll()
    end)
    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return cb
end

local function SectionLabel(parent, text, y)
    local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", 20, y)
    l:SetTextColor(1, 1, 1, 0.41)  -- Ellesmere TEXT_SECTION
    l:SetText(text)
    return y - 22
end

-- Renders the settings (section labels + checkboxes) into `parent` from the top.
-- Returns a function that re-syncs every checkbox with its current value.
local function BuildOptionsContent(parent, startY)
    local y = startY
    local checks = {}
    local function place(cb)
        checks[#checks + 1] = cb
        cb:SetPoint("TOPLEFT", 26, y)
        y = y - 26
    end
    y = SectionLabel(parent, "Display", y)
    place(MakeCheck(parent, "Enabled", function() return DB.enabled end, function(v) DB.enabled = v end,
        "Master on/off switch."))
    place(MakeCheck(parent, "Show under the map title", function() return DB.showUnder end, function(v) DB.showUnder = v end,
        "Lines under the big world-map title."))
    place(MakeCheck(parent, "Show in the minimap", function() return DB.showMinimap end, function(v) DB.showMinimap = v end,
        "Line under the minimap."))
    place(MakeCheck(parent, "Show on hover in the map", function() return DB.showMapHover end, function(v) DB.showMapHover = v end,
        "Line under the hovered zone's name on the continent map."))
    place(MakeCheck(parent, "Show as tooltip on the title", function() return DB.showTooltip end, function(v) DB.showTooltip = v end,
        "Tooltip when hovering the world-map title."))
    y = y - 8
    y = SectionLabel(parent, "Languages to show", y)
    for _, loc in ipairs(LOCALES) do
        place(MakeCheck(parent, LOCALE_NAMES[loc],
            function() return DB.languages[loc] end,
            function(v) DB.languages[loc] = v or nil end))
    end
    return function()
        for _, cb in ipairs(checks) do
            cb:SetChecked(cb._get() and true or false)
        end
    end
end

local optionsFrame
OpenOptions = function()
    if optionsFrame then
        optionsFrame:Show()
        return
    end
    local f = CreateFrame("Frame", "MapNameTranslatorOptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame = f
    f:SetSize(420, 580)
    f:SetPoint("CENTER")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.069, 0.058, 0.047, 0.96)  -- Ellesmere panel tint (#100d0a family)
    f:SetBackdropBorderColor(1, 1, 1, 0.05)        -- Ellesmere border (white @ 0.05)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 18, -16)
    header:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    header:SetText("MapNameTranslator")

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOPLEFT", 18, -38)
    sub:SetTextColor(1, 1, 1, 0.53)  -- Ellesmere TEXT_DIM
    sub:SetText("Map name translations")

    local rule = f:CreateTexture(nil, "BORDER")
    rule:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 0.7)
    rule:SetPoint("TOPLEFT", 18, -50)
    rule:SetPoint("TOPRIGHT", -18, -50)
    rule:SetHeight(1)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    local refresh = BuildOptionsContent(f, -68)
    f:SetScript("OnShow", refresh)

    local footer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer:SetPoint("BOTTOMLEFT", 18, 12)
    footer:SetTextColor(1, 1, 1, 0.41)  -- Ellesmere TEXT_SECTION
    footer:SetText("v1.0.0  ·  /mnt toggles  ·  /mnt config for options")

    f:Show()
end

-- ---------------- Esc > Options > AddOns (Blizzard Settings) ----------------
local function RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "MapNameTranslator"
    local refresh = BuildOptionsContent(panel, -20)
    panel:SetScript("OnShow", refresh)
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

local settingsFrame = CreateFrame("Frame")
settingsFrame:RegisterEvent("PLAYER_LOGIN")
settingsFrame:SetScript("OnEvent", function()
    settingsFrame:UnregisterEvent("PLAYER_LOGIN")
    RegisterSettings()
end)

-- ---------------- load + slash command ----------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON then return end
    ev:UnregisterEvent("ADDON_LOADED")

    if type(MapNameTranslatorDB) ~= "table" then MapNameTranslatorDB = {} end
    DB = MapNameTranslatorDB
    if DB.enabled == nil then DB.enabled = true end
    if DB.showUnder == nil then DB.showUnder = true end
    if DB.showMinimap == nil then DB.showMinimap = true end
    if DB.showMapHover == nil then DB.showMapHover = true end
    if DB.showTooltip == nil then DB.showTooltip = false end
    if type(DB.languages) ~= "table" then DB.languages = {} end
    -- Default language: Latin-American Spanish (esMX). Older builds defaulted to esES
    -- (Spain); migrate once so the default is esMX only, never both Spanish variants.
    if not DB.langDefaultMigrated then
        DB.langDefaultMigrated = true
        DB.languages.esES = nil
        DB.languages.esMX = true
    end

    SLASH_MAPNAMETRANSLATOR1 = "/mnt"
    SlashCmdList.MAPNAMETRANSLATOR = function(msg)
        msg = strlower(strtrim(msg or ""))
        if msg == "" then
            DB.enabled = not DB.enabled
            DEFAULT_CHAT_FRAME:AddMessage(("|cff0cd29dMapNameTranslator|r: %s"):format(DB.enabled and "enabled" or "disabled"))
            RefreshAll()
        elseif msg == "config" or msg == "options" or msg == "settings" then
            OpenOptions()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29dMapNameTranslator|r: /mnt (toggle)  |  /mnt config (options)")
        end
    end

    SetupMinimap()
    local mm = CreateFrame("Frame")
    mm:RegisterEvent("PLAYER_ENTERING_WORLD")
    mm:RegisterEvent("ZONE_CHANGED")
    mm:SetScript("OnEvent", function()
        SetupMinimap()
        UpdateMinimap()
    end)

    EnsureBuilt()
end)
