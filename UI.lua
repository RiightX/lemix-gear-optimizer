local addonName, addon = ...

local UI = {}
addon.UI = UI

local configFrame
local profileSelector
local equipmentManagerButton

function UI:Initialize()
    configFrame = LemixGearOptimizerConfigFrame
    profileSelector = LemixGearOptimizerProfileSelector

    self:SetupConfigFrame()
    self:SetupProfileSelector()

    C_Timer.After(1, function()
        self:HookEquipmentManager()
    end)

    addon:Debug("UI initialized")
end

function UI:SetupConfigFrame()
    if not configFrame then return end

    configFrame.Title:SetText(addon.L.CONFIG_TITLE)

    local content = configFrame.ScrollFrame.Content

    local yOffset = -10

    local specLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    specLabel:SetPoint("TOPLEFT", 10, yOffset)
    specLabel:SetText("Current Spec Profiles")

    yOffset = yOffset - 30

    local createButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    createButton:SetSize(150, 25)
    createButton:SetPoint("TOPLEFT", 10, yOffset)
    createButton:SetText(addon.L.CREATE_PROFILE)
    createButton:SetScript("OnClick", function()
        self:ShowCreateProfileDialog()
    end)
    content.createButton = createButton

    local optimizeButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    optimizeButton:SetSize(150, 25)
    optimizeButton:SetPoint("LEFT", createButton, "RIGHT", 10, 0)
    optimizeButton:SetText(addon.L.OPTIMIZE_GEAR)
    optimizeButton:SetScript("OnClick", function()
        self:OptimizeCurrentProfile()
    end)
    content.optimizeButton = optimizeButton
    
    local showStatsButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    showStatsButton:SetSize(150, 25)
    showStatsButton:SetPoint("LEFT", optimizeButton, "RIGHT", 10, 0)
    showStatsButton:SetText("Show Current Stats")
    showStatsButton:SetScript("OnClick", function()
        self:ShowCurrentStats()
    end)
    content.showStatsButton = showStatsButton

    yOffset = yOffset - 35

    local profileListFrame = CreateFrame("Frame", nil, content)
    profileListFrame:SetSize(520, 300)
    profileListFrame:SetPoint("TOPLEFT", 10, yOffset)
    content.profileListFrame = profileListFrame

    yOffset = yOffset - 310

    local autoEquipCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    autoEquipCheck:SetPoint("TOPLEFT", 10, yOffset)
    autoEquipCheck.Text:SetText(addon.L.AUTO_EQUIP)
    autoEquipCheck:SetChecked(addon.db.settings.autoEquipOnSpecChange)
    autoEquipCheck:SetScript("OnClick", function(self)
        addon.db.settings.autoEquipOnSpecChange = self:GetChecked()
        addon:Print("Auto-equip " .. (self:GetChecked() and "enabled" or "disabled"))
    end)

    content.autoEquipCheck = autoEquipCheck
end

function UI:SetupProfileSelector()
    if not profileSelector then return end

    profileSelector.Title:SetText("Select Profile")

    profileSelector.CloseButton = profileSelector.CloseButton or _G[profileSelector:GetName() .. "CloseButton"]
    if profileSelector.CloseButton then
        profileSelector.CloseButton:SetScript("OnClick", function()
            profileSelector:Hide()
        end)
    end
end

function UI:ToggleConfigWindow()
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        self:UpdateProfileList()
        configFrame:Show()
    end
end

