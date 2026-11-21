local _, ns = ...

local ipairs, wipe, sort, format = ipairs, wipe, table.sort, string.format
local floor, max, min = math.floor, math.max, math.min

local WIDTH, HEIGHT, ROW_H, ICON = 380, 440, 36, 28
local MIN_W, MIN_H, MAX_W, MAX_H = 320, 260, 900, 1200
local HEADER_H, BUTTON_W, BUTTON_H = 26, 38, 20
local BAR_W, THUMB_MIN, GRIP = 4, 24, 14
local frame, scroll, bar, content, summary, empty
local rows, isRow, headers = {}, {}, {}
local contentH, scrollRange = 1, 0

local UI = ns.UI
local C = UI.C
local Hex, Tint, Fill, Solid, Skin = UI.Hex, UI.Tint, UI.Fill, UI.Solid, UI.Skin
local ApplyFont = UI.ApplyFont

local HERE_TAG = " " .. Hex(C.success) .. "here|r"
local BANK_TAG = " " .. Hex(C.muted) .. "(bank)|r"

local function Clamp(v, lo, hi)
    return max(lo, min(hi, v))
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

local function SaveSize()
    BagBloatDB = BagBloatDB or {}
    BagBloatDB.size = { floor(frame:GetWidth() + 0.5), floor(frame:GetHeight() + 0.5) }
end

local function RestoreSize()
    local s = BagBloatDB and BagBloatDB.size
    local w = s and tonumber(s[1]) or WIDTH
    local h = s and tonumber(s[2]) or HEIGHT
    frame:SetSize(Clamp(w, MIN_W, MAX_W), Clamp(h, MIN_H, MAX_H))
end

function ns.IsRow(f)
    return isRow[f] == true
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
    Fill(hl, C.surfaceHover)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, 0)
    ApplyFont(row.count, 12)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("TOPRIGHT", -6, -5)
    row.status:SetJustifyH("RIGHT")
    ApplyFont(row.status, 12)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    ApplyFont(row.name, 14)

    row.quest = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.quest:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.quest:SetPoint("RIGHT", -6, 0)
    row.quest:SetJustifyH("LEFT")
    row.quest:SetWordWrap(false)
    Tint(row.quest, C.muted)
    ApplyFont(row.quest, 12)

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
    row.name:SetText(rec.inBank and name .. BANK_TAG or name)
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

local function ButtonOnClick(button)
    local g = button.group
    if g then ns.MoveRecords(g.recs, button.toBank) end
end

local function CreateButton(parent, label, toBank)
    local button = UI.Button(parent, label, BUTTON_W, BUTTON_H)
    button.toBank = toBank
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
    if reason then
        button.tip = reason
    else
        button.tip = format(button.toBank and "Move %d to the bank" or "Move %d to your bags", count)
    end
    UI.SetEnabled(button, reason == nil)
end

local function CreateHeader()
    local h = CreateFrame("Frame", nil, content)
    h:SetHeight(HEADER_H)

    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Fill(bg, C.surface)

    local line = Solid(h, "BORDER", C.divider)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)

    h.take = CreateButton(h, "Take", false)
    h.take:SetPoint("RIGHT", -4, 0)
    h.bank = CreateButton(h, "Bank", true)
    h.bank:SetPoint("RIGHT", h.take, "LEFT", -3, 0)

    h.count = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.count:SetJustifyH("RIGHT")
    Tint(h.count, C.muted)
    ApplyFont(h.count, 12)

    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", 6, 0)
    h.title:SetPoint("RIGHT", h.count, "LEFT", -6, 0)
    h.title:SetJustifyH("LEFT")
    h.title:SetWordWrap(false)
    Tint(h.title, C.text)
    ApplyFont(h.title, 14)
    return h
end

local function FillHeader(h, g)
    h.title:SetText(g.here and g.title .. HERE_TAG or g.title)
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

