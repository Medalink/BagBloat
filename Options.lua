local _, ns = ...

local OPTIONS = {
    {
        key = "openWithBank", default = true, name = "Open with the bank",
        tip = "Opens the Bag Bloat window when you open your bank and closes it when you leave.",
    },
    {
        key = "openWithBags", default = false, name = "Open with your bags",
        tip = "Opens the Bag Bloat window when you open your bags and closes it with them."
            .. " Works with the game's bags and EllesmereUI Bags.",
    },
    {
        key = "byZone", default = true, name = "Group by zone",
        tip = "Groups the window's items by the zone of their quest. Off shows one list.",
    },
    {
        key = "zoneLine", default = true, name = "Chat line for banked items",
        tip = "On entering a zone, says how many quest items for it are in your bank.",
    },
    {
        key = "fullLine", default = true, name = "Chat line when bags fill up",
        tip = "Says how many quest items are safe to delete when your bags fill up.",
    },
}

local DEFAULT, settings = {}, {}
local category
for _, option in ipairs(OPTIONS) do DEFAULT[option.key] = option.default end

--- The saved value of an option, or its default when you never changed it.
function ns.Option(key)
    local value = BagBloatDB and BagBloatDB[key]
    if value == nil then return DEFAULT[key] end
    return value
end

--- Sets an option from outside the settings page, and keeps the page in step.
function ns.SetOption(key, value)
    local setting = settings[key]
    if setting then
        setting:SetValue(value)
    else
        BagBloatDB = BagBloatDB or {}
        BagBloatDB[key] = value
    end
end

local function OnChanged()
    ns.RefreshWindow()
end

--- Adds the Bag Bloat page to the game's AddOns settings. Runs once saved variables are loaded.
function ns.RegisterOptions()
    if category then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting
        and Settings.CreateCheckbox and Settings.RegisterAddOnCategory) then
        return
    end
    BagBloatDB = BagBloatDB or {}
    category = Settings.RegisterVerticalLayoutCategory("Bag Bloat")
    for _, option in ipairs(OPTIONS) do
        local key = option.key
        if type(BagBloatDB[key]) ~= "boolean" then BagBloatDB[key] = option.default end
        local setting = Settings.RegisterAddOnSetting(category, "BagBloat_" .. key, key, BagBloatDB,
            Settings.VarType.Boolean, option.name, option.default)
        setting:SetValueChangedCallback(OnChanged)
        Settings.CreateCheckbox(category, setting, option.tip)
        settings[key] = setting
    end
    Settings.RegisterAddOnCategory(category)
end

--- Opens the game's settings on the Bag Bloat page.
function ns.OpenOptions()
    if not (category and Settings.OpenToCategory) then
        print("Bag Bloat: this client has no addon settings page.")
    elseif InCombatLockdown() then
        print("Bag Bloat: the settings open out of combat.")
    else
        Settings.OpenToCategory(category:GetID())
    end
end
