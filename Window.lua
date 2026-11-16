local _, ns = ...

local WIDTH, HEIGHT, ROW_H, ICON = 380, 440, 36, 28
local frame, content, summary, empty
local rows, isRow = {}, {}

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

local function CreateRow(index)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT")
    isRow[row] = true

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", 4, 0)

    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, 0)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("TOPRIGHT", -6, -5)
    row.status:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.quest = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.quest:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.quest:SetPoint("RIGHT", -6, 0)
    row.quest:SetJustifyH("LEFT")
    row.quest:SetWordWrap(false)

    row:SetScript("OnEnter", ns.ShowRowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", RowOnClick)
    return row
end

local function FillRow(row, rec)
    row.rec = rec
    row.icon:SetTexture(rec.icon)
    row.count:SetText(rec.count and rec.count > 1 and rec.count or "")
    local name = rec.name ~= "" and rec.name or rec.link
    row.name:SetText(rec.inBank and name .. " |cff808080(bank)|r" or name)
    local r, g, b = C_Item.GetItemQualityColor(rec.quality or 1)
    row.name:SetTextColor(r or 1, g or 1, b or 1)
    local v = ns.VERDICTS[rec.verdict]
    row.status:SetText(v.label)
    row.status:SetTextColor(v.r, v.g, v.b)
    row.quest:SetText(rec.questText or "")
end

function ns.RefreshWindow()
    if not ns.IsWindowShown() then return end
    local records = ns.Get()
    for i, rec in ipairs(records) do
        local row = rows[i]
        if not row then
            row = CreateRow(i)
            rows[i] = row
        end
        FillRow(row, rec)
        row:Show()
    end
    for i = #records + 1, #rows do
        rows[i].rec = nil
        rows[i]:Hide()
    end
    content:SetHeight(math.max(#records * ROW_H, 1))
    empty:SetShown(#records == 0)
    if #records == 0 then
        summary:SetText("")
    elseif ns.safeCount == 0 then
        summary:SetFormattedText("%d quest items, none safe to delete", #records)
    else
        summary:SetFormattedText("%d of %d quest items safe to delete", ns.safeCount, #records)
    end
end

local function CreateWindow()
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
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
    frame:SetBackdropBorderColor(0.22, 0.22, 0.25, 1)
    RestorePosition()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Bag Bloat")

    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -52)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 36, 1)
    scroll:SetScrollChild(content)

    empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("CENTER", scroll, "CENTER")
    empty:SetText("No quest items in your bags.")

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