function UI:UpdateProfileList()
    if not configFrame then return end

    local content = configFrame.ScrollFrame.Content
    local profileListFrame = content.profileListFrame
    if not profileListFrame then return end

    for _, child in ipairs({profileListFrame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local specID = addon.ProfileManager:GetCurrentSpec()
    if not specID then
        local noSpec = profileListFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        noSpec:SetPoint("TOPLEFT", 0, 0)
        noSpec:SetText("No specialization selected")
        return
    end

    local profiles = addon.ProfileManager:GetSpecProfiles(specID)

    if not profiles or #profiles == 0 then
        local noProfiles = profileListFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        noProfiles:SetPoint("TOPLEFT", 0, 0)
        noProfiles:SetText(addon.L.NO_PROFILES)
        return
    end

    local yOffset = 0

    for i, profile in ipairs(profiles) do
        local frame = CreateFrame("Frame", nil, profileListFrame, "BackdropTemplate")
        frame:SetSize(500, 80)
        frame:SetPoint("TOPLEFT", 0, yOffset)
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local nameLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        nameLabel:SetPoint("TOPLEFT", 10, -10)
        nameLabel:SetText(profile.name)

        local statsLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        statsLabel:SetPoint("TOPLEFT", 10, -30)
        local statsText = "Primary: " .. (profile.primaryStat or "None")
        if profile.thresholds and next(profile.thresholds) then
            statsText = statsText .. " | Thresholds: "
            for stat, value in pairs(profile.thresholds) do
                statsText = statsText .. stat .. " " .. value .. "% "
            end
        end
        statsLabel:SetText(statsText)

        local equipButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        equipButton:SetSize(80, 22)
        equipButton:SetPoint("TOPRIGHT", -10, -10)
        equipButton:SetText(addon.L.EQUIP_SET)
        equipButton:SetScript("OnClick", function()
            self:EquipProfile(profile.name)
        end)

        local editButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        editButton:SetSize(60, 22)
        editButton:SetPoint("RIGHT", equipButton, "LEFT", -5, 0)
        editButton:SetText("Edit")
        editButton:SetScript("OnClick", function()
            self:ShowEditProfileDialog(profile)
        end)

        local deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        deleteButton:SetSize(60, 22)
        deleteButton:SetPoint("TOPRIGHT", -10, -38)
        deleteButton:SetText("Delete")
        deleteButton:SetScript("OnClick", function()
            self:DeleteProfile(profile.name)
        end)

        local setActiveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        setActiveButton:SetSize(80, 22)
        setActiveButton:SetPoint("RIGHT", deleteButton, "LEFT", -5, 0)
        setActiveButton:SetText("Set Active")
        setActiveButton:SetScript("OnClick", function()
            addon.ProfileManager:SetActiveProfile(profile.name)
            self:UpdateProfileList()
        end)

        local activeProfile = addon.ProfileManager:GetActiveProfile(specID)
        if activeProfile and activeProfile.name == profile.name then
            frame:SetBackdropColor(0.1, 0.3, 0.1, 0.8)
            local activeLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            activeLabel:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
            activeLabel:SetText("(Active)")
            activeLabel:SetTextColor(0, 1, 0)
        end

        yOffset = yOffset - 90
    end
end

function UI:ShowCreateProfileDialog()
    StaticPopupDialogs["LEMIX_CREATE_PROFILE"] = {
        text = "Enter profile name:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnShow = function(self)
            if self.EditBox then
                self.EditBox:SetFocus()
            end
        end,
        OnAccept = function(dialog)
            local editBox = dialog.EditBox or _G[dialog:GetName().."EditBox"]
            if not editBox then
                addon:Print("Error: Could not access edit box")
                return
            end
            local name = editBox:GetText()
            if name and name ~= "" then
                local profile = addon.ProfileManager:CreateProfile(name)
                if profile then
                    addon.UI:UpdateProfileList()
                    addon:Print("Profile created: " .. name)
                end
            else
                addon:Print("Profile name cannot be empty")
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local editBox = parent.EditBox or _G[parent:GetName().."EditBox"]
            if not editBox then
                addon:Print("Error: Could not access edit box")
                return
            end
            local name = editBox:GetText()
            if name and name ~= "" then
                local profile = addon.ProfileManager:CreateProfile(name)
                if profile then
                    addon.UI:UpdateProfileList()
                    addon:Print("Profile created: " .. name)
                end
            end
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("LEMIX_CREATE_PROFILE")
end

function UI:ShowEditProfileDialog(profile)
    if not profile then return end
    
    if not profile.traits then
        profile.traits = {}
    end
    
    local editFrame = CreateFrame("Frame", "LemixEditProfileFrame", UIParent, "BackdropTemplate")
    editFrame:SetSize(500, 550)
    editFrame:SetPoint("CENTER")
    editFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    editFrame:SetFrameStrata("DIALOG")
    editFrame:EnableMouse(true)
    
    local scrollChild = CreateFrame("Frame", nil, editFrame)
    scrollChild:SetSize(460, 700)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, editFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    scrollFrame:SetScrollChild(scrollChild)
    
    local title = editFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Edit Profile: " .. profile.name)
    
    local yOffset = -10

    local primaryLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    primaryLabel:SetPoint("TOPLEFT", 0, yOffset)
    primaryLabel:SetText("Primary Stat:")
    
    local primaryDropdown = CreateFrame("Frame", "LemixPrimaryStatDropdown", scrollChild, "UIDropDownMenuTemplate")
    primaryDropdown:SetPoint("LEFT", primaryLabel, "RIGHT", 0, -3)
    UIDropDownMenu_SetWidth(primaryDropdown, 100)
    UIDropDownMenu_SetText(primaryDropdown, profile.primaryStat or "None")
    
    UIDropDownMenu_Initialize(primaryDropdown, function(self, level)
        local stats = {"HASTE", "CRIT", "MASTERY", "VERSATILITY"}
        for _, stat in ipairs(stats) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = stat
            info.func = function()
                profile.primaryStat = stat
                UIDropDownMenu_SetText(primaryDropdown, stat)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    yOffset = yOffset - 40
    
    local thresholdLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    thresholdLabel:SetPoint("TOPLEFT", 0, yOffset)
    thresholdLabel:SetText("Stat Thresholds:")
    
    yOffset = yOffset - 30
    
    local thresholdContainer = CreateFrame("Frame", nil, scrollChild)
    thresholdContainer:SetSize(360, 100)
    thresholdContainer:SetPoint("TOPLEFT", 0, yOffset)
    
    local thresholdY = 0
    local stats = {"CRIT", "HASTE", "MASTERY"}
    for _, stat in ipairs(stats) do
        local statLabel = thresholdContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        statLabel:SetPoint("TOPLEFT", 0, thresholdY)
        statLabel:SetText(stat .. ":")
        
        local editBox = CreateFrame("EditBox", nil, thresholdContainer, "InputBoxTemplate")
        editBox:SetSize(60, 20)
        editBox:SetPoint("LEFT", statLabel, "RIGHT", 10, 0)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(true)
        if profile.thresholds and profile.thresholds[stat] then
            editBox:SetText(tostring(profile.thresholds[stat]))
        end
        editBox:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if value then
                if not profile.thresholds then
                    profile.thresholds = {}
                end
                profile.thresholds[stat] = value
            else
                if profile.thresholds then
                    profile.thresholds[stat] = nil
                end
            end
            self:ClearFocus()
        end)
        
        thresholdY = thresholdY - 30
    end
    
    yOffset = yOffset - 100
    
    local traitLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    traitLabel:SetPoint("TOPLEFT", 0, yOffset)
    traitLabel:SetText("Legion Remix Traits:")
    
    yOffset = yOffset - 25
    
    local traitHelpText = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    traitHelpText:SetPoint("TOPLEFT", 0, yOffset)
    traitHelpText:SetText("(Trinkets, Rings, Necks)")
    traitHelpText:SetTextColor(0.7, 0.7, 0.7)
    
    yOffset = yOffset - 25
    
    local traitContainer = CreateFrame("Frame", nil, scrollChild)
    traitContainer:SetSize(460, 250)
    traitContainer:SetPoint("TOPLEFT", 0, yOffset)
    
    local traitY = 0
    local traits = {
        "Touch of Malice",
        "Lure of the Unknown Depths",
        "Storm Surger",
        "Thunderlord's Wrath",
        "Fel Meteor",
    }
    
    for _, trait in ipairs(traits) do
        local traitLabelText = traitContainer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        traitLabelText:SetPoint("TOPLEFT", 0, traitY)
        traitLabelText:SetText(trait .. ":")
        traitLabelText:SetWidth(200)
        traitLabelText:SetJustifyH("LEFT")
        
        local traitEditBox = CreateFrame("EditBox", nil, traitContainer, "InputBoxTemplate")
        traitEditBox:SetSize(40, 20)
        traitEditBox:SetPoint("LEFT", traitLabelText, "RIGHT", 10, 0)
        traitEditBox:SetAutoFocus(false)
        traitEditBox:SetNumeric(true)
        traitEditBox:SetMaxLetters(1)
        if profile.traits and profile.traits[trait] then
            traitEditBox:SetText(tostring(profile.traits[trait]))
        end
        traitEditBox:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if value and value > 0 then
                if not profile.traits then
                    profile.traits = {}
                end
                profile.traits[trait] = math.min(value, 5)
            else
                if profile.traits then
                    profile.traits[trait] = nil
                end
            end
            self:ClearFocus()
        end)
        
        traitY = traitY - 30
    end

    local saveButton = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 25)
    saveButton:SetPoint("BOTTOM", -55, 20)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        addon:Print("Profile updated: " .. profile.name)
        addon:Print("Click 'Optimize Gear' to recalculate with new settings")
        editFrame:Hide()
        UI:UpdateProfileList()
    end)

    local cancelButton = CreateFrame("Button", nil, editFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 25)
    cancelButton:SetPoint("LEFT", saveButton, "RIGHT", 10, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        editFrame:Hide()
    end)

    editFrame:Show()
