local _, addon = ...
local criteria = addon.new_module("criteria")

-- ---------------------------------------------------------------------------------------------------------------------
local main
local timer
local infos

-- ---------------------------------------------------------------------------------------------------------------------
local step_frames = {}

local demo_steps = {
  {
    name = "Boss 1",
    completed = true,
    cur_value = 1,
    final_value = 1
  },
  {
    name = "Boss 2",
    completed = false,
    cur_value = 0,
    final_value = 1
  },
  {
    name = "Boss 3",
    completed = false,
    cur_value = 0,
    final_value = 1
  },
  {
    name = "Boss 4",
    completed = false,
    cur_value = 0,
    final_value = 1
  },
  {
    name = addon.t("lbl_enemyforces"),
    completed = false,
    cur_value = 42,
    final_value = 123,
    quantity = "42%"
  }
}

-- ---------------------------------------------------------------------------------------------------------------------
local function create_step_frame(step_index)
  if step_frames[step_index] then
    return step_frames[step_index]
  end

  -- frame
  local frame = CreateFrame("Frame", nil, main.get_frame())
  if step_index == 1 then
    frame:SetPoint("TOPLEFT", timer.get_label_3_frame(), "BOTTOMLEFT", 0, -20)
  else
    frame:SetPoint("TOPLEFT", step_frames[step_index - 1], "BOTTOMLEFT", 0, -5)
  end

  -- text
  frame.text = frame:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
  frame.text:SetPoint("TOPLEFT")

  step_frames[step_index] = frame
  return step_frames[step_index]
end

-- ---------------------------------------------------------------------------------------------------------------------
local function set_step_completed(step_index, current_run, name)
  -- check if step was already set to completed
  if current_run.times[step_index] ~= nil then
    return
  end

  -- set step time
  local step_frame = step_frames[step_index]

  local elapsed_time = current_run.elapsed_time
  current_run.times[step_index] = elapsed_time

  -- check best times
  local best_times = addon.c("best_times")

  local best_time_zone = best_times[current_run.current_zone_id][step_index]
  if not best_time_zone or elapsed_time < best_time_zone then
    best_time_zone = elapsed_time
    best_times[current_run.current_zone_id][step_index] = elapsed_time
  end

  local best_time_zone_level = best_times[current_run.current_zone_id][current_run.level_key][step_index]
  if not best_time_zone_level or elapsed_time < best_time_zone_level then
    best_time_zone_level = elapsed_time
    best_times[current_run.current_zone_id][current_run.level_key][step_index] = elapsed_time
  end

  -- output step completion to chat if configured
  if addon.c("objective_time_inchat") and main.is_in_cm() then
    local text = name .. " " .. addon.t("lbl_completed") .. " (+" .. current_run.cm_level .. "). " .. addon.t("lbl_time") .. ": " .. main.format_seconds(elapsed_time) .. " " .. addon.t("lbl_besttime") .. ": "

    if addon.c("objective_time_perlevel") then
      text = text .. main.format_seconds(best_time_zone_level)
    else
      text = text .. main.format_seconds(best_time_zone)
    end

    addon.print(text)
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
local function resolve_time_info(step_index, current_run)
  if not current_run.times[step_index] or not addon.c("objective_time") then
    return ""
  end

  -- time info
  local time = current_run.times[step_index]
  local time_info = " - " .. main.format_seconds(time)

  -- add best times
  local best_times = addon.c("best_times")

  if addon.c("objective_time_perlevel") then
    -- best time per level and zone
    local best_time_zone_level = best_times[current_run.current_zone_id][current_run.level_key][step_index]

    if best_time_zone_level then
      local diff = time - best_time_zone_level
      local diff_info = ""
      if diff > 0 then
        diff_info = ", +" .. main.format_seconds(diff)
      end

      time_info = time_info .. " (" .. addon.t("lbl_best") .. ": " .. main.format_seconds(best_time_zone_level) .. diff_info .. ")"
    end
  else
    -- best time per zone
    local best_time_zone = best_times[current_run.current_zone_id][step_index]

    if best_time_zone then
      local diff = time - best_time_zone
      local diff_info = ""
      if diff > 0 then
        diff_info = ", +" .. main.format_seconds(diff)
      end

      time_info = time_info .. " (" .. addon.t("lbl_best") .. ": " .. main.format_seconds(best_time_zone) .. diff_info .. ")"
    end
  end

  return time_info
end