-- The bar shows only when the content is taller than the view. Called after a
-- refresh and whenever the scroll frame changes size.
local function UpdateScroll()
    if not (scroll and bar) then return end
    local view = scroll:GetHeight()
    scrollRange = max(0, contentH - view)
    if scrollRange <= 0 then
        bar:Hide()
        bar:SetMinMaxValues(0, 0)
        bar:SetValue(0)
        scroll:SetVerticalScroll(0)
        return
    end
    local track = bar:GetHeight()
    bar.thumb:SetHeight(Clamp(track * view / contentH, THUMB_MIN, max(THUMB_MIN, track)))
    bar:SetMinMaxValues(0, scrollRange)
    local offset = min(scroll:GetVerticalScroll(), scrollRange)
    scroll:SetVerticalScroll(offset)
    bar:SetValue(offset)
    bar:Show()
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
    contentH = max(y, 1)
    content:SetHeight(contentH)
    UpdateScroll()
    empty:SetShown(#records == 0)
    if #records == 0 then
        summary:SetText("")
    elseif ns.safeCount == 0 then
        summary:SetFormattedText("%d quest items, none safe to delete", #records)
    else
        summary:SetFormattedText("%d of %d quest items safe to delete", ns.safeCount, #records)
    end
end

local function PaintCheck(check)
    local on = check:GetChecked() and true or false
    if on then
        Skin(check, C.accent, C.accent)
    else
        Skin(check, C.clear, check.hover and C.borderHover or C.border)
    end
    check.mark:SetShown(on)
    Tint(check.label, check.hover and C.text or C.muted)
end

local function CheckOnEnter(check)
    check.hover = true
    PaintCheck(check)
end

local function CheckOnLeave(check)
    check.hover = false
    PaintCheck(check)
end

local function OnZoneToggle(check)
    BagBloatDB = BagBloatDB or {}
    BagBloatDB.byZone = check:GetChecked() and true or false
    PaintCheck(check)
    ns.RefreshWindow()
end

local function CreateCheck(close)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("RIGHT", close, "LEFT", -10, 0)
    label:SetText("By zone")
    ApplyFont(label, 13)

    -- A bare CheckButton: no template, so the only art is what is drawn here.
    local check = CreateFrame("CheckButton", nil, frame, "BackdropTemplate")
    check:SetSize(16, 16)
    check:SetPoint("RIGHT", label, "LEFT", -6, 0)
    UI.Panel(check, C.clear)
    check:SetHitRectInsets(0, -(label:GetStringWidth() + 6), 0, 0)
    check.label = label
    check.mark = Solid(check, "OVERLAY", C.mark)
    check.mark:SetSize(6, 6)
    check.mark:SetPoint("CENTER")
    check:SetChecked(ByZone())
    PaintCheck(check)
    check:SetScript("OnEnter", CheckOnEnter)
    check:SetScript("OnLeave", CheckOnLeave)
    check:SetScript("OnHide", CheckOnLeave)
    check:SetScript("OnClick", OnZoneToggle)
    return check
end

local function PaintGrip(grip)
    local c = grip.hover and C.text or C.faint
    for _, dot in ipairs(grip.dots) do Fill(dot, c) end
end

local function CreateGrip()
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP, GRIP)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip.dots = {}
    for i = 0, 2 do
        local dot = grip:CreateTexture(nil, "OVERLAY")
        dot:SetSize(2, 2)
        dot:SetPoint("BOTTOMRIGHT", -1 - i * 4, 1 + i * 4)
        grip.dots[#grip.dots + 1] = dot
    end
    PaintGrip(grip)
    grip:SetScript("OnEnter", function(self)
        self.hover = true
        PaintGrip(self)
    end)
    local function Leave(self)
        self.hover = false
        PaintGrip(self)
    end
    grip:SetScript("OnLeave", Leave)
    grip:SetScript("OnHide", Leave)
    grip:SetScript("OnMouseDown", function()
        -- Pin the top-left corner so the window grows toward the grip, not from its center.
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveSize()
        SavePosition()
    end)
    return grip
end

local function PaintBar()
    Fill(bar.thumb, (bar.hover or bar.drag) and C.muted or C.faint)
end

local function CreateBar()
    bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:EnableMouse(true)
    bar:SetWidth(BAR_W)
    bar:SetPoint("TOPRIGHT", -6, -54)
    bar:SetPoint("BOTTOMRIGHT", -6, 22)
    bar:SetHitRectInsets(-4, -4, 0, 0)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local track = Solid(bar, "BACKGROUND", C.divider)
    track:SetAllPoints()

    bar.thumb = bar:CreateTexture(nil, "OVERLAY")
    bar.thumb:SetSize(BAR_W, THUMB_MIN)
    bar:SetThumbTexture(bar.thumb)
    PaintBar()

    bar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
    bar:SetScript("OnEnter", function(self)
        self.hover = true
        PaintBar()
    end)
    bar:SetScript("OnLeave", function(self)
        self.hover = false
        PaintBar()
    end)
    bar:SetScript("OnMouseDown", function(self)
        self.drag = true
        PaintBar()
    end)
    bar:SetScript("OnMouseUp", function(self)
        self.drag = false
        PaintBar()
    end)
    bar:SetScript("OnHide", function(self)
        self.hover, self.drag = false, false
        PaintBar()
    end)
    bar:Hide()
end

local function OnWheel(_, delta)
    scroll:SetVerticalScroll(Clamp(scroll:GetVerticalScroll() - delta * ROW_H, 0, scrollRange))
end

local function CreateWindow()
    frame = CreateFrame("Frame", "BagBloatFrame", UIParent, "BackdropTemplate")
    RestoreSize()
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    else
        frame:SetMinResize(MIN_W, MIN_H)
        frame:SetMaxResize(MAX_W, MAX_H)
    end
    frame:SetDontSavePosition(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:SetScript("OnMouseWheel", OnWheel)
    UI.Panel(frame)
    RestorePosition()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Bag Bloat")
    Tint(title, C.text)
    ApplyFont(title, 17)

    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    summary:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(false)
    Tint(summary, C.muted)
    ApplyFont(summary, 13)

    local divider = Solid(frame, "BORDER", C.divider)
    divider:SetPoint("TOPLEFT", 1, -48)
    divider:SetPoint("TOPRIGHT", -1, -48)
    divider:SetHeight(1)

    CreateCheck(UI.CloseButton(frame))

    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 8, -54)
    scroll:SetPoint("BOTTOMRIGHT", -16, 8)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 24, 1)
    scroll:SetScrollChild(content)

    CreateBar()
    scroll:SetScript("OnVerticalScroll", function(_, offset) bar:SetValue(offset) end)
    scroll:SetScript("OnSizeChanged", function(_, w)
        content:SetWidth(w)
        UpdateScroll()
    end)

    CreateGrip()

    empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER", scroll, "CENTER")
    empty:SetText("No quest items in your bags.")
    Tint(empty, C.muted)
    ApplyFont(empty, 13)

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
