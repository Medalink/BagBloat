local _, ns = ...

local ipairs, wipe, sort, format = ipairs, wipe, table.sort, string.format
local floor, max, min, rad = math.floor, math.max, math.min, math.rad

local WIDTH, HEIGHT, ROW_H, ICON = 380, 440, 36, 28
local MIN_W, MIN_H, MAX_W, MAX_H = 320, 260, 900, 1200
local HEADER_H, BUTTON_W, BUTTON_H = 26, 38, 20
local BAR_W, THUMB_MIN, GRIP = 4, 24, 14
local FLAT = "Interface\\Buttons\\WHITE8X8"
local frame, scroll, bar, content, summary, empty
local rows, isRow, headers = {}, {}, {}
local fontPath
local contentH, scrollRange = 1, 0

-- Signal graphite values, copied from the Meda palette. Bag Bloat loads no Meda code.
local C = {
    bg = { 0.059, 0.059, 0.059, 1 },
    surface = { 1, 1, 1, 0.021 },
    surfaceHover = { 1, 1, 1, 0.064 },
    clear = { 1, 1, 1, 0 },
    border = { 1, 1, 1, 0.171 },
    borderHover = { 0.545, 0.545, 0.545, 1 },
    divider = { 1, 1, 1, 0.107 },
    text = { 0.961, 0.961, 0.961, 1 },
    muted = { 0.678, 0.678, 0.678, 1 },
    section = { 0.6, 0.6, 0.6, 1 },
    faint = { 0.545, 0.545, 0.545, 1 },
    accent = { 0, 0.831, 1, 1 },
    mark = { 0.059, 0.059, 0.059, 1 },
    success = { 0, 1, 0.533, 1 },
}

