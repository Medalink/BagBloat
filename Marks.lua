local _, ns = ...

local C_Container = C_Container

local MARK_TEXTURES = {
    check    = "Interface\\RaidFrame\\ReadyCheck-Ready",
    x        = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    question = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

-- [button] = { host, bag, slot, itemID, tex }: every item button we have
-- painted, so a rescan can repaint them without waiting for the bag addon.
local painted = setmetatable({}, { __mode = "k" })

local function Paint(btn, host, bag, slot, itemID)
    local state = painted[btn]
    local valid = bag and slot and itemID and slot > 0 and ns.IsPlain(itemID)
    if not valid then
        if state then
            state.bag = nil
            if state.tex then state.tex:Hide() end
        end
        return
    end

    if not state then
        state = {}
        painted[btn] = state
    end
    state.host, state.bag, state.slot, state.itemID = host, bag, slot, itemID

    local _, _, bySlot = ns.Get()
    local rec = bySlot[ns.SlotKey(bag, slot)]
    local mark = rec and rec.itemID == itemID and ns.VERDICTS[rec.verdict].mark
    if not mark then
        if state.tex then state.tex:Hide() end
        return
    end

    local tex = state.tex
    if not tex or tex:GetParent() ~= host then
        if tex then tex:Hide() end
        tex = host:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetPoint("TOPLEFT", host, "TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", host, "CENTER", -1, 1)
        state.tex = tex
    end
    tex:SetTexture(MARK_TEXTURES[mark])
    tex:Show()
end

-- The bag, slot and itemID a button last showed, for buttons we have painted.
function ns.ButtonSlot(button)
    local state = painted[button]
    if state and state.bag then return state.bag, state.slot, state.itemID end
end

-- Runs out of combat only, so it reads each slot's current item rather
-- than trusting the one the button showed at its last paint.
function ns.RepaintMarks()
    for btn, state in pairs(painted) do
        if state.bag and btn:IsVisible() then
            local itemID = C_Container.GetContainerItemID(state.bag, state.slot)
            Paint(btn, state.host, state.bag, state.slot, itemID or nil)
        end
    end
end

local gameFrames = {}

function ns.BagsOpen()
    local eui = _G.EUI_Bags
    if eui and eui.RegisterItemOverlayIcon and eui:IsVisible() then return true end
    if ns.bankOpen then return true end
    for i = 1, #gameFrames do
        if gameFrames[i]:IsShown() then return true end
    end
    return false
end

-- EllesmereUI Bags: its overlay API hands us every painted slot.
local function PaintEllesmere(btn, data)
    local info = data.info
    Paint(btn, btn._textOverlay or btn, data.bag, data.slot, info and info.itemID)
end

-- The game's bag windows: repaint after each one updates its items.
local function PaintGameFrame(frame)
    if not frame:IsShown() then return end
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button:GetBagID(), button:GetID()
        local itemID = bag and slot and slot > 0 and C_Container.GetContainerItemID(bag, slot)
        Paint(button, button, bag, slot, itemID or nil)
    end
end

-- The game's bank: one panel showing the selected tab's slots.
local function PaintBankPanel(panel)
    if not panel:IsVisible() then return end
    for _, button in panel:EnumerateValidItems() do
        local bag = button.GetBankTabID and button:GetBankTabID()
        local slot = button.GetContainerSlotID and button:GetContainerSlotID()
        local itemID = bag and slot and slot > 0 and C_Container.GetContainerItemID(bag, slot)
        Paint(button, button, bag, slot, itemID or nil)
    end
end

local function HookBankPanel()
    local panel = _G.BankPanel
    if not (panel and panel.EnumerateValidItems) then return end
    for _, method in ipairs({ "GenerateItemSlotsForSelectedTab", "RefreshAllItemsForSelectedTab" }) do
        if panel[method] then hooksecurefunc(panel, method, PaintBankPanel) end
    end
end

function ns.HookBags()
    HookBankPanel()
    local seen = {}
    local function add(frame)
        if frame and not seen[frame] and frame.UpdateItems and frame.EnumerateValidItems then
            seen[frame] = true
            gameFrames[#gameFrames + 1] = frame
            hooksecurefunc(frame, "UpdateItems", PaintGameFrame)
        end
    end
    add(ContainerFrameCombinedBags)
    local list = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
    if list then
        for _, frame in ipairs(list) do add(frame) end
    end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do add(_G["ContainerFrame" .. i]) end

    local eui = _G.EUI_Bags
    if eui and eui.RegisterItemOverlayIcon then
        eui.RegisterItemOverlayIcon("BagBloat", PaintEllesmere)
    end
end
