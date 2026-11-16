local _, ns = ...

local C_Container, C_QuestLog, C_Item = C_Container, C_QuestLog, C_Item
local ipairs, wipe, sort, find = ipairs, wipe, table.sort, string.find

local QUEST_ITEM_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12
local BAG = Enum.BagIndex
local BAGS = {
    BAG and BAG.Backpack or 0,
    BAG and BAG.Bag_1 or 1,
    BAG and BAG.Bag_2 or 2,
    BAG and BAG.Bag_3 or 3,
    BAG and BAG.Bag_4 or 4,
    BAG and BAG.ReagentBag or 5,
    BAG and BAG.Keyring or -1,
}

-- order sorts the window: things you can delete first, things to keep last.
-- mark picks the bag icon: check (have it or done it), x (gray or unused), question (not started).
ns.VERDICTS = {
    done    = { order = 1, safe = true, mark = "check",  label = "Quest done",      status = "Completed",         tip = "Quest already completed. Safe to delete.",   r = 0.30, g = 0.85, b = 0.40 },
    gray    = { order = 2, safe = true, mark = "x",  label = "Gray quest",      status = "Not started",       tip = "Quest is gray for you. Safe to delete.",     r = 0.62, g = 0.62, b = 0.62 },
    orphan  = { order = 3, mark = "x", label = "No quest in log", tip = "No quest in your log uses this. Check before deleting.", r = 1.00, g = 0.62, b = 0.20 },
    starter = { order = 4, mark = "question",  label = "Starts a quest",  status = "Not started",       tip = "Starts a quest you have not done.",       r = 1.00, g = 0.82, b = 0.00 },
    active  = { order = 5, mark = "check",  label = "On quest",        status = "In your quest log", tip = "A quest in your log needs this.",         r = 0.40, g = 0.70, b = 1.00 },
    pending = { order = 6, label = "Loading", tip = "Loading quest data.", r = 0.50, g = 0.50, b = 0.50 },
}
local VERDICTS = ns.VERDICTS

local SLOT_KEY = 1000
function ns.SlotKey(bag, slot) return bag * SLOT_KEY + slot end

local records, byItem, bySlot = {}, {}, {}
local logQuests, logObjectives, objectives, specialItems = {}, {}, {}, {}
local questRequested, questResolved = {}, {}
local dirty = true
ns.safeCount = 0

function ns.IsPlain(v)
    return not (issecretvalue and issecretvalue(v))
end

