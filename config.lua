local addon_name, addon = ...
local config = addon.new_module("config")

-- ---------------------------------------------------------------------------------------------------------------------
local config_gui
local main

-- ---------------------------------------------------------------------------------------------------------------------
local CONFIG_VALUES = {
  -- options
  objective_time = true,
  objective_time_perlevel = true,
  objective_time_inchat = true,
  show_deathcounter = true,
  progress_tooltip = true,
  show_absolute_numbers = false,
  insert_keystone = true,
  show_affixes_as_text = true,
  show_affixes_as_icons = false,
  hide_default_objectivetracker = true,
  show_reapingtimer = true,
  scale = 1.0,
  --
  position = {
    left = -260,
    top = 220,
    relative_point = "RIGHT"
  }
}

-- ---------------------------------------------------------------------------------------------------------------------
-- Options category
local category

-- ---------------------------------------------------------------------------------------------------------------------
local function on_input_enter(input)
  if not input.tooltip then
    return
  end

  GameTooltip:Hide()
  GameTooltip:ClearLines()
  GameTooltip:SetOwner(input, "ANCHOR_TOPLEFT")

  for _, v in pairs(input.tooltip) do
    GameTooltip:AddLine(v)
  end
  GameTooltip:Show()
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_button_click(button)
  local button_name = button.button_name

  if button_name == "delete_besttimes" then
    addon.set_config_value("best_times", {})
  elseif button_name == "delete_npcprogress" then
    addon.set_config_value("npc_progress", {})
  elseif button_name == "reset_scale" then
    addon.set_config_value("scale", CONFIG_VALUES.scale)
    addon.set_config_value("position", CONFIG_VALUES.position)
    ReloadUI()
  end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- local function export_data()
--   local npc_progress = addon.c("npc_progress")
--   if not npc_progress then
--     return
--   end

--   local frame = CreateFrame("Frame", nil, UIParent)
--   frame:SetPoint("CENTER", 0, 0)
--   frame:SetWidth(300)
--   frame:SetHeight(100)

--   local data = "{"
--   for npc_id, _ in pairs(npc_progress) do
--     local value, occurrences = nil, -1
--     for val, valOccurrences in pairs(npc_progress[npc_id]) do
--       if valOccurrences > occurrences then
--         value, occurrences = val, valOccurrences
--       end
--     end

--     data = data .. "[" .. npc_id .. "]={[" .. value .. "]=1},"
--   end
--   data = data .. "}"

--   local f = CreateFrame("EditBox", "MPTExport", frame, "InputBoxTemplate")
--   f:SetSize(300, 50)
--   f:SetPoint("CENTER", 0, 0)
--   f:SetScript("OnEnterPressed", frame.Hide)
--   f:SetText(data)

--   frame:Show()
-- end

-- ---------------------------------------------------------------------------------------------------------------------
local category_initialized = false
local unlock_checkbox

