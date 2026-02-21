local _, ns = ...
local cfg = ns.Config
local ipairs = ipairs
local pcall = pcall

-- =============================================================================
-- Styling Utilities
-- =============================================================================

local SQUARE_TEXTURE_PATH = "Interface\\AddOns\\muteCat CD\\Square"
local ICON_ZOOM = 0.06
local ICON_CROP = ICON_ZOOM * 0.5
local COOLDOWN_FONT_SIZE_DEFAULT = 14
local COOLDOWN_FONT_SIZE_BUFF = 10
local COOLDOWN_FONT_SIZE_UTILITY = 10
local STACK_FONT_SIZE = 16

local VIEWER_STYLE = {
    essential = { cooldownFontSize = COOLDOWN_FONT_SIZE_DEFAULT, iconSize = cfg.essentialSize },
    utility = { cooldownFontSize = COOLDOWN_FONT_SIZE_UTILITY, iconSize = cfg.utilitySize },
    buff = { cooldownFontSize = COOLDOWN_FONT_SIZE_BUFF, iconSize = cfg.buffSize },
}

local function GetIconTexture(iconFrame)
    if not iconFrame then return nil end
    return iconFrame.Icon or iconFrame.icon or iconFrame.IconTexture
end

local function ForceHide(tex)
    if not tex then return end
    tex:Hide()
    tex:SetAlpha(0)
    if not tex.__mcHideHooked and tex.HookScript then
        tex:HookScript("OnShow", function(self)
            self:Hide()
            self:SetAlpha(0)
        end)
        tex.__mcHideHooked = true
    end
end

local function HideOutOfRangeOverlay(iconFrame)
    if not iconFrame then return end
    local outOfRange = iconFrame.OutOfRange or iconFrame.outOfRange
    if not outOfRange then return end

    outOfRange:SetTexture(nil)
    ForceHide(outOfRange)
end