local function ReadQuestLog()
    wipe(logQuests); wipe(logObjectives); wipe(objectives); wipe(specialItems)
    local i = 1
    while true do
        local info = C_QuestLog.GetInfo(i)
        if not info then break end
        local questID = not info.isHeader and info.questID
        if questID and questID > 0 then
            logQuests[questID] = info
            local objs = C_QuestLog.GetQuestObjectives(questID)
            if objs then
                logObjectives[questID] = objs
                for _, o in ipairs(objs) do
                    if o.text and o.text ~= "" then
                        objectives[#objectives + 1] = { questID = questID, text = o.text }
                    end
                end
            end
            local link = GetQuestLogSpecialItemInfo and GetQuestLogSpecialItemInfo(i)
            if link then
                local itemID = C_Item.GetItemInfoInstant(link)
                if itemID then specialItems[itemID] = questID end
            end
        end
        i = i + 1
    end
end

-- 0 means the client has not loaded the quest yet, not level 0.
local function QuestLevel(questID)
    local info = logQuests[questID]
    if info and info.level and info.level > 0 then return info.level end
    local level = C_QuestLog.GetQuestDifficultyLevel(questID)
    if level and level > 0 then return level end
end

local function QuestTitle(questID)
    local info = logQuests[questID]
    return info and info.title or C_QuestLog.GetTitleForQuestID(questID)
end

local function IsGray(level)
    return level - UnitEffectiveLevel("player") < -UnitQuestTrivialLevelRange("player")
end

local function OwnerOfObjectiveItem(itemID, name)
    local owner = specialItems[itemID]
    if owner or not name or name == "" then return owner end
    for i = 1, #objectives do
        if find(objectives[i].text, name, 1, true) then return objectives[i].questID end
    end
end

local function Classify(bag, slot, info)
    local qi = C_Container.GetContainerItemQuestInfo(bag, slot)
    local questID = qi and qi.questID
    if questID and questID > 0 then
        if qi.isActive or logQuests[questID] or C_QuestLog.IsOnQuest(questID) then
            return "active", questID
        end
        if C_QuestLog.IsQuestFlaggedCompleted(questID) then return "done", questID end
        local level = QuestLevel(questID)
        if level then return IsGray(level) and "gray" or "starter", questID end
        if questResolved[questID] then return "starter", questID end
        if not questRequested[questID] then
            questRequested[questID] = true
            C_QuestLog.RequestLoadQuestByID(questID)
        end
        return "pending", questID
    end

    local isQuestItem = qi and qi.isQuestItem
    if not isQuestItem then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(info.itemID)
        isQuestItem = classID == QUEST_ITEM_CLASS
    end
    if not isQuestItem then return nil end

    local owner = OwnerOfObjectiveItem(info.itemID, info.itemName)
    if owner then return "active", owner end
    return "orphan"
end

local function ByVerdict(a, b)
    local oa, ob = VERDICTS[a.verdict].order, VERDICTS[b.verdict].order
    if oa ~= ob then return oa < ob end
    if a.name ~= b.name then return a.name < b.name end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

local function Scan()
    dirty = false
    ReadQuestLog()
    wipe(records); wipe(byItem); wipe(bySlot)
    local safe = 0
    for _, bag in ipairs(BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local verdict, questID = Classify(bag, slot, info)
                if verdict then
                    local inLog = questID and logQuests[questID] ~= nil
                    local rec = {
                        bag = bag, slot = slot, itemID = info.itemID,
                        name = info.itemName or "", link = info.hyperlink,
                        icon = info.iconFileID, count = info.stackCount, quality = info.quality,
                        verdict = verdict, questID = questID,
                        questTitle = questID and QuestTitle(questID),
                        questLevel = questID and QuestLevel(questID),
                        objectives = inLog and logObjectives[questID] or nil,
                        ready = inLog and C_QuestLog.ReadyForTurnIn(questID) or nil,
                    }
                    records[#records + 1] = rec
                    byItem[info.itemID] = byItem[info.itemID] or rec
                    bySlot[ns.SlotKey(bag, slot)] = rec
                    if VERDICTS[verdict].safe then safe = safe + 1 end
                end
            end
        end
    end
    sort(records, ByVerdict)
    ns.safeCount = safe
end

-- In combat this only hands back the last scan: nothing reads the game
-- until combat ends.
function ns.Get()
    if dirty and not InCombatLockdown() then Scan() end
    return records, byItem, bySlot
end

local refreshQueued = false
local function RunRefresh()
    refreshQueued = false
    if not dirty or InCombatLockdown() then return end
    if not (ns.IsWindowShown() or ns.MarksVisible()) then return end
    Scan()
    ns.RefreshWindow()
    ns.RepaintMarks()
end

function ns.MarkDirty()
    dirty = true
    if not refreshQueued then
        refreshQueued = true
        C_Timer.After(0.2, RunRefresh)
    end
end

function ns.QuestText(rec)
    if not rec.questTitle then return nil end
    if rec.questLevel then return "[" .. rec.questLevel .. "] " .. rec.questTitle end
    return rec.questTitle
end

local function AddDetailLines(tooltip, rec)
    local v = VERDICTS[rec.verdict]
    if rec.questID then
        tooltip:AddDoubleLine("Quest ID", rec.questID, 0.6, 0.6, 0.6, 1, 1, 1)
        if v.status then tooltip:AddDoubleLine("Status", v.status, 0.6, 0.6, 0.6, 1, 1, 1) end
    end
    if rec.objectives then
        for _, o in ipairs(rec.objectives) do
            if o.text and o.text ~= "" then
                if o.finished then
                    tooltip:AddLine("  " .. o.text, 0.30, 0.85, 0.40, true)
                else
                    tooltip:AddLine("  " .. o.text, 0.85, 0.85, 0.85, true)
                end
            end
        end
    end
    if rec.ready then tooltip:AddLine("Ready to turn in", 0.30, 0.85, 0.40) end
    tooltip:AddDoubleLine("Item ID", rec.itemID, 0.6, 0.6, 0.6, 1, 1, 1)
end

local tipOwner
function ns.AddVerdictLines(tooltip, rec)
    local v = VERDICTS[rec.verdict]
    tooltip:AddLine("Bag Bloat: " .. v.tip, v.r, v.g, v.b, true)
    local quest = ns.QuestText(rec)
    if quest then tooltip:AddLine(quest, 0.85, 0.85, 0.85, true) end
    if IsAltKeyDown() then AddDetailLines(tooltip, rec) end
    if tooltip == GameTooltip then tipOwner = tooltip:GetOwner() end
end

function ns.PickUp(rec)
    local info = C_Container.GetContainerItemInfo(rec.bag, rec.slot)
    if not info or info.itemID ~= rec.itemID then
        ns.MarkDirty()
        return
    end
    if CursorHasItem() then ClearCursor() end
    C_Container.PickupContainerItem(rec.bag, rec.slot)
end

local function OnItemTooltip(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    if tooltip:IsForbidden() then return end
    local id = data and data.id
    if type(id) ~= "number" or not ns.IsPlain(id) then return end
    local _, items = ns.Get()
    local rec = items[id]
    if rec then ns.AddVerdictLines(tooltip, rec) end
end

-- Alt redraws the tooltip only out of combat and only while it still shows
-- the item we annotated, so a unit or spell tooltip is never rebuilt.
local function OnAltChanged()
    if InCombatLockdown() or GameTooltip:IsForbidden() or not GameTooltip:IsShown() then return end
    local owner = GameTooltip:GetOwner()
    if not owner or owner ~= tipOwner then return end
    if ns.IsRow(owner) then
        ns.ShowRowTooltip(owner)
    elseif GameTooltip.RefreshData then
        GameTooltip:RefreshData()
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "MODIFIER_STATE_CHANGED" then
        if arg1 == "LALT" or arg1 == "RALT" then OnAltChanged() end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if dirty then ns.MarkDirty() end
        return
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        if not questRequested[arg1] then return end
        questResolved[arg1] = true
    elseif event == "PLAYER_LOGIN" then
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
        end
        GameTooltip:HookScript("OnHide", function() tipOwner = nil end)
        ns.HookBags()
        return
    end
    ns.MarkDirty()
end)
for _, event in ipairs({
    "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN",
    "PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT", "PLAYER_REGEN_ENABLED", "MODIFIER_STATE_CHANGED",
}) do
    events:RegisterEvent(event)
end

SLASH_BAGBLOAT1 = "/bagbloat"
SLASH_BAGBLOAT2 = "/bloat"
SlashCmdList.BAGBLOAT = function() ns.ToggleWindow() end

function BagBloat_OnAddonCompartmentClick()
    ns.ToggleWindow()
end
