local _, ns = ...

local format, floor, rad = string.format, math.floor, math.rad

local FLAT = "Interface\\Buttons\\WHITE8X8"
local DISABLED_ALPHA = 0.4

local UI = {}
ns.UI = UI

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
    danger = { 1, 0.278, 0.459, 1 },
    overlay = { 0.141, 0.141, 0.141, 1 },
}
UI.C = C
UI.FLAT = FLAT

function UI.Hex(c)
    return format("|cff%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

function UI.Tint(fs, c)
    fs:SetTextColor(c[1], c[2], c[3], c[4])
end

function UI.Fill(tex, c)
    tex:SetColorTexture(c[1], c[2], c[3], c[4])
end

function UI.Solid(parent, layer, c)
    local tex = parent:CreateTexture(nil, layer)
    UI.Fill(tex, c)
    return tex
end

function UI.Skin(f, fill, edge)
    f:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
    f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end
local Tint, Fill, Skin = UI.Tint, UI.Fill, UI.Skin

-- Expressway, when EllesmereUI or SharedMedia has it. Resolved on first use;
-- false means looked for and not found.
local fontPath

local function ResolveFont()
    if EllesmereUI and EllesmereUI.EXPRESSWAY then return EllesmereUI.EXPRESSWAY end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    return lsm and lsm:Fetch("font", "Expressway", true)
end

-- With Expressway the text takes the Meda role size; without it the template font stays.
function UI.ApplyFont(fs, size)
    if fontPath == nil then fontPath = ResolveFont() or false end
    if not fontPath then return end
    local _, current, flags = fs:GetFont()
    if current then fs:SetFont(fontPath, size or current, flags) end
end

-- A flat backdrop: fill and a 1px border. The frame needs BackdropTemplate.
function UI.Panel(f, fill, edge)
    f:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    Skin(f, fill or C.bg, edge or C.border)
    return f
end

-- Flat button: clear fill, border color, brighter border on hover, raised fill
-- while pressed. A button with a tone keeps that color on its border and label.
local function PaintButton(button)
    local live = button.hover and button:IsEnabled()
    local tone = button.tone
    local edge = tone or (live and C.borderHover or C.border)
    local fill = C.clear
    if button.down then
        fill = C.surfaceHover
    elseif live and tone then
        fill = C.surface
    end
    Skin(button, fill, edge)
end

function UI.ShowTip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.tip or "", 1, 1, 1)
    GameTooltip:Show()
end

local function ButtonOnEnter(button)
    button.hover = true
    PaintButton(button)
    UI.ShowTip(button)
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

-- A disabled button dims as a whole and still shows its tip.
function UI.SetEnabled(button, enabled)
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or DISABLED_ALPHA)
    PaintButton(button)
end

function UI.Button(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    UI.Panel(button, C.clear)
    PaintButton(button)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    Tint(button.label, C.text)
    UI.ApplyFont(button.label, 12)

    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", ButtonOnEnter)
    button:SetScript("OnLeave", ButtonOnLeave)
    button:SetScript("OnMouseDown", ButtonOnDown)
    button:SetScript("OnMouseUp", ButtonOnUp)
    button:SetScript("OnHide", ButtonOnLeave)
    return button
end

-- A tone colors the border and label; nil goes back to the plain look.
function UI.SetTone(button, c)
    button.tone = c
    Tint(button.label, c or C.text)
    PaintButton(button)
end

local function PaintClose(close)
    local c = close.hover and C.text or C.section
    Fill(close.a, c)
    Fill(close.b, c)
end

local function CloseOnLeave(close)
    close.hover = false
    PaintClose(close)
end

local function CloseOnClick(close)
    close:GetParent():Hide()
end

function UI.CloseButton(parent, onClick)
    local close = CreateFrame("Button", nil, parent)
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
    close:SetScript("OnLeave", CloseOnLeave)
    close:SetScript("OnHide", CloseOnLeave)
    close:SetScript("OnClick", onClick or CloseOnClick)
    return close
end