local function HideNativeBorderTextures(iconFrame)
    if not iconFrame then return end

    -- Common native border candidates (not our custom lower-case `icon.border`).
    ForceHide(iconFrame.Border)
    ForceHide(iconFrame.DebuffBorder)
    ForceHide(iconFrame.CooldownFlash)
    ForceHide(iconFrame.Ring)

    local regions = { iconFrame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.IsObjectType and region:IsObjectType("Texture") and region.GetName then
            local n = region:GetName()
            if n and (n:find("Border") or n:find("Debuff")) then
                ForceHide(region)
            end
        end
    end
end

local function ApplyIconCoreStyle(icon)
    local iconTexture = GetIconTexture(icon)
    if not iconTexture then return end

    if iconTexture.SetTexCoord then
        pcall(iconTexture.SetTexCoord, iconTexture, ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    end
    iconTexture:ClearAllPoints()
    iconTexture:SetAllPoints(icon)
end

local function IsComparableTexture(value)
    if issecretvalue then
        return not issecretvalue(value)
    end
    return true
end

local function IsTextureId(value, id)
    if not IsComparableTexture(value) then
        return false
    end
    local ok, result = pcall(function()
        return value == id
    end)
    return ok and result or false
end

local function IsOverlayAtlas(region, atlasName)
    if not region or not region.GetAtlas then
        return false
    end
    local ok, atlas = pcall(region.GetAtlas, region)
    return ok and type(atlas) == "string" and atlas == atlasName
end

local function ApplyCooldownSquareStyle(icon)
    for i = 1, select("#", icon:GetChildren()) do
        local child = select(i, icon:GetChildren())
        if child and child.SetSwipeTexture then
            child:SetSwipeTexture(SQUARE_TEXTURE_PATH)
            child:SetDrawEdge(false)
            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", icon, "TOPLEFT", cfg.borderThickness, -cfg.borderThickness)
            child:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cfg.borderThickness, cfg.borderThickness)
        end
    end

    for _, region in ipairs({ icon:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            local isDefaultSwipe = IsTextureId(texture, 6707800)

            if isDefaultSwipe then
                region:SetTexture(SQUARE_TEXTURE_PATH)
            elseif IsOverlayAtlas(region, "UI-HUD-CoolDownManager-IconOverlay") then
                region:SetAlpha(0)
            end
        end
    end
end

local function ApplyCooldownTextStyle(cooldown, fontSize)
    if not cooldown then return end
    local targetSize = fontSize or COOLDOWN_FONT_SIZE_DEFAULT

    local regions = { cooldown:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            local font, _, flags = region:GetFont()
            if font then
                region:SetFont(font, targetSize, flags)
            end
            region:SetShadowOffset(1, -1)
            region:SetShadowColor(0, 0, 0, 1)
        end
    end
end

local function ApplyStackTextStyle(icon)
    if not icon then return end

    local viewerType = icon.__mcViewerType
    if viewerType == "utility" then
        -- User requested: don't change utility stacks.
        return
    end

    local anchorPoint = "TOPRIGHT"
    local offsetX, offsetY = 0, 0
    if viewerType == "buff" then
        anchorPoint = "TOP"
        offsetX, offsetY = 1, 8
    end

    local function StyleStackFontString(fs)
        if not fs then return end
        local font, _, flags = fs:GetFont()
        if font then
            fs:SetFont(font, STACK_FONT_SIZE, flags)
        end
        fs:ClearAllPoints()
        fs:SetPoint(anchorPoint, icon, anchorPoint, offsetX, offsetY)
        fs:SetJustifyH(anchorPoint == "TOPRIGHT" and "RIGHT" or "CENTER")
        fs:SetJustifyV("TOP")
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    end

    -- CMC-style explicit paths (avoids touching cooldown text).
    local stackFS = nil
    if viewerType == "buff" then
        stackFS = icon.Applications and icon.Applications.Applications
        if icon.Applications and icon.Applications.SetFrameLevel then
            icon.Applications:SetFrameLevel(20)
        end
    else
        stackFS = icon.ChargeCount and icon.ChargeCount.Current
        if icon.ChargeCount and icon.ChargeCount.SetFrameLevel then
            icon.ChargeCount:SetFrameLevel(20)
        end
    end

    -- Fallback for templates that expose a direct count font string.
    if not stackFS then
        if icon.Count and icon.Count.IsObjectType and icon.Count:IsObjectType("FontString") then
            stackFS = icon.Count
        elseif icon.count and icon.count.IsObjectType and icon.count:IsObjectType("FontString") then
            stackFS = icon.count
        end
    end

    StyleStackFontString(stackFS)
end

local function SkinIcon(icon, cooldownFontSize, viewerType)
    if not icon then return end

    icon.__mcCooldownFontSize = cooldownFontSize or COOLDOWN_FONT_SIZE_DEFAULT
    icon.__mcViewerType = viewerType

    -- Always re-apply icon skin core; Blizzard may reset these on layout updates.
    ApplyIconCoreStyle(icon)

    if not icon.__mcSkinned then
        if not icon.border then
            local border = CreateFrame("Frame", nil, icon, "BackdropTemplate")
            border:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = cfg.borderThickness,
            })
            border:SetBackdropBorderColor(0, 0, 0, 1)
            icon.border = border
        end

        -- Hide default visual clutter.
        if icon.Shadow then icon.Shadow:Hide() end
        if icon.Gloss then icon.Gloss:Hide() end
        if icon.SetNormalTexture then icon:SetNormalTexture(nil) end
        if icon.GetNormalTexture and icon:GetNormalTexture() then icon:GetNormalTexture():SetAlpha(0) end
        if icon.SetPushedTexture then icon:SetPushedTexture(nil) end
        if icon.SetHighlightTexture then icon:SetHighlightTexture(nil) end

        if not icon.__mcStyleHooked then
            icon:HookScript("OnShow", function(self)
                local cd = self.cooldown or self.Cooldown
                ApplyCooldownTextStyle(cd, self.__mcCooldownFontSize or COOLDOWN_FONT_SIZE_DEFAULT)
                ApplyStackTextStyle(self)
                HideOutOfRangeOverlay(self)
                HideNativeBorderTextures(self)
            end)
            icon.__mcStyleHooked = true
        end

        icon.__mcSkinned = true
    end

    -- Always re-apply dynamic elements; Blizzard can reset these during updates.
    local cooldown = icon.cooldown or icon.Cooldown
    if cooldown then
        ApplyCooldownTextStyle(cooldown, icon.__mcCooldownFontSize)
    end
    ApplyCooldownSquareStyle(icon)

    HideOutOfRangeOverlay(icon)
    HideNativeBorderTextures(icon)
    ApplyStackTextStyle(icon)
end

-- =============================================================================
-- Public Interface
-- =============================================================================

function ns.ApplyStyles()
    local function SkinViewerItems(viewer, viewerType)
        if not viewer then return end
        local style = VIEWER_STYLE[viewerType] or VIEWER_STYLE.essential
        local children = { viewer:GetChildren() }
        for _, child in ipairs(children) do
            if GetIconTexture(child) then
                if style.iconSize then
                    child:SetSize(style.iconSize, style.iconSize)
                end
                SkinIcon(child, style.cooldownFontSize, viewerType)
            end
        end
    end

    if EssentialCooldownViewer and not EssentialCooldownViewer.__mcHooked then
        hooksecurefunc(EssentialCooldownViewer, "RefreshLayout", function()
            SkinViewerItems(EssentialCooldownViewer, "essential")
        end)
        EssentialCooldownViewer.__mcHooked = true
    end
    if UtilityCooldownViewer and not UtilityCooldownViewer.__mcHooked then
        hooksecurefunc(UtilityCooldownViewer, "RefreshLayout", function()
            SkinViewerItems(UtilityCooldownViewer, "utility")
        end)
        UtilityCooldownViewer.__mcHooked = true
    end
    if BuffIconCooldownViewer and not BuffIconCooldownViewer.__mcHooked then
        hooksecurefunc(BuffIconCooldownViewer, "RefreshLayout", function()
            SkinViewerItems(BuffIconCooldownViewer, "buff")
        end)
        BuffIconCooldownViewer.__mcHooked = true
    end

    SkinViewerItems(EssentialCooldownViewer, "essential")
    SkinViewerItems(UtilityCooldownViewer, "utility")
    SkinViewerItems(BuffIconCooldownViewer, "buff")
end
