local _, addon = ...
local timer = addon.new_module("timer")

-- ---------------------------------------------------------------------------------------------------------------------
local main
local criteria
local infos

-- ---------------------------------------------------------------------------------------------------------------------
local timer_frames = {}

-- ---------------------------------------------------------------------------------------------------------------------
local function on_frame_mousedown()
  -- only end on SHIFT + Click
  if not IsModifiedClick("CHATLINK") then
    return
  end

  -- skip if not in cm
  if not main.is_in_cm() then
    return
  end

  -- resolve text
  local current_run = main.get_current_run()
  local time_text = addon.t("lbl_timeleft") .. ": " .. main.format_seconds(current_run.time_left) .. " || +2: " .. main.format_seconds(current_run.time_left_2) .. " || +3: " .. main.format_seconds(current_run.time_left_3)

  -- send message
  local channel = "PARTY"
  if GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE) > 0 then
    channel = "INSTANCE_CHAT"
  end

  SendChatMessage(time_text, channel)
end

-- ---------------------------------------------------------------------------------------------------------------------
local function create_timer_frames()
  if timer_frames.time_left then
    return
  end

  local main_frame = main.get_frame()

  -- time left
  local time_left_frame = CreateFrame("Frame", nil, main_frame)
  time_left_frame:ClearAllPoints()
  time_left_frame:SetScript("OnMouseDown", on_frame_mousedown)

  time_left_frame.text = time_left_frame:CreateFontString(nil, "OVERLAY", "GameFontGreenLarge")
  time_left_frame.text:SetPoint("TOPLEFT")

  timer_frames.time_left = time_left_frame

  -- time in cm
  local time_in_cm_frame = CreateFrame("Frame", nil, main_frame)
  time_in_cm_frame:ClearAllPoints()
  time_in_cm_frame:SetPoint("BOTTOMLEFT", time_left_frame, "BOTTOMRIGHT", 5, 1)
  time_in_cm_frame:SetScript("OnMouseDown", on_frame_mousedown)

  time_in_cm_frame.text = time_in_cm_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  time_in_cm_frame.text:SetPoint("TOPLEFT")

  timer_frames.time_in_cm = time_in_cm_frame

  -- +2 label
  local label_2_frame = CreateFrame("Frame", nil, main_frame)
  label_2_frame:ClearAllPoints()
  label_2_frame:SetPoint("TOPLEFT", time_left_frame, "BOTTOMLEFT", 0, -5)
  label_2_frame:SetScript("OnMouseDown", on_frame_mousedown)

  label_2_frame.text = label_2_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label_2_frame.text:SetPoint("TOPLEFT")

  timer_frames.label_2 = label_2_frame

  -- +2 timer
  local time_2_frame = CreateFrame("Frame", nil, main_frame)
  time_2_frame:ClearAllPoints()
  time_2_frame:SetPoint("BOTTOMLEFT", label_2_frame, "BOTTOMRIGHT", 5, 0)
  time_2_frame:SetScript("OnMouseDown", on_frame_mousedown)

  time_2_frame.text = time_2_frame:CreateFontString(nil, "OVERLAY", "GameFontGreen")
  time_2_frame.text:SetPoint("TOPLEFT")

  timer_frames.time_2 = time_2_frame

  -- +3 label
  local label_3_frame = CreateFrame("Frame", nil, main_frame)
  label_3_frame:ClearAllPoints()
  label_3_frame:SetPoint("TOPLEFT", label_2_frame, "BOTTOMLEFT", 0, -5)
  label_3_frame:SetScript("OnMouseDown", on_frame_mousedown)

  label_3_frame.text = label_3_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label_3_frame.text:SetPoint("TOPLEFT")

  timer_frames.label_3 = label_3_frame

  -- +3 timer
  local time_3_frame = CreateFrame("Frame", nil, main_frame)
  time_3_frame:ClearAllPoints()
  time_3_frame:SetPoint("BOTTOMLEFT", label_3_frame, "BOTTOMRIGHT", 5, 0)
  time_3_frame:SetScript("OnMouseDown", on_frame_mousedown)

  time_3_frame.text = time_3_frame:CreateFontString(nil, "OVERLAY", "GameFontGreen")
  time_3_frame.text:SetPoint("TOPLEFT")

  timer_frames.time_3 = time_3_frame
end

