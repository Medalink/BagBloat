local _, ns = ...

local UI = ns.UI
local C = UI.C

local MENU_W, ITEM_H, PAD = 124, 22, 4
local HOVER = { 1, 1, 1, 0.08 }
local ITEM_COUNT = 3
local menu

-- The popup keeps copies of bag, slot and itemID, never the record: records are
-- reused tables that the next scan rewrites.
local function PaintItem(item)
    UI.Tint(item.label, item.tone or (item.hover and C.text or C.muted))
    item.bg:SetShown(item.hover == true)
end

local function ItemOnEnter(item)
    item.hover = true
    PaintItem(item)
end

local function ItemOnLeave(item)
    item.hover = false
    PaintItem(item)
end

-- Runs from the click, so DeleteRecord has the hardware event the game needs.
local function ItemOnClick(item)
    local action = item.action
    local itemID, bag, slot, keepOn, hideOn = menu.itemID, menu.bag, menu.slot, menu.keepOn, menu.hideOn
    menu:Hide()
    if action == "keep" then
        ns.SetKeep(itemID, not keepOn)
    elseif action == "hide" then
        ns.SetHide(itemID, not hideOn)
    elseif action == "delete" and bag then
        local _, _, bySlot = ns.Get()
        local rec = bySlot[ns.SlotKey(bag, slot)]
        if rec and rec.itemID == itemID then ns.DeleteRecord(rec) end
    end
end

local function CreateItem(index)
    local item = CreateFrame("Button", nil, menu)
    item:SetHeight(ITEM_H)
    item:SetPoint("TOPLEFT", PAD, -PAD - (index - 1) * ITEM_H)
    item:SetPoint("TOPRIGHT", -PAD, -PAD - (index - 1) * ITEM_H)
    item.bg = UI.Solid(item, "BACKGROUND", HOVER)
    item.bg:SetAllPoints()
    item.label = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    item.label:SetPoint("LEFT", 8, 0)
    UI.ApplyFont(item.label, 12)
    item:SetScript("OnEnter", ItemOnEnter)
    item:SetScript("OnLeave", ItemOnLeave)
    item:SetScript("OnHide", ItemOnLeave)
    item:SetScript("OnClick", ItemOnClick)
    return item
end

-- A press anywhere outside the popup closes it.
local function OnMouseDown(self)
    if not self:IsMouseOver() then self:Hide() end
end

-- Escape closes the popup alone, not the window behind it.
local function OnKeyDown(self, key)
    local close = key == "ESCAPE"
    self:SetPropagateKeyboardInput(not close)
    if close then self:Hide() end
end

local function CreateMenu()
    menu = CreateFrame("Frame", "BagBloatMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:EnableKeyboard(true)
    menu:SetPropagateKeyboardInput(true)
    UI.Panel(menu, C.overlay, C.border)
    menu.items = {}
    for i = 1, ITEM_COUNT do menu.items[i] = CreateItem(i) end
    menu.items[1].action, menu.items[2].action, menu.items[3].action = "keep", "hide", "delete"
    menu.items[3].tone = C.danger
    menu:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
    menu:SetScript("OnEvent", OnMouseDown)
    menu:SetScript("OnKeyDown", OnKeyDown)
    tinsert(UISpecialFrames, "BagBloatMenu")
    menu:Hide()
end

local function ShowItem(index, text)
    local item = menu.items[index]
    item.label:SetText(text)
    item.hover = false
    PaintItem(item)
    item:Show()
end

function ns.CloseMenu()
    if menu then menu:Hide() end
end

-- rec is read here and not kept.
function ns.OpenMenu(rec)
    if not menu then CreateMenu() end
    local itemID = rec.itemID
    local cdb = ns.CharDB()
    menu.itemID, menu.bag, menu.slot = itemID, rec.bag, rec.slot
    menu.keepOn, menu.hideOn = cdb.keep[itemID], cdb.hide[itemID]
    for _, item in ipairs(menu.items) do item:Hide() end
    ShowItem(1, menu.keepOn and "Stop keeping" or "Keep")
    ShowItem(2, menu.hideOn and "Show again" or "Hide")
    local count = 2
    if rec.bag and not rec.inBank and ns.VERDICTS[rec.verdict].safe then
        ShowItem(3, "Delete")
        count = 3
    end
    menu:SetSize(MENU_W, PAD * 2 + count * ITEM_H)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 4, y / scale + 4)
    menu:Show()
end
