local _, ns = ...

local ipairs, wipe, sort, format = ipairs, wipe, table.sort, string.format
local find, lower = string.find, string.lower
local floor, max, min = math.floor, math.max, math.min

local WIDTH, HEIGHT, ROW_H, ICON = 380, 440, 36, 28
local MIN_W, MIN_H, MAX_W, MAX_H = 320, 260, 900, 1200
local HEADER_H, BUTTON_W, BUTTON_H, DELETE_W = 26, 38, 20, 48
local SEARCH_W, SEARCH_H = 120, 18
local DISARM_AFTER, DELETE_GAP = 10, 0.3
local BAR_W, THUMB_MIN, GRIP = 4, 24, 14
local frame, scroll, bar, content, summary, empty, search
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

local zoneCheck, SyncZoneCheck
local following, autoOpened = false, false

local function ByZone()
    return ns.Option("byZone")
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
    if not row.rec then return end
    -- A rescan here rebinds the rows, so the record is read after it.
    local _, items = ns.Get()
    local rec = row.rec
    if not rec then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if rec.bag then
        GameTooltip:SetBagItem(rec.bag, rec.slot)
        GameTooltip:AddLine("Click to pick up", 0.5, 0.5, 0.5)
    else
        if rec.link then
            GameTooltip:SetHyperlink(rec.link)
        else
            GameTooltip:SetItemByID(rec.itemID)
        end
        -- The game's item tooltip only gets a verdict line for items in your bags.
        if not items[rec.itemID] then ns.AddVerdictLines(GameTooltip, rec) end
        GameTooltip:AddLine("In your bank, seen on your last visit", 0.5, 0.5, 0.5)
    end
    GameTooltip:AddLine("Right-click for options", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function RowOnClick(row, mouse)
    local rec = row.rec
    if not rec then return end
    if mouse == "RightButton" then
        ns.OpenMenu(rec)
        return
    end
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

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", ns.ShowRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", RowOnClick)
    return row
end

local function FillRow(row, rec, kind)
    row.rec = rec
    row.icon:SetTexture(rec.icon)
    row.count:SetText(rec.count and rec.count > 1 and rec.count or "")
    local name = rec.name ~= "" and rec.name or rec.link or "?"
    row.name:SetText(rec.inBank and name .. BANK_TAG or name)
    local r, g, b = C_Item.GetItemQualityColor(rec.quality or 1)
    row.name:SetTextColor(r or 1, g or 1, b or 1)
    local v = ns.VERDICTS[rec.verdict]
    if kind == "ready" then
        row.status:SetText("Ready to turn in")
        Tint(row.status, C.success)
    else
        row.status:SetText(v.label)
        row.status:SetTextColor(v.r, v.g, v.b)
    end
    row.quest:SetText(rec.questText or "")
end

-- The search box text, lowercased; empty means no filter.
local query = ""

local function Matches(rec)
    if query == "" then return true end
    return find(lower(rec.name), query, 1, true)
        or (rec.questTitle and find(lower(rec.questTitle), query, 1, true))
        or (rec.zone and find(lower(rec.zone), query, 1, true))
end

-- Groups. The tables are pooled: a refresh reuses them and builds no new ones.
local groupPool, groupUsed = {}, 0
local zoneGroup, zoneList, groups = {}, {}, {}
local readyGroup, otherGroup, safeGroup, hiddenGroup
local listed = 0

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

