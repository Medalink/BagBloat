local _, ns = ...

local ipairs, wipe, sort, format = ipairs, wipe, table.sort, string.format

local WIDTH, HEIGHT, ROW_H, ICON = 380, 440, 36, 28
local HEADER_H, BUTTON_W, BUTTON_H = 26, 38, 18
local FLAT = "Interface\\Buttons\\WHITE8X8"
local frame, content, summary, empty
local rows, isRow, headers = {}, {}, {}
local fontPath

-- Expressway, when EllesmereUI or SharedMedia has it; resolved once.
local function ResolveFont()
    if EllesmereUI and EllesmereUI.EXPRESSWAY then return EllesmereUI.EXPRESSWAY end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return lsm and lsm:Fetch("font", "Expressway", true)
end

function ns.ApplyFont(fs)
    if not fontPath then return end
    local _, size, flags = fs:GetFont()
    if size then fs:SetFont(fontPath, size, flags) end
end

local function ByZone()
    return not (BagBloatDB and BagBloatDB.byZone == false)
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    BagBloatDB = BagBloatDB or {}
    BagBloatDB.point = { point, relPoint, x, y }
end

local function RestorePosition()
    frame:ClearAllPoints()
    local p = BagBloatDB and BagBloatDB.point
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER")
    end
end

function ns.IsRow(frame)
    return isRow[frame] == true
end

