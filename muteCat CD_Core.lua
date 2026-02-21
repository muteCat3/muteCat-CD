local addonName, ns = ...

-- =============================================================================
-- Namespace & Initialization
-- =============================================================================
ns.Config = {
    essentialSize = 42,
    utilitySize = 32,
    buffSize = 30,
    borderThickness = 1,
}

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
f:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
f:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
f:RegisterEvent("CLIENT_SCENE_OPENED")
f:RegisterEvent("CLIENT_SCENE_CLOSED")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_UPDATE_RESTING")

local refreshHooked = false
local visibilityApplyQueued = false
local visibilityApplyDirty = false
local cvarConfigured = false

local function ShouldHideByVisibilityRules()
    local qol = _G.muteCatQOL
    if qol and qol.ShouldHideByVisibilityRules then
        return qol:ShouldHideByVisibilityRules()
    end
    -- Fallback if QoL is not loaded.
    if InCombatLockdown() then return false end
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then return false end
    if (C_ActionBar and C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar()) or UnitInVehicle("player") then return true end
    if (C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()) then return true end
    local shapeshiftFormID = GetShapeshiftFormID and GetShapeshiftFormID() or nil
    if IsMounted() or shapeshiftFormID == 3 or shapeshiftFormID == 29 or shapeshiftFormID == 27 then return true end
    if IsResting and IsResting() then return true end
    return false
end

local function GetViewerAlpha(viewer)
    if not viewer or not viewer.settingMap then
        return 1
    end
    local setting = viewer.settingMap[Enum.EditModeCooldownViewerSetting.Opacity]
    if setting and setting.value ~= nil then
        return (setting.value + 50) / 100
    end
    return 1
end

local function ApplyVisibilityRules()
    local hide = ShouldHideByVisibilityRules()
    local viewers = { EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer }
    for _, viewer in ipairs(viewers) do
        if viewer then
            viewer:SetAlpha(hide and 0 or GetViewerAlpha(viewer))
        end
    end
end

local function QueueApplyVisibilityRules(delay)
    if visibilityApplyQueued then
        visibilityApplyDirty = true
        return
    end
    visibilityApplyQueued = true
    C_Timer.After(delay or 0, function()
        visibilityApplyQueued = false
        ApplyVisibilityRules()
        if visibilityApplyDirty then
            visibilityApplyDirty = false
            QueueApplyVisibilityRules(0)
        end
    end)
end

local function EnsureViewerHooks()
    if refreshHooked then return end
    local function HookViewer(viewer)
        if viewer and viewer.RefreshLayout then
            hooksecurefunc(viewer, "RefreshLayout", function()
                QueueApplyVisibilityRules(0)
            end)
        end
    end
    HookViewer(EssentialCooldownViewer)
    HookViewer(UtilityCooldownViewer)
    HookViewer(BuffIconCooldownViewer)
    refreshHooked = true
end

local function ApplyCooldownViewerSkin()
    -- Midnight: Ensure the native viewers are active (only once per session).
    if not cvarConfigured then
        C_CVar.SetCVar("cooldownViewerEnabled", "1")
        cvarConfigured = true
    end
    if ns.ApplyStyles then
        ns.ApplyStyles()
    end
    EnsureViewerHooks()
    ApplyVisibilityRules()
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        ApplyCooldownViewerSkin()
        -- Load-order safety: viewers may initialize shortly after login.
        C_Timer.After(0.5, ApplyCooldownViewerSkin)
        C_Timer.After(2, ApplyCooldownViewerSkin)
    elseif event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "Blizzard_CooldownViewer" then
            ApplyCooldownViewerSkin()
            C_Timer.After(0, ApplyCooldownViewerSkin)
        end
    elseif event == "CLIENT_SCENE_OPENED" then
        local qol = _G.muteCatQOL
        if qol and qol.SetClientSceneActive then
            local sceneType = ...
            qol:SetClientSceneActive(sceneType == 1)
        end
        QueueApplyVisibilityRules(0)
    elseif event == "CLIENT_SCENE_CLOSED" then
        local qol = _G.muteCatQOL
        if qol and qol.SetClientSceneActive then
            qol:SetClientSceneActive(false)
        end
        QueueApplyVisibilityRules(0)
    elseif event == "PLAYER_REGEN_ENABLED"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "UPDATE_OVERRIDE_ACTIONBAR"
        or event == "MOUNT_JOURNAL_USABILITY_CHANGED"
        or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_VEHICLE_ACTIONBAR"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "PLAYER_UPDATE_RESTING"
    then
        QueueApplyVisibilityRules(0)
    end
end)
