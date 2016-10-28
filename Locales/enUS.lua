local L = LibStub("AceLocale-3.0"):NewLocale("MythicPlusTimer", "enUS", true)
if L == nil then
    return
end

L["ToggleCommandText"] = "Lock/Unlock timer frame"
L["Loot"] = "Loot"
L["NoLoot"] = "No Loot"
L["Best"] = "best"
L["ObjectiveTimes"] = "Show Objective Times"
L["ObjectiveTimesDesc"] = "Shows the completion time and your best time per objective."
L["DeleteBestTimes"] = "Delete best times"
L["DeleteBestTimesRecords"] = "Deletes the best times records."
L["DeathCounter"] = "Death Counter (Limitation: Does not count a death if it is too far away)"
L["DeathCounterDesc"] = "Shows a death counter and the time lost caused by player deaths. (5s per death)"
L["Deaths"] = "Deaths"
L["Completed"] = "completed"
L["Time"] = "Time"
L["BestTime"] = "Best"
L["ObjectiveTimesInChat"] = "Show Completion Times in chat"
L["ObjectiveTimesInChatDesc"] = "Shows the completion times as a chat message."
L["TimeLeft"] = "Time left"
L["ObjectiveTimePerLevel"] = "Completion time per level"
L["ObjectiveTimePerLevelDesc"] = "Shows the completion times per level and not for the full dungeon."
L["ProgressTooltip"] = "Show progress percent in tooltip (Database builds itself by killing the mobs inside the dungeon)"
L["ProgressTooltipDesc"] = "Shows the progress toolbar of the mob in his tooltip."
L["DeleteNPCProgress"] = "Delete progress percent database"
L["DeleteNPCProgressDesc"] = "Clears the progress percent database."
