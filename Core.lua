local _, ns = ...

local C_Container, C_QuestLog, C_Item = C_Container, C_QuestLog, C_Item
local ipairs, wipe, sort, find, format = ipairs, wipe, table.sort, string.find, string.format

-- [questID] = the area a quest-starting item belongs to, from QuestZones.lua.
local QUEST_AREA = ns.QUEST_AREA or {}

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

-- The bank's tabs, readable only while the bank is open.
local BANK_BAGS, IS_BANK, IS_ACCOUNT = {}, {}, {}
if BAG then
    for _, prefix in ipairs({ "CharacterBankTab_", "AccountBankTab_" }) do
        for i = 1, 12 do
            local bag = BAG[prefix .. i]
            if bag then
                BANK_BAGS[#BANK_BAGS + 1] = bag
                IS_BANK[bag] = true
                if prefix == "AccountBankTab_" then IS_ACCOUNT[bag] = true end
            end
        end
    end
end
ns.bankOpen = false
ns.moving = false
local BANK_TYPE = Enum.BankType and Enum.BankType.Character
local BANKER = Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker

-- order sorts the window: things you can delete first, things to keep last.
-- mark picks the bag icon: check (have it or done it), x (gray or unused), question (not started, hidden or secret).
ns.VERDICTS = {
    done    = { order = 1, safe = true, mark = "check",  label = "Quest done",      status = "Completed",         tip = "Quest already completed. Safe to delete.",   r = 0.30, g = 0.85, b = 0.40 },
    gray    = { order = 2, safe = true, mark = "x",  label = "Gray quest",      status = "Not started",       tip = "Quest is gray for you. Safe to delete.",     r = 0.62, g = 0.62, b = 0.62 },
    orphan  = { order = 3, mark = "x", label = "No quest in log", tip = "No quest in your log uses this. Check before deleting.", r = 1.00, g = 0.40, b = 0.30 },
    starter = { order = 4, mark = "question",  label = "Starts a quest",  status = "Not started",       tip = "Starts a quest you have not done.",       r = 1.00, g = 0.82, b = 0.00 },
    hidden  = { order = 5, mark = "question", label = "Hidden quest", tip = "Starts a hidden quest with no name. Keep it.", r = 1.00, g = 0.62, b = 0.20 },
    secret  = { order = 5, mark = "question", label = "Secret quest", tip = "Part of a secret quest chain. Keep it.", r = 0.75, g = 0.45, b = 1.00 },
    active  = { order = 6, mark = "check",  label = "On quest",        status = "In your quest log", tip = "A quest in your log needs this.",         r = 0.40, g = 0.70, b = 1.00 },
    pending = { order = 7, label = "Loading", tip = "Loading quest data.", r = 0.50, g = 0.50, b = 0.50 },
    -- The two verdicts you set yourself, from the keep and hide lists.
    kept    = {
        order = 5, mark = "question", label = "Kept by you", tip = "You marked this to keep.",
        r = 0, g = 0.831, b = 1,
    },
    ignored = { order = 8, label = "Hidden by you", r = 0.545, g = 0.545, b = 0.545 },
}
local VERDICTS = ns.VERDICTS
-- An ignored item has no tip, so it gets no tooltip line.
for _, v in pairs(VERDICTS) do
    if v.tip then v.line = "Bag Bloat: " .. v.tip end
end

-- Items of secret quest chains, always kept whatever the game reports.
-- The server hides most of them from the client's own item data.
local SECRET_ITEMS = {
    -- The Dawn Waker secret, started by the Skyborne ring.
    [264908] = true, -- Ancient Heirloom
    [280612] = true, -- Night Watchman's Torch
    [282315] = true, -- Ancient Hilt
    [264501] = true, -- Ancient Skyborne Blade
    [276188] = true, -- Eluvi'ana
    [279276] = true, -- Mathystral Amulet Fragment
    [279277] = true, -- Mathystral Amulet
    [279275] = true, -- Clouded Water Globe
    [282337] = true, -- Befouled Water Globe
    [282406] = true, -- Azsharan Key
    [282404] = true, -- Narassin's Tome
    [282548] = true, -- Star of Elune
    [282547] = true, -- Abyssal Mote
    [282431] = true, -- Tears of Anguish
    [282699] = true, -- Cleansed Water Globe
    -- The Stone Key secret: the key's lock is still unknown.
    [281350] = true, -- Keystone Fragment
    [284092] = true, -- Keystone Fragment
    [284093] = true, -- Keystone Fragment
    [281358] = true, -- Stone Key
    -- The Bloody Map from Hammerfall: where it points is still unknown.
    [271745] = true, -- Bloody Map
    -- The Coldflame Saber: both are used up when the saber is made.
    [273637] = true, -- Blade of Silverlaine
    [277490] = true, -- Scroll of the Saber
    -- Lyn the Ignored in the Dalaran sewers: the tome summons her again and again.
    [276561] = true, -- Black Tome
    [275989] = true, -- Tome of Dalaran
    [277507] = true, -- Dalaran Sewer Key
    -- Ta'shkal, the secret hunter pet on Mount Hyjal.
    [276909] = true, -- Corrupted Cat Figurine
    -- The Malignant Root ring, a secret trade with Rethiel the Greenwarden.
    [279537] = true, -- Rotheap Innards
}

local SLOT_KEY = 1000
function ns.SlotKey(bag, slot) return bag * SLOT_KEY + slot end

local records, byItem, bySlot, recPool = {}, {}, {}, {}
local logQuests, logObjectives, objText, objQuest, specialItems = {}, {}, {}, {}, {}
-- [questID] = the quest log header the quest sits under, else its map's name.
local logZone = {}
local questRequested, questResolved = {}, {}
-- [itemID] = whether it can be a quest item at all; fixed per item, so most
-- of your bag is skipped after one look.
local relevant = {}
local bagsDirty, questsDirty = true, true
local scanCount, lastScanMs = 0, 0
ns.safeCount = 0
ns.safeBagCount = 0

function ns.IsPlain(v)
    return not (issecretvalue and issecretvalue(v))
end

-- Saved variables are not loaded when this file runs, so the tables are made on use.
-- keep and hide are [itemID] = true; bank and warbank are the quest items the
-- last visit saw in the character tabs and in the account tabs.
function ns.CharDB()
    local db = BagBloatCharDB
    if not db then
        db = {}
        BagBloatCharDB = db
    end
    db.keep = db.keep or {}
    db.hide = db.hide or {}
    db.bank = db.bank or {}
    db.warbank = db.warbank or {}
    return db
end

-- [groupTitle] = true when the player collapsed that window group.
function ns.Collapsed()
    BagBloatDB = BagBloatDB or {}
    BagBloatDB.collapsed = BagBloatDB.collapsed or {}
    return BagBloatDB.collapsed
end

-- [mapID] = the map's name, or false when it has none. GetMapInfo builds a
-- table on every call, so each map is read once.
local mapNames = {}

local function MapName()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local name = mapNames[mapID]
    if name == nil then
        local info = C_Map.GetMapInfo(mapID)
        name = info and info.name or false
        mapNames[mapID] = name
    end
    return name or nil
end

-- Whether a zone name is where the player stands.
function ns.IsHere(zone)
    if not zone or zone == "" then return false end
    return zone == GetRealZoneText() or zone == GetZoneText() or zone == MapName()
end

-- [areaID] = the area's name, or false when the game has none.
local areaName = {}

local function AreaZoneName(questID)
    local areaID = QUEST_AREA[questID]
    if not areaID then return end
    local name = areaName[areaID]
    if name == nil then
        name = C_Map.GetAreaInfo(areaID)
        if not name or name == "" then name = false end
        areaName[areaID] = name
    end
    return name or nil
end

local function MapZoneName(questID)
    local mapID = GetQuestUiMapID and GetQuestUiMapID(questID)
    if not mapID or mapID <= 0 then return end
    local map = C_Map.GetMapInfo(mapID)
    return map and map.name
end

local function ReadQuestLog()
    wipe(logQuests); wipe(logObjectives); wipe(objText); wipe(objQuest); wipe(specialItems)
    wipe(logZone)
    local header
    local i = 1
    while true do
        local info = C_QuestLog.GetInfo(i)
        if not info then break end
        if info.isHeader then
            header = info.title
            if header == "" then header = nil end
        end
        local questID = not info.isHeader and info.questID
        if questID and questID > 0 then
            logQuests[questID] = info
            logZone[questID] = header or MapZoneName(questID)
            local objs = C_QuestLog.GetQuestObjectives(questID)
            if objs then
                logObjectives[questID] = objs
                for _, o in ipairs(objs) do
                    if o.text and o.text ~= "" then
                        local n = #objText + 1
                        objText[n], objQuest[n] = o.text, questID
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
    for i = 1, #objText do
        if find(objText[i], name, 1, true) then return objQuest[i] end
    end
end

-- The rules, on plain values, so an item in your bags and one remembered from
-- the bank are judged the same way. questID is what the game reports for the
-- item; the quest that owns an objective item comes back as the second value.
local function ClassifyQuest(itemID, itemName, questID, isActive, isQuestItem)
    if SECRET_ITEMS[itemID] then
        return "secret", questID and questID > 0 and questID or nil
    end
    if questID and questID > 0 then
        if isActive or logQuests[questID] or C_QuestLog.IsOnQuest(questID) then
            return "active", questID
        end
        -- A quest with no title is a hidden one, never shown to the player,
        -- so only a named quest can make the item safe to delete.
        local title = QuestTitle(questID)
        local named = title and title ~= ""
        if named then
            if C_QuestLog.IsQuestFlaggedCompleted(questID) then return "done", questID end
            local level = QuestLevel(questID)
            if level then return IsGray(level) and "gray" or "starter", questID end
        end
        if questResolved[questID] then return named and "starter" or "hidden", questID end
        if not questRequested[questID] then
            questRequested[questID] = true
            C_QuestLog.RequestLoadQuestByID(questID)
        end
        return "pending", questID
    end

    if not isQuestItem then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
        isQuestItem = classID == QUEST_ITEM_CLASS
    end
    if not isQuestItem then return nil end

    local owner = OwnerOfObjectiveItem(itemID, itemName)
    if owner then return "active", owner end
    return "orphan"
end

-- Your own lists decide last, for items in your bags and remembered ones alike.
-- Keeping never hides a quest you are on.
local function Override(verdict, itemID, keep, hide)
    if hide[itemID] then return "ignored" end
    if keep[itemID] and verdict ~= "active" then return "kept" end
    return verdict
end

local function IsRelevant(bag, slot, itemID)
    local known = relevant[itemID]
    if known ~= nil then return known end
    if SECRET_ITEMS[itemID] then
        relevant[itemID] = true
        return true
    end
    local qi = C_Container.GetContainerItemQuestInfo(bag, slot)
    if qi and (qi.isQuestItem or (qi.questID and qi.questID > 0)) then
        relevant[itemID] = true
        return true
    end
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID == QUEST_ITEM_CLASS then
        relevant[itemID] = true
        return true
    end
    -- A "no" is only final once the item has loaded: before that the quest
    -- info can be empty for an item that does start a quest.
    if classID ~= nil and C_Item.GetItemNameByID(itemID) then relevant[itemID] = false end
    return false
end

-- Remembered bank items have no bag or slot; they sort after the live ones.
local function ByVerdict(a, b)
    local oa, ob = VERDICTS[a.verdict].order, VERDICTS[b.verdict].order
    if oa ~= ob then return oa < ob end
    if a.name ~= b.name then return a.name < b.name end
    if a.bag ~= b.bag then return (a.bag or 100) < (b.bag or 100) end
    return (a.slot or 0) < (b.slot or 0)
end

-- A bank section (the character tabs, or the account tabs) reports its size
-- only while it is open and loaded. One can be readable without the other.
local function SectionReady(account)
    for _, bag in ipairs(BANK_BAGS) do
        if (IS_ACCOUNT[bag] or false) == account and C_Container.GetContainerNumSlots(bag) > 0 then
            return true
        end
    end
    return false
end

-- Bank contents arrive a moment after the bank opens, so a read this early
-- must not replace the memory.
local BANK_SETTLE = 1
local bankOpenedAt = 0

local function PoolRecord(n)
    local rec = recPool[n]
    if not rec then
        rec = {}
        recPool[n] = rec
    end
    return rec
end

-- Records are reused tables, so every field is set on every scan.
local function SetItemFields(rec, bag, slot, itemID, name, link, icon, count, quality, inBank, cached)
    rec.bag, rec.slot, rec.itemID, rec.inBank, rec.cached = bag, slot, itemID, inBank, cached
    rec.name, rec.link, rec.icon, rec.count, rec.quality = name or "", link, icon, count, quality
end

-- A quest under a collapsed log header may be missing from logZone.
local function ZoneFor(questID, verdict)
    if not questID then return end
    return logZone[questID] or (verdict == "active" and MapZoneName(questID)) or AreaZoneName(questID) or nil
end

local function SetQuestFields(rec, verdict, questID)
    local inLog = questID and logQuests[questID] ~= nil
    local level = questID and QuestLevel(questID)
    local title = questID and QuestTitle(questID)
    rec.verdict, rec.questID, rec.questLevel, rec.questTitle = verdict, questID, level, title
    rec.questText = title and (level and "[" .. level .. "] " .. title or title) or nil
    rec.zone = ZoneFor(questID, verdict)
    rec.objectives = inLog and logObjectives[questID] or nil
    rec.ready = inLog and C_QuestLog.ReadyForTurnIn(questID) or nil
end

-- One small entry per bank quest item, reusing the saved tables from the last
-- visit. Holds what the game reported, not the verdict: the rules run again
-- when the item is shown.
local function RememberBankItem(bank, i, itemID, info, qi)
    local entry = bank[i]
    if not entry then
        entry = {}
        bank[i] = entry
    end
    local questID = qi and qi.questID
    entry.itemID, entry.count = itemID, info.stackCount
    entry.questID = questID and questID > 0 and questID or nil
    entry.isQuestItem = qi and qi.isQuestItem or nil
    entry.name, entry.link, entry.icon, entry.quality = info.itemName, info.hyperlink, info.iconFileID, info.quality
end

-- Ends a scan for one bank section. A section read live keeps only what this
-- scan saw; one out of reach is listed from what the last visit saw.
local function CloseSection(list, live, settled, seen, n, safe, keep, hide)
    if live then
        if settled then
            for i = #list, seen + 1, -1 do list[i] = nil end
        end
        return n, safe
    end
    for i = 1, #list do
        local e = list[i]
        local verdict, questID = ClassifyQuest(e.itemID, e.name, e.questID, false, e.isQuestItem)
        if verdict then
            n = n + 1
            local rec = PoolRecord(n)
            verdict = Override(verdict, e.itemID, keep, hide)
            SetItemFields(rec, nil, nil, e.itemID, e.name, e.link, e.icon, e.count, e.quality, true, true)
            SetQuestFields(rec, verdict, questID)
            records[n] = rec
            if VERDICTS[verdict].safe then safe = safe + 1 end
        end
    end
    return n, safe
end

local function Scan()
    local started = debugprofilestop()
    if questsDirty then
        questsDirty = false
        ReadQuestLog()
    end
    bagsDirty = false
    wipe(records); wipe(byItem); wipe(bySlot)
    local cdb = ns.CharDB()
    local keep, hide = cdb.keep, cdb.hide
    local charLive = ns.bankOpen and SectionReady(false)
    local acctLive = ns.bankOpen and SectionReady(true)
    local settled = ns.bankOpen and GetTime() - bankOpenedAt >= BANK_SETTLE
    local n, safe, safeBag, charN, acctN = 0, 0, 0, 0, 0
    local lastBag = #BAGS + (ns.bankOpen and #BANK_BAGS or 0)
    for b = 1, lastBag do
        local bag = BAGS[b] or BANK_BAGS[b - #BAGS]
        local inBank = IS_BANK[bag] or nil
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            local info = itemID and IsRelevant(bag, slot, itemID) and C_Container.GetContainerItemInfo(bag, slot)
            local qi = info and C_Container.GetContainerItemQuestInfo(bag, slot)
            local verdict, questID
            if info then
                verdict, questID = ClassifyQuest(itemID, info.itemName, qi and qi.questID, qi and qi.isActive,
                    qi and qi.isQuestItem)
            end
            if verdict then
                n = n + 1
                local rec = PoolRecord(n)
                verdict = Override(verdict, itemID, keep, hide)
                SetItemFields(rec, bag, slot, itemID, info.itemName, info.hyperlink, info.iconFileID,
                    info.stackCount, info.quality, inBank, nil)
                SetQuestFields(rec, verdict, questID)
                records[n] = rec
                byItem[itemID] = byItem[itemID] or rec
                bySlot[ns.SlotKey(bag, slot)] = rec
                if VERDICTS[verdict].safe then
                    safe = safe + 1
                    if not inBank then safeBag = safeBag + 1 end
                end
                if inBank and settled then
                    if IS_ACCOUNT[bag] then
                        acctN = acctN + 1
                        RememberBankItem(cdb.warbank, acctN, itemID, info, qi)
                    else
                        charN = charN + 1
                        RememberBankItem(cdb.bank, charN, itemID, info, qi)
                    end
                end
            end
        end
    end
    n, safe = CloseSection(cdb.bank, charLive, settled, charN, n, safe, keep, hide)
    _, safe = CloseSection(cdb.warbank, acctLive, settled, acctN, n, safe, keep, hide)
    sort(records, ByVerdict)
    ns.safeCount, ns.safeBagCount = safe, safeBag
    scanCount = scanCount + 1
    lastScanMs = debugprofilestop() - started
    -- Records are reused tables: the window must never show an old row.
    ns.RefreshWindow()
end

-- In combat this only hands back the last scan: nothing reads the game
-- until combat ends.
function ns.Get()
    if (bagsDirty or questsDirty) and not InCombatLockdown() then Scan() end
    return records, byItem, bySlot
end

local refreshQueued = false
local function RunRefresh()
    refreshQueued = false
    if not (bagsDirty or questsDirty) or InCombatLockdown() then return end
    if not (ns.IsWindowShown() or ns.BagsOpen() or ns.bankOpen) then return end
    Scan()
    ns.RepaintMarks()
end

-- Bursts of bag and quest events collapse into one rescan, and only while
-- the bags or the window are open; otherwise the next tooltip or open does it.
function ns.MarkDirty(questsChanged)
    bagsDirty = true
    if questsChanged then questsDirty = true end
    if not refreshQueued then
        refreshQueued = true
        C_Timer.After(0.25, RunRefresh)
    end
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
    if not v.line then return end
    tooltip:AddLine(v.line, v.r, v.g, v.b, true)
    if rec.questText then tooltip:AddLine(rec.questText, 0.85, 0.85, 0.85, true) end
    if IsAltKeyDown() then AddDetailLines(tooltip, rec) end
    if tooltip == GameTooltip then tipOwner = tooltip:GetOwner() end
end

function ns.PickUp(rec)
    if not rec.bag then return end
    local info = C_Container.GetContainerItemInfo(rec.bag, rec.slot)
    if not info or info.itemID ~= rec.itemID then
        ns.MarkDirty()
        return
    end
    if CursorHasItem() then ClearCursor() end
    C_Container.PickupContainerItem(rec.bag, rec.slot)
end

-- Moves quest items between bags and bank one at a time. The queue holds
-- copies of bag, slot and itemID because records are reused tables. The bank
-- must be open before every single UseContainerItem: with it closed the call
-- would use the item.
local MOVE_DELAY, LOCKED_RETRIES, CURSOR_WAITS = 0.08, 3, 40
local cursorWaits = 0

-- The event flag and the banker interaction must both say the bank is open.
local function BankIsOpen()
    if not ns.bankOpen then return false end
    local pim = C_PlayerInteractionManager
    if BANKER and pim and pim.IsInteractingWithNpcOfType then
        return pim.IsInteractingWithNpcOfType(BANKER) == true
    end
    return true
end
ns.BankIsOpen = BankIsOpen

local moveBag, moveSlot, moveItem, moveTries = {}, {}, {}, {}
local moveHead, moveTail = 1, 0

local function Enqueue(bag, slot, itemID, tries)
    moveTail = moveTail + 1
    moveBag[moveTail], moveSlot[moveTail] = bag, slot
    moveItem[moveTail], moveTries[moveTail] = itemID, tries
end

local function EndMove()
    wipe(moveBag); wipe(moveSlot); wipe(moveItem); wipe(moveTries)
    moveHead, moveTail, cursorWaits = 1, 0, 0
    ns.moving = false
    ns.MarkDirty()
end

local function MoveStep()
    while moveHead <= moveTail do
        if not BankIsOpen() or InCombatLockdown() then break end
        -- An item on the cursor pauses the move rather than ending it.
        if CursorHasItem() then
            cursorWaits = cursorWaits + 1
            if cursorWaits > CURSOR_WAITS then break end
            C_Timer.After(0.25, MoveStep)
            return
        end
        local bag, slot, itemID, tries = moveBag[moveHead], moveSlot[moveHead], moveItem[moveHead], moveTries[moveHead]
        moveHead = moveHead + 1
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemID then
            if not info.isLocked then
                if BANK_TYPE and not IS_BANK[bag] then
                    C_Container.UseContainerItem(bag, slot, nil, BANK_TYPE)
                else
                    C_Container.UseContainerItem(bag, slot)
                end
                C_Timer.After(MOVE_DELAY, MoveStep)
                return
            elseif tries < LOCKED_RETRIES then
                Enqueue(bag, slot, itemID, tries + 1)
                C_Timer.After(MOVE_DELAY, MoveStep)
                return
            end
        end
    end
    EndMove()
end

-- toBank moves the records in your bags to the bank; otherwise the records in
-- the bank to your bags. Records on the other side are skipped.
function ns.MoveRecords(recs, toBank)
    if ns.moving or not BankIsOpen() or InCombatLockdown() then return end
    local wantBag = toBank and true or false
    for _, rec in ipairs(recs) do
        if rec.bag and (rec.inBank == nil) == wantBag then
            Enqueue(rec.bag, rec.slot, rec.itemID, 0)
        end
    end
    if moveTail == 0 then return end
    ns.moving = true
    MoveStep()
    ns.RefreshWindow()
end

local function SlotLocked(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    return info and info.isLocked
end

-- [itemID] = true once the game refused to delete it this session.
local refused = {}

-- The first record in list (default: all of them) that DeleteRecord would take.
function ns.NextDeletable(list)
    for _, rec in ipairs(list or records) do
        if rec.bag and not rec.inBank and VERDICTS[rec.verdict].safe and not refused[rec.itemID]
            and not SlotLocked(rec.bag, rec.slot) then
            return rec
        end
    end
end

-- Deletes the stack in one slot, and only when the quest rules still call it
-- safe. DeleteCursorItem needs a hardware event, so this runs straight from a
-- click and never from a timer. rec is a pooled table that a rescan reuses, so
-- the slot is copied first and checked again against a fresh scan.
function ns.DeleteRecord(rec)
    if not rec or InCombatLockdown() then return false end
    local bag, slot, itemID = rec.bag, rec.slot, rec.itemID
    if not bag or rec.inBank or not VERDICTS[rec.verdict].safe then return false end
    local _, _, slots = ns.Get()
    local fresh = slots[ns.SlotKey(bag, slot)]
    if not fresh or fresh.itemID ~= itemID or fresh.inBank or not VERDICTS[fresh.verdict].safe then return false end
    local link = fresh.link
    if CursorHasItem() or GetCursorInfo() then return false end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or info.itemID ~= itemID or info.isLocked then return false end
    C_Container.PickupContainerItem(bag, slot)
    local kind, id = GetCursorInfo()
    if kind == "item" and id == itemID then
        DeleteCursorItem()
        if CursorHasItem() then
            -- The game refused: put the item back and stop offering it.
            ClearCursor()
            refused[itemID] = true
            print("Bag Bloat: the game would not delete " .. (link or itemID))
            return false
        end
        print("Bag Bloat: deleted " .. (link or itemID))
        ns.MarkDirty()
        return true
    end
    ClearCursor()
    return false
end

-- Keeping and hiding exclude each other.
function ns.SetKeep(itemID, on)
    local cdb = ns.CharDB()
    cdb.keep[itemID] = on and true or nil
    if on then cdb.hide[itemID] = nil end
    ns.MarkDirty()
end

function ns.SetHide(itemID, on)
    local cdb = ns.CharDB()
    cdb.hide[itemID] = on and true or nil
    if on then cdb.keep[itemID] = nil end
    ns.MarkDirty()
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

local QUEST_EVENTS = { QUEST_LOG_UPDATE = true, QUEST_TURNED_IN = true }

-- A scan made outside the queued refresh repaints the bag icons itself.
local function Fresh()
    if (bagsDirty or questsDirty) and not InCombatLockdown() then
        Scan()
        ns.RepaintMarks()
    end
    return records
end

-- [zone] = true once this session's chat line about that zone's bank items ran.
local announced = {}

-- Quest items for the zone you are in that sit in the bank, live or remembered.
local function ZoneLine()
    if InCombatLockdown() then return end
    local zone = GetRealZoneText()
    if not zone or zone == "" then zone = GetZoneText() end
    if not zone or zone == "" or announced[zone] then return end
    local count = 0
    for _, rec in ipairs(Fresh()) do
        if rec.inBank and rec.zone and ns.IsHere(rec.zone) and not VERDICTS[rec.verdict].safe
            and rec.verdict ~= "ignored" then
            count = count + 1
        end
    end
    if count == 0 then return end
    announced[zone] = true
    if count == 1 then
        print(format("Bag Bloat: %d quest item for %s is in your bank.", count, zone))
    else
        print(format("Bag Bloat: %d quest items for %s are in your bank.", count, zone))
    end
end

local BAGS_FULL_GAP = 120
local lastFree, lastFullLine

-- Free slots in the general bags; bags that hold only reagents or the like do not count.
local function GeneralFreeSlots()
    local free = 0
    for bag = 0, 4 do
        local n, family = C_Container.GetContainerNumFreeSlots(bag)
        if n and (family or 0) == 0 then free = free + n end
    end
    return free
end

-- One chat line when the general bags fill up, and only when something in
-- them is safe to delete.
local function BagsFullLine()
    if InCombatLockdown() then return end
    local free = GeneralFreeSlots()
    local was = lastFree
    lastFree = free
    if free > 0 or not was or was == 0 then return end
    local now = GetTime()
    if lastFullLine and now - lastFullLine < BAGS_FULL_GAP then return end
    Fresh()
    local count = ns.safeBagCount
    if count == 0 then return end
    lastFullLine = now
    if count == 1 then
        print("Bag Bloat: bags full. 1 quest item is safe to delete. Type /bloat.")
    else
        print(format("Bag Bloat: bags full. %d quest items are safe to delete. Type /bloat.", count))
    end
end

-- Reads the bank once the game has had time to fill it, even with every
-- window closed, so the memory of the bank is always written.
local function ScanBank()
    if not ns.bankOpen or InCombatLockdown() then return end
    bagsDirty = true
    Scan()
    ns.RepaintMarks()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_REGEN_DISABLED" then
        ns.RefreshWindow()
        if event == "ZONE_CHANGED_NEW_AREA" then C_Timer.After(1, ZoneLine) end
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(5, ZoneLine)
        return
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.MarkDirty()
        BagsFullLine()
        return
    elseif event == "MODIFIER_STATE_CHANGED" then
        if arg1 == "LALT" or arg1 == "RALT" then OnAltChanged() end
        return
    elseif event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
        ns.bankOpen = event == "BANKFRAME_OPENED"
        if ns.bankOpen then
            bankOpenedAt = GetTime()
            C_Timer.After(BANK_SETTLE + 0.1, ScanBank)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if bagsDirty or questsDirty then ns.MarkDirty() else ns.RefreshWindow() end
        BagsFullLine()
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
    ns.MarkDirty(QUEST_EVENTS[event])
end)
for _, event in ipairs({
    "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN",
    "PLAYER_LEVEL_UP", "QUEST_DATA_LOAD_RESULT", "PLAYER_REGEN_ENABLED", "MODIFIER_STATE_CHANGED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED",
    "PLAYER_ENTERING_WORLD",
}) do
    events:RegisterEvent(event)
end

-- The first slot in your bags, or the open bank, that holds itemID.
function ns.FindItem(itemID)
    local lastBag = #BAGS + (ns.bankOpen and #BANK_BAGS or 0)
    for b = 1, lastBag do
        local bag = BAGS[b] or BANK_BAGS[b - #BAGS]
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if C_Container.GetContainerItemID(bag, slot) == itemID then return bag, slot end
        end
    end
end

-- What the game says about one item and what the rules made of it, as
-- "key: value" lines for /bloat why. bag and slot are nil for an item that is
-- not in your bags; the bank memory then stands in for the game's quest info.
function ns.Explain(bag, slot, itemID)
    ns.Get()
    local lines = {}
    local function add(key, value)
        lines[#lines + 1] = key .. ": " .. tostring(value)
    end
    local gameVersion, gameBuild = GetBuildInfo()
    add("addon version", C_AddOns.GetAddOnMetadata("BagBloat", "Version"))
    add("client build", gameVersion .. " (" .. tostring(gameBuild) .. ")")
    add("player level", UnitLevel("player"))

    local info, qi, entry
    if bag and C_Container.GetContainerItemID(bag, slot) == itemID then
        info = C_Container.GetContainerItemInfo(bag, slot)
        qi = C_Container.GetContainerItemQuestInfo(bag, slot)
    else
        if bag then add("note", "that slot holds a different item now") end
        bag, slot = nil, nil
        local cdb = ns.CharDB()
        for _, list in ipairs({ cdb.bank, cdb.warbank }) do
            for _, e in ipairs(list) do
                if e.itemID == itemID then entry = entry or e end
            end
        end
    end
    local name = info and info.itemName or entry and entry.name or C_Item.GetItemNameByID(itemID)
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    add("item id", itemID)
    add("name", name)
    add("quality", info and info.quality or entry and entry.quality)
    add("item class id", classID)
    add("item subclass id", subClassID)
    add("bag", bag)
    add("slot", slot)

    local isQuestItem, questID, isActive = qi and qi.isQuestItem, qi and qi.questID, qi and qi.isActive
    if entry then
        isQuestItem, questID = entry.isQuestItem, entry.questID
        add("source", "remembered bank entry")
    end
    add("quest info isQuestItem", isQuestItem)
    add("quest info questID", questID)
    add("quest info isActive", isActive)
    if questID and questID > 0 then
        add("quest title", QuestTitle(questID))
        add("quest difficulty level", C_QuestLog.GetQuestDifficultyLevel(questID))
        add("flagged completed", C_QuestLog.IsQuestFlaggedCompleted(questID))
        add("on quest", C_QuestLog.IsOnQuest(questID))
        add("in log", logQuests[questID] ~= nil)
        add("ready for turn-in", C_QuestLog.ReadyForTurnIn(questID))
        add("log zone", logZone[questID])
        add("quest ui map id", GetQuestUiMapID and GetQuestUiMapID(questID))
        add("table area id", QUEST_AREA[questID])
        add("table area name", AreaZoneName(questID))
        add("load requested", questRequested[questID])
        add("load resolved", questResolved[questID])
    end

    local cdb = ns.CharDB()
    local owner = OwnerOfObjectiveItem(itemID, name)
    add("in secret list", SECRET_ITEMS[itemID] == true)
    add("kept by you", cdb.keep[itemID] == true)
    add("hidden by you", cdb.hide[itemID] == true)
    add("objective owner", owner and (owner .. " " .. tostring(QuestTitle(owner))) or "none")
    local verdict, ownerID = ClassifyQuest(itemID, name, questID, isActive, isQuestItem)
    if verdict then verdict = Override(verdict, itemID, cdb.keep, cdb.hide) end
    add("final verdict", verdict and VERDICTS[verdict].label or "not a quest item")
    add("zone used", ZoneFor(ownerID, verdict) or "none")
    return lines
end

local function PrintStats()
    UpdateAddOnMemoryUsage()
    print(string.format("Bag Bloat: %.0f KB, %d quest items, %d scans, last scan %.2f ms",
        GetAddOnMemoryUsage("BagBloat"), #records, scanCount, lastScanMs))
end

SLASH_BAGBLOAT1 = "/bagbloat"
SLASH_BAGBLOAT2 = "/bloat"
SlashCmdList.BAGBLOAT = function(msg)
    local word, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    word = word:lower()
    if word == "stats" then
        PrintStats()
    elseif word == "why" then
        ns.Why(rest)
    else
        ns.ToggleWindow()
    end
end

function BagBloat_OnAddonCompartmentClick()
    ns.ToggleWindow()
end