-- The first group that fits: hidden, ready, safe, its zone, then the rest.
local function PickGroup(rec)
    if rec.verdict == "ignored" then
        hiddenGroup = hiddenGroup or NewGroup("Hidden by you", "hidden")
        return hiddenGroup
    elseif rec.ready then
        readyGroup = readyGroup or NewGroup("Ready to turn in", "ready")
        return readyGroup
    elseif ns.VERDICTS[rec.verdict].safe then
        safeGroup = safeGroup or NewGroup("Safe to delete", "safe")
        return safeGroup
    elseif rec.zone then
        local g = zoneGroup[rec.zone]
        if not g then
            g = NewGroup(rec.zone, "zone")
            zoneGroup[rec.zone] = g
            zoneList[#zoneList + 1] = g
        end
        return g
    end
    otherGroup = otherGroup or NewGroup("Not in your quest log", "other")
    return otherGroup
end

local function BuildGroups(records)
    groupUsed, listed = 0, 0
    readyGroup, otherGroup, safeGroup, hiddenGroup = nil, nil, nil, nil
    wipe(zoneGroup); wipe(zoneList); wipe(groups)
    for _, rec in ipairs(records) do
        if Matches(rec) then
            local g = PickGroup(rec)
            g.recs[#g.recs + 1] = rec
            if rec.inBank then
                g.bankCount = g.bankCount + 1
            else
                g.bagCount = g.bagCount + 1
            end
            listed = listed + 1
        end
    end

    if #zoneList > 0 then
        for _, g in ipairs(zoneList) do g.here = ns.IsHere(g.title) end
        sort(zoneList, ZoneOrder)
    end
    if readyGroup then groups[#groups + 1] = readyGroup end
    for _, g in ipairs(zoneList) do groups[#groups + 1] = g end
    if otherGroup then groups[#groups + 1] = otherGroup end
    if safeGroup then groups[#groups + 1] = safeGroup end
    if hiddenGroup then groups[#groups + 1] = hiddenGroup end
end

-- Hidden items start folded; searching shows every match.
local function IsCollapsed(g)
    if query ~= "" then return false end
    local state = ns.Collapsed()[g.title]
    if state == nil then return g.kind == "hidden" end
    return state
end

-- Set below, with the Delete button's state.
local DisarmDelete

local function HeaderOnClick(h)
    local g = h.group
    if not g or query ~= "" then return end
    local state = ns.Collapsed()
    state[g.title] = not IsCollapsed(g)
    DisarmDelete()
    ns.RefreshWindow()
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
    if not ns.BankIsOpen() then
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

-- The Delete button. The first click arms it, each click after that deletes
-- one item, and it disarms 10 s after the last click or when the window hides.
local armed, armedAt, lastDelete, deletedOne, disarmQueued = false, 0, 0, false, false

local function Disarm()
    armed, deletedOne = false, false
end
DisarmDelete = Disarm

local function DisarmCheck()
    disarmQueued = false
    if not armed then return end
    local left = DISARM_AFTER - (GetTime() - armedAt)
    if left > 0.05 then
        disarmQueued = true
        C_Timer.After(left, DisarmCheck)
    else
        Disarm()
        ns.RefreshWindow()
    end
end

local function FillDelete(button, g)
    button.group = g
    local reason, nextRec
    if InCombatLockdown() or UnitAffectingCombat("player") then
        reason = "In combat"
    elseif IsCollapsed(g) then
        -- A folded group shows no rows: never delete what cannot be seen.
        reason = "Open the group first"
    else
        nextRec = ns.NextDeletable(g.recs)
        if not nextRec then reason = "Nothing in your bags to delete" end
    end
    if reason then Disarm() end
    button.label:SetText(armed and "Sure?" or "Delete")
    if reason then
        button.tip = reason
    elseif not armed then
        button.tip = "Click to arm. Each click after that deletes one item."
    elseif deletedOne then
        button.tip = "Deletes " .. (nextRec.name ~= "" and nextRec.name or nextRec.link or "?")
    else
        button.tip = "Click again to delete one item per click"
    end
    UI.SetEnabled(button, reason == nil)
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == button then UI.ShowTip(button) end
end

-- DeleteCursorItem needs a hardware event, so the delete happens right here.
local function DeleteOnClick(button)
    local now = GetTime()
    armedAt = now
    if not disarmQueued then
        disarmQueued = true
        C_Timer.After(DISARM_AFTER, DisarmCheck)
    end
    if not armed then
        armed, deletedOne = true, false
        FillDelete(button, button.group)
        return
    end
    -- A second click before the bags update would hit the item just deleted.
    if now - lastDelete < DELETE_GAP then return end
    -- A rescan rebuilds the groups, so the target is read after it.
    ns.Get()
    local g = button.group
    if not armed or not button:IsEnabled() then return end
    if g and ns.DeleteRecord(ns.NextDeletable(g.recs)) then
        lastDelete, deletedOne = now, true
    end
end

local function CreateHeader()
    local h = CreateFrame("Button", nil, content)
    h:SetHeight(HEADER_H)
    h:SetScript("OnClick", HeaderOnClick)

    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Fill(bg, C.surface)

    local hl = h:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Fill(hl, C.surface)

    local line = Solid(h, "BORDER", C.divider)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)

    -- A plus when folded, a minus when open, from 1px bars.
    h.signH = Solid(h, "OVERLAY", C.faint)
    h.signH:SetSize(9, 1)
    h.signH:SetPoint("CENTER", h, "LEFT", 12, 0)
    h.signV = Solid(h, "OVERLAY", C.faint)
    h.signV:SetSize(1, 9)
    h.signV:SetPoint("CENTER", h, "LEFT", 12, 0)

    h.take = CreateButton(h, "Take", false)
    h.take:SetPoint("RIGHT", -4, 0)
    h.bank = CreateButton(h, "Bank", true)
    h.bank:SetPoint("RIGHT", h.take, "LEFT", -3, 0)
    h.delete = UI.Button(h, "Delete", DELETE_W, BUTTON_H)
    h.delete:SetPoint("RIGHT", -4, 0)
    UI.SetTone(h.delete, C.danger)
    h.delete:SetScript("OnClick", DeleteOnClick)

    h.count = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.count:SetJustifyH("RIGHT")
    Tint(h.count, C.muted)
    ApplyFont(h.count, 12)

    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", 22, 0)
    h.title:SetPoint("RIGHT", h.count, "LEFT", -6, 0)
    h.title:SetJustifyH("LEFT")
    h.title:SetWordWrap(false)
    Tint(h.title, C.text)
    ApplyFont(h.title, 14)
    return h
end

local function FillHeader(h, g, collapsed)
    h.group = g
    h.signV:SetShown(collapsed)
    h.title:SetText(g.here and g.title .. HERE_TAG or g.title)
    local n = #g.recs
    local word = n == 1 and "item" or "items"
    if g.bankCount > 0 then
        h.count:SetFormattedText("%d %s, %d in bank", n, word, g.bankCount)
    else
        h.count:SetFormattedText("%d %s", n, word)
    end
    h.count:ClearAllPoints()
    if g.kind == "hidden" then
        h.bank:Hide()
        h.take:Hide()
        h.delete:Hide()
        h.count:SetPoint("RIGHT", h, "RIGHT", -6, 0)
    elseif g.kind == "safe" then
        h.bank:Hide()
        h.take:Hide()
        FillDelete(h.delete, g)
        h.delete:Show()
        h.count:SetPoint("RIGHT", h.delete, "LEFT", -6, 0)
    else
        h.delete:Hide()
        FillButton(h.bank, g, g.bagCount)
        FillButton(h.take, g, g.bankCount)
        h.bank:Show()
        h.take:Show()
        h.count:SetPoint("RIGHT", h.bank, "LEFT", -6, 0)
    end
end

local function ShowRow(n, rec, y, kind)
    local row = rows[n]
    if not row then
        row = CreateRow()
        rows[n] = row
    end
    FillRow(row, rec, kind)
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
    SyncZoneCheck()
    local records = ns.Get()
    local y, rowN, headN = 0, 0, 0
    if ByZone() then
        BuildGroups(records)
        if not safeGroup then DisarmDelete() end
        for _, g in ipairs(groups) do
            headN = headN + 1
            local h = headers[headN]
            if not h then
                h = CreateHeader()
                headers[headN] = h
            end
            local collapsed = IsCollapsed(g)
            FillHeader(h, g, collapsed)
            Place(h, y)
            h:Show()
            y = y + HEADER_H
            if not collapsed then
                for _, rec in ipairs(g.recs) do
                    rowN = rowN + 1
                    y = ShowRow(rowN, rec, y, g.kind)
                end
            end
        end
    else
        DisarmDelete()
        listed = 0
        for _, rec in ipairs(records) do
            if Matches(rec) then
                listed = listed + 1
                rowN = rowN + 1
                y = ShowRow(rowN, rec, y)
            end
        end
    end
    for i = headN + 1, #headers do
        local h = headers[i]
        h.group, h.bank.group, h.take.group, h.delete.group = nil, nil, nil, nil
        h:Hide()
    end
    for i = rowN + 1, #rows do
        rows[i].rec = nil
        rows[i]:Hide()
    end
    contentH = max(y, 1)
    content:SetHeight(contentH)
    UpdateScroll()
    empty:SetShown(listed == 0)
    if listed == 0 then
        empty:SetText(#records == 0 and "No quest items in your bags." or "Nothing matches.")
    end
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
    ns.SetOption("byZone", check:GetChecked() and true or false)
    PaintCheck(check)
    ns.RefreshWindow()
end

function SyncZoneCheck()
    local on = ByZone()
    if zoneCheck:GetChecked() ~= on then
        zoneCheck:SetChecked(on)
        PaintCheck(zoneCheck)
    end
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
    zoneCheck = check
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

local function PaintSearch()
    Skin(search, C.surface, search.focus and C.text or C.border)
    search.hint:SetShown(not search.focus and search:GetText() == "")
end

local function SearchOnChanged(box)
    PaintSearch()
    local text = lower(box:GetText())
    if text == query then return end
    query = text
    DisarmDelete()
    ns.RefreshWindow()
end

local function SearchOnFocus(box, focus)
    box.focus = focus
    PaintSearch()
end

-- Escape clears the text and the focus; with no text it only drops the focus,
-- so the next Escape closes the window.
local function SearchOnEscape(box)
    if box:GetText() ~= "" then box:SetText("") end
    box:ClearFocus()
end

local function CreateSearch()
    search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    search:SetSize(SEARCH_W, SEARCH_H)
    search:SetPoint("TOPRIGHT", -12, -27)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetTextColor(C.text[1], C.text[2], C.text[3], C.text[4])
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    search:SetTextInsets(6, 6, 0, 0)
    ApplyFont(search, 12)
    UI.Panel(search, C.surface, C.border)

    search.hint = search:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    search.hint:SetPoint("LEFT", 6, 0)
    search.hint:SetText("Search")
    Tint(search.hint, C.faint)
    ApplyFont(search.hint, 12)
    PaintSearch()

    search:SetScript("OnTextChanged", SearchOnChanged)
    search:SetScript("OnEditFocusGained", function(box) SearchOnFocus(box, true) end)
    search:SetScript("OnEditFocusLost", function(box) SearchOnFocus(box, false) end)
    search:SetScript("OnEscapePressed", SearchOnEscape)
    search:SetScript("OnEnterPressed", search.ClearFocus)
end

local function OnWindowHide()
    if not frame:IsShown() then autoOpened = false end
    Disarm()
    search:SetText("")
    search:ClearFocus()
    ns.CloseMenu()
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

    CreateSearch()

    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- Both points sit on the search box's center line, so the height is the text's own.
    summary:SetPoint("LEFT", frame, "TOPLEFT", 12, -(27 + SEARCH_H / 2))
    summary:SetPoint("RIGHT", search, "LEFT", -8, 0)
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
    frame:SetScript("OnHide", OnWindowHide)
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

--- Opens the window when the bank or the bags open, as the options say, and
--- closes it again when they close. It acts only when that state changes, so a
--- window you closed stays closed, and it never closes one you opened yourself.
--- An opening that combat held up is left pending, for the next call to make.
function ns.FollowBags()
    local want = (ns.Option("openWithBank") and ns.bankOpen)
        or (ns.Option("openWithBags") and ns.BagFramesShown()) or false
    if want == following then return end
    if not want then
        following = false
        if autoOpened then frame:Hide() end
    elseif ns.IsWindowShown() then
        following = true
    elseif not InCombatLockdown() then
        following = true
        if not frame then CreateWindow() end
        frame:Show()
        autoOpened = true
    end
end
