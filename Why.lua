local _, ns = ...

local concat, max, min = table.concat, math.max, math.min

local UI = ns.UI
local C = UI.C

local BOX_W, BOX_H, PAD = 440, 420, 12
local box, edit, report

-- A report is read-only: typing is undone so the text stays as the game gave it.
local function OnTextChanged(self, user)
    if user then
        self:SetText(report)
        self:HighlightText()
    end
end

local function OnWheel(scroll, delta)
    local range = scroll:GetVerticalScrollRange()
    scroll:SetVerticalScroll(max(0, min(range, scroll:GetVerticalScroll() - delta * 28)))
end

local function CreateBox()
    box = CreateFrame("Frame", "BagBloatWhy", UIParent, "BackdropTemplate")
    box:SetSize(BOX_W, BOX_H)
    box:SetPoint("CENTER")
    box:SetFrameStrata("DIALOG")
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", box.StartMoving)
    box:SetScript("OnDragStop", box.StopMovingOrSizing)
    UI.Panel(box)

    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -10)
    title:SetText("Bag Bloat: why")
    UI.Tint(title, C.text)
    UI.ApplyFont(title, 17)
    UI.CloseButton(box)

    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", PAD, 10)
    hint:SetText("Ctrl+C to copy")
    UI.Tint(hint, C.muted)
    UI.ApplyFont(hint, 12)

    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", PAD, -40)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, 30)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", OnWheel)

    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetWidth(BOX_W - PAD * 2)
    UI.ApplyFont(edit, 12)
    edit:SetScript("OnTextChanged", OnTextChanged)
    edit:SetScript("OnEscapePressed", function() box:Hide() end)
    scroll:SetScrollChild(edit)

    tinsert(UISpecialFrames, "BagBloatWhy")
    box:Hide()
end

local function ShowReport(lines)
    if not box then CreateBox() end
    report = concat(lines, "\n")
    edit:SetText(report)
    box:Show()
    edit:SetFocus()
    edit:HighlightText()
end

-- The item under the mouse: one of our rows, a bag button we have painted, or
-- any item tooltip whose item sits in your bags.
local function HoveredItem()
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    if not owner then return end
    if ns.IsRow(owner) then
        local rec = owner.rec
        if rec then return rec.bag, rec.slot, rec.itemID end
        return
    end
    local bag, slot, itemID = ns.ButtonSlot(owner)
    if bag then return bag, slot, itemID end
    local data = GameTooltip.GetTooltipData and GameTooltip:GetTooltipData()
    local id = data and data.id
    local isItem = data and data.type == Enum.TooltipDataType.Item
    if isItem and type(id) == "number" and ns.IsPlain(id) then
        bag, slot = ns.FindItem(id)
        return bag, slot, id
    end
end

-- arg is what follows /bloat why: an item link or an item ID, or nothing.
function ns.Why(arg)
    if InCombatLockdown() then
        print("Bag Bloat: not in combat.")
        return
    end
    local bag, slot, itemID
    if arg and arg ~= "" then
        itemID = tonumber(arg:match("item:(%d+)")) or tonumber(arg:match("^%d+$"))
        if itemID then bag, slot = ns.FindItem(itemID) end
    else
        bag, slot, itemID = HoveredItem()
    end
    if not itemID then
        print("Bag Bloat: hover an item in your bags, then type /bloat why.")
        return
    end
    ShowReport(ns.Explain(bag, slot, itemID))
end
