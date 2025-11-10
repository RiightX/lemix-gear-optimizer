local addonName, addon = ...

local GearOptimizer = {}
addon.GearOptimizer = GearOptimizer

local optimizedSets = {}

function GearOptimizer:Initialize()
    addon:Debug("GearOptimizer initialized")
end

function GearOptimizer:ScoreItemForProfile(item, profile, currentTotals)
    if not item or not item.stats or not profile then return 0 end

    local score = 0
    local stats = item.stats

    if profile.primaryStat and stats[profile.primaryStat] then
        score = score + (stats[profile.primaryStat] * 1000)
    end

    if profile.thresholds then
        for stat, threshold in pairs(profile.thresholds) do
            if stats[stat] and currentTotals[stat] < threshold then
                local needed = threshold - currentTotals[stat]
                score = score + (math.min(stats[stat], needed) * 500)
            end
        end
    end

    if profile.secondaryStats then
        for _, statInfo in ipairs(profile.secondaryStats) do
            local stat = statInfo.stat
            local priority = statInfo.priority
            if stats[stat] then
                score = score + (stats[stat] * (100 - priority * 10))
            end
        end
    end

    return score
end

function GearOptimizer:OptimizeGearForProfile(profile)
    if not profile then
        addon:Print("No profile specified")
        return nil
    end

    if not addon.StatScanner then
        addon:Print("StatScanner not available")
        return nil
    end

    local allGear = addon.StatScanner:GetAllAvailableGear()

    if not next(allGear) then
        addon:Print("No gear found to optimize")
        return nil
    end

    local bestSet = {}
    local currentTotals = {
        HASTE = 0,
        CRIT = 0,
        MASTERY = 0,
        VERSATILITY = 0,
    }

    local sortedSlots = {}
    for slotID in pairs(allGear) do
        table.insert(sortedSlots, slotID)
    end
    table.sort(sortedSlots)

    for _, slotID in ipairs(sortedSlots) do
        local items = allGear[slotID]
        local bestItem = nil
        local bestScore = -1

        for _, item in ipairs(items) do
            local score = self:ScoreItemForProfile(item, profile, currentTotals)
            if score > bestScore then
                bestScore = score
                bestItem = item
            end
        end

        if bestItem then
            bestSet[slotID] = bestItem

            if bestItem.stats then
                for stat, value in pairs(bestItem.stats) do
                    currentTotals[stat] = currentTotals[stat] + value
                end
            end
        end
    end

    return bestSet, currentTotals
end

function GearOptimizer:OptimizeGearGreedy(profile)
    if not profile then return nil end
    if not addon.StatScanner then return nil end

    local allGear = addon.StatScanner:GetAllAvailableGear()
    if not next(allGear) then return nil end

    local primaryStat = profile.primaryStat
    local thresholds = profile.thresholds or {}
    local secondaryStats = profile.secondaryStats or {}
    local traits = profile.traits or {}

    local TRAIT_SLOTS = {[2] = true, [11] = true, [12] = true, [13] = true, [14] = true}

    local statGear = {}
    local traitGear = {}

    for slotID, items in pairs(allGear) do
        if TRAIT_SLOTS[slotID] then
            traitGear[slotID] = items
        else
            statGear[slotID] = items
        end
    end

    local bestSet, totals
    local hasThresholds = next(thresholds) ~= nil

    if hasThresholds then
        bestSet, totals = self:OptimizeWithThresholds(statGear, primaryStat, thresholds, secondaryStats)
    else
        bestSet, totals = self:OptimizeSimple(statGear, primaryStat, secondaryStats)
    end

    if not bestSet then
        bestSet = {}
        totals = {HASTE = 0, CRIT = 0, MASTERY = 0, VERSATILITY = 0}
    end

    local traitSet = self:OptimizeTraits(traitGear, traits)
    for slotID, item in pairs(traitSet) do
        bestSet[slotID] = item
    end

    return bestSet, totals
end