-- ---------------------------------------------------------------------------------------------------------------------
local function resolve_step_info(step_index, current_run, name, completed, cur_value, final_value, quantity)
  -- enemy forces
  if final_value >= 100 then
    -- absolute number
    local quantity_number = string.sub(quantity, 1, string.len(quantity) - 1)

    -- percentage
    local quantity_percent = (quantity_number / final_value) * 100
    local mult = 10 ^ 2
    quantity_percent = math.floor(quantity_percent * mult + 0.5) / mult
    if quantity_percent > 100 then
      quantity_percent = 100
    end

    -- set to 100% if completed (needed if enemy forces is the last criteria which gets completed, quantity is not updated to 100% in this case)
    if completed then
      quantity_percent = 100
      quantity_number = final_value
      current_run.quantity_completed = true
    end

    -- save to current_run
    current_run.quantity_number = quantity_number
    current_run.final_quantity_number = final_value

    -- resolve absolute number text
    local absolute_number = ""
    if addon.c("show_absolute_numbers") then
      local missing_absolute = final_value - quantity_number
      if missing_absolute == 0 then
        missing_absolute = ""
      else
        missing_absolute = " - " .. missing_absolute
      end

      absolute_number = "(" .. quantity_number .. "/" .. final_value .. missing_absolute .. ") "
    end

    return "- " .. quantity_percent .. "% " .. absolute_number .. name
  end

  -- boss
  if completed then
    cur_value = final_value
  end

  return "- " .. cur_value .. "/" .. final_value .. " " .. name
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_scenario_criteria_update()
  -- check if we have an run
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  -- resolve steps
  local _, _, steps = C_Scenario.GetStepInfo()
  if not steps or steps <= 0 then
    return
  end

  -- set needs update
  criteria.needs_update = true

  -- check if all are completed
  local completed_steps = 0
  for i = 1, steps do
    local _, _, completed = C_Scenario.GetCriteriaInfo(i)

    if completed then
      completed_steps = completed_steps + 1
    end
  end

  if completed_steps == steps then
    current_run.is_completed = true
    criteria.update()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_config_change()
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  -- update demo
  if current_run.is_demo then
    criteria.update_demo_criteria(current_run)
    return
  end

  -- update criteria
  criteria.needs_update = true
  criteria.update()
end

-- ---------------------------------------------------------------------------------------------------------------------
function criteria.on_challenge_mode_start()
  criteria.needs_update = true
  criteria.update()

  -- first timer tick must update criterias ... criterias are not always known until the timer elapsed
  criteria.needs_update = true
end

-- ---------------------------------------------------------------------------------------------------------------------
function criteria.on_player_entering_world()
  -- update if in cm
  if main.is_in_cm() then
    criteria.needs_update = true
    criteria.update()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function criteria.update()
  -- called every second by the timer module

  -- skip update if no criteria was updated
  if not criteria.needs_update then
    return
  end

  -- update all
  criteria.needs_update = false

  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  local _, _, steps = C_Scenario.GetStepInfo()
  if not steps or steps <= 0 then
    return
  end

  for i = 1, steps do
    local name, _, completed, cur_value, final_value, _, _, quantity = C_Scenario.GetCriteriaInfo(i)
    criteria.update_step(i, current_run, name, completed, cur_value, final_value, quantity)
  end

  -- update reaping
  infos.update_reaping()
end

-- ---------------------------------------------------------------------------------------------------------------------
function criteria.update_step(step_index, current_run, name, completed, cur_value, final_value, quantity)
  -- resolve frame
  local step_frame = create_step_frame(step_index)

  -- update times
  if completed then
    set_step_completed(step_index, current_run, name)

    -- set font
    if not step_frame.text.current_font or step_frame.text.current_font ~= "GameFontDisable" then
      step_frame.text:SetFontObject("GameFontDisable")
      step_frame.text.current_font = "GameFontDisable"
    end
  else
    -- set font
    if not step_frame.text.current_font or step_frame.text.current_font ~= "GameFontHighlight" then
      step_frame.text:SetFontObject("GameFontHighlight")
      step_frame.text.current_font = "GameFontHighlight"
    end

    -- reset current run time
    if current_run.times[step_index] then
      current_run.times[step_index] = nil
    end
  end

  -- resolve time info
  local time_info = resolve_time_info(step_index, current_run)

  -- resolve step info
  local step_info = resolve_step_info(step_index, current_run, name, completed, cur_value, final_value, quantity)

  -- set text
  local objective_text = step_info .. time_info
  local current_objective_text = step_frame.text:GetText()

  if current_objective_text ~= objective_text then
    step_frame.text:SetText(objective_text)

    if not current_objective_text or not objective_text or string.len(current_objective_text) ~= string.len(objective_text) then
      step_frame:SetHeight(step_frame.text:GetStringHeight())
      step_frame:SetWidth(step_frame.text:GetStringWidth())
    end
  end

  -- show frame
  step_frame:Show()
end

-- ---------------------------------------------------------------------------------------------------------------------
function criteria.hide_frames()
  for _, frame in pairs(step_frames) do
    frame:Hide()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
function criteria.get_last_frame(current_run)
  -- check if demo
  if current_run.is_demo then
    return step_frames[#demo_steps]
  end

  local _, _, steps = C_Scenario.GetStepInfo()
  return step_frames[steps]
end

-- ---------------------------------------------------------------------------------------------------------------------
function criteria.update_demo_criteria(demo_run)
  for i, step in ipairs(demo_steps) do
    criteria.update_step(i, demo_run, step.name, step.completed, step.cur_value, step.final_value, step.quantity)
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Init
function criteria:init()
  main = addon.get_module("main")
  timer = addon.get_module("timer")
  infos = addon.get_module("infos")
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Enable
function criteria:enable()
  -- register events
  addon.register_event("SCENARIO_CRITERIA_UPDATE", on_scenario_criteria_update)

  -- config listeners
  addon.register_config_listener("best_times", on_config_change)
  addon.register_config_listener("objective_time_inchat", on_config_change)
  addon.register_config_listener("objective_time_perlevel", on_config_change)
  addon.register_config_listener("objective_time", on_config_change)
  addon.register_config_listener("show_absolute_numbers", on_config_change)
end