function ns.ShowRowTooltip(row)
    local rec = row.rec
    if not rec then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(rec.bag, rec.slot)
    GameTooltip:AddLine("Click to pick up", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function RowOnClick(row)
    local rec = row.rec
    if not rec then return end
    if IsModifiedClick() and rec.link and HandleModifiedItemClick(rec.link) then return end
    ns.PickUp(rec)
end

-- Rows and headers sit in one column; y is how far below the top of content.
local function Place(f, y)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    f:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
end

local function CreateRow()
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    isRow[row] = true

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", 4, 0)

    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, 0)
    ns.ApplyFont(row.count)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("TOPRIGHT", -6, -5)
    row.status:SetJustifyH("RIGHT")
    ns.ApplyFont(row.status)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    ns.ApplyFont(row.name)

    row.quest = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.quest:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.quest:SetPoint("RIGHT", -6, 0)
    row.quest:SetJustifyH("LEFT")
    row.quest:SetWordWrap(false)
    ns.ApplyFont(row.quest)

    row:SetScript("OnEnter", ns.ShowRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", RowOnClick)
    return row
end

local function FillRow(row, rec)
    row.rec = rec
    row.icon:SetTexture(rec.icon)
    row.count:SetText(rec.count and rec.count > 1 and rec.count or "")
    local name = rec.name ~= "" and rec.name or rec.link or "?"
    row.name:SetText(rec.inBank and name .. " |cff808080(bank)|r" or name)
    local r, g, b = C_Item.GetItemQualityColor(rec.quality or 1)
    row.name:SetTextColor(r or 1, g or 1, b or 1)
    local v = ns.VERDICTS[rec.verdict]
    row.status:SetText(v.label)
    row.status:SetTextColor(v.r, v.g, v.b)
    row.quest:SetText(rec.questText or "")
end

-- Groups. The tables are pooled: a refresh reuses them and builds no new ones.
local groupPool, groupUsed = {}, 0
local zoneGroup, zoneList, groups = {}, {}, {}
local otherGroup, safeGroup

local function NewGroup(title, kind)
    groupUsed = groupUsed + 1
    local g = groupPool[groupUsed]
    if not g then
        g = { recs = {} }
        groupPool[groupUsed] = g
    end
    g.title, g.kind, g.here = title, kind, false
    g.bagCount, g.bankCount = 0, 0
    wipe(g.recs)
    return g
end

local function ZoneOrder(a, b)
    if a.here ~= b.here then return a.here end
    return a.title < b.title
end

local function MapZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name
end

local function BuildGroups(records)
    groupUsed = 0
    otherGroup, safeGroup = nil, nil
    wipe(zoneGroup); wipe(zoneList); wipe(groups)
    for _, rec in ipairs(records) do
        local g
        if rec.zone then
            g = zoneGroup[rec.zone]
            if not g then
                g = NewGroup(rec.zone, "zone")
                zoneGroup[rec.zone] = g
                zoneList[#zoneList + 1] = g
            end
        elseif ns.VERDICTS[rec.verdict].safe then
            safeGroup = safeGroup or NewGroup("Safe to delete", "safe")
            g = safeGroup
        else
            otherGroup = otherGroup or NewGroup("Not in your quest log", "other")
            g = otherGroup
        end
        g.recs[#g.recs + 1] = rec
        if rec.inBank then
            g.bankCount = g.bankCount + 1
        else
            g.bagCount = g.bagCount + 1
        end
    end

    if #zoneList > 0 then
        local real, zone, map = GetRealZoneText(), GetZoneText(), MapZone()
        for _, g in ipairs(zoneList) do
            local t = g.title
            g.here = (t == real or t == zone or t == map) and t ~= ""
        end
        sort(zoneList, ZoneOrder)
    end
    for _, g in ipairs(zoneList) do groups[#groups + 1] = g end
    if otherGroup then groups[#groups + 1] = otherGroup end
    if safeGroup then groups[#groups + 1] = safeGroup end
end

local function ButtonOnEnter(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.tip or "", 1, 1, 1)
    GameTooltip:Show()
end

local function ButtonOnClick(button)
    local g = button.group
    if g then ns.MoveRecords(g.recs, button.toBank) end
end

local function CreateButton(parent, label, toBank)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(BUTTON_W, BUTTON_H)
    button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    button:SetBackdropColor(0.14, 0.14, 0.16, 1)
    button:SetBackdropBorderColor(0.3, 0.3, 0.34, 1)
    button.toBank = toBank

    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.1)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    ns.ApplyFont(button.label)

    -- A disabled button still needs to explain itself.
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", ButtonOnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", ButtonOnClick)
    return button
end

local function FillButton(button, g, count)
    local reason
    if not ns.bankOpen then
        reason = "Open your bank"
    elseif InCombatLockdown() or UnitAffectingCombat("player") then
        reason = "In combat"
    elseif ns.moving then
        reason = "Moving items"
    elseif count == 0 then
        reason = "Nothing to move"
    end
    button.group = g
    button:SetEnabled(reason == nil)
    if reason then
        button.label:SetTextColor(0.5, 0.5, 0.5)
        button.tip = reason
    else
        button.label:SetTextColor(1, 0.82, 0)
        button.tip = format(button.toBank and "Move %d to the bank" or "Move %d to your bags", count)
    end
end

local function CreateHeader()
    local h = CreateFrame("Frame", nil, content)
    h:SetHeight(HEADER_H)

    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.05)

    h.take = CreateButton(h, "Take", false)
    h.take:SetPoint("RIGHT", -4, 0)
    h.bank = CreateButton(h, "Bank", true)
    h.bank:SetPoint("RIGHT", h.take, "LEFT", -3, 0)

    h.count = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.count:SetJustifyH("RIGHT")
    ns.ApplyFont(h.count)

    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", 6, 0)
    h.title:SetPoint("RIGHT", h.count, "LEFT", -6, 0)
    h.title:SetJustifyH("LEFT")
    h.title:SetWordWrap(false)
    ns.ApplyFont(h.title)
    return h
end

local function FillHeader(h, g)
    h.title:SetText(g.here and g.title .. " |cff4dd966here|r" or g.title)
    local n = #g.recs
    local word = n == 1 and "item" or "items"
    if g.bankCount > 0 then
        h.count:SetFormattedText("%d %s, %d in bank", n, word, g.bankCount)
    else
        h.count:SetFormattedText("%d %s", n, word)
    end
    h.count:ClearAllPoints()
    if g.kind == "safe" then
        h.bank:Hide()
        h.take:Hide()
        h.count:SetPoint("RIGHT", h, "RIGHT", -6, 0)
    else
        FillButton(h.bank, g, g.bagCount)
        FillButton(h.take, g, g.bankCount)
        h.bank:Show()
        h.take:Show()
        h.count:SetPoint("RIGHT", h.bank, "LEFT", -6, 0)
    end
end

local function ShowRow(n, rec, y)
    local row = rows[n]
    if not row then
        row = CreateRow()
        rows[n] = row
    end
    FillRow(row, rec)
    Place(row, y)
    row:Show()
    return y + ROW_H
end

function ns.RefreshWindow()
    if not ns.IsWindowShown() then return end
    local records = ns.Get()
    local y, rowN, headN = 0, 0, 0
    if ByZone() then
        BuildGroups(records)
        for _, g in ipairs(groups) do
            headN = headN + 1
            local h = headers[headN]
            if not h then
                h = CreateHeader()
                headers[headN] = h
            end
            FillHeader(h, g)
            Place(h, y)
            h:Show()
            y = y + HEADER_H
            for _, rec in ipairs(g.recs) do
                rowN = rowN + 1
                y = ShowRow(rowN, rec, y)
            end
        end
    else
        for _, rec in ipairs(records) do
            rowN = rowN + 1
            y = ShowRow(rowN, rec, y)
        end
    end
    for i = headN + 1, #headers do
        headers[i].bank.group, headers[i].take.group = nil, nil
        headers[i]:Hide()
    end
    for i = rowN + 1, #rows do
        rows[i].rec = nil
        rows[i]:Hide()
    end
    content:SetHeight(math.max(y, 1))
    empty:SetShown(#records == 0)
    if #records == 0 then
        summary:SetText("")
    elseif ns.safeCount == 0 then
        summary:SetFormattedText("%d quest items, none safe to delete", #records)
    else
        summary:SetFormattedText("%d of %d quest items safe to delete", ns.safeCount, #records)
    end
end

local function OnZoneToggle(check)
    BagBloatDB = BagBloatDB or {}
    BagBloatDB.byZone = check:GetChecked() and true or false
    ns.RefreshWindow()
end

local function CreateWindow()
    fontPath = ResolveFont()
    frame = CreateFrame("Frame", "BagBloatFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    frame:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
    frame:SetBackdropBorderColor(0.22, 0.22, 0.25, 1)
    RestorePosition()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Bag Bloat")
    ns.ApplyFont(title)

    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ns.ApplyFont(summary)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    local zoneLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneLabel:SetPoint("RIGHT", close, "LEFT", 2, 0)
    zoneLabel:SetText("By zone")
    ns.ApplyFont(zoneLabel)

    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check:SetPoint("RIGHT", zoneLabel, "LEFT", -2, 0)
    check:SetHitRectInsets(0, -(zoneLabel:GetStringWidth() + 4), 0, 0)
    check:SetChecked(ByZone())
    check:SetScript("OnClick", OnZoneToggle)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -52)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 36, 1)
    scroll:SetScrollChild(content)

    empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER", scroll, "CENTER")
    empty:SetText("No quest items in your bags.")
    ns.ApplyFont(empty)

    frame:SetScript("OnShow", ns.RefreshWindow)
    tinsert(UISpecialFrames, "BagBloatFrame")
    frame:Hide()
end

function ns.IsWindowShown()
    return frame ~= nil and frame:IsShown()
end

function ns.ToggleWindow()
    if not frame then CreateWindow() end
    frame:SetShown(not frame:IsShown())
end
