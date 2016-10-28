MythicPlusTimerCMTimer = {}

-- ---------------------------------------------------------------------------------------------------------------------
local surrenderedSoul
function MythicPlusTimerCMTimer:Init()
    if not MythicPlusTimerDB.pos then
        MythicPlusTimerDB.pos = {}
    end

    if MythicPlusTimerDB.pos.left == nil then
        MythicPlusTimerDB.pos.left = -260;
    end
    
    if MythicPlusTimerDB.pos.top == nil then
        MythicPlusTimerDB.pos.top = 190;
    end

    if MythicPlusTimerDB.pos.relativePoint == nil then
        MythicPlusTimerDB.pos.relativePoint = "RIGHT";
    end
    
    if not MythicPlusTimerDB.bestTimes then
        MythicPlusTimerDB.bestTimes = {}
    end

    MythicPlusTimerCMTimer.isCompleted = false;
    MythicPlusTimerCMTimer.started = false;
    MythicPlusTimerCMTimer.reset = false;
    MythicPlusTimerCMTimer.frames = {};
    MythicPlusTimerCMTimer.timerStarted = false;
    MythicPlusTimerCMTimer.lastKill = {};

    
    MythicPlusTimerCMTimer.frame = CreateFrame("Frame", "CmTimer", UIParent);
    MythicPlusTimerCMTimer.frame:SetPoint(MythicPlusTimerDB.pos.relativePoint,MythicPlusTimerDB.pos.left,MythicPlusTimerDB.pos.top)
    MythicPlusTimerCMTimer.frame:EnableMouse(true)
    MythicPlusTimerCMTimer.frame:RegisterForDrag("LeftButton")
    MythicPlusTimerCMTimer.frame:SetScript("OnDragStart", MythicPlusTimerCMTimer.frame.StartMoving)
    MythicPlusTimerCMTimer.frame:SetScript("OnDragStop", MythicPlusTimerCMTimer.frame.StopMovingOrSizing)
    MythicPlusTimerCMTimer.frame:SetScript("OnMouseDown", MythicPlusTimerCMTimer.OnFrameMouseDown)
    MythicPlusTimerCMTimer.frame:SetWidth(100);
    MythicPlusTimerCMTimer.frame:SetHeight(100);
    MythicPlusTimerCMTimer.frameToggle = false


    MythicPlusTimerCMTimer.eventFrame = CreateFrame("Frame")
    MythicPlusTimerCMTimer.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    MythicPlusTimerCMTimer.eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    MythicPlusTimerCMTimer.eventFrame:SetScript("OnEvent", function(self, event, timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
        if subEvent == "PARTY_KILL" then
            MythicPlusTimerCMTimer:OnPartyKill(destGUID)
            return
        end
        
        if event == "SCENARIO_CRITERIA_UPDATE" then
            MythicPlusTimerCMTimer:OnCriteriaUpdate()
            return
        end
        
        
        if subEvent ~= "UNIT_DIED" then 
            return 
        end

        local isPlayer = strfind(destGUID, "Player")
        if not isPlayer then
            return
        end

        local isFeign = UnitIsFeignDeath(destName);
        if isFeign then
            return
        end

        if not surrenderedSoul then
            surrenderedSoul = GetSpellInfo(212570) 
        end

        if UnitDebuff(destName, surrenderedSoul) == surrenderedSoul then
            return
        end
        
        MythicPlusTimerCMTimer:OnPlayerDeath()
    end)

    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        MythicPlusTimerCMTimer:OnTooltipSetUnit(self)
    end)
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnTooltipSetUnit(el)
    if not MythicPlusTimerDB.config.progressTooltip then
        return
    end
    
    local unit = select(2, el:GetUnit())
    if not unit then
        return
    end

    local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo();
    if difficulty ~= 8 or MythicPlusTimerCMTimer.started == false or MythicPlusTimerCMTimer.isCompleted then
        return
    end

    if UnitCanAttack("player", unit) and not UnitIsDead(unit) then
        local guid = UnitGUID(unit)
        local npcID = MythicPlusTimerCMTimer:resolveNpcID(guid)
        if not npcID then
            return
        end
        
        local value = MythicPlusTimerCMTimer:GetProgressValue(npcID)
        if not value then
            return
        end

        local _, _, steps = C_Scenario.GetStepInfo();
        if not steps or steps <= 0 then
            return
        end
            
        local _, _, _, _, finalValue = C_Scenario.GetCriteriaInfo(steps);
        local quantityPercent = (value / finalValue) * 100

        local mult = 10^2
        quantityPercent = math.floor(quantityPercent * mult + 0.5) / mult
        if(quantityPercent > 100) then
            quantityPercent = 100
        end
    
        local name = C_Scenario.GetCriteriaInfo(steps)
    
        GameTooltip:AddDoubleLine(name..": +"..quantityPercent.."%")
        GameTooltip:Show()
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnPartyKill(destGUID)
    local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo();
    if difficulty ~= 8 or MythicPlusTimerCMTimer.started == false or MythicPlusTimerCMTimer.isCompleted then
        return
    end
    
    if not MythicPlusTimerCMTimer.lastKill then
        MythicPlusTimerCMTimer.lastKill = {}
    end
    
    if not MythicPlusTimerCMTimer.lastKill[1] or MythicPlusTimerCMTimer.lastKill[1]  == nil then
        MythicPlusTimerCMTimer.lastKill[1] = GetTime() * 1000
    end

    local npcID = MythicPlusTimerCMTimer:resolveNpcID(destGUID)
    if npcID then
        local valid = ((GetTime() * 1000) - MythicPlusTimerCMTimer.lastKill[1]) > 100
        MythicPlusTimerCMTimer.lastKill = {GetTime() * 1000, npcID, valid} 
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnCriteriaUpdate()
    local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo();
    if difficulty ~= 8 or MythicPlusTimerCMTimer.started == false or MythicPlusTimerCMTimer.isCompleted then
        return
    end
    
    if not MythicPlusTimerDB.currentRun.currentQuantity then
        MythicPlusTimerDB.currentRun.currentQuantity = 0
    end

    local _, _, steps = C_Scenario.GetStepInfo();
    if not steps or steps <= 0 then
        return
    end
    
    local _, _, _, _, finalValue, _, _, quantity = C_Scenario.GetCriteriaInfo(steps);
    if MythicPlusTimerDB.currentRun.currentQuantity >= finalValue then
        return
    end

    local quantityNumber = string.sub(quantity, 1, string.len(quantity) - 1)
    quantityNumber = tonumber(quantityNumber)

    local delta = quantityNumber - MythicPlusTimerDB.currentRun.currentQuantity

    if delta > 0 then
        MythicPlusTimerDB.currentRun.currentQuantity = quantityNumber
        if MythicPlusTimerDB.currentRun.currentQuantity >= finalValue then
            return
        end

        local timestamp, npcID, valid  = unpack(MythicPlusTimerCMTimer.lastKill)
        if timestamp and npcID and delta and valid then
            if (GetTime() * 1000) - timestamp <= 600 then
                MythicPlusTimerCMTimer:UpdateProgressValue(npcID, delta);
            end
        end
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:UpdateProgressValue(npcID, value)
    if not MythicPlusTimerDB.npcProgress then
        MythicPlusTimerDB.npcProgress = {}
    end
    
    if not MythicPlusTimerDB.npcProgress[npcID] then
        MythicPlusTimerDB.npcProgress[npcID] = {}
    end

    if MythicPlusTimerDB.npcProgress[npcID][value] == nil then
        MythicPlusTimerDB.npcProgress[npcID][value] = 1
    else
        MythicPlusTimerDB.npcProgress[npcID][value] = MythicPlusTimerDB.npcProgress[npcID][value] + 1
    end
    
    for val, occurrences in pairs(MythicPlusTimerDB.npcProgress[npcID]) do
        if val ~= value then
            MythicPlusTimerDB.npcProgress[npcID][val] = occurrences * 0.80
        end
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:GetProgressValue(npcID)
    if not MythicPlusTimerDB.npcProgress then 
        return
    end

    if not MythicPlusTimerDB.npcProgress[npcID] then
        return
    end
    
    local value, occurrences = nil, -1
    for val, valOccurrences in pairs(MythicPlusTimerDB.npcProgress[npcID]) do
        if valOccurrences > occurrences then
            value, occurrences = val, valOccurrences
        end
    end
    
    return value
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:ToggleFrame()
    if MythicPlusTimerCMTimer.frameToggle then
        MythicPlusTimerCMTimer.frame:SetMovable(false)
        MythicPlusTimerCMTimer.frame:SetBackdrop(nil)
        MythicPlusTimerCMTimer.frameToggle = false

        local _, _, relativePoint, xOfs, yOfs = MythicPlusTimerCMTimer.frame:GetPoint()
        MythicPlusTimerDB.pos.relativePoint = relativePoint;
        MythicPlusTimerDB.pos.top = yOfs;
        MythicPlusTimerDB.pos.left = xOfs;

        local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo();
        if difficulty ~= 8 then
            MythicPlusTimerCMTimer.frame:Hide();
        end
    else
        MythicPlusTimerCMTimer.frame:SetMovable(true)
        local backdrop = {
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 1,
            insets = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0
            }
        }

        MythicPlusTimerCMTimer.frame:SetBackdrop(backdrop)
        MythicPlusTimerCMTimer.frameToggle = true
        MythicPlusTimerCMTimer.frame:Show();
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnComplete()
    if not MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"] or MythicPlusTimerDB.currentRun.time < MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"] then
        MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"] = MythicPlusTimerDB.currentRun.time
    end

    if not MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l"..MythicPlusTimerDB.currentRun.cmLevel]["_complete"] or MythicPlusTimerDB.currentRun.time < MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l"..MythicPlusTimerDB.currentRun.cmLevel]["_complete"] then
        MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l"..MythicPlusTimerDB.currentRun.cmLevel]["_complete"] = MythicPlusTimerDB.currentRun.time
    end
    
    if MythicPlusTimerDB.config.objectiveTimeInChat then
        local text = MythicPlusTimerDB.currentRun.zoneName.." +"..MythicPlusTimerDB.currentRun.cmLevel.." "..MythicPlusTimer.L["Completed"].."! "..MythicPlusTimer.L["Time"]..": "..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.time).." "..MythicPlusTimer.L["BestTime"]..": "
        if MythicPlusTimerDB.config.objectiveTimePerLevel then
            text = text..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l"..MythicPlusTimerDB.currentRun.cmLevel]["_complete"])
        else
            text = text..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"])
        end
        
        MythicPlusTimer:Print(text)
    end
    
    ObjectiveTrackerFrame:Show();
    MythicPlusTimerCMTimer.isCompleted = true;
    MythicPlusTimerCMTimer.frame:Hide();
    ObjectiveTrackerFrame:Show();
    MythicPlusTimerCMTimer:HideObjectivesFrames()

    MythicPlusTimerDB.currentRun = {}
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnStart()
    MythicPlusTimerDB.currentRun = {}
    
    MythicPlusTimerCMTimer.isCompleted = false;
    MythicPlusTimerCMTimer.started = true;
    MythicPlusTimerCMTimer.reset = false;
    MythicPlusTimerCMTimer.lastKill = {};
    
    MythicPlusTimer:StartCMTimer()
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnReset()
    MythicPlusTimerCMTimer.frame:Hide();
    ObjectiveTrackerFrame:Show();
    MythicPlusTimerCMTimer.isCompleted = false;
    MythicPlusTimerCMTimer.started = false;
    MythicPlusTimerCMTimer.lastKill = {};
    MythicPlusTimerCMTimer.reset = true;
    MythicPlusTimerCMTimer:HideObjectivesFrames()

    MythicPlusTimerDB.currentRun = {}
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:HideObjectivesFrames()
    if MythicPlusTimerCMTimer.frames.objectives then
        for key, _ in pairs(MythicPlusTimerCMTimer.frames.objectives) do
            MythicPlusTimerCMTimer.frames.objectives[key]:Hide()
        end
    end
