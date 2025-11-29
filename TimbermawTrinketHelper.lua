--[[
TimbermawTrinketHelper
- Watches pull timers (DBM/BigWigs/etc) via raid warnings / chat
- Schedules logic at 6s and 3s before pull
- If Defender of the Timbermaw was used, swaps to Drake Fang Talisman in the same slot
- Only auto-swaps out of combat; otherwise prints warnings
]]

local ADDON_NAME = ...
local TTH = CreateFrame("Frame", "TimbermawTrinketHelperFrame")

------------------------------------------------------------
-- Config / SavedVariables
------------------------------------------------------------

-- You can change these to item IDs if you want, but names are easy & readable
local DEFENDER_NAME = "Defender of the Timbermaw"
local DRAKE_NAME    = "Drake Fang Talisman"

local TRINKET_SLOT_TOP    = 13
local TRINKET_SLOT_BOTTOM = 14

-- Default config
local defaults = {
    autoSwap   = true,              -- true = auto-equip DFT at 6s/3s out of combat
    useItemRack = false,            -- true = use ItemRack set instead of EquipItemByName
    itemRackSet = "DrakeFang_Prepull", -- ItemRack set name if useItemRack = true
    debug = false,
}

TimberTrinketDB = TimberTrinketDB or {}

local function CopyDefaults(tbl, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(tbl[k]) ~= "table" then
                tbl[k] = {}
            end
            CopyDefaults(tbl[k], v)
        else
            if tbl[k] == nil then
                tbl[k] = v
            end
        end
    end
end

CopyDefaults(TimberTrinketDB, defaults)

------------------------------------------------------------
-- Utility: printing & debugging
------------------------------------------------------------

local function TTH_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96TimbermawTrinkets:|r " .. (msg or ""))
end

local function TTH_Debug(msg)
    if TimberTrinketDB.debug then
        TTH_Print("|cffff8800DEBUG:|r " .. msg)
    end
end

------------------------------------------------------------
-- Pull timer tracking
------------------------------------------------------------

local activePull = false
local pullTime = nil      -- absolute game time (GetTime())
local pullDuration = nil  -- seconds
local pullSource = nil    -- "DBM", "BigWigs", "Chat", etc.

-- We don't cancel C_Timer.After easily, so we guard with this function
local function TTH_ClearPull()
    activePull = false
    pullTime = nil
    pullDuration = nil
    pullSource = nil
    TTH_Debug("Pull cleared")
end

local function TTH_StartPull(duration, source)
    if not duration or duration <= 0 then return end

    local now = GetTime()
    pullDuration = duration
    pullTime = now + duration
    activePull = true
    pullSource = source or "Unknown"

    TTH_Debug(("Detected pull: %ds from %s"):format(duration, pullSource))

    local sixDelay = duration - 6
    local threeDelay = duration - 3

    if sixDelay > 0 then
        C_Timer.After(sixDelay, function()
            if not activePull or not pullTime then return end
            if (pullTime - GetTime()) > 6.5 then
                -- Some other pull reset happened
                return
            end
            TTH_OnSixSeconds()
        end)
    else
        -- Very short timer, just fire immediately
        C_Timer.After(0.1, function()
            if activePull then
                TTH_OnSixSeconds()
            end
        end)
    end

    if threeDelay > 0 then
        C_Timer.After(threeDelay, function()
            if not activePull or not pullTime then return end
            if (pullTime - GetTime()) > 3.5 then
                return
            end
            TTH_OnThreeSeconds()
        end)
    else
        C_Timer.After(0.1, function()
            if activePull then
                TTH_OnThreeSeconds()
            end
        end)
    end
end

------------------------------------------------------------
-- Trinket inspection helpers
------------------------------------------------------------

local function GetItemNameFromSlot(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then return nil end
    local name = GetItemInfo(link)
    return name
end

local function FindDefenderSlot()
    local name13 = GetItemNameFromSlot(TRINKET_SLOT_TOP)
    local name14 = GetItemNameFromSlot(TRINKET_SLOT_BOTTOM)

    if name13 == DEFENDER_NAME then
        return TRINKET_SLOT_TOP
    elseif name14 == DEFENDER_NAME then
        return TRINKET_SLOT_BOTTOM
    end

    return nil
end

local function IsDrakeEquipped()
    local name13 = GetItemNameFromSlot(TRINKET_SLOT_TOP)
    local name14 = GetItemNameFromSlot(TRINKET_SLOT_BOTTOM)

    return name13 == DRAKE_NAME or name14 == DRAKE_NAME
end

-- "Used" == on cooldown. We don't try to check the exact buff name; cooldown is good enough.
local function IsDefenderOnCooldown(slotId)
    if not slotId then return false end
    local start, duration, enabled = GetInventoryItemCooldown("player", slotId)
    if enabled ~= 1 or not start or not duration then
        return false
    end
    if duration <= 1.5 then
        -- GCD-like or no real cooldown
        return false
    end

    local remaining = (start + duration) - GetTime()
    if remaining > 0 then
        return true
    end
    return false
end

------------------------------------------------------------
-- Equip helpers
------------------------------------------------------------

local function EquipDrake(slotId, reason)
    reason = reason or "no reason"
    if not slotId then
        TTH_Debug("EquipDrake called with nil slot")
        return
    end

    if InCombatLockdown() then
        TTH_Print("Already in combat, cannot swap to Drake Fang Talisman.")
        return
    end

    -- ItemRack integration (optional)
    if TimberTrinketDB.useItemRack and ItemRack and ItemRack.EquipSet and TimberTrinketDB.itemRackSet then
        TTH_Debug("Using ItemRack set: " .. TimberTrinketDB.itemRackSet)
        ItemRack.EquipSet(TimberTrinketDB.itemRackSet)
        TTH_Print(("Equipping ItemRack set '%s' (%s)."):format(TimberTrinketDB.itemRackSet, reason))
        return
    end

    -- Direct equip
    TTH_Debug(("EquipItemByName(%s, %d)"):format(DRAKE_NAME, slotId))
    EquipItemByName(DRAKE_NAME, slotId)
    TTH_Print(("Equipping Drake Fang Talisman (%s)."):format(reason))
end

------------------------------------------------------------
-- Timing callbacks: 6s and 3s before pull
------------------------------------------------------------

function TTH_OnSixSeconds()
    if not activePull then return end

    local remaining = pullTime and (pullTime - GetTime()) or 0
    TTH_Debug(("6s callback fired, ~%.1fs remaining"):format(remaining))

    local slot = FindDefenderSlot()
    if not slot then
        TTH_Debug("Defender not equipped at 6s, doing nothing.")
        return
    end

    local used = IsDefenderOnCooldown(slot)

    if used then
        if TimberTrinketDB.autoSwap and not InCombatLockdown() then
            EquipDrake(slot, "Defender was used before pull (6s check)")
        else
            TTH_Print("Defender of the Timbermaw used – press your Drake Fang Talisman macro / ItemRack set now.")
        end
    else
        TTH_Debug("Defender is equipped but not on cooldown at 6s.")
    end
end

function TTH_OnThreeSeconds()
    if not activePull then return end

    local remaining = pullTime and (pullTime - GetTime()) or 0
    TTH_Debug(("3s callback fired, ~%.1fs remaining"):format(remaining))

    if InCombatLockdown() then
        TTH_Print("3s to pull but already in combat – cannot swap trinkets.")
        return
    end

    local slot = FindDefenderSlot()

    if slot then
        if TimberTrinketDB.autoSwap then
            EquipDrake(slot, "Defender still equipped at 3s")
        else
            TTH_Print("3 seconds to pull – Defender of the Timbermaw still equipped, swap to Drake Fang Talisman now.")
        end
    else
        if IsDrakeEquipped() then
            TTH_Debug("3s check: Drake already equipped, all good.")
        else
            TTH_Debug("3s check: neither Defender nor Drake found in trinket slots.")
        end
    end
end

------------------------------------------------------------
-- Pull detection from chat / addons
------------------------------------------------------------

-- Parse something like:
-- "Pull in 10 sec", "Pull in 10 seconds", "Pull in 10"
local function ParsePullSecondsFromMessage(msg)
    if not msg then return nil end

    local s = msg:match("Pull in (%d+)")
    if not s then
        s = msg:match("Pull in (%d+) sec")
    end
    if not s then
        s = msg:match("Pull in (%d+) seconds")
    end

    local secs = tonumber(s)
    if secs and secs >= 3 and secs <= 60 then
        return secs
    end
    return nil
end

-- Handle "pull timer cancelled" style messages
local function MessageCancelsPull(msg)
    if not msg then return false end
    msg = msg:lower()
    if msg:find("pull cancelled") then return true end
    if msg:find("pull timer cancelled") then return true end
    if msg:find("pull aborted") then return true end
    return false
end

local function OnChatEvent(event, msg, author, ...)
    -- Basic raid/party warning text parsing
    local secs = ParsePullSecondsFromMessage(msg)
    if secs then
        TTH_StartPull(secs, "Chat:" .. event)
        return
    end

    if MessageCancelsPull(msg) then
        TTH_ClearPull()
        return
    end
end

-- Optional: some BigWigs addon messages look like "BigWigs" prefix with "Pull 10"
local function OnAddonMessage(prefix, msg, channel, sender)
    -- BigWigs example (this is intentionally conservative)
    if prefix == "BigWigs" and msg then
        local secs = msg:match("Pull (%d+)")
        secs = tonumber(secs)
        if secs and secs >= 3 and secs <= 60 then
            TTH_StartPull(secs, "BigWigs")
            return
        end
        if MessageCancelsPull(msg) then
            TTH_ClearPull()
            return
        end
    end

    -- If you want to wire DBM addon messages, you can expand this function.
    -- Many DBM pulls are already covered via RAID_WARNING chat text.
end

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------

SLASH_TIMBERTRINKET1 = "/timbertrinket"
SLASH_TIMBERTRINKET2 = "/ttmw"

SlashCmdList["TIMBERTRINKET"] = function(msg)
    msg = msg and msg:lower() or ""

    if msg == "auto" then
        TimberTrinketDB.autoSwap = true
        TTH_Print("Auto-swap ENABLED (will equip Drake out of combat).")
    elseif msg == "manual" then
        TimberTrinketDB.autoSwap = false
        TTH_Print("Auto-swap DISABLED (will only print chat alerts).")
    elseif msg:match("^itemrack") then
        local opt = msg:match("^itemrack%s+(%S+)")
        if opt == "on" then
            TimberTrinketDB.useItemRack = true
            TTH_Print("ItemRack integration ENABLED.")
        elseif opt == "off" then
            TimberTrinketDB.useItemRack = false
            TTH_Print("ItemRack integration DISABLED.")
        else
            TTH_Print("Usage: /ttmw itemrack on|off")
        end
    elseif msg:match("^set%s+") then
        local setName = msg:match("^set%s+(.+)")
        if setName and setName ~= "" then
            TimberTrinketDB.itemRackSet = setName
            TTH_Print("ItemRack set name set to: " .. setName)
        else
            TTH_Print("Usage: /ttmw set <ItemRackSetName>")
        end
    elseif msg == "debug on" then
        TimberTrinketDB.debug = true
        TTH_Print("Debug messages ENABLED.")
    elseif msg == "debug off" then
        TimberTrinketDB.debug = false
        TTH_Print("Debug messages DISABLED.")
    else
        TTH_Print("Usage:")
        TTH_Print("/ttmw auto        - auto-swap Drake out of combat (default)")
        TTH_Print("/ttmw manual      - only print chat alerts, no auto-equip")
        TTH_Print("/ttmw itemrack on - use ItemRack set for swaps")
        TTH_Print("/ttmw itemrack off")
        TTH_Print("/ttmw set <name>  - ItemRack set to equip (default: DrakeFang_Prepull)")
        TTH_Print("/ttmw debug on|off")
    end
end

------------------------------------------------------------
-- Event wiring
------------------------------------------------------------

TTH:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            -- Ensure defaults exist
            TimberTrinketDB = TimberTrinketDB or {}
            CopyDefaults(TimberTrinketDB, defaults)
            TTH_Print("Loaded. Watching for pull timers to manage Defender/Drake.")
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Enter combat
        if activePull then
            TTH_Debug("Entered combat while pull active; further swaps will be blocked.")
        end
    elseif event == "CHAT_MSG_RAID_WARNING" or
           event == "CHAT_MSG_RAID" or
           event == "CHAT_MSG_PARTY" or
           event == "CHAT_MSG_PARTY_LEADER" then
        OnChatEvent(event, ...)
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    end
end)

TTH:RegisterEvent("ADDON_LOADED")
TTH:RegisterEvent("PLAYER_REGEN_DISABLED")

-- Pull text usually shows up in warnings/raid/party depending on config
TTH:RegisterEvent("CHAT_MSG_RAID_WARNING")
TTH:RegisterEvent("CHAT_MSG_RAID")
TTH:RegisterEvent("CHAT_MSG_PARTY")
TTH:RegisterEvent("CHAT_MSG_PARTY_LEADER")

-- For BigWigs / others using addon messages
TTH:RegisterEvent("CHAT_MSG_ADDON")

-- Make sure we are registered for addon messages (just in case)
C_ChatInfo.RegisterAddonMessagePrefix("BigWigs")
-- If you later wire DBM specifically, you can do:
-- C_ChatInfo.RegisterAddonMessagePrefix("D4")