-- ---------------------------------------------------------------------------------------------------------------------
local function update_frame_points()
  local info_frames = main.get_info_frames()
  local time_left_frame = timer_frames.time_left

  -- time left
  local time_left_frame_ref = info_frames.affixes_icons
  if not addon.c("show_affixes_as_icons") then
    time_left_frame_ref = info_frames.affixes_text
  end

  if not addon.c("show_affixes_as_text") and not addon.c("show_affixes_as_icons") then
    time_left_frame_ref = info_frames.dungeon
  end

  if not time_left_frame.ref_frame or time_left_frame.ref_frame ~= time_left_frame_ref then
    time_left_frame:SetPoint("TOPLEFT", time_left_frame_ref, "BOTTOMLEFT", 0, -10)
    time_left_frame.ref_frame = time_left_frame_ref
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_update_time(_, elapsed_time)
  -- hide default tracker (on every time update because we can only hide it out of combat)
  if main then
    main.hide_default_tracker()
  end

  -- skip until next second
  if timer.elapsed_time == elapsed_time then
    return
  end

  timer.elapsed_time = elapsed_time

  -- check if timer is started
  if not timer.started then
    return
  end

  -- create frames (they are also created on cm start)
  create_timer_frames()
  update_frame_points()

  -- setup
  local current_run = main.get_current_run()
  if not current_run then
    return
  end

  local time_left_frame = timer_frames.time_left
  local time_in_cm_frame = timer_frames.time_in_cm

  current_run.elapsed_time = elapsed_time

  -- time left
  local time_left = current_run.max_time - elapsed_time
  if time_left < 0 then
    time_left = 0
  end

  current_run.time_left = time_left

  -- time left - font
  local font = "GameFontGreenLarge"
  if time_left == 0 then
    font = "GameFontRedLarge"
  end

  if not time_left_frame.text.current_font or time_left_frame.text.current_font ~= font then
    time_left_frame.text:SetFontObject(font)
    time_left_frame.text.current_font = font
  end

  -- time left - text
  local time_left_text = main.format_seconds(time_left)
  local current_time_left_text = time_left_frame.text:GetText()

  time_left_frame.text:SetText(time_left_text)

  if not current_time_left_text or not time_left_text or string.len(time_left_text) ~= string.len(current_time_left_text) then
    local current_width = time_left_frame.text:GetStringWidth() + 2
    if not time_left_frame.width or current_width > time_left_frame.width then
      time_left_frame.width = current_width
    end

    time_left_frame:SetHeight(time_left_frame.text:GetStringHeight())
    time_left_frame:SetWidth(time_left_frame.width)
  end

  -- time in cm
  local time_in_cm_text = "(" .. main.format_seconds(elapsed_time) .. " / " .. main.format_seconds(current_run.max_time) .. ")"
  local current_time_in_cm_text = time_in_cm_frame.text:GetText()

  time_in_cm_frame.text:SetText(time_in_cm_text)

  if not time_in_cm_text or not current_time_in_cm_text or string.len(time_in_cm_text) ~= string.len(current_time_in_cm_text) then
    time_in_cm_frame:SetHeight(time_in_cm_frame.text:GetStringHeight())
    time_in_cm_frame:SetWidth(time_in_cm_frame.text:GetStringWidth())
  end

  -- chest timer
  local two_chest_time = current_run.max_time * 0.8
  local time_left_2 = two_chest_time - elapsed_time
  if time_left_2 < 0 then
    time_left_2 = 0
  end

  current_run.time_left_2 = time_left_2

  local three_chest_time = current_run.max_time * 0.6
  local time_left_3 = three_chest_time - elapsed_time
  if time_left_3 < 0 then
    time_left_3 = 0
  end

  current_run.time_left_3 = time_left_3

  -- +2
  local label_2_frame = timer_frames.label_2
  local time_2_frame = timer_frames.time_2

  local current_label_2_text = label_2_frame.text:GetText()
  local current_time_2_text = time_2_frame.text:GetText()
  local label_2_text = "+2 (" .. main.format_seconds(two_chest_time) .. ")"
  local time_2_text = ""
  local update_time_2_frame_pos = false

  if time_left_2 == 0 then
    if not label_2_frame.text.currentFont or label_2_frame.text.currentFont ~= "GameFontDisable" then
      label_2_frame.text:SetFontObject("GameFontDisable")
      label_2_frame.text.currentFont = "GameFontDisable"
    end

    -- hide time 2 frame
    time_2_frame:Hide()
  else
    label_2_text = label_2_text .. ":"

    if not label_2_frame.text.currentFont or label_2_frame.text.currentFont ~= "GameFontHighlight" then
      label_2_frame.text:SetFontObject("GameFontHighlight")
      label_2_frame.text.currentFont = "GameFontHighlight"
    end

    -- update time 2 info
    time_2_text = main.format_seconds(time_left_2)
    time_2_frame.text:SetText(time_2_text)
    time_2_frame:Show()
    update_time_2_frame_pos = true
  end

  label_2_frame.text:SetText(label_2_text)

  -- +2 update frames
  if not label_2_text or not current_label_2_text or string.len(label_2_text) ~= string.len(current_label_2_text) then
    label_2_frame:SetHeight(label_2_frame.text:GetStringHeight())
    label_2_frame:SetWidth(label_2_frame.text:GetStringWidth())
  end

  if update_time_2_frame_pos and (not time_2_text or not current_time_2_text or string.len(time_2_text) ~= string.len(current_time_2_text)) then
    time_2_frame:SetHeight(time_2_frame.text:GetStringHeight())
    time_2_frame:SetWidth(time_2_frame.text:GetStringWidth())
  end

  -- +3
  local label_3_frame = timer_frames.label_3
  local time_3_frame = timer_frames.time_3

  local current_label_3_text = label_3_frame.text:GetText()
  local current_time_3_text = time_3_frame.text:GetText()
  local label_3_text = "+3 (" .. main.format_seconds(three_chest_time) .. ")"
  local time_3_text = ""
  local update_time_3_frame_pos = false

  if time_left_3 == 0 then
    if not label_3_frame.text.currentFont or label_3_frame.text.currentFont ~= "GameFontDisable" then
      label_3_frame.text:SetFontObject("GameFontDisable")
      label_3_frame.text.currentFont = "GameFontDisable"
    end

    -- hide time 3 frame
    time_3_frame:Hide()
  else
    label_3_text = label_3_text .. ":"

    if not label_3_frame.text.currentFont or label_3_frame.text.currentFont ~= "GameFontHighlight" then
      label_3_frame.text:SetFontObject("GameFontHighlight")
      label_3_frame.text.currentFont = "GameFontHighlight"
    end

    -- update time 3 info
    time_3_text = main.format_seconds(time_left_3)
    time_3_frame.text:SetText(time_3_text)
    time_3_frame:Show()
    update_time_3_frame_pos = true
  end

  label_3_frame.text:SetText(label_3_text)

  -- +3 update frames
  if not label_3_text or not current_label_3_text or string.len(label_3_text) ~= string.len(current_label_3_text) then
    label_3_frame:SetHeight(label_3_frame.text:GetStringHeight())
    label_3_frame:SetWidth(label_3_frame.text:GetStringWidth())
  end

  if update_time_3_frame_pos and (not time_3_text or not current_time_3_text or string.len(time_3_text) ~= string.len(current_time_3_text)) then
    time_3_frame:SetHeight(time_3_frame.text:GetStringHeight())
    time_3_frame:SetWidth(time_3_frame.text:GetStringWidth())
  end

  -- update criteria
  criteria.update()

  -- update infos
  infos.update_deathcounter()
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_challenge_mode_completed()
  timer.started = false
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_challenge_mode_reset()
  timer.started = false