local function Hex(c)
    return format("|cff%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

local HERE_TAG = " " .. Hex(C.success) .. "here|r"
local BANK_TAG = " " .. Hex(C.muted) .. "(bank)|r"

local function Tint(fs, c)
    fs:SetTextColor(c[1], c[2], c[3], c[4])
end

local function Fill(tex, c)
    tex:SetColorTexture(c[1], c[2], c[3], c[4])
end

local function Solid(parent, layer, c)
    local tex = parent:CreateTexture(nil, layer)
    Fill(tex, c)
    return tex
end

local function Skin(f, fill, edge)
    f:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
    f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

local function Clamp(v, lo, hi)
    return max(lo, min(hi, v))
end

-- Expressway, when EllesmereUI or SharedMedia has it; resolved once.
local function ResolveFont()
    if EllesmereUI and EllesmereUI.EXPRESSWAY then return EllesmereUI.EXPRESSWAY end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return lsm and lsm:Fetch("font", "Expressway", true)
end

-- With Expressway the text takes the Meda role size; without it the template font stays.
function ns.ApplyFont(fs, size)
    if not fontPath then return end
    local _, current, flags = fs:GetFont()
    if current then fs:SetFont(fontPath, size or current, flags) end
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
    ns.ApplyFont(row.count, 12)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("TOPRIGHT", -6, -5)
    row.status:SetJustifyH("RIGHT")
    ns.ApplyFont(row.status, 12)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    ns.ApplyFont(row.name, 14)

    row.quest = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.quest:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.quest:SetPoint("RIGHT", -6, 0)
    row.quest:SetJustifyH("LEFT")
    row.quest:SetWordWrap(false)
    Tint(row.quest, C.muted)
    ns.ApplyFont(row.quest, 12)

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

-- Flat button: clear fill, border color, brighter border on hover, raised fill while pressed.
local function PaintButton(button)
    local edge = (button.hover and button:IsEnabled()) and C.borderHover or C.border
    Skin(button, button.down and C.surfaceHover or C.clear, edge)
end

local function ButtonOnEnter(button)
    button.hover = true
    PaintButton(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.tip or "", 1, 1, 1)
    GameTooltip:Show()
end

local function ButtonOnLeave(button)
    button.hover, button.down = false, false
    PaintButton(button)
    if GameTooltip:GetOwner() == button then GameTooltip_Hide() end
end

local function ButtonOnDown(button)
    if not button:IsEnabled() then return end
    button.down = true
    PaintButton(button)
end

local function ButtonOnUp(button)
    button.down = false
    PaintButton(button)
end

local function ButtonOnClick(button)
    local g = button.group
    if g then ns.MoveRecords(g.recs, button.toBank) end
end

local function CreateButton(parent, label, toBank)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(BUTTON_W, BUTTON_H)
    button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    button.toBank = toBank
    PaintButton(button)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    Tint(button.label, C.text)
    ns.ApplyFont(button.label, 12)

    -- A disabled button still needs to explain itself.
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", ButtonOnEnter)
    button:SetScript("OnLeave", ButtonOnLeave)
    button:SetScript("OnMouseDown", ButtonOnDown)
    button:SetScript("OnMouseUp", ButtonOnUp)
    button:SetScript("OnHide", ButtonOnLeave)
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
    button:SetAlpha(reason and 0.4 or 1)
    if reason then
        button.tip = reason
    else
        button.tip = format(button.toBank and "Move %d to the bank" or "Move %d to your bags", count)
    end
    PaintButton(button)
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
    ns.ApplyFont(h.count, 12)

    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", 6, 0)
    h.title:SetPoint("RIGHT", h.count, "LEFT", -6, 0)
    h.title:SetJustifyH("LEFT")
    h.title:SetWordWrap(false)
    Tint(h.title, C.text)
    ns.ApplyFont(h.title, 14)
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

local function PaintClose(close)
    local c = close.hover and C.text or C.section
    Fill(close.a, c)
    Fill(close.b, c)
end

local function CreateClose()
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -6, -6)
    -- Two 1px bars rotated into an X; rotation turns a flat texture, no art file.
    close.a = close:CreateTexture(nil, "OVERLAY")
    close.a:SetSize(1, 12)
    close.a:SetPoint("CENTER")
    close.a:SetRotation(rad(45))
    close.b = close:CreateTexture(nil, "OVERLAY")
    close.b:SetSize(1, 12)
    close.b:SetPoint("CENTER")
    close.b:SetRotation(rad(-45))
    -- Rotated 1px bars render unevenly while snapped to the pixel grid.
    for _, t in ipairs({ close.a, close.b }) do
        if t.SetSnapToPixelGrid then
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
        end
    end
    PaintClose(close)
    close:SetScript("OnEnter", function(self)
        self.hover = true
        PaintClose(self)
    end)
    local function Leave(self)
        self.hover = false
        PaintClose(self)
    end
    close:SetScript("OnLeave", Leave)
    close:SetScript("OnHide", Leave)
    close:SetScript("OnClick", function() frame:Hide() end)
    return close
end

local function CreateCheck(close)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("RIGHT", close, "LEFT", -10, 0)
    label:SetText("By zone")
    ns.ApplyFont(label, 13)

    -- A bare CheckButton: no template, so the only art is what is drawn here.
    local check = CreateFrame("CheckButton", nil, frame, "BackdropTemplate")
    check:SetSize(16, 16)
    check:SetPoint("RIGHT", label, "LEFT", -6, 0)
    check:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
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
    fontPath = ResolveFont()
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
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    Skin(frame, C.bg, C.border)
    RestorePosition()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Bag Bloat")
    Tint(title, C.text)
    ns.ApplyFont(title, 17)

    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    summary:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    summary:SetJustifyH("LEFT")
    summary:SetWordWrap(false)
    Tint(summary, C.muted)
    ns.ApplyFont(summary, 13)

    local divider = Solid(frame, "BORDER", C.divider)
    divider:SetPoint("TOPLEFT", 1, -48)
    divider:SetPoint("TOPRIGHT", -1, -48)
    divider:SetHeight(1)

    CreateCheck(CreateClose())

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
    ns.ApplyFont(empty, 13)

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
