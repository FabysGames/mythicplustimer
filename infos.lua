local _, addon = ...
local infos = addon.new_module("infos")

-- ---------------------------------------------------------------------------------------------------------------------
local main
local criteria

-- ---------------------------------------------------------------------------------------------------------------------
local deathcounter_frame

-- ---------------------------------------------------------------------------------------------------------------------
local function create_deathcounter_frame()
  if deathcounter_frame then
    return deathcounter_frame
  end

  -- frame
  local frame = CreateFrame("Frame", nil, main.get_frame())
  frame:ClearAllPoints()

  -- text
  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local font_path, _, font_flags = frame.text:GetFont()
  frame.text:SetFont(font_path, 12, font_flags)

  if addon.c("align_right") then
    frame.text:SetPoint("TOPRIGHT")
    frame.text:SetJustifyH("RIGHT")
  else 
    frame.text:SetPoint("TOPLEFT")
    frame.text:SetJustifyH("LEFT")
  end

  deathcounter_frame = frame
  return deathcounter_frame
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_config_change()
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  -- update demo
  if current_run.is_demo then
    -- deathcounter
    current_run.deathcount = -1
    infos.update_deathcounter_info(current_run, 2, 10)
    return
  end

  -- update deathcounter
  current_run.deathcount = -1 -- reset count in cache to trigger the rerender
  infos.update_deathcounter()
end

-- ---------------------------------------------------------------------------------------------------------------------
local function update_deathcounter(current_run, deathcount, death_timelost)
  -- check deathcount
  if not deathcount or deathcount == 0 or not addon.c("show_deathcounter") then
    current_run.deathcount_visible = false

    if deathcounter_frame then
      deathcounter_frame:Hide()
    end
    return
  end

  -- check if we can skip the update
  local last_criteria_frame = criteria.get_last_frame(current_run)
  if current_run.deathcount == deathcount and deathcounter_frame and deathcounter_frame.ref_frame == last_criteria_frame and current_run.deathcount_visible then
    return
  end

  current_run.deathcount = deathcount
  current_run.deathcount_visible = true

  -- update
  create_deathcounter_frame()

  local deathcounter_text = string.format("|c%s%s %s|r|c%s -%s", addon.c("color_deathcounter"), deathcount, addon.t("lbl_deaths"), addon.c("color_deathcounter_timelost"), main.format_seconds(death_timelost))
  local current_deathcounter_text = deathcounter_frame.text:GetText()

  if current_deathcounter_text ~= deathcounter_text then
    deathcounter_frame.text:SetText(deathcounter_text)

    -- update size
    if not current_deathcounter_text or not deathcounter_text or string.len(current_deathcounter_text) ~= string.len(deathcounter_text) then
      deathcounter_frame:SetHeight(deathcounter_frame.text:GetStringHeight())
      deathcounter_frame:SetWidth(deathcounter_frame.text:GetStringWidth())
    end
  end

  -- update point (last criteria frame can be different in every dungeon)
  if not deathcounter_frame.ref_frame or deathcounter_frame.ref_frame ~= last_criteria_frame then
    if addon.c("align_right") then
      deathcounter_frame:SetPoint("TOPRIGHT", last_criteria_frame, "BOTTOMRIGHT", 0, -5)
    else 
      deathcounter_frame:SetPoint("TOPLEFT", last_criteria_frame, "BOTTOMLEFT", 0, -5)
    end

    deathcounter_frame.ref_frame = last_criteria_frame
  end

  -- show
  deathcounter_frame:Show()
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.hide_frames()
  -- deathcounter frame
  if deathcounter_frame then
    deathcounter_frame:Hide()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.update_deathcounter()
  -- is called every second by the timer
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  -- skip if run is completed
  if current_run.is_completed then
    return
  end

  -- update demo
  if current_run.is_demo then
    current_run.deathcount = -1
    infos.update_deathcounter_info(current_run, 2, 10)
    return
  end

  -- update from C_ChallengeMode
  local deathcount, death_timelost = C_ChallengeMode.GetDeathCount()
  update_deathcounter(current_run, deathcount, death_timelost)
end

-- ---------------------------------------------------------------------------------------------------------------------
function infos.update_deathcounter_info(current_run, deathcount, death_timelost)
  -- used to update the deathcounter directly (demo)
  update_deathcounter(current_run, deathcount, death_timelost)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Init
function infos:init()
  main = addon.get_module("main")
  criteria = addon.get_module("criteria")
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Enable
function infos:enable()
  -- config listeners
  addon.register_config_listener("show_deathcounter", on_config_change)
  addon.register_config_listener("show_absolute_numbers", on_config_change)
  addon.register_config_listener("show_enemy_forces_bar", on_config_change)
  addon.register_config_listener("color_deathcounter", on_config_change)
  addon.register_config_listener("color_deathcounter_timelost", on_config_change)
  addon.register_config_listener("show_percent_numbers", on_config_change)
end