end

-- ---------------------------------------------------------------------------------------------------------------------
function timer.on_challenge_mode_start()
  create_timer_frames()

  timer.elapsed_time = -1
  timer.started = true

  -- set times to 0 on start
  on_update_time(nil, 0)
end

-- ---------------------------------------------------------------------------------------------------------------------
function timer.on_player_entering_world()
  -- check if in cm
  if main.is_in_cm() then
    timer.elapsed_time = -1
    timer.started = true
    return
  end

  -- stop timer
  timer.started = false
end

-- ---------------------------------------------------------------------------------------------------------------------
function timer.update_time(elapsed_time)
  on_update_time(nil, elapsed_time)
end

-- ---------------------------------------------------------------------------------------------------------------------
function timer.get_label_3_frame()
  return timer_frames.label_3
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Init
function timer:init()
  main = addon.get_module("main")
  criteria = addon.get_module("criteria")
  infos = addon.get_module("infos")
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Enable
function timer:enable()
  -- register events
  addon.register_event("CHALLENGE_MODE_COMPLETED", on_challenge_mode_completed)
  addon.register_event("CHALLENGE_MODE_RESET", on_challenge_mode_reset)

  -- start if in cm
  if main.is_in_cm() then
    timer.on_challenge_mode_start()
  end
end

hooksecurefunc("Scenario_ChallengeMode_UpdateTime", on_update_time)