local function on_category_refresh(self)
  if category_initialized then
    unlock_checkbox.checkbox:SetChecked(main.is_frame_moveable())
    return
  end
  category_initialized = true

  local name = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  name:SetPoint("TOPLEFT", 10, -16)
  name:SetText(addon_name)

  -- checkboxes
  local checkboxes = {
    "objective_time",
    "objective_time_perlevel",
    "objective_time_inchat",
    "show_deathcounter",
    "progress_tooltip",
    "show_absolute_numbers",
    "insert_keystone",
    "show_affixes_as_text",
    "show_affixes_as_icons",
    "hide_default_objectivetracker",
    "show_reapingtimer"
  }

  local checkboxes_frames = {}
  for i, key in ipairs(checkboxes) do
    local config_name = addon.t("config_" .. key)

    local tooltip = {}
    table.insert(tooltip, config_name)
    table.insert(tooltip, "|cFFFFFFFF" .. addon.t("config_desc_" .. key))

    local checkbox =
      config_gui.create_checkbox(
      key,
      config_name,
      addon.c(key),
      function(config_key, checked)
        local current_run = main.get_current_run()
        if current_run and current_run.is_completed then
          main.show_demo()
        end

        addon.set_config_value(config_key, checked)
      end,
      tooltip,
      self
    )
    if i == 1 then
      checkbox:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -10)
    else
      checkbox:SetPoint("TOPLEFT", checkboxes_frames[i - 1], "BOTTOMLEFT", 0, -3)
    end

    checkboxes_frames[i] = checkbox
  end

  -- scale slider
  local slider_tooltip = {}
  table.insert(slider_tooltip, addon.t("config_scale"))
  table.insert(slider_tooltip, "|cFFFFFFFF" .. addon.t("config_desc_scale"))

  local slider =
    config_gui.create_slider(
    addon.t("config_scale"),
    function(val)
      addon.set_config_value("scale", val)
    end,
    0.5,
    3,
    0.1,
    addon.c("scale"),
    slider_tooltip,
    self
  )
  slider:SetPoint("TOPLEFT", checkboxes_frames[#checkboxes_frames], "BOTTOMLEFT", 0, -10)

  -- buttons
  local buttons = {
    "reset_scale"
  }

  local buttons_frames = {}
  for i, key in ipairs(buttons) do
    local button_name = addon.t("config_" .. key)

    local tooltip = {}
    table.insert(tooltip, button_name)
    table.insert(tooltip, "|cFFFFFFFF" .. addon.t("config_desc_" .. key))

    local button = config_gui.create_button(key, button_name, on_button_click, tooltip, self)
    if i == 1 then
      button:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -3)
    else
      button:SetPoint("TOPLEFT", buttons_frames[i - 1], "BOTTOMLEFT", 0, -3)
    end

    button:SetPoint("RIGHT", -10, 0)

    buttons_frames[i] = button
  end

  -- line
  local line = config_gui.create_line(self)
  line:SetPoint("TOPLEFT", buttons_frames[#buttons_frames], "BOTTOMLEFT", 0, -3)

  -- scary buttons
  local scary_buttons = {
    "delete_besttimes",
    "delete_npcprogress"
  }

  local scary_buttons_frames = {}
  for i, key in ipairs(scary_buttons) do
    local button_name = addon.t("config_" .. key)

    local tooltip = {}
    table.insert(tooltip, button_name)
    table.insert(tooltip, "|cFFFFFFFF" .. addon.t("config_desc_" .. key))

    local button = config_gui.create_button(key, button_name, on_button_click, tooltip, self)
    if i == 1 then
      button:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -3)
    else
      button:SetPoint("TOPLEFT", scary_buttons_frames[i - 1], "BOTTOMLEFT", 0, -3)
    end

    button:SetPoint("RIGHT", -10, 0)

    scary_buttons_frames[i] = button
  end

  -- unlock checkbox
  local unlock_name = addon.t("config_unlock_frame")

  local tooltip = {}
  table.insert(tooltip, unlock_name)
  table.insert(tooltip, "|cFFFFFFFF" .. addon.t("config_desc_unlock_frame"))

  unlock_checkbox =
    config_gui.create_checkbox(
    "unlock_frame",
    unlock_name,
    addon.c(key),
    function(config_key, checked)
      main.toggle_frame_movement()
    end,
    tooltip,
    self
  )

  unlock_checkbox:SetPoint("TOPRIGHT", self, "TOPRIGHT", -10, -10)
  unlock_checkbox.checkbox:SetChecked(main.is_frame_moveable())

  -- -- export data button
  -- local export_button = config_gui.create_button("export_data", "Export Data", export_data, nil, self)
  -- export_button:SetPoint("TOPLEFT", scary_buttons_frames[#scary_buttons_frames], "BOTTOMLEFT", 0, -3)
  -- export_button:SetPoint("RIGHT", -10, 0)
end

-- ---------------------------------------------------------------------------------------------------------------------
local function on_category_default()
  MythicPlusTimerDB.config = CONFIG_VALUES
end

-- ---------------------------------------------------------------------------------------------------------------------
local function create_options_category()
  category = CreateFrame("Frame")
  category.name = addon_name
  category.default = on_category_default
  category.refresh = on_category_refresh

  InterfaceOptions_AddCategory(category)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Slash Commands
local function on_slash_command(msg)
  -- toggle
  if msg == "toggle" then
    main.toggle_frame_movement()
    return
  end

  -- config
  if msg == "config" then
    if not category then
      return
    end

    InterfaceOptionsFrame_OpenToCategory(category)
    InterfaceOptionsFrame_OpenToCategory(category)
    return
  end

  -- help
  addon.print("/mpt toggle|cCCCCCCCC: " .. addon.t("lbl_togglecommandtext"))
  addon.print("/mpt config|cCCCCCCCC: " .. addon.t("lbl_configcommandtext"))
end

SLASH_MYTHICPLUSTIMER1 = "/mpt"
SLASH_MYTHICPLUSTIMER2 = "/mythicplustimer"
SlashCmdList["MYTHICPLUSTIMER"] = on_slash_command

-- ---------------------------------------------------------------------------------------------------------------------
function config.update_unlock_checkbox()
  if not unlock_checkbox then
    return
  end

  unlock_checkbox.checkbox:SetChecked(main.is_frame_moveable())
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Init
function config:init()
  config_gui = addon.get_module("config_gui")
  main = addon.get_module("main")

  -- config values
  if MythicPlusTimerDB == nil then
    MythicPlusTimerDB = {}
  end

  if not MythicPlusTimerDB.config then
    MythicPlusTimerDB.config = CONFIG_VALUES
  end

  for key, value in pairs(CONFIG_VALUES) do
    if MythicPlusTimerDB.config[key] == nil then
      -- set default
      MythicPlusTimerDB.config[key] = value

      -- if show_absolute_numbers set default from 2.x values
      if key == "show_absolute_numbers" and MythicPlusTimerDB.config.showAbsoluteNumbers then
        MythicPlusTimerDB.config[key] = MythicPlusTimerDB.config.showAbsoluteNumbers
      end
    end
  end

  -- add data from 2.x
  if MythicPlusTimerDB.config["best_times"] == nil and MythicPlusTimerDB["bestTimes"] ~= nil then
    MythicPlusTimerDB.config["best_times"] = MythicPlusTimerDB["bestTimes"]
    MythicPlusTimerDB["bestTimes"] = nil
  end

  if MythicPlusTimerDB.config["npc_progress"] == nil and MythicPlusTimerDB["npcProgress"] ~= nil then
    MythicPlusTimerDB.config["npc_progress"] = MythicPlusTimerDB["npcProgress"]
    MythicPlusTimerDB["npcProgress"] = nil
  end

  if MythicPlusTimerDB["pos"] ~= nil and MythicPlusTimerDB["pos"].left ~= nil and MythicPlusTimerDB["pos"].top ~= nil and MythicPlusTimerDB["pos"].relativePoint ~= nil then
    MythicPlusTimerDB.config["position"] = {
      left = MythicPlusTimerDB["pos"].left,
      top = MythicPlusTimerDB["pos"].top,
      relative_point = MythicPlusTimerDB["pos"].relativePoint
    }
    MythicPlusTimerDB["pos"] = nil
  end

  -- set default progress values
  if MythicPlusTimerDB.config["npc_progress"] == nil then
    MythicPlusTimerDB.config["npc_progress"] = {[141283] = {[4] = 1}, [138281] = {[6] = 1}, [100216] = {[4] = 1}, [100248] = {[4] = 1}, [141284] = {[4] = 1}, [91785] = {[2] = 1}, [130653] = {[4] = 1}, [96480] = {[1] = 1}, [134514] = {[9] = 1}, [97087] = {[2] = 1}, [97119] = {[1] = 1}, [96640] = {[2] = 1}, [121711] = {[4] = 1}, [137517] = {[4] = 1}, [95842] = {[2] = 1}, [91786] = {[4] = 1}, [119923] = {[4] = 1}, [114334] = {[4] = 1}, [135474] = {[4] = 1}, [139626] = {[1] = 1}, [114526] = {[1] = 1}, [100250] = {[4] = 1}, [98813] = {[4] = 1}, [95779] = {[10] = 1}, [98366] = {[4] = 1}, [95843] = {[5] = 1}, [91787] = {[1] = 1}, [95939] = {[10] = 1}, [133432] = {[5] = 1}, [121553] = {[4] = 1}, [113537] = {[10] = 1}, [137521] = {[4] = 1}, [126919] = {[4] = 1}, [114783] = {[4] = 1}, [105617] = {[4] = 1}, [102583] = {[4] = 1}, [102104] = {[4] = 1}, [115486] = {[8] = 1}, [96611] = {[2] = 1}, [114624] = {[8] = 1}, [99358] = {[4] = 1}, [98368] = {[4] = 1}, [120405] = {[4] = 1}, [102584] = {[4] = 1}, [105682] = {[8] = 1}, [134139] = {[10] = 1}, [104277] = {[4] = 1}, [98177] = {[12] = 1}, [134331] = {[6] = 1}, [127879] = {[4] = 1}, [114625] = {[1] = 1}, [134012] = {[6] = 1}, [99359] = {[3] = 1}, [113699] = {[8] = 1}, [120374] = {[4] = 1}, [91790] = {[4] = 1}, [114338] = {[10] = 1}, [105715] = {[4] = 1}, [104246] = {[4] = 1}, [136249] = {[18] = 1}, [130435] = {[5] = 1}, [118714] = {[4] = 1}, [99360] = {[9] = 1}, [136186] = {[9] = 1}, [128551] = {[4] = 1}, [104247] = {[4] = 1}, [105876] = {[1] = 1}, [98243] = {[4] = 1}, [114627] = {[4] = 1}, [128967] = {[4] = 1}, [134144] = {[13] = 1}, [91792] = {[10] = 1}, [99649] = {[12] = 1}, [135231] = {[8] = 1}, [98691] = {[4] = 1}, [130437] = {[2] = 1}, [114628] = {[4] = 1}, [101438] = {[4] = 1}, [91793] = {[1] = 1}, [134338] = {[9] = 1}, [131847] = {[4] = 1}, [96584] = {[4] = 1}, [98756] = {[4] = 1}, [118717] = {[4] = 1}, [128969] = {[8] = 1}, [135234] = {[3] = 1}, [91794] = {[1] = 1}, [131849] = {[4] = 1}, [98533] = {[10] = 1}, [135235] = {[4] = 1}, [102781] = {[4] = 1}, [141495] = {[1] = 1}, [131850] = {[4] = 1}, [102430] = {[1] = 1}, [134150] = {[18] = 1}, [98406] = {[4] = 1}, [95947] = {[4] = 1}, [105720] = {[4] = 1}, [97097] = {[4] = 1}, [90997] = {[4] = 1}, [136250] = {[4] = 1}, [135365] = {[8] = 1}, [137473] = {[4] = 1}, [118719] = {[4] = 1}, [134024] = {[1] = 1}, [99365] = {[4] = 1}, [130024] = {[1] = 1}, [129599] = {[3] = 1}, [91796] = {[10] = 1}, [114312] = {[314] = 1}, [137474] = {[6] = 1}, [136643] = {[6] = 1}, [118712] = {[4] = 1}, [134600] = {[4] = 1}, [96587] = {[4] = 1}, [90998] = {[4] = 1}, [137516] = {[4] = 1}, [134005] = {[1] = 1}, [98759] = {[4] = 1}, [98280] = {[4] = 1}, [126928] = {[4] = 1}, [99366] = {[4] = 1}, [129547] = {[4] = 1}, [98919] = {[4] = 1}, [114792] = {[4] = 1}, [133835] = {[4] = 1}, [133963] = {[1] = 1}, [137029] = {[5] = 1}, [135049] = {[2] = 1}, [134602] = {[4] = 1}, [116549] = {[4] = 1}, [135241] = {[4] = 1}, [141285] = {[4] = 1}, [98728] = {[7] = 1}, [141565] = {[1] = 1}, [98792] = {[4] = 1}, [98810] = {[6] = 1}, [130027] = {[7] = 1}, [129548] = {[4] = 1}, [130400] = {[6] = 1}, [122969] = {[4] = 1}, [137478] = {[6] = 1}, [137989] = {[1] = 1}, [130404] = {[4] = 1}, [135562] = {[2] = 1}, [97068] = {[5] = 1}, [134157] = {[4] = 1}, [91000] = {[8] = 1}, [98275] = {[4] = 1}, [130661] = {[4] = 1}, [105915] = {[4] = 1}, [114634] = {[4] = 1}, [135052] = {[1] = 1}, [130028] = {[7] = 1}, [134158] = {[6] = 1}, [130635] = {[4] = 1}, [122970] = {[4] = 1}, [139269] = {[4] = 1}, [135245] = {[8] = 1}, [98538] = {[10] = 1}, [99033] = {[4] = 1}, [136139] = {[12] = 1}, [138247] = {[1] = 1}, [91001] = {[4] = 1}, [127106] = {[6] = 1}, [97197] = {[2] = 1}, [131858] = {[4] = 1}, [118723] = {[10] = 1}, [136076] = {[6] = 1}, [122971] = {[4] = 1}, [129550] = {[4] = 1}, [114252] = {[4] = 1}, [98954] = {[4] = 1}, [105629] = {[1] = 1}, [127111] = {[6] = 1}, [134991] = {[6] = 1}, [135240] = {[2] = 1}, [104251] = {[4] = 1}, [140038] = {[3] = 1}, [131670] = {[6] = 1}, [97677] = {[1] = 1}, [118706] = {[2] = 1}, [134417] = {[10] = 1}, [118724] = {[4] = 1}, [102404] = {[4] = 1}, [101414] = {[2] = 1}, [130025] = {[7] = 1}, [127757] = {[4] = 1}, [114796] = {[4] = 1}, [98681] = {[6] = 1}, [134418] = {[9] = 1}, [135167] = {[4] = 1}, [129788] = {[4] = 1}, [138187] = {[4] = 1}, [128434] = {[4] = 1}, [113998] = {[4] = 1}, [97678] = {[8] = 1}, [98732] = {[1] = 1}, [137485] = {[4] = 1}, [134994] = {[1] = 1}, [96608] = {[2] = 1}, [130026] = {[6] = 1}, [134284] = {[4] = 1}, [134739] = {[8] = 1}, [122973] = {[4] = 1}, [97185] = {[10] = 1}, [137486] = {[4] = 1}, [98425] = {[4] = 1}, [102788] = {[4] = 1}, [98733] = {[4] = 1}, [130011] = {[4] = 1}, [127381] = {[3] = 1}, [114542] = {[4] = 1}, [97200] = {[4] = 1}, [137487] = {[4] = 1}, [133463] = {[12] = 1}, [97754] = {[1] = 1}, [135699] = {[7] = 1}, [138254] = {[1] = 1}, [101991] = {[4] = 1}, [131445] = {[9] = 1}, [102566] = {[12] = 1}, [134251] = {[4] = 1}, [130909] = {[4] = 1}, [121569] = {[4] = 1}, [134990] = {[4] = 1}, [138255] = {[4] = 1}, [137969] = {[6] = 1}, [98776] = {[8] = 1}, [134423] = {[1] = 1}, [133912] = {[6] = 1}, [102375] = {[3] = 1}, [131677] = {[6] = 1}, [133593] = {[5] = 1}, [115757] = {[8] = 1}, [135254] = {[4] = 1}, [119930] = {[4] = 1}, [116550] = {[4] = 1}, [135239] = {[4] = 1}, [133836] = {[4] = 1}, [134041] = {[4] = 1}, [134616] = {[2] = 1}, [114633] = {[4] = 1}, [91006] = {[4] = 1}, [114544] = {[4] = 1}, [135192] = {[4] = 1}, [105921] = {[4] = 1}, [136214] = {[18] = 1}, [100364] = {[4] = 1}, [134617] = {[1] = 1}, [132126] = {[4] = 1}, [95861] = {[4] = 1}, [138465] = {[4] = 1}, [144071] = {[4] = 1}, [136470] = {[4] = 1}, [137484] = {[6] = 1}, [97043] = {[4] = 1}, [98926] = {[4] = 1}, [134137] = {[9] = 1}, [127799] = {[4] = 1}, [97171] = {[10] = 1}, [133852] = {[4] = 1}, [102232] = {[4] = 1}, [105636] = {[4] = 1}, [95766] = {[4] = 1}, [127480] = {[1] = 1}, [133482] = {[1] = 1}, [135258] = {[1] = 1}, [114801] = {[4] = 1}, [134364] = {[4] = 1}, [129366] = {[4] = 1}, [105699] = {[3] = 1}, [120550] = {[4] = 1}, [106785] = {[1] = 1}, [134173] = {[1] = 1}, [91008] = {[4] = 1}, [97172] = {[1] = 1}, [100531] = {[8] = 1}, [134174] = {[5] = 1}, [92350] = {[4] = 1}, [97173] = {[4] = 1}, [136665] = {[7] = 1}, [133663] = {[4] = 1}, [133345] = {[5] = 1}, [114802] = {[4] = 1}, [100526] = {[4] = 1}, [129526] = {[4] = 1}, [97365] = {[4] = 1}, [131492] = {[4] = 1}, [106786] = {[1] = 1}, [134686] = {[4] = 1}, [104295] = {[1] = 1}, [98706] = {[6] = 1}, [131812] = {[6] = 1}, [98770] = {[4] = 1}, [96247] = {[1] = 1}, [102351] = {[1] = 1}, [127482] = {[4] = 1}, [95832] = {[2] = 1}, [131685] = {[4] = 1}, [114803] = {[4] = 1}, [101549] = {[1] = 1}, [119977] = {[4] = 1}, [129601] = {[4] = 1}, [129370] = {[4] = 1}, [106787] = {[1] = 1}, [100527] = {[3] = 1}, [135263] = {[4] = 1}, [129367] = {[4] = 1}, [131112] = {[6] = 1}, [118700] = {[2] = 1}, [130485] = {[4] = 1}, [95769] = {[4] = 1}, [129527] = {[4] = 1}, [139799] = {[9] = 1}, [98963] = {[1] = 1}, [114804] = {[4] = 1}, [114636] = {[4] = 1}, [119978] = {[1] = 1}, [129559] = {[4] = 1}, [135971] = {[12] = 1}, [131819] = {[4] = 1}, [139800] = {[9] = 1}, [102253] = {[4] = 1}, [96664] = {[2] = 1}, [135329] = {[8] = 1}, [98370] = {[4] = 1}, [126918] = {[4] = 1}, [127485] = {[3] = 1}, [95834] = {[2] = 1}, [98900] = {[4] = 1}, [114626] = {[4] = 1}, [100529] = {[1] = 1}, [102094] = {[4] = 1}, [105703] = {[1] = 1}, [98677] = {[1] = 1}, [101679] = {[4] = 1}, [129369] = {[8] = 1}, [99188] = {[4] = 1}, [136353] = {[10] = 1}, [131818] = {[4] = 1}, [101839] = {[4] = 1}, [129529] = {[4] = 1}, [95771] = {[4] = 1}, [134629] = {[6] = 1}, [135204] = {[4] = 1}, [96657] = {[12] = 1}, [134599] = {[4] = 1}, [91332] = {[4] = 1}, [102095] = {[4] = 1}, [131436] = {[6] = 1}, [122972] = {[4] = 1}, [97081] = {[5] = 1}, [104278] = {[10] = 1}, [118690] = {[4] = 1}, [102287] = {[10] = 1}, [92610] = {[4] = 1}, [118703] = {[4] = 1}, [130488] = {[4] = 1}, [95772] = {[4] = 1}, [127486] = {[7] = 1}, [115765] = {[4] = 1}, [99956] = {[4] = 1}, [139422] = {[6] = 1}, [138464] = {[4] = 1}, [136347] = {[1] = 1}, [105705] = {[4] = 1}, [120556] = {[4] = 1}, [135706] = {[3] = 1}, [118716] = {[4] = 1}, [104300] = {[4] = 1}, [135846] = {[2] = 1}, [114584] = {[1] = 1}, [118704] = {[10] = 1}, [105952] = {[6] = 1}, [130521] = {[1] = 1}, [105651] = {[10] = 1}, [141851] = {[1] = 1}, [91781] = {[4] = 1}, [122984] = {[6] = 1}, [134232] = {[4] = 1}, [138019] = {[4] = 1}, [105706] = {[10] = 1}, [114541] = {[1] = 1}, [97083] = {[5] = 1}, [115488] = {[4] = 1}, [136295] = {[13] = 1}, [139425] = {[4] = 1}, [136934] = {[4] = 1}, [118705] = {[10] = 1}, [128435] = {[1] = 1}, [130522] = {[2] = 1}, [127488] = {[7] = 1}, [120366] = {[4] = 1}, [91782] = {[10] = 1}, [115831] = {[4] = 1}, [100539] = {[4] = 1}, [137830] = {[4] = 1}, [127497] = {[9] = 1}, [114637] = {[4] = 1}, [97084] = {[5] = 1}, [104270] = {[8] = 1}, [136297] = {[9] = 1}, [97182] = {[6] = 1}, [133870] = {[4] = 1}, [137511] = {[4] = 1}, [131666] = {[4] = 1}, [130012] = {[4] = 1}, [131669] = {[1] = 1}, [106059] = {[4] = 1}, [91783] = {[4] = 1}, [133685] = {[4] = 1}, [119952] = {[4] = 1}, [133935] = {[5] = 1}, [115417] = {[8] = 1}, [131586] = {[4] = 1}, [96574] = {[5] = 1}, [131585] = {[4] = 1}, [129600] = {[3] = 1}, [130436] = {[1] = 1}, [141566] = {[1] = 1}, [133430] = {[8] = 1}, [139110] = {[11] = 1}, [135366] = {[6] = 1}, [141282] = {[1] = 1}, [129602] = {[6] = 1}, [118713] = {[4] = 1}, [133436] = {[5] = 1}, [131587] = {[5] = 1}, [114364] = {[1] = 1}, [131402] = {[1] = 1}, [129699] = {[4] = 1}, [139946] = {[6] = 1}}
  end

  -- set config
  addon.set_config(MythicPlusTimerDB.config)

  -- options category
  create_options_category()
end
