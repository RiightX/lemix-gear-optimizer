local addonName, addon = ...

local StatScanner = {}
addon.StatScanner = StatScanner

local scanTooltip
local itemCache = {}
local INVENTORY_SLOTS = {
    [1] = "HEADSLOT",
    [2] = "NECKSLOT",
    [3] = "SHOULDERSLOT",
    [5] = "CHESTSLOT",
    [6] = "WAISTSLOT",
    [7] = "LEGSSLOT",
    [8] = "FEETSLOT",
    [9] = "WRISTSLOT",
    [10] = "HANDSSLOT",
    [11] = "FINGER0SLOT",
    [12] = "FINGER1SLOT",
    [13] = "TRINKET0SLOT",
    [14] = "TRINKET1SLOT",
    [15] = "BACKSLOT",
    [16] = "MAINHANDSLOT",
    [17] = "SECONDARYHANDSLOT",
}

local TRAIT_SLOTS = {
    [2] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
}

local KNOWN_TRAITS = {
    "Touch of Malice",
    "Lure of the Unknown Depths",
    "Storm Surger",
    "Thunderlord's Wrath",
    "Fel Meteor",
    "Chaos Nova",
    "Void Tendril",
    "Fel Burst",
    "Holy Nova",
    "Light's Judgment",
}

function StatScanner:Initialize()
    scanTooltip = CreateFrame("GameTooltip", "LemixGearOptimizerScanTooltip", UIParent, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.frame:SetScript("OnEvent", function(frame, event, ...)
        if event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
            itemCache = {}
        end
    end)

    addon:Debug("StatScanner initialized")
end

function StatScanner:ParseStatLine(line)
    if not line or line == "" then return nil end

    line = line:gsub("|r", "")
    line = line:gsub("|c%x%x%x%x%x%x%x%x", "")

    local stats = {}
    local value, stat

    value, stat = line:match("^([%d%.%+%-,]+)%%%s*([%w%s%.]+)$")

    if not value or not stat then
        stat, value = line:match("^([%w%s%.]+)%s+([%d%.%+%-,]+)%%$")
    end

    if value and stat then
        value = value:gsub("[^%d%-%.%+]", "")

        local numValue = tonumber(value)
        if numValue then
            local statUpper = stat:upper():gsub("%s+", "")

            if statUpper == "HASTE" or statUpper:find("HASTE") then
                stats.HASTE = (stats.HASTE or 0) + numValue
            elseif statUpper:find("CRIT") then
                stats.CRIT = (stats.CRIT or 0) + numValue
            elseif statUpper:find("MAST") then
                stats.MASTERY = (stats.MASTERY or 0) + numValue
            elseif statUpper:find("VERS") then
                stats.VERSATILITY = (stats.VERSATILITY or 0) + numValue
            end
        end
    end

    return next(stats) and stats or nil
end

function StatScanner:ScanItemTooltip(itemLink)
    if not itemLink then return nil end

    if itemCache[itemLink] then
        return itemCache[itemLink].stats, itemCache[itemLink].trait, itemCache[itemLink].itemLevel
    end

    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)

    local stats = {
        HASTE = 0,
        CRIT = 0,
        MASTERY = 0,
        VERSATILITY = 0,
    }

    local trait = nil

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    local itemLevel = 0
    if itemID then
        local itemInfo = {C_Item.GetItemInfo(itemLink)}
        if itemInfo and itemInfo[4] then
            itemLevel = itemInfo[4]
        end
    end

    local numLines = scanTooltip:NumLines()
    for i = 1, numLines do
        local leftText = _G["LemixGearOptimizerScanTooltipTextLeft" .. i]
        if leftText then
            local line = leftText:GetText()
            if line then
                if addon.db and addon.db.settings and addon.db.settings.debug then
                    addon:Debug("Tooltip line " .. i .. ": " .. line)
                end

                local lineStats = self:ParseStatLine(line)
                if lineStats then
                    for stat, value in pairs(lineStats) do
                        stats[stat] = stats[stat] + value
                    end
                end

                if not trait then
                    trait = self:ParseTraitLine(line)
                end
            end
        end

        local rightText = _G["LemixGearOptimizerScanTooltipTextRight" .. i]
        if rightText then
            local line = rightText:GetText()
            if line then
                local lineStats = self:ParseStatLine(line)
                if lineStats then
                    for stat, value in pairs(lineStats) do
                        stats[stat] = stats[stat] + value
                    end
                end
            end
        end
    end

    local hasStats = false
    for _, value in pairs(stats) do
        if value > 0 then
            hasStats = true
            break
        end
    end

    if hasStats and addon.db and addon.db.settings and addon.db.settings.debug then
        local debugStr = "Parsed stats for " .. itemLink .. ": "
        for stat, value in pairs(stats) do
            if value > 0 then
                debugStr = debugStr .. stat .. "=" .. value .. "% "
            end
        end
        addon:Debug(debugStr)
    end

    local cacheData = {
        stats = hasStats and stats or nil,
        trait = trait,
        itemLevel = itemLevel,
    }

    itemCache[itemLink] = cacheData
    return cacheData.stats, cacheData.trait, cacheData.itemLevel
