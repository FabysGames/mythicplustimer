MythicPlusTimerCMTimer = {}

-- ---------------------------------------------------------------------------------------------------------------------
local surrenderedSoul
function MythicPlusTimerCMTimer:Init()
  if not MythicPlusTimerDB.pos then
    MythicPlusTimerDB.pos = {}
  end

  if MythicPlusTimerDB.pos.left == nil then
    MythicPlusTimerDB.pos.left = -260
  end

  if MythicPlusTimerDB.pos.top == nil then
    MythicPlusTimerDB.pos.top = 190
  end

  if MythicPlusTimerDB.pos.relativePoint == nil then
    MythicPlusTimerDB.pos.relativePoint = "RIGHT"
  end

  if not MythicPlusTimerDB.bestTimes then
    MythicPlusTimerDB.bestTimes = {}
  end

  MythicPlusTimerCMTimer.isCompleted = false
  MythicPlusTimerCMTimer.started = false
  MythicPlusTimerCMTimer.reset = false
  MythicPlusTimerCMTimer.frames = {}
  MythicPlusTimerCMTimer.timerStarted = false
  MythicPlusTimerCMTimer.lastKill = {}

  MythicPlusTimerCMTimer.frame = CreateFrame("Frame", "CmTimer", UIParent)
  MythicPlusTimerCMTimer.frame:EnableMouse(true)
  MythicPlusTimerCMTimer.frame:RegisterForDrag("LeftButton")
  MythicPlusTimerCMTimer.frame:SetScript("OnDragStart", MythicPlusTimerCMTimer.frame.StartMoving)
  MythicPlusTimerCMTimer.frame:SetScript("OnDragStop", MythicPlusTimerCMTimer.frame.StopMovingOrSizing)
  MythicPlusTimerCMTimer.frame:SetScript("OnMouseDown", MythicPlusTimerCMTimer.OnFrameMouseDown)
  MythicPlusTimerCMTimer.frame:SetWidth(200)
  MythicPlusTimerCMTimer.frame:SetHeight(25)
  MythicPlusTimerCMTimer.frame:SetScale(MythicPlusTimerDB.config.scale)
  MythicPlusTimerCMTimer.frame:SetPoint(MythicPlusTimerDB.pos.relativePoint, MythicPlusTimerDB.pos.left, MythicPlusTimerDB.pos.top)
  MythicPlusTimerCMTimer.frameToggle = false

  MythicPlusTimerCMTimer.frame.drag_text = MythicPlusTimerCMTimer.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  MythicPlusTimerCMTimer.frame.drag_text:SetPoint("TOPLEFT", 0, 0)
  MythicPlusTimerCMTimer.frame.drag_text:SetText("MythicPlusTimer")
  MythicPlusTimerCMTimer.frame.drag_text:Hide()

  MythicPlusTimerCMTimer.eventFrame = CreateFrame("Frame")
  MythicPlusTimerCMTimer.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  MythicPlusTimerCMTimer.eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
  MythicPlusTimerCMTimer.eventFrame:SetScript(
    "OnEvent",
    function(self, event)
      if event == "SCENARIO_CRITERIA_UPDATE" then
        MythicPlusTimerCMTimer:OnCriteriaUpdate()
        return
      end

      _, subEvent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()

      if subEvent == "PARTY_KILL" then
        MythicPlusTimerCMTimer:OnPartyKill(destGUID)
        return
      end

      if subEvent ~= "UNIT_DIED" then
        return
      end

      local isPlayer = strfind(destGUID, "Player")
      if not isPlayer then
        return
      end

      local isFeign = UnitIsFeignDeath(destName)
      if isFeign then
        return
      end

      if not surrenderedSoul then
        surrenderedSoul = GetSpellInfo(212570)
      end

      for i = 1, 40 do
        local debuffName = UnitDebuff(destName, i)
        if debuffName == nil then
          break
        end

        if debuffName == surrenderedSoul then
          return
        end
      end

      MythicPlusTimerCMTimer:OnPlayerDeath(destName)
    end
  )

  GameTooltip:HookScript(
    "OnTooltipSetUnit",
    function(self)
      MythicPlusTimerCMTimer:OnTooltipSetUnit(self)
    end
  )
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

  local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo()
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

    local _, _, steps = C_Scenario.GetStepInfo()
    if not steps or steps <= 0 then
      return
    end

    local _, _, _, _, finalValue = C_Scenario.GetCriteriaInfo(steps)
    local quantityPercent = (value / finalValue) * 100

    local mult = 10 ^ 2
    quantityPercent = math.floor(quantityPercent * mult + 0.5) / mult
    if (quantityPercent > 100) then
      quantityPercent = 100
    end

    local name = C_Scenario.GetCriteriaInfo(steps)

    local absoluteNumber = ""
    if MythicPlusTimerDB.config.showAbsoluteNumbers then
      absoluteNumber = " (+" .. value .. ")"
    end

    GameTooltip:AddDoubleLine(name .. ": +" .. quantityPercent .. "%" .. absoluteNumber)
    GameTooltip:Show()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnPartyKill(destGUID)
  local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo()
  if difficulty ~= 8 or MythicPlusTimerCMTimer.started == false or MythicPlusTimerCMTimer.isCompleted then
    return
  end

  if not MythicPlusTimerCMTimer.lastKill then
    MythicPlusTimerCMTimer.lastKill = {}
  end

  if not MythicPlusTimerCMTimer.lastKill[1] or MythicPlusTimerCMTimer.lastKill[1] == nil then
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
  local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo()
  if difficulty ~= 8 or MythicPlusTimerCMTimer.started == false or MythicPlusTimerCMTimer.isCompleted then
    return
  end

  if not MythicPlusTimerDB.currentRun.currentQuantity then
    MythicPlusTimerDB.currentRun.currentQuantity = 0
  end

  local _, _, steps = C_Scenario.GetStepInfo()
  if not steps or steps <= 0 then
    return
  end

  local _, _, _, _, finalValue, _, _, quantity = C_Scenario.GetCriteriaInfo(steps)
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

    local timestamp, npcID, valid = unpack(MythicPlusTimerCMTimer.lastKill)
    if timestamp and npcID and delta and valid then
      if (GetTime() * 1000) - timestamp <= 600 then
        MythicPlusTimerCMTimer:UpdateProgressValue(npcID, delta)
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
    MythicPlusTimerDB.pos.relativePoint = relativePoint
    MythicPlusTimerDB.pos.top = yOfs
    MythicPlusTimerDB.pos.left = xOfs

    local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo()
    if difficulty ~= 8 then
      MythicPlusTimerCMTimer.frame:Hide()
    end

    MythicPlusTimerCMTimer.frame.drag_text:Hide()
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
    MythicPlusTimerCMTimer.frame:Show()
    MythicPlusTimerCMTimer.frame.drag_text:Show()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnComplete()
  if not MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"] or MythicPlusTimerDB.currentRun.time < MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"] then
    MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"] = MythicPlusTimerDB.currentRun.time
  end

  if not MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l" .. MythicPlusTimerDB.currentRun.cmLevel]["_complete"] or MythicPlusTimerDB.currentRun.time < MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l" .. MythicPlusTimerDB.currentRun.cmLevel]["_complete"] then
    MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l" .. MythicPlusTimerDB.currentRun.cmLevel]["_complete"] = MythicPlusTimerDB.currentRun.time
  end

  if MythicPlusTimerDB.config.objectiveTimeInChat then
    local text = MythicPlusTimerDB.currentRun.zoneName .. " +" .. MythicPlusTimerDB.currentRun.cmLevel .. " " .. MythicPlusTimer.L["Completed"] .. "! " .. MythicPlusTimer.L["Time"] .. ": " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.time) .. " " .. MythicPlusTimer.L["BestTime"] .. ": "
    if MythicPlusTimerDB.config.objectiveTimePerLevel then
      text = text .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["l" .. MythicPlusTimerDB.currentRun.cmLevel]["_complete"])
    else
      text = text .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[MythicPlusTimerDB.currentRun.currentZoneID]["_complete"])
    end

    MythicPlusTimer:Print(text)
  end

  ObjectiveTrackerFrame:Show()
  MythicPlusTimerCMTimer.isCompleted = true
  MythicPlusTimerCMTimer.frame:Hide()
  ObjectiveTrackerFrame:Show()
  MythicPlusTimerCMTimer:HideObjectivesFrames()

  MythicPlusTimerDB.currentRun = {}
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnStart()
  MythicPlusTimerDB.currentRun = {}

  MythicPlusTimerCMTimer.isCompleted = false
  MythicPlusTimerCMTimer.started = true
  MythicPlusTimerCMTimer.reset = false
  MythicPlusTimerCMTimer.lastKill = {}

  MythicPlusTimer:StartCMTimer()
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnReset()
  MythicPlusTimerCMTimer.frame:Hide()
  ObjectiveTrackerFrame:Show()
  MythicPlusTimerCMTimer.isCompleted = false
  MythicPlusTimerCMTimer.started = false
  MythicPlusTimerCMTimer.lastKill = {}
  MythicPlusTimerCMTimer.reset = true
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

  if MythicPlusTimerCMTimer.frames.affixesIcon then
    for key, _ in pairs(MythicPlusTimerCMTimer.frames.affixesIcon) do
      MythicPlusTimerCMTimer.frames.affixesIcon[key]:Hide()
    end
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:ReStart()
  local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo()
  local _, timeCM = GetWorldElapsedTime(1)

  if difficulty == 8 and timeCM > 0 then
    MythicPlusTimerCMTimer.started = true
    MythicPlusTimerCMTimer.lastKill = {}

    local _, _, steps = C_Scenario.GetStepInfo()
    local _, _, _, _, _, _, _, quantity = C_Scenario.GetCriteriaInfo(steps)
    local quantityNumber = string.sub(quantity, 1, string.len(quantity) - 1)
    quantityNumber = tonumber(quantityNumber)

    MythicPlusTimerDB.currentRun.currentQuantity = quantityNumber

    MythicPlusTimer:StartCMTimer()
    return
  end

  MythicPlusTimerCMTimer.frame:Hide()
  ObjectiveTrackerFrame:Show()
  MythicPlusTimerCMTimer.reset = false
  MythicPlusTimerCMTimer.timerStarted = false
  MythicPlusTimerCMTimer.started = false
  MythicPlusTimerCMTimer.lastKill = {}
  MythicPlusTimerCMTimer.isCompleted = false
  MythicPlusTimerDB.currentRun = {}
  return
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:OnPlayerDeath(name)
  local _, _, difficulty, _, _, _, _, _ = GetInstanceInfo()

  if difficulty ~= 8 then
    return
  end

  if not MythicPlusTimerCMTimer.started then
    return
  end

  if MythicPlusTimerDB.currentRun.deathNames == nil then
    return
  end

  if MythicPlusTimerDB.currentRun.deathNames[name] == nil then
    MythicPlusTimerDB.currentRun.deathNames[name] = 1
  else
    MythicPlusTimerDB.currentRun.deathNames[name] = MythicPlusTimerDB.currentRun.deathNames[name] + 1
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:Draw(timeCM)
  local _, _, difficulty, _, _, _, _, currentZoneID = GetInstanceInfo()
  if difficulty ~= 8 then
    MythicPlusTimerCMTimer.frame:Hide()
    ObjectiveTrackerFrame:Show()
    return
  end

  if not MythicPlusTimerCMTimer.isCompleted then
    if MythicPlusTimerDB.config.hideDefaultObjectiveTracker then
      ObjectiveTrackerFrame:Hide()
    else
      ObjectiveTrackerFrame:Show()
    end
  end

  if not MythicPlusTimerCMTimer.started and not MythicPlusTimerCMTimer.reset and MythicPlusTimerCMTimer.timerStarted then
    MythicPlusTimer:CancelCMTimer()
    MythicPlusTimerCMTimer.timerStarted = false
    MythicPlusTimerCMTimer.frame:Hide()
    ObjectiveTrackerFrame:Show()
    return
  end

  if MythicPlusTimerCMTimer.reset or MythicPlusTimerCMTimer.isCompleted then
    MythicPlusTimerCMTimer.reset = false
    MythicPlusTimerCMTimer.timerStarted = false
    MythicPlusTimerCMTimer.started = false
    MythicPlusTimerCMTimer.lastKill = {}
    MythicPlusTimer:CancelCMTimer()
    MythicPlusTimerCMTimer.frame:Hide()
    ObjectiveTrackerFrame:Show()
    return
  end

  MythicPlusTimerCMTimer.timerStarted = true
  if not timeCM or timeCM <= 0 then
    return
  end

  local cmLevel, affixes, _ = C_ChallengeMode.GetActiveKeystoneInfo()

  if not MythicPlusTimerCMTimer.isCompleted then
    MythicPlusTimerCMTimer.frame:Show()
  end

  if not MythicPlusTimerDB.bestTimes[currentZoneID] then
    MythicPlusTimerDB.bestTimes[currentZoneID] = {}
  end

  if not MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel] then
    MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel] = {}
  end

  if not MythicPlusTimerDB.currentRun.times then
    MythicPlusTimerDB.currentRun.times = {}
  end

  if MythicPlusTimerDB.currentRun.deathNames == nil then
    MythicPlusTimerDB.currentRun.deathNames = {}
  end

  local currentMapId = C_ChallengeMode.GetActiveChallengeMapID()
  local zoneName, _, maxTime = C_ChallengeMode.GetMapUIInfo(currentMapId)
  local bonus = C_ChallengeMode.GetPowerLevelDamageHealthMod(cmLevel)

  -- draw
  MythicPlusTimerDB.currentRun.cmLevel = cmLevel
  MythicPlusTimerDB.currentRun.zoneName = zoneName
  MythicPlusTimerDB.currentRun.currentZoneID = currentZoneID
  MythicPlusTimerDB.currentRun.time = timeCM

  -- dungeon name + key level
  if not MythicPlusTimerCMTimer.frames.dungeonInfo then
    local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frame, 0, -30)

    f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontNormalLarge")
    f.text:SetPoint("TOPLEFT", 0, 0)
    MythicPlusTimerCMTimer.frames.dungeonInfo = f

    local infoOnEnter = function(self, motion)
      if not MythicPlusTimerCMTimer.frames.dungeonInfo.tooltip then
        return
      end

      GameTooltip:Hide()
      GameTooltip:ClearLines()
      GameTooltip:SetOwner(MythicPlusTimerCMTimer.frames.dungeonInfo, "ANCHOR_BOTTOMLEFT")

      for _, v in pairs(MythicPlusTimerCMTimer.frames.dungeonInfo.tooltip) do
        GameTooltip:AddLine(v)
      end
      GameTooltip:Show()
    end

    MythicPlusTimerCMTimer.frames.dungeonInfo:SetScript("OnEnter", infoOnEnter)
    MythicPlusTimerCMTimer.frames.dungeonInfo:SetScript("OnLeave", GameTooltip_Hide)
  end

  local dungeonName = "+" .. cmLevel .. " - " .. zoneName
  if MythicPlusTimerCMTimer.frames.dungeonInfo.text:GetText() ~= dungeonName then
    MythicPlusTimerCMTimer.frames.dungeonInfo.text:SetText(dungeonName)
    MythicPlusTimerCMTimer.frames.dungeonInfo:SetHeight(MythicPlusTimerCMTimer.frames.dungeonInfo.text:GetStringHeight())
    MythicPlusTimerCMTimer.frames.dungeonInfo:SetWidth(MythicPlusTimerCMTimer.frames.dungeonInfo.text:GetStringWidth())
  end

  local tooltip = {}
  table.insert(tooltip, dungeonName)
  table.insert(tooltip, "|cFFFFFFFF" .. "+" .. bonus .. "%")
  table.insert(tooltip, " ")

  -- affixes
  if not MythicPlusTimerCMTimer.frames.affixesText then
    local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.dungeonInfo, "BOTTOMLEFT", 0, -2)

    f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", 0, 0)
    MythicPlusTimerCMTimer.frames.affixesText = f
  end

  if not MythicPlusTimerCMTimer.frames.affixesIcons then
    local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.dungeonInfo, "BOTTOMLEFT", 0, -2)
    f:SetHeight(16)

    MythicPlusTimerCMTimer.frames.affixesIcons = f
  end

  if not MythicPlusTimerCMTimer.frames.affixesIcon then
    MythicPlusTimerCMTimer.frames.affixesIcon = {}
  end

  local txt = ""
  local isReaping = false
  local firstAffix = true
  local prevAffixFrame
  for j, affixID in ipairs(affixes) do
    local affixName, affixDesc, _ = C_ChallengeMode.GetAffixInfo(affixID)

    if not firstAffix then
      txt = txt .. " - "
    end
    txt = txt .. affixName

    table.insert(tooltip, affixName)
    table.insert(tooltip, "|cFFFFFFFF" .. affixDesc)
    table.insert(tooltip, "  ")

    firstAffix = false

    if affixID == 117 then
      isReaping = true
    end

    -- affix icons
    local affixFrame = MythicPlusTimerCMTimer.frames.affixesIcon[j]

    if MythicPlusTimerDB.config.showAffixesAsIcons then
      if not affixFrame then
        affixFrame = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frames.affixesIcons)
        affixFrame:SetSize(16, 16)

        local border = affixFrame:CreateTexture(nil, "OVERLAY")
        border:SetAllPoints()
        border:SetAtlas("ChallengeMode-AffixRing-Sm")
        affixFrame.Border = border

        local portrait = affixFrame:CreateTexture(nil, "ARTWORK")
        portrait:SetSize(16, 16)
        portrait:SetPoint("CENTER", border)
        affixFrame.Portrait = portrait

        affixFrame.SetUp = ScenarioChallengeModeAffixMixin.SetUp
        affixFrame:SetScript("OnEnter", ScenarioChallengeModeAffixMixin.OnEnter)
        affixFrame:SetScript("OnLeave", GameTooltip_Hide)

        MythicPlusTimerCMTimer.frames.affixesIcon[j] = affixFrame
      end

      if prevAffixFrame then
        if not affixFrame.refFrame or affixFrame.refFrame ~= prevAffixFrame then
          affixFrame:SetPoint("LEFT", prevAffixFrame, "RIGHT", 5, 0)
          affixFrame.refFrame = prevAffixFrame
        end
      else
        if not affixFrame.refFrame or affixFrame.refFrame ~= MythicPlusTimerCMTimer.frames.affixesIcons then
          affixFrame:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.affixesIcons, "TOPLEFT", 0, 0)
          affixFrame.refFrame = MythicPlusTimerCMTimer.frames.affixesIcons
        end
      end

      prevAffixFrame = affixFrame

      affixFrame:Show()

      if not affixFrame.affixID or affixFrame.affixID ~= affixID then
        affixFrame:SetUp(affixID)
        affixFrame.affixID = affixID
      end
    end
  end

  MythicPlusTimerCMTimer.frames.dungeonInfo.tooltip = tooltip

  if MythicPlusTimerDB.config.showAffixesAsText then
    MythicPlusTimerCMTimer.frames.affixesText:Show()

    if MythicPlusTimerCMTimer.frames.affixesText.text:GetText() ~= txt then
      MythicPlusTimerCMTimer.frames.affixesText.text:SetText(txt)
      MythicPlusTimerCMTimer.frames.affixesText:SetHeight(MythicPlusTimerCMTimer.frames.affixesText.text:GetStringHeight())
      MythicPlusTimerCMTimer.frames.affixesText:SetWidth(MythicPlusTimerCMTimer.frames.affixesText.text:GetStringWidth())

      MythicPlusTimerCMTimer.frames.affixesIcons.refName = "text"
      MythicPlusTimerCMTimer.frames.affixesIcons:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.dungeonInfo, "BOTTOMLEFT", 0, -6 - MythicPlusTimerCMTimer.frames.affixesText:GetHeight())
    end
  else
    MythicPlusTimerCMTimer.frames.affixesText.text:SetText("")
    MythicPlusTimerCMTimer.frames.affixesText:Hide()

    if not MythicPlusTimerCMTimer.frames.affixesIcons.refName or MythicPlusTimerCMTimer.frames.affixesIcons.refName ~= "info" then
      MythicPlusTimerCMTimer.frames.affixesIcons:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.dungeonInfo, "BOTTOMLEFT", 0, -2)
      MythicPlusTimerCMTimer.frames.affixesIcons.refName = "info"
    end
  end

  if MythicPlusTimerDB.config.showAffixesAsIcons then
    MythicPlusTimerCMTimer.frames.affixesIcons:SetWidth(16 * #affixes)
    MythicPlusTimerCMTimer.frames.affixesIcons:Show()
  else
    MythicPlusTimerCMTimer.frames.affixesIcons:Hide()
  end

  -- Time
  local timeLeft = maxTime - timeCM
  if timeLeft < 0 then
    timeLeft = 0
  end

  if not MythicPlusTimerCMTimer.frames.time then
    local font = "GameFontGreenLarge"
    if timeLeft == 0 then
      font = "GameFontRedLarge"
    end

    local t = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    t:ClearAllPoints()

    t.text = t:CreateFontString(nil, "BACKGROUND", font)
    t.text:SetPoint("TOPLEFT")

    local t2 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    t2:ClearAllPoints()

    t2.text = t2:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    t2.text:SetPoint("TOPLEFT")

    MythicPlusTimerCMTimer.frames.time = {
      timer = t,
      timer2 = t2
    }
  end

  local font = "GameFontGreenLarge"
  if timeLeft == 0 then
    font = "GameFontRedLarge"
  end

  if not MythicPlusTimerCMTimer.frames.time.timer.text.currentFont or MythicPlusTimerCMTimer.frames.time.timer.text.currentFont ~= font then
    MythicPlusTimerCMTimer.frames.time.timer.text:SetFontObject(font)
  end

  local timeLeftText = MythicPlusTimerCMTimer:FormatSeconds(timeLeft)
  local currentTimeLeftText = MythicPlusTimerCMTimer.frames.time.timer.text:GetText()

  MythicPlusTimerCMTimer.frames.time.timer.text:SetText(timeLeftText)

  if not currentTimeLeftText or not timeLeftText or string.len(timeLeftText) ~= string.len(currentTimeLeftText) then
    MythicPlusTimerCMTimer.frames.time.timer:SetHeight(MythicPlusTimerCMTimer.frames.time.timer.text:GetStringHeight())
    local currentWidth = MythicPlusTimerCMTimer.frames.time.timer.text:GetStringWidth()
    if not MythicPlusTimerCMTimer.frames.time.timer.width or currentWidth > MythicPlusTimerCMTimer.frames.time.timer.width then
      MythicPlusTimerCMTimer.frames.time.timer.width = currentWidth
    end
    MythicPlusTimerCMTimer.frames.time.timer:SetWidth(MythicPlusTimerCMTimer.frames.time.timer.width)
  end

  local timerRef = MythicPlusTimerCMTimer.frames.affixesIcons
  if not MythicPlusTimerDB.config.showAffixesAsIcons then
    timerRef = MythicPlusTimerCMTimer.frames.affixesText
  end

  if not MythicPlusTimerDB.config.showAffixesAsText and not MythicPlusTimerDB.config.showAffixesAsIcons then
    timerRef = MythicPlusTimerCMTimer.frames.dungeonInfo
  end

  if not MythicPlusTimerCMTimer.frames.time.timer.refFrame or MythicPlusTimerCMTimer.frames.time.timer.refFrame ~= timerRef then
    MythicPlusTimerCMTimer.frames.time.timer:SetPoint("TOPLEFT", timerRef, "BOTTOMLEFT", 0, -10)
    MythicPlusTimerCMTimer.frames.time.timer.refFrame = timerRef
  end

  local dungeonTimeText = "(" .. MythicPlusTimerCMTimer:FormatSeconds(timeCM) .. " / " .. MythicPlusTimerCMTimer:FormatSeconds(maxTime) .. ")"
  local currentDungeonTimeText = MythicPlusTimerCMTimer.frames.time.timer2.text:GetText()

  MythicPlusTimerCMTimer.frames.time.timer2.text:SetText(dungeonTimeText)

  if not dungeonTimeText or not currentDungeonTimeText or string.len(dungeonTimeText) ~= string.len(currentDungeonTimeText) then
    MythicPlusTimerCMTimer.frames.time.timer2:SetHeight(MythicPlusTimerCMTimer.frames.time.timer2.text:GetStringHeight())
    MythicPlusTimerCMTimer.frames.time.timer2:SetWidth(MythicPlusTimerCMTimer.frames.time.timer2.text:GetStringWidth())
    MythicPlusTimerCMTimer.frames.time.timer2:SetPoint("BOTTOMLEFT", MythicPlusTimerCMTimer.frames.time.timer, "BOTTOMRIGHT", 5, 1)
  end

  MythicPlusTimerDB.currentRun.timeLeft = timeLeft

  -- Chest Timer
  local threeChestTime = maxTime * 0.6
  local twoChestTime = maxTime * 0.8

  local timeLeft3 = threeChestTime - timeCM
  if timeLeft3 < 0 then
    timeLeft3 = 0
  end

  local timeLeft2 = twoChestTime - timeCM
  if timeLeft2 < 0 then
    timeLeft2 = 0
  end

  MythicPlusTimerDB.currentRun.timeLeft3 = timeLeft3
  MythicPlusTimerDB.currentRun.timeLeft2 = timeLeft2

  if not MythicPlusTimerCMTimer.frames.chesttimer then
    local l2 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    l2:ClearAllPoints()

    l2.text = l2:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    l2.text:SetPoint("TOPLEFT")

    local t2 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    t2:ClearAllPoints()

    t2.text = t2:CreateFontString(nil, "BACKGROUND", "GameFontGreen")
    t2.text:SetPoint("TOPLEFT")

    local l3 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    l3:ClearAllPoints()

    l3.text = l3:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    l3.text:SetPoint("TOPLEFT")

    local t3 = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
    t3:ClearAllPoints()

    t3.text = t3:CreateFontString(nil, "BACKGROUND", "GameFontGreen")
    t3.text:SetPoint("TOPLEFT")

    MythicPlusTimerCMTimer.frames.chesttimer = {
      label2 = l2,
      time2 = t2,
      label3 = l3,
      time3 = t3
    }
  end

  -- -- +2
  local currentTimeLeft2Label = MythicPlusTimerCMTimer.frames.chesttimer.label2.text:GetText()
  local currentTime2 = MythicPlusTimerCMTimer.frames.chesttimer.time2.text:GetText()
  local timeLeft2LabelText = ""
  local updateTime2Pos = false
  local timeLeft2Text = ""

  if timeLeft2 == 0 then
    timeLeft2LabelText = "+2 (" .. MythicPlusTimerCMTimer:FormatSeconds(twoChestTime) .. ")"

    MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetText(timeLeft2LabelText)
    if not MythicPlusTimerCMTimer.frames.chesttimer.label2.text.currentFont or MythicPlusTimerCMTimer.frames.chesttimer.label2.text.currentFont ~= "GameFontDisable" then
      MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetFontObject("GameFontDisable")
    end

    MythicPlusTimerCMTimer.frames.chesttimer.time2:Hide()
  else
    timeLeft2LabelText = "+2 (" .. MythicPlusTimerCMTimer:FormatSeconds(twoChestTime) .. "):"

    MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetText(timeLeft2LabelText)
    if not MythicPlusTimerCMTimer.frames.chesttimer.label2.text.currentFont or MythicPlusTimerCMTimer.frames.chesttimer.label2.text.currentFont ~= "GameFontHighlight" then
      MythicPlusTimerCMTimer.frames.chesttimer.label2.text:SetFontObject("GameFontHighlight")
    end

    timeLeft2Text = MythicPlusTimerCMTimer:FormatSeconds(timeLeft2)
    MythicPlusTimerCMTimer.frames.chesttimer.time2.text:SetText(timeLeft2Text)
    MythicPlusTimerCMTimer.frames.chesttimer.time2:Show()
    updateTime2Pos = true
  end

  if not timeLeft2LabelText or not currentTimeLeft2Label or string.len(timeLeft2LabelText) ~= string.len(currentTimeLeft2Label) then
    MythicPlusTimerCMTimer.frames.chesttimer.label2:SetHeight(MythicPlusTimerCMTimer.frames.chesttimer.label2.text:GetStringHeight())
    MythicPlusTimerCMTimer.frames.chesttimer.label2:SetWidth(MythicPlusTimerCMTimer.frames.chesttimer.label2.text:GetStringWidth())
    MythicPlusTimerCMTimer.frames.chesttimer.label2:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.time.timer, "BOTTOMLEFT", 0, -5)
  end

  if updateTime2Pos and (not timeLeft2Text or not currentTime2 or string.len(timeLeft2Text) ~= string.len(currentTime2)) then
    MythicPlusTimerCMTimer.frames.chesttimer.time2:SetHeight(MythicPlusTimerCMTimer.frames.chesttimer.time2.text:GetStringHeight())
    MythicPlusTimerCMTimer.frames.chesttimer.time2:SetWidth(MythicPlusTimerCMTimer.frames.chesttimer.time2.text:GetStringWidth())
    MythicPlusTimerCMTimer.frames.chesttimer.time2:SetPoint("BOTTOMLEFT", MythicPlusTimerCMTimer.frames.chesttimer.label2, "BOTTOMRIGHT", 5, 0)
  end

  -- -- +3
  local currentTimeLeft3Label = MythicPlusTimerCMTimer.frames.chesttimer.label3.text:GetText()
  local currentTime3 = MythicPlusTimerCMTimer.frames.chesttimer.time3.text:GetText()
  local timeLeft3LabelText = ""
  local updateTime3Pos = false
  local timeLeft3Text = ""

  if timeLeft3 == 0 then
    timeLeft3LabelText = "+3 (" .. MythicPlusTimerCMTimer:FormatSeconds(threeChestTime) .. ")"

    MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetText(timeLeft3LabelText)
    if not MythicPlusTimerCMTimer.frames.chesttimer.label3.text.currentFont or MythicPlusTimerCMTimer.frames.chesttimer.label3.text.currentFont ~= "GameFontDisable" then
      MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetFontObject("GameFontDisable")
    end

    MythicPlusTimerCMTimer.frames.chesttimer.time3:Hide()
  else
    timeLeft3LabelText = "+3 (" .. MythicPlusTimerCMTimer:FormatSeconds(threeChestTime) .. "):"

    MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetText("+3 (" .. MythicPlusTimerCMTimer:FormatSeconds(threeChestTime) .. "):")
    if not MythicPlusTimerCMTimer.frames.chesttimer.label3.text.currentFont or MythicPlusTimerCMTimer.frames.chesttimer.label3.text.currentFont ~= "GameFontHighlight" then
      MythicPlusTimerCMTimer.frames.chesttimer.label3.text:SetFontObject("GameFontHighlight")
    end

    timeLeft3Text = MythicPlusTimerCMTimer:FormatSeconds(timeLeft3)
    MythicPlusTimerCMTimer.frames.chesttimer.time3.text:SetText(timeLeft3Text)
    MythicPlusTimerCMTimer.frames.chesttimer.time3:Show()
    updateTime3Pos = true
  end

  if not timeLeft3LabelText or not currentTimeLeft3Label or string.len(timeLeft3LabelText) ~= string.len(currentTimeLeft3Label) then
    MythicPlusTimerCMTimer.frames.chesttimer.label3:SetHeight(MythicPlusTimerCMTimer.frames.chesttimer.label3.text:GetStringHeight())
    MythicPlusTimerCMTimer.frames.chesttimer.label3:SetWidth(MythicPlusTimerCMTimer.frames.chesttimer.label3.text:GetStringWidth())
    MythicPlusTimerCMTimer.frames.chesttimer.label3:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.chesttimer.label2, "BOTTOMLEFT", 0, -5)
  end

  if updateTime3Pos and (not timeLeft3Text or not currentTime3 or string.len(timeLeft3Text) ~= string.len(currentTime3)) then
    MythicPlusTimerCMTimer.frames.chesttimer.time3:SetHeight(MythicPlusTimerCMTimer.frames.chesttimer.time3.text:GetStringHeight())
    MythicPlusTimerCMTimer.frames.chesttimer.time3:SetWidth(MythicPlusTimerCMTimer.frames.chesttimer.time3.text:GetStringWidth())
    MythicPlusTimerCMTimer.frames.chesttimer.time3:SetPoint("BOTTOMLEFT", MythicPlusTimerCMTimer.frames.chesttimer.label3, "BOTTOMRIGHT", 5, 0)
  end

  -- Objectives
  local _, _, steps = C_Scenario.GetStepInfo()
  if not MythicPlusTimerCMTimer.frames.objectives then
    MythicPlusTimerCMTimer.frames.objectives = {}
  end

  local stepsCount = 0
  local prevStepFrame
  local finalQuantity
  local currentQuantity
  local quantityProgressDone = false
  for i = 1, steps do
    stepsCount = stepsCount + 1
    if not MythicPlusTimerCMTimer.frames.objectives[i] then
      local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
      f:ClearAllPoints()

      f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
      f.text:SetPoint("TOPLEFT")

      MythicPlusTimerCMTimer.frames.objectives[i] = f
    end

    local name, _, status, curValue, finalValue, _, _, quantity = C_Scenario.GetCriteriaInfo(i)
    if status then
      if not MythicPlusTimerCMTimer.frames.objectives[i].text.currentFont or MythicPlusTimerCMTimer.frames.objectives[i].text.currentFont ~= "GameFontDisable" then
        MythicPlusTimerCMTimer.frames.objectives[i].text:SetFontObject("GameFontDisable")
      end

      if MythicPlusTimerDB.currentRun.times[i] == nil then
        MythicPlusTimerDB.currentRun.times[i] = timeCM

        if not MythicPlusTimerDB.bestTimes[currentZoneID][i] or timeCM < MythicPlusTimerDB.bestTimes[currentZoneID][i] then
          MythicPlusTimerDB.bestTimes[currentZoneID][i] = timeCM
        end

        if not MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel][i] or timeCM < MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel][i] then
          MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel][i] = timeCM
        end

        if MythicPlusTimerDB.config.objectiveTimeInChat then
          local text = name .. " " .. MythicPlusTimer.L["Completed"] .. " (+" .. cmLevel .. "). " .. MythicPlusTimer.L["Time"] .. ": " .. MythicPlusTimerCMTimer:FormatSeconds(timeCM) .. " " .. MythicPlusTimer.L["BestTime"] .. ": "

          if MythicPlusTimerDB.config.objectiveTimePerLevel then
            text = text .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel][i])
          else
            text = text .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID][i])
          end

          MythicPlusTimer:Print(text)
        end
      end
    else
      if not MythicPlusTimerCMTimer.frames.objectives[i].text.currentFont or MythicPlusTimerCMTimer.frames.objectives[i].text.currentFont ~= "GameFontHighlight" then
        MythicPlusTimerCMTimer.frames.objectives[i].text:SetFontObject("GameFontHighlight")
      end

      if MythicPlusTimerDB.currentRun.times[i] then
        MythicPlusTimerDB.currentRun.times[i] = nil
      end
    end

    local bestTimeStr = ""
    if MythicPlusTimerDB.currentRun.times[i] and MythicPlusTimerDB.config.objectiveTime then
      bestTimeStr = " - " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.times[i])

      if MythicPlusTimerDB.config.objectiveTimePerLevel then
        if MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel][i] then
          local diff = MythicPlusTimerDB.currentRun.times[i] - MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel][i]
          local diffStr = ""
          if diff > 0 then
            diffStr = ", +" .. MythicPlusTimerCMTimer:FormatSeconds(diff)
          end

          bestTimeStr = bestTimeStr .. " (" .. MythicPlusTimer.L["Best"] .. ": " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID]["l" .. cmLevel][i]) .. diffStr .. ")"
        end
      else
        if MythicPlusTimerDB.bestTimes[currentZoneID][i] then
          local diff = MythicPlusTimerDB.currentRun.times[i] - MythicPlusTimerDB.bestTimes[currentZoneID][i]
          local diffStr = ""
          if diff > 0 then
            diffStr = ", +" .. MythicPlusTimerCMTimer:FormatSeconds(diff)
          end

          bestTimeStr = bestTimeStr .. " (" .. MythicPlusTimer.L["Best"] .. ": " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.bestTimes[currentZoneID][i]) .. diffStr .. ")"
        end
      end
    end

    local objectiveText = ""
    if finalValue >= 100 then
      local quantityNumber = string.sub(quantity, 1, string.len(quantity) - 1)
      local quantityPercent = (quantityNumber / finalValue) * 100

      finalQuantity = finalValue
      currentQuantity = quantityNumber

      if status then
        quantityProgressDone = true
      end

      local mult = 10 ^ 2
      quantityPercent = math.floor(quantityPercent * mult + 0.5) / mult
      if (quantityPercent > 100) then
        quantityPercent = 100
      end

      local absoluteNumber = ""
      if MythicPlusTimerDB.config.showAbsoluteNumbers then
        local missingAbsolute = finalValue - quantityNumber
        if missingAbsolute == 0 then
          missingAbsolute = ""
        else
          missingAbsolute = " - " .. missingAbsolute
        end

        absoluteNumber = "(" .. quantityNumber .. "/" .. finalValue .. missingAbsolute .. ") "
      end

      objectiveText = "- " .. quantityPercent .. "% " .. absoluteNumber .. name .. bestTimeStr
    else
      if status then
        curValue = finalValue
      end

      objectiveText = "- " .. curValue .. "/" .. finalValue .. " " .. name .. bestTimeStr
    end

    local objectiveFrame = MythicPlusTimerCMTimer.frames.objectives[i]

    local currentObjectiveText = objectiveFrame.text:GetText()
    if currentObjectiveText ~= objectiveText then
      objectiveFrame.text:SetText(objectiveText)

      if not currentObjectiveText or not objectiveText or string.len(currentObjectiveText) ~= string.len(objectiveText) then
        objectiveFrame:SetHeight(objectiveFrame.text:GetStringHeight())
        objectiveFrame:SetWidth(objectiveFrame.text:GetStringWidth())
      end
    end

    if prevStepFrame then
      if not objectiveFrame.refFrame or objectiveFrame.refFrame ~= prevStepFrame then
        objectiveFrame:SetPoint("TOPLEFT", prevStepFrame, "BOTTOMLEFT", 0, -5)
        objectiveFrame.refFrame = prevStepFrame
      end
    else
      if not objectiveFrame.refFrame or objectiveFrame.refFrame ~= MythicPlusTimerCMTimer.frames.chesttimer.label3 then
        objectiveFrame:SetPoint("TOPLEFT", MythicPlusTimerCMTimer.frames.chesttimer.label3, "BOTTOMLEFT", 0, -20)
        objectiveFrame.refFrame = MythicPlusTimerCMTimer.frames.chesttimer.label3
      end
    end

    objectiveFrame:Show()

    prevStepFrame = MythicPlusTimerCMTimer.frames.objectives[i]
  end

  local nextRefFrame = prevStepFrame

  -- Death Count
  local deathCount, deathTimeLost = C_ChallengeMode.GetDeathCount()
  if deathTimeLost and deathTimeLost > 0 and deathCount and deathCount > 0 and MythicPlusTimerDB.config.deathCounter then
    if not MythicPlusTimerCMTimer.frames.deathCounter then
      local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
      f:ClearAllPoints()

      f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
      f.text:SetPoint("TOPLEFT")

      MythicPlusTimerCMTimer.frames.deathCounter = f

      local deathCounterOnEnter = function(self, motion)
        if not MythicPlusTimerCMTimer.frames.deathCounter.tooltip then
          return
        end

        GameTooltip:Hide()
        GameTooltip:ClearLines()
        GameTooltip:SetOwner(MythicPlusTimerCMTimer.frames.deathCounter, "ANCHOR_TOPLEFT")

        for _, v in pairs(MythicPlusTimerCMTimer.frames.deathCounter.tooltip) do
          GameTooltip:AddLine(v)
        end
        GameTooltip:Show()
      end

      local deathCounterOnLeave = function(self, motion)
        GameTooltip:Hide()
      end

      MythicPlusTimerCMTimer.frames.deathCounter:SetScript("OnEnter", deathCounterOnEnter)
      MythicPlusTimerCMTimer.frames.deathCounter:SetScript("OnLeave", deathCounterOnLeave)
    end

    local deathCountText = deathCount .. " " .. MythicPlusTimer.L["Deaths"] .. ":|cFFFF0000 -" .. MythicPlusTimerCMTimer:FormatSeconds(deathTimeLost)
    local currentDeathCountText = MythicPlusTimerCMTimer.frames.deathCounter.text:GetText()

    if currentDeathCountText ~= deathCountText then
      MythicPlusTimerCMTimer.frames.deathCounter.text:SetText(deathCountText)

      if not currentDeathCountText or not deathCountText or string.len(currentDeathCountText) ~= string.len(deathCountText) then
        MythicPlusTimerCMTimer.frames.deathCounter:SetHeight(MythicPlusTimerCMTimer.frames.deathCounter.text:GetStringHeight())
        MythicPlusTimerCMTimer.frames.deathCounter:SetWidth(MythicPlusTimerCMTimer.frames.deathCounter.text:GetStringWidth())
      end
    end

    if not MythicPlusTimerCMTimer.frames.deathCounter.refFrame or MythicPlusTimerCMTimer.frames.deathCounter.refFrame ~= prevStepFrame then
      MythicPlusTimerCMTimer.frames.deathCounter:SetPoint("TOPLEFT", prevStepFrame, "BOTTOMLEFT", 0, -5)
      MythicPlusTimerCMTimer.frames.deathCounter.refFrame = prevStepFrame
    end

    MythicPlusTimerCMTimer.frames.deathCounter:Show()

    if MythicPlusTimerDB.currentRun.deathNames then
      local tooltip = {}
      table.insert(tooltip, MythicPlusTimer.L["Deaths"])

      for name, count in pairs(MythicPlusTimerDB.currentRun.deathNames) do
        table.insert(tooltip, "|cFFFFFFFF" .. name .. ": " .. count)
      end

      MythicPlusTimerCMTimer.frames.deathCounter.tooltip = tooltip
    else
      MythicPlusTimerCMTimer.frames.deathCounter.tooltip = nil
    end

    nextRefFrame = MythicPlusTimerCMTimer.frames.deathCounter
  else
    if MythicPlusTimerCMTimer.frames.deathCounter then
      MythicPlusTimerCMTimer.frames.deathCounter:Hide()
    end
  end

  -- reaping timer
  if isReaping and MythicPlusTimerDB.config.showReapingTimer and finalQuantity and not quantityProgressDone then
    if not MythicPlusTimerCMTimer.frames.reaping then
      local f = CreateFrame("Frame", nil, MythicPlusTimerCMTimer.frame)
      f:ClearAllPoints()

      f.text = f:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
      f.text:SetPoint("TOPLEFT")

      MythicPlusTimerCMTimer.frames.reaping = f
    end

    local reapingQuantity = finalQuantity / 5
    local reapingIn = reapingQuantity - currentQuantity % reapingQuantity
    local reapingInPercent = (reapingIn / finalQuantity) * 100

    local mult = 10 ^ 2
    reapingInPercent = math.floor(reapingInPercent * mult + 0.5) / mult

    local reapingText = MythicPlusTimer.L["ReapingIn"] .. ": " .. reapingInPercent .. "%"

    if MythicPlusTimerDB.config.showAbsoluteNumbers then
      reapingText = reapingText .. " (" .. math.ceil(reapingIn) .. ")"
    end

    local currentReapingText = MythicPlusTimerCMTimer.frames.reaping.text:GetText()

    if currentReapingText ~= reapingText then
      MythicPlusTimerCMTimer.frames.reaping.text:SetText(reapingText)

      if not currentReapingText or not reapingText or string.len(currentReapingText) ~= string.len(reapingText) then
        MythicPlusTimerCMTimer.frames.reaping:SetHeight(MythicPlusTimerCMTimer.frames.reaping.text:GetStringHeight())
        MythicPlusTimerCMTimer.frames.reaping:SetWidth(MythicPlusTimerCMTimer.frames.reaping.text:GetStringWidth())
      end
    end

    if not MythicPlusTimerCMTimer.frames.reaping.refFrame or MythicPlusTimerCMTimer.frames.reaping.refFrame ~= nextRefFrame then
      MythicPlusTimerCMTimer.frames.reaping:SetPoint("TOPLEFT", nextRefFrame, "BOTTOMLEFT", 0, -5)
      MythicPlusTimerCMTimer.frames.reaping.refFrame = nextRefFrame
    end

    MythicPlusTimerCMTimer.frames.reaping:Show()
  else
    if MythicPlusTimerCMTimer.frames.reaping then
      MythicPlusTimerCMTimer.frames.reaping:Hide()
    end
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:ResolveTime(seconds)
  local min = math.floor(seconds / 60)
  local sec = seconds - (min * 60)
  return min, sec
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

    local timeText = MythicPlusTimer.L["TimeLeft"] .. ": " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.timeLeft) .. " || +2: " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.timeLeft2) .. " || +3: " .. MythicPlusTimerCMTimer:FormatSeconds(MythicPlusTimerDB.currentRun.timeLeft3)

    local channel = "PARTY"
    if GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE) > 0 then
      channel = "INSTANCE_CHAT"
    end
    SendChatMessage(timeText, channel)
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function MythicPlusTimerCMTimer:resolveNpcID(guid)
  local targetType, _, _, _, _, npcID = strsplit("-", guid)
  if targetType == "Vehicle" or targetType == "Creature" and npcID then
    return tonumber(npcID)
  end
end