function GearOptimizer:OptimizeWithThresholds(allGear, primaryStat, thresholds, secondaryStats)
    local MAX_ITERATIONS = 1000
    local iteration = 0

    local bestOverallSet = nil
    local bestOverallScore = -math.huge
    local bestOverallTotals = nil

    local sortedSlots = {}
    for slotID in pairs(allGear) do
        table.insert(sortedSlots, slotID)
    end
    table.sort(sortedSlots)

    local function tryConfiguration(slotIndex, currentSet, currentTotals, unmetThresholds)
        iteration = iteration + 1
        if iteration > MAX_ITERATIONS then return end

        if slotIndex > #sortedSlots then
            local configScore = self:ScoreConfiguration(currentSet, currentTotals, primaryStat, thresholds, secondaryStats, unmetThresholds)
            if configScore > bestOverallScore then
                bestOverallScore = configScore
                bestOverallSet = {}
                bestOverallTotals = {}
                for k, v in pairs(currentSet) do
                    bestOverallSet[k] = v
                end
                for k, v in pairs(currentTotals) do
                    bestOverallTotals[k] = v
                end
            end
            return
        end

        local slotID = sortedSlots[slotIndex]
        local items = allGear[slotID]

        local sortedItems = {}
        for _, item in ipairs(items) do
            local itemScore = self:ScoreItemForThresholds(item, currentTotals, unmetThresholds, primaryStat)
            table.insert(sortedItems, {item = item, score = itemScore})
        end
        table.sort(sortedItems, function(a, b) return a.score > b.score end)

        local itemsToTry = math.min(3, #sortedItems)
        for i = 1, itemsToTry do
            local item = sortedItems[i].item

            local newSet = {}
            for k, v in pairs(currentSet) do newSet[k] = v end
            newSet[slotID] = item

            local newTotals = {}
            for k, v in pairs(currentTotals) do newTotals[k] = v end
            if item.stats then
                for stat, value in pairs(item.stats) do
                    newTotals[stat] = newTotals[stat] + value
                end
            end

            local newUnmetThresholds = {}
            for stat, threshold in pairs(thresholds) do
                if newTotals[stat] < threshold then
                    newUnmetThresholds[stat] = threshold
                end
            end

            tryConfiguration(slotIndex + 1, newSet, newTotals, newUnmetThresholds)
        end
    end

    local initialTotals = {HASTE = 0, CRIT = 0, MASTERY = 0, VERSATILITY = 0}
    tryConfiguration(1, {}, initialTotals, thresholds)

    return bestOverallSet, bestOverallTotals
end

function GearOptimizer:ScoreItemForThresholds(item, currentTotals, unmetThresholds, primaryStat)
    if not item or not item.stats then return 0 end

    local score = 0

    for stat, threshold in pairs(unmetThresholds) do
        if item.stats[stat] then
            local contribution = item.stats[stat]
            score = score + (contribution * 10000)
        end
    end

    if primaryStat and item.stats[primaryStat] then
        score = score + (item.stats[primaryStat] * 100)
    end

    score = score + ((item.itemLevel or 0) * 0.1)

    return score
end

function GearOptimizer:ScoreConfiguration(gearSet, totals, primaryStat, thresholds, secondaryStats, unmetThresholds)
    local score = 0

    local thresholdPenalty = 0
    for stat, threshold in pairs(thresholds) do
        if totals[stat] < threshold then
            local deficit = threshold - totals[stat]
            thresholdPenalty = thresholdPenalty + (deficit * 1000000)
        end
    end

    score = score - thresholdPenalty

    if primaryStat and totals[primaryStat] then
        score = score + (totals[primaryStat] * 1000)
    end

    for i, statInfo in ipairs(secondaryStats) do
        if totals[statInfo.stat] then
            score = score + (totals[statInfo.stat] * (100 / i))
        end
    end

    return score
end

function GearOptimizer:OptimizeSimple(allGear, primaryStat, secondaryStats)
    local bestSet = {}
    local currentTotals = {HASTE = 0, CRIT = 0, MASTERY = 0, VERSATILITY = 0}

    for slotID, items in pairs(allGear) do
        local bestItem = nil
        local bestScore = -math.huge

        for _, item in ipairs(items) do
            if item.stats then
                local score = 0

                if primaryStat and item.stats[primaryStat] then
                    score = score + (item.stats[primaryStat] * 1000)
                end

                for i, statInfo in ipairs(secondaryStats) do
                    if item.stats[statInfo.stat] then
                        score = score + (item.stats[statInfo.stat] * (100 / i))
                    end
                end

                score = score + ((item.itemLevel or 0) * 0.1)

                if score > bestScore then
                    bestScore = score
                    bestItem = item
                elseif score == bestScore and bestItem then
                    if (item.itemLevel or 0) > (bestItem.itemLevel or 0) then
                        bestItem = item
                    end
                end
            end
        end

        if bestItem then
            bestSet[slotID] = bestItem
            if bestItem.stats then
                for stat, value in pairs(bestItem.stats) do
                    currentTotals[stat] = currentTotals[stat] + value
                end
            end
        end
    end

    return bestSet, currentTotals
end

function GearOptimizer:OptimizeTraits(traitGear, traitPrefs)
    local bestSet = {}
    local usedTraits = {}

    for trait, count in pairs(traitPrefs) do
        usedTraits[trait] = 0
    end

    local sortedSlots = {}
    for slotID in pairs(traitGear) do
        table.insert(sortedSlots, slotID)
    end
    table.sort(sortedSlots)

    for _, slotID in ipairs(sortedSlots) do
        local items = traitGear[slotID]
        local bestItem = nil
        local bestScore = -math.huge

        for _, item in ipairs(items) do
            local score = 0

            if item.trait and traitPrefs[item.trait] then
                local currentCount = usedTraits[item.trait] or 0
                local desiredCount = traitPrefs[item.trait]

                if currentCount < desiredCount then
                    score = score + 100000
                end
            end

            score = score + ((item.itemLevel or 0) * 100)

            if score > bestScore then
                bestScore = score
                bestItem = item
            elseif score == bestScore and bestItem then
                if (item.itemLevel or 0) > (bestItem.itemLevel or 0) then
                    bestItem = item
                end
            end
        end

        if bestItem then
            bestSet[slotID] = bestItem
            if bestItem.trait then
                usedTraits[bestItem.trait] = (usedTraits[bestItem.trait] or 0) + 1
            end
        end
    end

    return bestSet
end

function GearOptimizer:GetOptimizedSet(profileName, specID)
    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then return nil end

    local key = specID .. "_" .. profileName
    return optimizedSets[key]
end

function GearOptimizer:SetOptimizedSet(profileName, gearSet, specID)
    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then return end

    local key = specID .. "_" .. profileName
    optimizedSets[key] = gearSet
end

function GearOptimizer:OptimizeAndSave(profileName, specID)
    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then
        addon:Print("No spec selected")
        return false
    end

    local profile = addon.ProfileManager:GetProfile(profileName, specID)
    if not profile then
        addon:Print("Profile not found: " .. profileName)
        return false
    end

    addon:Print("Optimizing gear for profile: " .. profileName)
    addon:Print("  Primary stat: " .. (profile.primaryStat or "None"))
    if profile.thresholds and next(profile.thresholds) then
        local threshStr = "  Thresholds: "
        for stat, value in pairs(profile.thresholds) do
            threshStr = threshStr .. stat .. " " .. value .. "%, "
        end
        addon:Print(threshStr)
    end

    local gearSet, totals = self:OptimizeGearGreedy(profile)

    if not gearSet then
        addon:Print("Failed to optimize gear")
        return false
    end

    self:SetOptimizedSet(profileName, {
        gearSet = gearSet,
        totals = totals,
        timestamp = time(),
    }, specID)

    addon:Print("Optimization complete!")
    if totals then
        local statOrder = {"CRIT", "HASTE", "MASTERY", "VERSATILITY"}
        local statStr = "Optimized stats: "
        for _, stat in ipairs(statOrder) do
            local value = totals[stat]
            if value and value > 0 then
                statStr = statStr .. stat .. ": " .. string.format("%.1f%%", value) .. " | "
            end
        end
        addon:Print(statStr)

        if profile.thresholds then
            for stat, threshold in pairs(profile.thresholds) do
                local current = totals[stat] or 0
                if current < threshold then
                    addon:Print("WARNING: Could not reach " .. stat .. " threshold of " .. threshold .. "% (got " .. string.format("%.1f%%", current) .. ")")
                end
            end
        end
    end

    if gearSet and profile.traits and next(profile.traits) then
        local equippedTraits = {}
        local TRAIT_SLOTS = {[2] = true, [11] = true, [12] = true, [13] = true, [14] = true}
        for slotID, item in pairs(gearSet) do
            if TRAIT_SLOTS[slotID] and item.trait then
                equippedTraits[item.trait] = (equippedTraits[item.trait] or 0) + 1
            end
        end

        local traitStr = "Traits: "
        for trait, count in pairs(equippedTraits) do
            traitStr = traitStr .. trait .. " x" .. count .. " | "
        end
        addon:Print(traitStr)

        for trait, desiredCount in pairs(profile.traits) do
            local actualCount = equippedTraits[trait] or 0
            if actualCount < desiredCount then
                addon:Print("WARNING: Could not equip " .. desiredCount .. "x " .. trait .. " (got " .. actualCount .. ")")
            end
        end
    end

    addon:Print("Click 'Equip Set' to equip the optimized gear")

    return true, gearSet, totals
end

function GearOptimizer:EquipOptimizedSet(profileName, specID)
    specID = specID or addon.ProfileManager:GetCurrentSpec()
    if not specID then return false end

    local optimizedData = self:GetOptimizedSet(profileName, specID)
    if not optimizedData or not optimizedData.gearSet then
        addon:Print("No optimized set found. Run optimization first.")
        return false
    end

    if InCombatLockdown() then
        addon:Print("Cannot equip gear during combat")
        return false
    end

    local gearSet = optimizedData.gearSet
    local equippedCount = 0

    for slotID, item in pairs(gearSet) do
        local currentItemLink = GetInventoryItemLink("player", slotID)

        if currentItemLink ~= item.itemLink then
            if item.bag and item.slot then
                C_Container.PickupContainerItem(item.bag, item.slot)
                PickupInventoryItem(slotID)
                equippedCount = equippedCount + 1
            end
        end
    end

    if equippedCount > 0 then
        addon:Print("Equipped " .. equippedCount .. " items for: " .. profileName)
    else
        addon:Print("All optimal items already equipped")
    end
    return true
end

