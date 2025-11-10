local addonName, addon = ...

LemixGearOptimizer = addon
addon.name = addonName
addon.version = "0.2.2"

local frame = CreateFrame("Frame")
addon.frame = frame

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            addon:OnInitialize()
        end
    elseif event == "PLAYER_LOGIN" then
        addon:OnEnable()
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", OnEvent)

function addon:OnInitialize()
    if not LemixGearOptimizerDB then
        LemixGearOptimizerDB = {
            profiles = {},
            activeProfiles = {},
            settings = {
                autoEquipOnSpecChange = true,
                scanBankItems = false,
            }
        }
    end

    addon.db = LemixGearOptimizerDB

    self:Print("Initialized v" .. self.version)
end

function addon:OnEnable()
    self:Print("Loaded! Type /lgo to open configuration")

    if addon.ProfileManager then
        addon.ProfileManager:Initialize()
    end

    if addon.StatScanner then
        addon.StatScanner:Initialize()
    end

    if addon.GearOptimizer then
        addon.GearOptimizer:Initialize()
    end

    if addon.EquipmentManager then
        addon.EquipmentManager:Initialize()
    end

    if addon.UI then
        addon.UI:Initialize()
    end
end

function addon:Print(msg)
    print("|cff00ff00[Lemix Gear Optimizer]|r " .. tostring(msg))
end

function addon:Debug(msg)
    if self.db and self.db.settings and self.db.settings.debug then
        print("|cffff9900[LGO Debug]|r " .. tostring(msg))
    end
end

SLASH_LEMIXGEAROPTIMIZER1 = "/lgo"
SLASH_LEMIXGEAROPTIMIZER2 = "/lemixgear"
SlashCmdList["LEMIXGEAROPTIMIZER"] = function(msg)
    msg = msg:lower():trim()

    if msg == "stats" or msg == "show" then
        if addon.UI and addon.UI.ShowCurrentStats then
            addon.UI:ShowCurrentStats()
        end
    elseif msg == "debug" or msg == "debug on" then
        addon.db.settings.debug = true
        addon:Print("Debug mode enabled. Hover over items to see tooltip parsing.")
        if addon.StatScanner then
            addon.StatScanner:ClearCache()
        end
    elseif msg == "debug off" then
        addon.db.settings.debug = false
        addon:Print("Debug mode disabled")
    elseif msg == "clear" or msg == "clearcache" then
        if addon.StatScanner then
            addon.StatScanner:ClearCache()
            addon:Print("Item cache cleared")
        end
    else
        if addon.UI and addon.UI.ToggleConfigWindow then
            addon.UI:ToggleConfigWindow()
        end
    end
end

