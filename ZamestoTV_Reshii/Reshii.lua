local ADDON_NAME = "TWW_UpgradeAndGem"

if not TWWUpgradeAndGemDB then
    TWWUpgradeAndGemDB = {}
end

-- === CONFIG ===

local ITEM_ID_TO_TRACK = 235499 -- Reshii Wraps
local ITEM_SLOT = 15 -- Cloak slot
local CURRENCY_ID = 3278 -- Upgrade currency
local QUEST_ID = 90955 -- Quest to check

local UPGRADE_STEPS = {
    {need = 3, maxBonus = 9844},
    {need = 6, maxBonus = 9850},
    {need = 9, maxBonus = 9877},
    {need = 12, maxBonus = 9883},
    {need = 15, maxBonus = 9893},
}

-- === GEM DATA ===

local reshiiGems = {
    [238041] = "Versatility (Upgrade to Epic Quality)", -- Pure Dexterous Fiber
    [238037] = "Mastery (Upgrade to Epic Quality)",     -- Pure Energizing Fiber
    [238040] = "Crit (Upgrade to Epic Quality)",        -- Pure Precise Fiber
    [238039] = "Haste (Upgrade to Epic Quality)",       -- Pure Chromomatic Fiber
    [238042] = "Versatility",                           -- Additional Versatility Gem
    [238046] = "Mastery",                               -- Additional Mastery Gem
    [238044] = "Crit",                                  -- Additional Crit Gem
    [238045] = "Haste",                                 -- Additional Haste Gem
}

local reshiiGemColors = {
    [238041] = "FFABABAB", -- Gray for Versatility
    [238037] = "FF71D5FF", -- Blue for Mastery
    [238040] = "FFFFC100", -- Yellow for Crit
    [238039] = "FFFF6B6B", -- Red for Haste
    [238042] = "FFABABAB", -- Gray for Versatility
    [238046] = "FF71D5FF", -- Blue for Mastery
    [238044] = "FFFFC100", -- Yellow for Crit
    [238045] = "FFFF6B6B", -- Red for Haste
}

local function GetGemIconString(gemID)
    local iconID = gemID and GetItemIcon(gemID)
    if not iconID then
        return "|TInterface/ItemSocketingFrame/UI-EMPTYSOCKET-RED:24|t"
    end
    return "|T" .. iconID .. ":24|t"
end

local function FormatReshiiGem(gemID)
    if not gemID then
        return GetGemIconString(nil) .. " Missing"
    end
    local gemName = reshiiGems[gemID] or "Unknown"
    local color = reshiiGemColors[gemID] or "FFFFFFFF"
    local icon = GetGemIconString(gemID)
    return icon .. WrapTextInColorCode(gemName, color)
end

local function ParseItemLink(link)
    if not link then return {} end
    local _, linkOptions = LinkUtil.ExtractLink(link)
    local item = {strsplit(":", linkOptions)}
    local t = {}
    for i = 1, 4 do
        local gem = tonumber(item[i+2])
        if gem then
            t.gems = t.gems or {}
            t.gems[i] = gem
        end
    end
    return t
end

-- === UPGRADE REMINDER UTILS ===

local function GetCurrencyInfoSafe(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return {
                name = info.name or info.currencyName,
                quantity = info.quantity or 0,
                iconFileID = info.iconFileID or info.icon,
                totalEarned = info.totalEarned or 0,
            }
        end
    end
    local name, quantity, _, _, _, iconFileID = GetCurrencyInfo(currencyID)
    return {name = name, quantity = quantity, iconFileID = iconFileID, totalEarned = quantity}
end

local function GetHighestNumericTokenFromItemLink(link)
    if not link then return 0 end
    local h = string.match(link, "|Hitem:([^|]+)|h")
    if not h then return 0 end
    local tokens = {strsplit(":", h)}
    local maxNum = 0
    for i = 1, #tokens do
        local n = tonumber(tokens[i])
        if n and n > maxNum then
            maxNum = n
        end
    end
    return maxNum
end

-- === FRAME CREATION ===

local frame = CreateFrame("Frame", ADDON_NAME.."Frame", UIParent, "BackdropTemplate")
frame:SetSize(310, 90)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = {left = 3, right = 3, top = 3, bottom = 3}
})
frame:SetBackdropColor(0,0,0,0.6)

-- Draggable code
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(48, 48)
icon:SetPoint("LEFT", frame, "LEFT", 8, 0)

local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
label:SetPoint("LEFT", icon, "RIGHT", 8, 15)
label:SetJustifyH("LEFT")
label:SetText("")

local subLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subLabel:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
subLabel:SetJustifyH("LEFT")
subLabel:SetText("")

local gemLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gemLabel:SetPoint("TOPLEFT", subLabel, "BOTTOMLEFT", 0, -5)
gemLabel:SetJustifyH("LEFT")
gemLabel:SetText("")

-- === CLOSE BUTTON ===

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetSize(24, 24)
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
closeButton:SetScript("OnClick", function()
    frame:Hide()
    TWWUpgradeAndGemDB.frameOpen = false -- Save frame closed state
end)

-- === TALENTS BUTTON ===

local talentsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
talentsButton:SetSize(80, 24)
talentsButton:SetPoint("RIGHT", frame, "RIGHT", -25, 0)
talentsButton:SetText("Talents")
talentsButton:SetScript("OnClick", function()
    -- Calls functions directly instead of RunMacroText
    if GenericTraitUI_LoadUI then
        GenericTraitUI_LoadUI()
    end
    if GenericTraitFrame and GenericTraitFrame.SetSystemID then
        GenericTraitFrame:SetSystemID(29)
    end
    if GenericTraitFrame and GenericTraitFrame.SetTreeID then
        GenericTraitFrame:SetTreeID(1115)
    end
    if GenericTraitFrame then
        ToggleFrame(GenericTraitFrame)
    end
end)

-- Initially hide frame, will be shown based on saved variable on load
frame:Hide()

-- === UPDATE LOGIC ===

local function EvaluateAndUpdate()
    local equippedItemID = GetInventoryItemID("player", ITEM_SLOT)
    if not equippedItemID or equippedItemID ~= ITEM_ID_TO_TRACK then
        frame:Hide()
        TWWUpgradeAndGemDB.frameOpen = false -- Save closed state if item not equipped
        return
    end

    local itemLink = GetInventoryItemLink("player", ITEM_SLOT)
    local itemName = itemLink and GetItemInfo(itemLink) or ("Item "..ITEM_ID_TO_TRACK)
    local currentBonus = GetHighestNumericTokenFromItemLink(itemLink)
    local cinfo = GetCurrencyInfoSafe(CURRENCY_ID)
    local totalEarned = cinfo.totalEarned or 0
    local isQuestCompleted = C_QuestLog.IsQuestFlaggedCompleted(QUEST_ID)

    -- Check upgrade conditions
    local shouldShowUpgrade = false
    for _, step in ipairs(UPGRADE_STEPS) do
        if totalEarned >= step.need and (currentBonus == 0 or currentBonus < step.maxBonus) then
            shouldShowUpgrade = true
            break
        end
    end

    -- Gem info
    local gemText = "Missing Gem"
    if itemLink then
        local parsed = ParseItemLink(itemLink)
        if parsed.gems and parsed.gems[1] then
            gemText = FormatReshiiGem(parsed.gems[1])
        else
            gemText = GetGemIconString(nil).." Missing"
        end
    end

    if shouldShowUpgrade or not isQuestCompleted then
        icon:SetTexture(cinfo.iconFileID or select(10, GetItemInfo(itemLink)))
        label:SetText(itemName .. ": " .. totalEarned)
        subLabel:SetText("Upgrade! ("..totalEarned..")")
        gemLabel:SetText("Gem: "..gemText)
        if TWWUpgradeAndGemDB.frameOpen ~= false then
            frame:Show()
            TWWUpgradeAndGemDB.frameOpen = true
        else
            frame:Hide()
        end
    else
        icon:SetTexture(select(10, GetItemInfo(itemLink)))
        label:SetText(itemName .. ": " .. totalEarned)
        subLabel:SetText("No upgrade needed")
        gemLabel:SetText("Gem: "..gemText)
        if TWWUpgradeAndGemDB.frameOpen ~= false then
            frame:Show()
            TWWUpgradeAndGemDB.frameOpen = true
        else
            frame:Hide()
        end
    end
end

-- === EVENTS ===

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if TWWUpgradeAndGemDB.frameOpen == nil then
            TWWUpgradeAndGemDB.frameOpen = true -- default to open on first load
        end
        EvaluateAndUpdate()
    else
        EvaluateAndUpdate()
    end
end)

-- Slash commands for refreshing / toggling

SLASH_TWWUPGEM1 = "/twwupgem"
SlashCmdList["TWWUPGEM"] = function()
    EvaluateAndUpdate()
end

SLASH_TWWWRAPS1 = "/wraps"
SlashCmdList["TWWWRAPS"] = function()
    if frame:IsShown() then
        frame:Hide()
        TWWUpgradeAndGemDB.frameOpen = false
    else
        frame:Show()
        TWWUpgradeAndGemDB.frameOpen = true
    end
end

C_Timer.After(1, EvaluateAndUpdate)