end

function StatScanner:ParseTraitLine(line)
    if not line then return nil end

    for _, trait in ipairs(KNOWN_TRAITS) do
        if line:find(trait) then
            return trait
        end
    end

    return nil
end

function StatScanner:GetEquippedItems()
    local equipped = {}

    for slotID, slotName in pairs(INVENTORY_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local stats, trait, itemLevel = self:ScanItemTooltip(itemLink)
            equipped[slotID] = {
                itemLink = itemLink,
                slotName = slotName,
                stats = stats,
                trait = trait,
                itemLevel = itemLevel,
                isTraitSlot = TRAIT_SLOTS[slotID] or false,
            }
        end
    end

    return equipped
end

function StatScanner:GetBagItems()
    local bagItems = {}

    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.hyperlink then
                    local itemLink = itemInfo.hyperlink
                    local itemEquipLoc = select(4, C_Item.GetItemInfoInstant(itemLink))

                    if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_BAG" then
                        local stats, trait, itemLevel = self:ScanItemTooltipFromBag(bag, slot, itemLink)
                        local slotIDs = self:GetSlotIDsFromEquipLoc(itemEquipLoc)
                        for _, slotID in ipairs(slotIDs) do
                            if not bagItems[slotID] then
                                bagItems[slotID] = {}
                            end

                            table.insert(bagItems[slotID], {
                                itemLink = itemLink,
                                bag = bag,
                                slot = slot,
                                stats = stats,
                                trait = trait,
                                itemLevel = itemLevel,
                                isTraitSlot = TRAIT_SLOTS[slotID] or false,
                            })
                        end
                    end
                end
            end
        end
    end

    return bagItems
end

function StatScanner:ScanItemTooltipFromBag(bag, slot, itemLink)
    if not itemLink then return nil end

    if itemCache[itemLink] then
        return itemCache[itemLink].stats, itemCache[itemLink].trait, itemCache[itemLink].itemLevel
    end

    scanTooltip:ClearLines()
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:SetBagItem(bag, slot)

    local stats = {
        HASTE = 0,
        CRIT = 0,
        MASTERY = 0,
        VERSATILITY = 0,
    }

    local trait = nil

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    local itemLevel = 0
    if itemID then
        local itemInfo = {C_Item.GetItemInfo(itemLink)}
        if itemInfo and itemInfo[4] then
            itemLevel = itemInfo[4]
        end
    end

    local numLines = scanTooltip:NumLines()
    for i = 1, numLines do
        local leftText = _G["LemixGearOptimizerScanTooltipTextLeft" .. i]
        if leftText then
            local line = leftText:GetText()
            if line then
                if addon.db and addon.db.settings and addon.db.settings.debug then
                    addon:Debug("Bag item line " .. i .. ": " .. line)
                end

                local lineStats = self:ParseStatLine(line)
                if lineStats then
                    for stat, value in pairs(lineStats) do
                        stats[stat] = stats[stat] + value
                    end
                end

                if not trait then
                    trait = self:ParseTraitLine(line)
                end
            end
        end
    end

    scanTooltip:Hide()

    local hasStats = false
    for _, value in pairs(stats) do
        if value > 0 then
            hasStats = true
            break
        end
    end

    if hasStats and addon.db and addon.db.settings and addon.db.settings.debug then
        local debugStr = "Parsed bag item " .. itemLink .. ": "
        for stat, value in pairs(stats) do
            if value > 0 then
                debugStr = debugStr .. stat .. "=" .. value .. "% "
            end
        end
        addon:Debug(debugStr)
    end

    local cacheData = {
        stats = hasStats and stats or nil,
        trait = trait,
        itemLevel = itemLevel,
    }

    itemCache[itemLink] = cacheData
    return cacheData.stats, cacheData.trait, cacheData.itemLevel
end

function StatScanner:GetSlotIDFromEquipLoc(equipLoc)
    local mapping = {
        INVTYPE_HEAD = 1,
        INVTYPE_NECK = 2,
        INVTYPE_SHOULDER = 3,
        INVTYPE_CHEST = 5,
        INVTYPE_ROBE = 5,
        INVTYPE_WAIST = 6,
        INVTYPE_LEGS = 7,
        INVTYPE_FEET = 8,
        INVTYPE_WRIST = 9,
        INVTYPE_HAND = 10,
        INVTYPE_FINGER = 11,
        INVTYPE_TRINKET = 13,
        INVTYPE_CLOAK = 15,
        INVTYPE_WEAPON = 16,
        INVTYPE_2HWEAPON = 16,
        INVTYPE_WEAPONMAINHAND = 16,
        INVTYPE_WEAPONOFFHAND = 17,
        INVTYPE_SHIELD = 17,
        INVTYPE_HOLDABLE = 17,
    }

    return mapping[equipLoc]
end

function StatScanner:GetSlotIDsFromEquipLoc(equipLoc)
    if equipLoc == "INVTYPE_FINGER" then
        return {11, 12}
    elseif equipLoc == "INVTYPE_TRINKET" then
        return {13, 14}
    else
        local slotID = self:GetSlotIDFromEquipLoc(equipLoc)
        return slotID and {slotID} or {}
    end
end

function StatScanner:GetAllAvailableGear()
    local allGear = {}

    local equipped = self:GetEquippedItems()
    for slotID, item in pairs(equipped) do
        if not allGear[slotID] then
            allGear[slotID] = {}
        end
        table.insert(allGear[slotID], item)
    end

    local bagItems = self:GetBagItems()
    for slotID, items in pairs(bagItems) do
        if not allGear[slotID] then
            allGear[slotID] = {}
        end
        for _, item in ipairs(items) do
            table.insert(allGear[slotID], item)
        end
    end

    return allGear
end

function StatScanner:CalculateTotalStats(itemSet)
    local total = {
        HASTE = 0,
        CRIT = 0,
        MASTERY = 0,
        VERSATILITY = 0,
    }

    for slotID, item in pairs(itemSet) do
        if item and item.stats and not TRAIT_SLOTS[slotID] then
            for stat, value in pairs(item.stats) do
                total[stat] = total[stat] + value
            end
        end
    end

    return total
end

function StatScanner:GetEquippedTraits()
    local traits = {}

    for slotID in pairs(TRAIT_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local _, trait = self:ScanItemTooltip(itemLink)
            if trait then
                traits[trait] = (traits[trait] or 0) + 1
            end
        end
    end

    return traits
end

function StatScanner:ClearCache()
    itemCache = {}
end