end


-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:ReStart()
    local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo();
    local _, timeCM = GetWorldElapsedTime(1);
    
    if difficulty == 8 and timeCM > 0 then
        MythicPlusTimerCMTimer.started = true;
        MythicPlusTimerCMTimer.lastKill = {};

        local _, _, steps = C_Scenario.GetStepInfo();
        local _, _, _, _, _, _, _, quantity = C_Scenario.GetCriteriaInfo(steps);
        local quantityNumber = string.sub(quantity, 1, string.len(quantity) - 1)
        quantityNumber = tonumber(quantityNumber)

        MythicPlusTimerDB.currentRun.currentQuantity = quantityNumber
    
        MythicPlusTimer:StartCMTimer()
        return
    end

    MythicPlusTimerCMTimer.frame:Hide();
    ObjectiveTrackerFrame:Show();
    MythicPlusTimerCMTimer.reset = false
    MythicPlusTimerCMTimer.timerStarted = false
    MythicPlusTimerCMTimer.started = false
    MythicPlusTimerCMTimer.lastKill = {};
    MythicPlusTimerCMTimer.isCompleted = false
    MythicPlusTimerDB.currentRun = {}
    return
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnPlayerDeath()
    local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo();
    local _, timeCM = GetWorldElapsedTime(1);

    if difficulty ~= 8 then
        return
    end
    
    if not MythicPlusTimerCMTimer.started then
        return
    end
    
    if MythicPlusTimerDB.currentRun.death == nil then
        return
    end

    MythicPlusTimerDB.currentRun.death = MythicPlusTimerDB.currentRun.death + 1
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:Draw()
    local _, _, difficulty, _, _, _, _, currentZoneID = GetInstanceInfo();
    if difficulty ~= 8 then
        MythicPlusTimerCMTimer.frame:Hide();
        ObjectiveTrackerFrame:Show();
        return
    end

    if not MythicPlusTimerCMTimer.isCompleted then
        ObjectiveTrackerFrame:Hide();
    end

    if not MythicPlusTimerCMTimer.started and not MythicPlusTimerCMTimer.reset and MythicPlusTimerCMTimer.timerStarted then
        MythicPlusTimer:CancelCMTimer()
        MythicPlusTimerCMTimer.timerStarted = false
        MythicPlusTimerCMTimer.frame:Hide();
        ObjectiveTrackerFrame:Show();
        return
    end

    if MythicPlusTimerCMTimer.reset or MythicPlusTimerCMTimer.isCompleted then
        MythicPlusTimerCMTimer.reset = false
        MythicPlusTimerCMTimer.timerStarted = false
        MythicPlusTimerCMTimer.started = false
        MythicPlusTimerCMTimer.lastKill = {};
        MythicPlusTimer:CancelCMTimer()
        MythicPlusTimerCMTimer.frame:Hide();
        ObjectiveTrackerFrame:Show();
        return
    end

    
    MythicPlusTimerCMTimer.timerStarted = true
    local _, timeCM = GetWorldElapsedTime(1)
    if not timeCM or timeCM <= 0 then
        return
    end

    local cmLevel, affixes, empowered = C_ChallengeMode.GetActiveKeystoneInfo();

    if not MythicPlusTimerCMTimer.isCompleted then
        MythicPlusTimerCMTimer.frame:Show();
    end
   
    if not MythicPlusTimerDB.bestTimes[currentZoneID] then
        MythicPlusTimerDB.bestTimes[currentZoneID] = {}
    end

    if not MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel] then
        MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel] = {}
    end

    if not MythicPlusTimerDB.currentRun.times  then
        MythicPlusTimerDB.currentRun.times = {}
    end

    if MythicPlusTimerDB.currentRun.death == nil then
        MythicPlusTimerDB.currentRun.death = 0
    end

    local currentMapId = C_ChallengeMode.GetActiveChallengeMapID();
    local zoneName, _, maxTime = C_ChallengeMode.GetMapInfo(currentMapId);
    local bonus = C_ChallengeMode.GetPowerLevelDamageHealthMod(cmLevel);

    -- Info
    MythicPlusTimerDB.currentRun.cmLevel = cmLevel
    MythicPlusTimerDB.currentRun.zoneName = zoneName
    MythicPlusTimerDB.currentRun.currentZoneID = currentZoneID
    MythicPlusTimerDB.currentRun.time = timeCM

    if not MythicPlusTimerCMTimer.frames.info then
        local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
        f:SetAllPoints()
        f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontNormalLarge");
        f.text:SetPoint("TOPLEFT",0,0);
        MythicPlusTimerCMTimer.frames.info = f
    end
    MythicPlusTimerCMTimer.frames.info.text:SetText("+" .. cmLevel .. " - " .. zoneName);
    
    
    -- Tooltip
    if not MythicPlusTimerCMTimer.frames.infos then
        local i = CreateFrame("Frame",nil, MythicPlusTimerCMTimer.frame)
        i:SetAllPoints()
        i.text = i:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
        i.text:SetPoint("TOPLEFT", 0, -18);
        MythicPlusTimerCMTimer.frames.infos = i

        local debuffOnEnter = function(self, motion)
            if not MythicPlusTimerCMTimer.frames.infos.tooltip then
                return
            end
            
            GameTooltip:Hide()
            GameTooltip:ClearLines()
            GameTooltip:SetOwner(MythicPlusTimerCMTimer.frame, "ANCHOR_LEFT")
            
            for _, v in pairs(MythicPlusTimerCMTimer.frames.infos.tooltip) do
                GameTooltip:AddLine(v)
            end
            GameTooltip:Show()
        end

        
        local debuffOnLeave = function(self, motion)
            GameTooltip:Hide()
        end

        MythicPlusTimerCMTimer.frame:SetScript("OnEnter", debuffOnEnter)
        MythicPlusTimerCMTimer.frame:SetScript("OnLeave", debuffOnLeave)
    end
    
    local tooltip = {};
    table.insert(tooltip, "+" .. cmLevel .. " - " .. zoneName);
    table.insert(tooltip, "|cFFFFFFFF" .. "+"..bonus.."%");
    table.insert(tooltip, " ")

    local txt = ""
    if empowered then
        txt = txt .. MythicPlusTimer.L["Loot"]
    else
        txt = txt .. MythicPlusTimer.L["NoLoot"]
    end

    for _, affixID in ipairs(affixes) do
        local affixName, affixDesc, _ = C_ChallengeMode.GetAffixInfo(affixID);
        txt = txt ..  " - "..affixName

        table.insert(tooltip, affixName)
        table.insert(tooltip, "|cFFFFFFFF" .. affixDesc)
        table.insert(tooltip, "  ")
    end

    MythicPlusTimerCMTimer.frames.infos.tooltip = tooltip;
    MythicPlusTimerCMTimer.frames.infos.text:SetText(txt)



    -- Time
    local timeLeft = maxTime - timeCM;
    if timeLeft < 0 then
        timeLeft = 0;
    end
    
    if not MythicPlusTimerCMTimer.frames.time then
        local font = "GameFontGreenLarge"
        if timeLeft == 0 then
            font = "GameFontRedLarge"
        end

        local t = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
        t:SetAllPoints()
        t.text = t:CreateFontString(nil, "BACKGROUND", font);
        t.text:SetPoint("TOPLEFT", 0, -40);

        
        local t2 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
        t2:SetAllPoints()
        t2.text = t2:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
        t2.text:SetPoint("TOPLEFT", 55, -42);
        
        MythicPlusTimerCMTimer.frames.time = {
            timer = t;
            timer2 = t2;
        }
    end

    local font = "GameFontGreenLarge"
    if timeLeft == 0 then
        font = "GameFontRedLarge"
    end
    MythicPlusTimerCMTimer.frames.time.timer.text:SetFontObject(font);
    MythicPlusTimerCMTimer.frames.time.timer.text:SetText(MythicPlusTimerCMTimer:FormatSeconds(timeLeft));
    MythicPlusTimerCMTimer.frames.time.timer2.text:SetText("(".. MythicPlusTimerCMTimer:FormatSeconds(timeCM) .." / ".. MythicPlusTimerCMTimer:FormatSeconds(maxTime) ..")");

    MythicPlusTimerDB.currentRun.timeLeft = timeLeft
    
    
    -- Chest Timer
    local threeChestTime = maxTime * 0.6;
    local twoChestTime = maxTime * 0.8;

    local timeLeft3 = threeChestTime - timeCM;
    if timeLeft3 < 0 then
        timeLeft3 = 0;
    end

    local timeLeft2 = twoChestTime - timeCM;
    if timeLeft2 < 0 then
        timeLeft2 = 0;
    end

    MythicPlusTimerDB.currentRun.timeLeft3 = timeLeft3
    MythicPlusTimerDB.currentRun.timeLeft2 = timeLeft2
    
    if not MythicPlusTimerCMTimer.frames.chesttimer then
        local l2 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
        l2:SetAllPoints()
        l2.text = l2:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
        l2.text:SetPoint("TOPLEFT", 0,-60);

        local t2 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
        t2:SetAllPoints()
        t2.text = t2:CreateFontString(nil, "BACKGROUND", "GameFontGreen");
        t2.text:SetPoint("TOPLEFT", 75, -60);

        
        local l3 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
        l3:SetAllPoints()
        l3.text = l3:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
        l3.text:SetPoint("TOPLEFT", 0,-75);

        local t3 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
        t3:SetAllPoints()
        t3.text = t3:CreateFontString(nil, "BACKGROUND", "GameFontGreen");
        t3.text:SetPoint("TOPLEFT", 75, -75);


        MythicPlusTimerCMTimer.frames.chesttimer = {
            label2 = l2;
            time2 = t2;
            
            label3 = l3;
            time3 = t3;
        }
    end
    
    -- -- 2 Chest
    if timeLeft2 == 0 then
        MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetText("+2 ("..MythicPlusTimerCMTimer:FormatSeconds(twoChestTime)..")")
        MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetFontObject("GameFontDisable");
        MythicPlusTimerCMTimer.frames.chesttimer.time2:Hide()
    else
        MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetText("+2 ("..MythicPlusTimerCMTimer:FormatSeconds(twoChestTime).."):")
        MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetFontObject("GameFontHighlight");
        
        MythicPlusTimerCMTimer.frames.chesttimer.time2.text:SetText(MythicPlusTimerCMTimer:FormatSeconds(timeLeft2));
        MythicPlusTimerCMTimer.frames.chesttimer.time2:Show()
    end


    -- -- 3 Chest
    if timeLeft3 == 0 then
        MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetText("+3 ("..MythicPlusTimerCMTimer:FormatSeconds(threeChestTime)..")")
        MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetFontObject("GameFontDisable");
        MythicPlusTimerCMTimer.frames.chesttimer.time3:Hide()
    else
        MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetText("+3 ("..MythicPlusTimerCMTimer:FormatSeconds(threeChestTime).."):")
        MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetFontObject("GameFontHighlight");
        
        MythicPlusTimerCMTimer.frames.chesttimer.time3.text:SetText(MythicPlusTimerCMTimer:FormatSeconds(timeLeft3))
        MythicPlusTimerCMTimer.frames.chesttimer.time3:Show()
    end
    
    
    
    -- Objectives
    local _, _, steps = C_Scenario.GetStepInfo();
    if not MythicPlusTimerCMTimer.frames.objectives then
        MythicPlusTimerCMTimer.frames.objectives = {}
    end
    
    local stepsCount = 0
    for i = 1, steps do
        stepsCount = stepsCount + 1
        if not MythicPlusTimerCMTimer.frames.objectives[i] then
            local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
            f:SetAllPoints()
            f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
            f.text:SetPoint("TOPLEFT", 0, -90 - (i * 17))

            MythicPlusTimerCMTimer.frames.objectives[i] = f
        end
        MythicPlusTimerCMTimer.frames.objectives[i]:Show()
        
        local name, _, status, curValue, finalValue, _, _, quantity = C_Scenario.GetCriteriaInfo(i);
        if status then
            MythicPlusTimerCMTimer.frames.objectives[i].text:SetFontObject("GameFontDisable")

            if MythicPlusTimerDB.currentRun.times[i] == nil then
                MythicPlusTimerDB.currentRun.times[i] = timeCM

                if not MythicPlusTimerDB.bestTimes[currentZoneID][i] or timeCM < MythicPlusTimerDB.bestTimes[currentZoneID][i] then
                    MythicPlusTimerDB.bestTimes[currentZoneID][i] = timeCM
                end
                
                if not MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel][i] or timeCM < MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel][i] then
                    MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel][i] = timeCM
                end

                if MythicPlusTimerDB.config.objectiveTimeInChat then
                    local text = name.." "..MythicPlusTimer.L["Completed"].." (+"..cmLevel.."). "..MythicPlusTimer.L["Time"]..": "..MythicPlusTimerCMTimer:FormatSeconds(timeCM).." "..MythicPlusTimer.L["BestTime"]..": "

                    if MythicPlusTimerDB.config.objectiveTimePerLevel then
                        text = text..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel][i])
                    else
                        text = text..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID][i])
                    end
                
                    MythicPlusTimer:Print(text)
                end
            end
        else
            MythicPlusTimerCMTimer.frames.objectives[i].text:SetFontObject("GameFontHighlight")
            
            if MythicPlusTimerDB.currentRun.times[i] then
                MythicPlusTimerDB.currentRun.times[i] = nil
            end
        end

        local bestTimeStr = ""
        if MythicPlusTimerDB.currentRun.times[i] and MythicPlusTimerDB.config.objectiveTime then
            bestTimeStr = " - " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.times[i])
            
            if MythicPlusTimerDB.config.objectiveTimePerLevel then
                if MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel][i] then
                    local diff =  MythicPlusTimerDB.currentRun.times[i] - MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel][i];
                    local diffStr = ""
                    if diff > 0 then
                        diffStr = ", +" ..MythicPlusTimerCMTimer:FormatSeconds(diff)
                    end

                    bestTimeStr = bestTimeStr .. " (".. MythicPlusTimer.L["Best"] ..": " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID]["l"..cmLevel][i]) .. diffStr .. ")"
                end
            else    
                if MythicPlusTimerDB.bestTimes[currentZoneID][i] then
                    local diff =  MythicPlusTimerDB.currentRun.times[i] - MythicPlusTimerDB.bestTimes[currentZoneID][i];
                    local diffStr = ""
                    if diff > 0 then
                        diffStr = ", +" ..MythicPlusTimerCMTimer:FormatSeconds(diff)
                    end
                    
                    bestTimeStr = bestTimeStr .. " (".. MythicPlusTimer.L["Best"] ..": " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID][i]) .. diffStr .. ")"
                end
            end
        end
        
        if finalValue >= 100 then
            local quantityNumber = string.sub(quantity, 1, string.len(quantity) - 1)
            local quantityPercent = (quantityNumber / finalValue) * 100

            local mult = 10^2
            quantityPercent = math.floor(quantityPercent * mult + 0.5) / mult
            if(quantityPercent > 100) then
                quantityPercent = 100
            end

            MythicPlusTimerCMTimer.frames.objectives[i].text:SetText("- "..quantityPercent.."% "..name .. bestTimeStr);
        else
            if status then
                curValue = finalValue
            end

            MythicPlusTimerCMTimer.frames.objectives[i].text:SetText("- "..curValue.."/"..finalValue.." "..name .. bestTimeStr);
        end
    end
    
    
    -- Death Count
    if MythicPlusTimerDB.currentRun.death > 0 and MythicPlusTimerDB.config.deathCounter then
        local i = stepsCount + 1
        if not MythicPlusTimerCMTimer.frames.deathCounter then
            local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
            f:SetAllPoints()
            f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
            MythicPlusTimerCMTimer.frames.deathCounter = f
        end
        MythicPlusTimerCMTimer.frames.deathCounter.text:SetPoint("TOPLEFT", 0, -90 - (i * 17))
        MythicPlusTimerCMTimer.frames.deathCounter:Show()

        local seconds = MythicPlusTimerDB.currentRun.death * 5
        MythicPlusTimerCMTimer.frames.deathCounter.text:SetText(MythicPlusTimerDB.currentRun.death.." "..MythicPlusTimer.L["Deaths"]..":|cFFFF0000 -"..MythicPlusTimerCMTimer:FormatSeconds(seconds))
    else
        if MythicPlusTimerCMTimer.frames.deathCounter then
            MythicPlusTimerCMTimer.frames.deathCounter:Hide()
        end
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:ResolveTime(seconds)
    local min = math.floor(seconds/60);
    local sec = seconds - (min * 60);
    return min, sec;
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:FormatSeconds(seconds)
    local min, sec = MythicPlusTimerCMTimer:ResolveTime(seconds)
    if min < 10 then
        min = "0" .. min
    end
    
    if sec < 10 then
        sec = "0" .. sec
    end
    
    return min .. ":" .. sec
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnFrameMouseDown()
    if IsModifiedClick("CHATLINK") then
        if not MythicPlusTimerDB.currentRun.time then
            return
        end
        
        local timeText = MythicPlusTimer.L["TimeLeft"]..": "..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.timeLeft).." || +2: "..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.timeLeft2).." || +3: "..MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.timeLeft3)

        local channel = "PARTY"
        if GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE) > 0 then
            channel = "INSTANCE_CHAT"
        end
        SendChatMessage(timeText, channel)
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:resolveNpcID(guid)
    local targetType, _,_,_,_, npcID = strsplit("-", guid)
    if targetType == "Vehicle" or targetType == "Creature" and npcID then
        return tonumber(npcID)
    end
end