end

function UI:DeleteProfile(profileName)
    StaticPopupDialogs["LEMIX_DELETE_PROFILE"] = {
        text = "Delete profile '" .. profileName .. "'?",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            addon.ProfileManager:DeleteProfile(profileName)
            UI:UpdateProfileList()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("LEMIX_DELETE_PROFILE")
end

function UI:EquipProfile(profileName)
    local specID = addon.ProfileManager:GetCurrentSpec()
    if not specID then return end

    addon.GearOptimizer:OptimizeAndSave(profileName, specID)

    C_Timer.After(0.5, function()
        addon.GearOptimizer:EquipOptimizedSet(profileName, specID)
    end)
end

function UI:OptimizeCurrentProfile()
    local specID = addon.ProfileManager:GetCurrentSpec()
    if not specID then
        addon:Print("No spec selected")
        return
    end
    
    local activeProfile = addon.ProfileManager:GetActiveProfile(specID)
    if not activeProfile then
        addon:Print("No active profile set")
        return
    end
    
    addon.GearOptimizer:OptimizeAndSave(activeProfile.name, specID)
end

function UI:ShowCurrentStats()
    if not addon.StatScanner then
        addon:Print("StatScanner not available")
        return
    end
    
    local equipped = addon.StatScanner:GetEquippedItems()
    local totals = addon.StatScanner:CalculateTotalStats(equipped)
    
    addon:Print("=== Currently Equipped Stats ===")
    local statOrder = {"CRIT", "HASTE", "MASTERY", "VERSATILITY"}
    for _, stat in ipairs(statOrder) do
        local value = totals[stat]
        if value and value > 0 then
            addon:Print(stat .. ": " .. string.format("%.1f%%", value))
        end
    end
    
    local traits = addon.StatScanner:GetEquippedTraits()
    if next(traits) then
        addon:Print("=== Current Traits ===")
        for trait, count in pairs(traits) do
            addon:Print(trait .. ": x" .. count)
        end
    end
end

function UI:HookEquipmentManager()
    if PaperDollFrame and not equipmentManagerButton then
        self:CreateEquipmentManagerButton()
    end
end

function UI:CreateEquipmentManagerButton()
    if equipmentManagerButton then return end

    if not PaperDollFrame then
        C_Timer.After(2, function()
            self:CreateEquipmentManagerButton()
        end)
        return
    end

    equipmentManagerButton = CreateFrame("Button", "LemixGearOptimizerButton", PaperDollFrame, "UIPanelButtonTemplate")
    equipmentManagerButton:SetSize(120, 22)
    equipmentManagerButton:SetPoint("BOTTOMLEFT", PaperDollFrame, "BOTTOMLEFT", 15, 80)
    equipmentManagerButton:SetText("Lemix Optimizer")
    equipmentManagerButton:SetScript("OnClick", function()
        self:ShowProfileSelectorForEquip()
    end)

    addon:Debug("Equipment Manager button created")
end

function UI:ShowProfileSelectorForEquip()
    if not profileSelector then return end

    local content = profileSelector.ScrollFrame.Content

    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local specID = addon.ProfileManager:GetCurrentSpec()
    if not specID then
        local noSpec = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        noSpec:SetPoint("TOPLEFT", 0, 0)
        noSpec:SetText("No specialization selected")
        profileSelector:Show()
        return
    end

    local profiles = addon.ProfileManager:GetSpecProfiles(specID)

    if not profiles or #profiles == 0 then
        local noProfiles = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        noProfiles:SetPoint("TOPLEFT", 0, 0)
        noProfiles:SetText(addon.L.NO_PROFILES)
        profileSelector:Show()
        return
    end

    local yOffset = 0

    for i, profile in ipairs(profiles) do
        local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        button:SetSize(220, 30)
        button:SetPoint("TOPLEFT", 10, yOffset)
        button:SetText(profile.name)
        button:SetScript("OnClick", function()
            self:EquipProfile(profile.name)
            profileSelector:Hide()
        end)

        yOffset = yOffset - 35
    end

    local configButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    configButton:SetSize(220, 30)
    configButton:SetPoint("TOPLEFT", 10, yOffset - 10)
    configButton:SetText("Open Configuration")
    configButton:SetScript("OnClick", function()
        profileSelector:Hide()
        self:ToggleConfigWindow()
    end)

    profileSelector:Show()
end

