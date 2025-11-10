local addonName, addon = ...

local EquipmentManager = {}
addon.EquipmentManager = EquipmentManager

local pendingEquip = nil

function EquipmentManager:Initialize()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    self.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.frame:SetScript("OnEvent", function(frame, event, ...)
        self:OnEvent(event, ...)
    end)

    addon:Debug("EquipmentManager initialized")
end

function EquipmentManager:OnEvent(event, ...)
    if event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        self:OnSpecChange()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingEquip then
            self:EquipProfile(pendingEquip.profile, pendingEquip.specID)
            pendingEquip = nil
        end
    end
end

function EquipmentManager:OnSpecChange()
    if not addon.db.settings.autoEquipOnSpecChange then
        return
    end

    local specID = addon.ProfileManager:GetCurrentSpec()
    if not specID then return end

    local activeProfile = addon.ProfileManager:GetActiveProfile(specID)
    if not activeProfile then
        addon:Debug("No active profile for spec " .. specID)
        return
    end

    addon:Print("Spec changed, auto-equipping profile: " .. activeProfile.name)

    self:EquipProfile(activeProfile.name, specID)
end

function EquipmentManager:EquipProfile(profileName, specID)
    if InCombatLockdown() then
        addon:Print("Cannot equip gear during combat. Will equip after combat.")
        pendingEquip = {profile = profileName, specID = specID}
        return false
    end

    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then return false end

    local optimizedData = addon.GearOptimizer:GetOptimizedSet(profileName, specID)

    if not optimizedData or not optimizedData.gearSet then
        addon:Print("No optimized gear set found. Run optimization first.")

        local success = addon.GearOptimizer:OptimizeAndSave(profileName, specID)
        if success then
            optimizedData = addon.GearOptimizer:GetOptimizedSet(profileName, specID)
        else
            return false
        end
    end

    local gearSet = optimizedData.gearSet

    for slotID, item in pairs(gearSet) do
        if item.bag and item.slot then
            local currentItemLink = GetInventoryItemLink("player", slotID)
            if currentItemLink ~= item.itemLink then
                C_Container.PickupContainerItem(item.bag, item.slot)
                PickupInventoryItem(slotID)
            end
        end
    end

    addon:Print("Equipped profile: " .. profileName)
    return true
end

function EquipmentManager:CreateEquipmentSet(profileName, gearSet, specID)
    if InCombatLockdown() then
        addon:Print("Cannot create equipment set during combat")
        return false
    end

    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then return false end

    local setName = "LGO_" .. profileName .. "_" .. specID

    local existingSets = C_EquipmentSet.GetEquipmentSetIDs()
    for _, setID in ipairs(existingSets) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
        if name == setName then
            C_EquipmentSet.DeleteEquipmentSet(setID)
        end
    end

    for slotID, item in pairs(gearSet) do
        if item.bag and item.slot then
            local currentItemLink = GetInventoryItemLink("player", slotID)
            if currentItemLink ~= item.itemLink then
                C_Container.PickupContainerItem(item.bag, item.slot)
                PickupInventoryItem(slotID)
            end
        end
    end

    C_Timer.After(0.5, function()
        local newSetID = C_EquipmentSet.CreateEquipmentSet(setName)
        if newSetID then
            addon:Print("Created equipment set: " .. setName)
        else
            addon:Print("Failed to create equipment set")
        end
    end)

    return true
end

function EquipmentManager:UseEquipmentSet(profileName, specID)
    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then return false end

    local setName = "LGO_" .. profileName .. "_" .. specID

    local existingSets = C_EquipmentSet.GetEquipmentSetIDs()
    for _, setID in ipairs(existingSets) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
        if name == setName then
            if InCombatLockdown() then
                addon:Print("Cannot equip set during combat")
                return false
            end

            C_EquipmentSet.UseEquipmentSet(setID)
            addon:Print("Equipped set: " .. setName)
            return true
        end
    end

    addon:Print("Equipment set not found: " .. setName)
    return false
end

function EquipmentManager:GetEquipmentSetForProfile(profileName, specID)
    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then return nil end

    local setName = "LGO_" .. profileName .. "_" .. specID

    local existingSets = C_EquipmentSet.GetEquipmentSetIDs()
    for _, setID in ipairs(existingSets) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
        if name == setName then
            return setID
        end
    end

    return nil
end

function EquipmentManager:HookEquipmentManagerFrame()
    if not PaperDollFrame then return end

    if addon.UI and addon.UI.CreateEquipmentManagerButton then
        addon.UI:CreateEquipmentManagerButton()
    end
end

