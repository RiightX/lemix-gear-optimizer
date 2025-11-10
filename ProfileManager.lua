local addonName, addon = ...

local ProfileManager = {}
addon.ProfileManager = ProfileManager

function ProfileManager:Initialize()
    addon:Debug("ProfileManager initialized")
end

function ProfileManager:GetCurrentSpec()
    return GetSpecialization()
end

function ProfileManager:GetSpecProfiles(specID)
    specID = specID or self:GetCurrentSpec()
    if not specID then return {} end
    
    if not addon.db.profiles[specID] then
        addon.db.profiles[specID] = {}
    end
    
    return addon.db.profiles[specID]
end

function ProfileManager:CreateProfile(name, specID)
    specID = specID or self:GetCurrentSpec()
    if not specID then
        addon:Print("Cannot create profile: No spec selected")
        return false
    end
    
    if not addon.db.profiles[specID] then
        addon.db.profiles[specID] = {}
    end
    
    for _, profile in ipairs(addon.db.profiles[specID]) do
        if profile.name == name then
            addon:Print("Profile '" .. name .. "' already exists")
            return false
        end
    end
    
    local profile = {
        name = name,
        primaryStat = "HASTE",
        thresholds = {},
        secondaryStats = {},
        traits = {},
    }
    
    table.insert(addon.db.profiles[specID], profile)
    addon:Print("Created profile: " .. name)
    return profile
end

function ProfileManager:DeleteProfile(profileName, specID)
    specID = specID or self:GetCurrentSpec()
    if not specID then return false end
    
    local profiles = addon.db.profiles[specID]
    if not profiles then return false end
    
    for i, profile in ipairs(profiles) do
        if profile.name == profileName then
            table.remove(profiles, i)
            
            if addon.db.activeProfiles[specID] == profileName then
                addon.db.activeProfiles[specID] = nil
            end
            
            addon:Print("Deleted profile: " .. profileName)
            return true
        end
    end
    
    return false
end

function ProfileManager:GetProfile(profileName, specID)
    specID = specID or self:GetCurrentSpec()
    if not specID then return nil end
    
    local profiles = addon.db.profiles[specID]
    if not profiles then return nil end
    
    for _, profile in ipairs(profiles) do
        if profile.name == profileName then
            return profile
        end
    end
    
    return nil
end

function ProfileManager:SetActiveProfile(profileName, specID)
    specID = specID or self:GetCurrentSpec()
    if not specID then return false end
    
    local profile = self:GetProfile(profileName, specID)
    if not profile then
        addon:Print("Profile not found: " .. profileName)
        return false
    end
    
    addon.db.activeProfiles[specID] = profileName
    addon:Print("Active profile set to: " .. profileName)
    return true
end

function ProfileManager:GetActiveProfile(specID)
    specID = specID or self:GetCurrentSpec()
    if not specID then return nil end
    
    local profileName = addon.db.activeProfiles[specID]
    if not profileName then return nil end
    
    return self:GetProfile(profileName, specID)
end

function ProfileManager:UpdateProfile(profileName, updates, specID)
    specID = specID or self:GetCurrentSpec()
    if not specID then return false end
    
    local profile = self:GetProfile(profileName, specID)
    if not profile then return false end
    
    for key, value in pairs(updates) do
        profile[key] = value
    end
    
    return true
end

function ProfileManager:AddThreshold(profileName, stat, value, specID)
    specID = specID or self:GetCurrentSpec()
    local profile = self:GetProfile(profileName, specID)
    if not profile then return false end
    
    if not profile.thresholds then
        profile.thresholds = {}
    end
    
    profile.thresholds[stat] = value
    return true
end

function ProfileManager:RemoveThreshold(profileName, stat, specID)
    specID = specID or self:GetCurrentSpec()
    local profile = self:GetProfile(profileName, specID)
    if not profile then return false end
    
    if profile.thresholds then
        profile.thresholds[stat] = nil
    end
    
    return true
end

function ProfileManager:AddSecondaryStat(profileName, stat, priority, specID)
    specID = specID or self:GetCurrentSpec()
    local profile = self:GetProfile(profileName, specID)
    if not profile then return false end
    
    if not profile.secondaryStats then
        profile.secondaryStats = {}
    end
    
    table.insert(profile.secondaryStats, {stat = stat, priority = priority})
    
    table.sort(profile.secondaryStats, function(a, b)
        return a.priority < b.priority
    end)
    
    return true
end

function ProfileManager:ClearSecondaryStats(profileName, specID)
    specID = specID or self:GetCurrentSpec()
    local profile = self:GetProfile(profileName, specID)
    if not profile then return false end
    
    profile.secondaryStats = {}
    return true
end

