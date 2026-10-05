-- LORT Endless: an endless survival mode.
--   At the camp's quest board there is an extra entry, "Endless Mode", under the quest list. Click it (click
--   it again to un-choose), then Select as usual: the next mission is played as endless mode on the map of the quest that is highlighted.
--   Waves of the game's own enemies spawn around the players and grow with every wave; every fifth wave
--   brings a boss.
--   Every few kills there is a reward: an attribute (Strength, Agility or Intelligence) and one of three
--   random power-ups, chosen in the game's own menus. Alone, the game pauses and the menus open straight
--   away. With other players, power crystals shatter next to the players when the wave is cleared and
--   every player gets their own pickups to absorb.
--   The day keeps cycling, but each time a new day begins the day counter is put back, so the final day (and
--   the forced move to the next map) never arrives.
-- Co-op: everything is run by the host's game, so only the host needs the mod. The other players get the
-- enemies, the choice menus and the wave announcements (as chat lines); the wave dial and the quest panel
-- are only changed on the host's screen.

local UEHelpers = require("UEHelpers")

local PREFIX = "[LORT Endless] "
-- Relative to the game's Binaries/Win64 folder, which is where the game runs from.
local BEST_PATH = "ue4ss/Mods/LORT_Endless/best_wave.txt"
local STEP_PATH = "ue4ss/Mods/LORT_Endless/last_step.txt"

local TICK_MS = 500
local KILLS_PER_REWARD = 15
local BOSS_EVERY = 5
-- Enemies in wave N: WAVE_BASE + WAVE_GROWTH * N, arriving a few at a time while fewer than MAX_ALIVE of them
-- are about.
local WAVE_BASE = 6
local WAVE_GROWTH = 3
local SPAWN_BATCH = 5
local SPAWN_EVERY_TICKS = 4
local MAX_ALIVE = 30
-- A wave is over when all of it has arrived and this few of its enemies are left, or after the time limit.
-- Enemies the game put in the level itself do not hold a wave up.
local WAVE_LEFTOVERS = 1
local WAVE_TIME_LIMIT_TICKS = 360
local WAVE_BREAK_TICKS = 8
-- Each wave after the first multiplies the health of the wave's enemies by this.
local HEALTH_GROWTH = 1.12
-- Each wave after the first also adds this much to the enemies' BaseDamage attribute. Measured 2026-10-05:
-- a Goblin Fighter hits for 11 at 0 and for 19 at 40, so about a fifth of it arrives per hit.
local DAMAGE_PER_WAVE = 6.0
local COMBAT_ATTRIBUTES_PATH = "/Script/Angelscript.BWCombatAttributes"
-- A boss asked for outside its arena arrives with almost no health (the Ranger boss: 90, a plain goblin has
-- 56). It is given this much on the first boss wave, growing like everything else from there and with the
-- number of players, and twice the damage bonus.
local BOSS_HEALTH = 2500.0
local BOSS_DAMAGE_FACTOR = 2.0
-- Boss waves bring one boss up to this wave; one more from the boss wave after it, and again every
-- BOSS_COUNT_STEP waves, up to MAX_BOSSES.
local SINGLE_BOSS_UNTIL = 15
local BOSS_COUNT_STEP = 15
local MAX_BOSSES = 3
-- Each boss killed gives the host a random weapon this far above the level of the run's items: one level
-- for every WEAPON_WAVES_PER_LEVEL waves. (The game's own drops stay at the map's level.)
local WEAPON_WAVES_PER_LEVEL = 2
local WEAPONS = { "Weapon_Crossbow", "Weapon_Broadsword", "Weapon_Sledgehammer", "Weapon_Spinhammer", "Weapon_ArcaneStaff",
    "Weapon_LightningWand", "Weapon_MagicSword", "Weapon_Swiftbow", "Weapon_Strongbow", "Weapon_Blinkblades", "Weapon_Pistol",
    "Weapon_ClubShield", "Weapon_AssaultRifle", "Weapon_BaseballBat", "Weapon_SwordShield", "Weapon_Monsterhammer",
    "Weapon_Katana", "Weapon_ThrowingDaggers", "Weapon_HolyClaymore", "Weapon_VoidCrossbow", "Weapon_VoidWand",
    "Weapon_VoidStaff" }
local BANNER_TICKS = 6
-- The game's spawn function drops enemies at the player's feet; each is moved to a walkable spot at least
-- SPAWN_MIN_DISTANCE and at most SPAWN_MAX_DISTANCE away (cm).
local SPAWN_MIN_DISTANCE = 1200.0
local SPAWN_MAX_DISTANCE = 2600.0
local SPAWN_PLACE_TRIES = 8
local SPAWN_LIFT = 100.0
local HEALTH_ATTRIBUTES_PATH = "/Script/Angelscript.BWHealthAttributes"
-- A wave's enemy is taken for one of this mod's only if it first shows up this close to a player (cm); the
-- game's spawn function puts them somewhere around the host. When a wave has made no progress for STRAGGLER_TICKS, its
-- enemies farther away than STRAGGLER_DISTANCE are brought back near a player; when that has not helped
-- by the next time, they are let go and the wave moves on without them.
local OWN_SPAWN_DISTANCE = 4000.0
-- An enemy that was asked for is waited for this many ticks (the game spawns them a little later).
local AWAIT_TICKS = 6
-- The game's spawn function puts enemies where the host's camera is looking, and does nothing when that is
-- the sky. After this many requests in a row with no arrivals the quest panel says so.
local MISSES_BEFORE_HINT = 2
-- An enemy that disappears this close to a player (cm) counts as killed.
local VANISH_KILL_DISTANCE = 5000.0
-- Co-op. Each extra player adds this share to the size of a wave and to the kills a reward takes.
local COOP_WAVE_FACTOR = 0.6
-- With other players the mod sends no menus and touches no guest (three sessions on 2026-10-05 ended with
-- the host's game dying on exactly that). Rewards come from the game's own power crystals instead: the mod
-- spawns one and opens it the way a cleared camp does, and the game drops each player's pickups itself.
-- An attribute crystal drops three attribute pickups per player; all but one per player and reward are
-- removed again. A power-up crystal drops one power-up pickup per player.
local ATTRIBUTE_CRYSTAL = "/Game/Gameplay/Objects/UpgradeCrystals/BP_UpgradeCrystal_Attribute_All"
local POWERUP_CRYSTAL = "/Game/Gameplay/Objects/UpgradeCrystals/BP_UpgradeCrystal_CampPowerup_Common"
local ATTRIBUTE_PICKUP_CLASS = "BP_UpgradeShard_All_C"
-- How far from the player the crystals appear (cm), how long after that the spare pickups are looked for
-- (ticks, and for how many ticks at most), and how long the break before the next wave is.
local CRYSTAL_DISTANCE = 380.0
local TRIM_AFTER_TICKS = 4
local TRIM_GIVE_UP_TICKS = 20
local COOP_REWARD_BREAK_TICKS = 40
local PLAYER_ATTRIBUTES_PATH = "/Script/Angelscript.BWPlayerAttributes"
local STRAGGLER_TICKS = 16
local STRAGGLER_DISTANCE = 1500.0
-- If a choice menu is still up after this many ticks, the game is unpaused regardless.
local MENU_TIME_LIMIT_TICKS = 600

-- ESlateVisibility
local VIS_COLLAPSED = 1
local VIS_SELF_HIT_TEST_INVISIBLE = 4

-- Enemy names from the game's NPC table, grouped by the wave from which they may appear.
local ENEMY_TIERS = {
    { from = 1, names = { "GoblinPeasant", "Goblin", "Slime", "GoblinFighter", "GoblinArcher" } },
    { from = 3, names = { "GoblinBrawler", "GoblinLobber", "GoblinTrapper", "GoblinMage", "GoblinThief", "SlimeFire",
        "SlimeForest", "GoblinBomber" } },
    { from = 6, names = { "GoblinWarrior", "GoblinShield", "GoblinWizard", "GoblinArbalest", "GoblinPoacher",
        "GoblinSlimecaller", "GoblinDefender", "GoblinMedic", "GoblinRifleman", "SlimeViking" } },
    { from = 10, names = { "GoblinWarchief", "GoblinSharpshooter", "GoblinSmusher", "GoblinSlimemancer", "GoblinSniper",
        "GoblinChampion", "TrollSapper" } },
}
local BOSSES = { "Boss_Ranger", "Boss_Stomper", "boss_forestsoul", "Boss_Necromancer" }
-- Rows of the game's power-up table (each with "powerup_" in front) that a power-up choice is drawn from.
local POWERUPS = {
    "attackspeed", "damageboost", "increasedhealth", "increasedmovementspeed", "jumpheight", "thorns", "bulwark",
    "critchance", "parrychance", "armor", "magicresist", "cooldownrate", "healingreceived", "damage_stunned",
    "lifesteal", "healonkill", "extraskillcharge", "healoncrit", "maxhealthonkill", "burningonhit", "stunonhit",
    "slowonhit", "healthregen", "knockback", "critdamage", "spawngoldonhit", "block", "increasedamagelowhealth",
    "bigdamage", "increasedamageclose", "healcharge", "increasedsprintspeed", "spawngoldoncrit",
    "spawngoldondmgreceived", "bonustohighhpenemies", "bonusdmgtoboss", "secondchance", "bonusdmgtofactiongoblin",
    "bonusdmgtofactionskeleton", "bonusdmgtofactionslime", "increasedrunandsprint", "clapback", "critchancecritdmg",
    "magicdamageboost", "physicaldamageboost", "bleedonhit", "maxphysresistonhurt", "increasedmgonkill",
    "increaseatkspeedonkill", "electricityonhit", "buffchanceonhitatkspeed", "buffchanceonhitmovementspeed",
    "bonusdmgduringnight", "bonusdmgduringday", "damageonkillexplosion", "healonkillaoe", "slowonhurt",
    "buffchanceonabilityhitcritdamage", "buffchanceonabilityhitparry", "damageonhitaoe",
    "cursedcritchancecritdamage", "increasestatusduration", "pinball", "pingpongslow", "pingpongfire",
    "spawnpickuponkillhealth", "spawnpickuponkillmovespeed", "spawnpickuponkillcrit", "lightningstrike",
    "bigcritdamage", "bigcooldownrate", "explodeonhit", "sunder", "bigtank", "aura_pulsedamage", "aura_tickdamage",
    "aura_armorbuff", "aura_movespeedliferegen", "aura_lifesteal", "bonusdmgtobeards", "bonusdmgtowearinghats",
    "bonusdmgtocasters", "bonusdmgtofighters", "bigcritchance", "bonustohighhpenemiesbig", "hybriddamageboost",
    "increasedhealthmedium", "increasedhealthbig", "buffchanceonhitmagicalphysical", "healthregencurse",
    "increasedamageability", "increasedamageovertime", "damageonkillburning", "dodgecharge", "magicalsunder",
    "poisononhit", "buffonability_movementspeed", "mediumdamageproc", "aoedamageoncrit", "spawnmineonability",
    "lilcritdamage", "lilcooldownrate",
}

local active = false
local status_note = ""
local wave = 0
local wave_to_spawn = 0
local wave_ticks = 0
local break_ticks = 0
-- Bosses of the current wave still to arrive.
local boss_pending = 0
-- The highest item level the run had when the mode started.
local base_item_level = 1
local kills = 0
local kills_since_reward = 0
-- Choice menus still to be shown ("attribute" or "powerup"), whether one is up now, and for how many ticks.
local menu_queue = {}
local menu_showing = false
local menu_ticks = 0
local last_progress_tick = 0
local last_own_alive = 0
-- Whether the wave's stragglers have been brought back once since the last kill.
local recalled = false
local best_wave = 0
local hold_day = nil
local day_actor_address = nil
local last_world_time = nil
local was_paused = false
local banner_ticks = 0
local note_ticks = 0
-- Every enemy in the level by address: whether it was alive at the last look, whether it belongs to a wave
-- of this mod, whether it is a boss, and where it was last seen.
local tracked = {}
-- Enemies this mod has asked for that have not been seen (and moved away from the player) yet; each entry
-- says whether it is a boss.
local awaited = {}
-- Ticks the mode has run.
local mode_ticks = 0
-- Co-op: rewards earned and not yet dropped (each the number of power-up crystals), and the trimming of
-- spare attribute pickups that is still to do: { at = tick, until_tick = tick, keep = n, before = {addresses} }.
local coop_rewards = {}
local trim = nil
-- The choice menu that is up: its kind, for an attribute menu the player it went to (their controller's
-- address) and what their attributes added up to when it opened.
local menu_kind = nil
local menu_target = nil
local menu_baseline = nil
local placed = 0
-- This wave: how many of its enemies were asked for and recognised on arrival, and what else turned up.
local wave_asked = 0
local wave_seen = 0
local strangers = 0
local nearest_stranger = math.huge
-- Requests in a row that brought nothing, and how many arrivals there were when the last one was made.
local spawn_misses = 0
local seen_at_request = 0
local cheat_objects = {}
local alive_mode = nil
local errors_logged = {}

-- How many enemies of the current wave are still to be killed (alive ones and ones yet to arrive).
local wave_left = 0

local function log(message)
    print(PREFIX .. message .. "\n")
end

-- Notes the step the mod is about to take, in a file that always holds just the latest one. After a crash
-- the file says where the mod was.
local function step(text)
    local file = io.open(STEP_PATH, "w")
    if file then
        file:write(os.date("%H:%M:%S ") .. text .. "\n")
        file:close()
    end
end

local function is_valid(object)
    -- Asking a game object for a property it does not have gives back a function, not nil, and some values
    -- the game hands over are wrappers without an IsValid of their own.
    if type(object) ~= "userdata" then
        return false
    end
    local ok, valid = pcall(function()
        return object:IsValid()
    end)
    return ok and valid == true
end

-- Runs one step of the mode; a failure is logged once per label and never stops the rest.
local function attempt(label, fn)
    local ok, err = pcall(fn)
    if not ok and not errors_logged[label] then
        errors_logged[label] = true
        log(label .. " failed: " .. tostring(err))
    end
    return ok
end

local function to_text(value)
    local ok, text = pcall(FText, value)
    if ok then
        return text
    end
    return UEHelpers.GetKismetTextLibrary():Conv_StringToText(value)
end

local function local_controller()
    -- The helper can throw for a moment while the game is between states.
    local ok, controller = pcall(UEHelpers.GetPlayerController)
    return ok and is_valid(controller) and controller or nil
end

local function player_count()
    local game_state = UEHelpers.GetGameStateBase()
    if is_valid(game_state) then
        local ok, count = pcall(function()
            return #game_state.PlayerArray
        end)
        if ok and type(count) == "number" then
            return count
        end
    end
    local states = FindAllOf("PlayerState")
    return states and #states or 0
end

-- True on the machine that runs the game for everyone (always true alone).
local function is_host()
    local controller = local_controller()
    if controller == nil then
        return false
    end
    local ok, server = pcall(function()
        return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"):IsServer(controller)
    end)
    return ok and server == true
end

-- The controllers of all players who have a character, the host's own first. Only the host sees them all.
local function players()
    local list = {}
    local mine = local_controller()
    for _, controller in ipairs(FindAllOf("BWPlayerController") or {}) do
        if controller:IsValid() and is_valid(controller.Pawn) then
            if mine ~= nil and controller:GetAddress() == mine:GetAddress() then
                table.insert(list, 1, controller)
            else
                table.insert(list, controller)
            end
        end
    end
    return list
end

local function coop()
    return player_count() > 1
end

-- How much bigger things get with more players.
local function team_factor()
    return 1.0 + COOP_WAVE_FACTOR * (math.max(1, player_count()) - 1)
end

-- The game's developer functions live on objects that hang off a cheat manager, which shipping builds never
-- create. Each player's controller gets its own; without a controller the host's is meant.
local function cheat_object(class_name, controller)
    controller = controller or local_controller()
    if controller == nil then
        return nil
    end
    local key = class_name .. "@" .. tostring(controller:GetAddress())
    local cached = cheat_objects[key]
    if is_valid(cached) and is_valid(controller.CheatManager) then
        return cached
    end
    local manager = controller.CheatManager
    if not is_valid(manager) then
        manager = StaticConstructObject(StaticFindObject("/Script/BWGame.BWCheatManager"), controller)
        controller.CheatManager = manager
    end
    local object = StaticConstructObject(StaticFindObject("/Script/Angelscript." .. class_name), manager)
    cheat_objects[key] = object
    return object
end

-- Tells every player something through the game's chat (the host "says" it). Alone, nothing is said.
local function announce_to_all(text)
    if not coop() then
        return
    end
    attempt("chat", function()
        local_controller():ServerSendSayMessage(text)
    end)
end

-- On-screen: the game's own HUD ---------------------------------------------------------------------
-- The day dial's label reads "Wave N", and the quest panel on the right shows the mode: what is left of the
-- wave and how far the next reward is. Both are put back when the mode is switched off.

local DAY_TEXT_FIELDS = { "FiveDayText", "FourDayText", "ThreeDayText", "TwoDayText", "OneDayText", "FinalNightText" }
local dial_saved = nil
local dial_label = nil
local quest_saved = nil

-- The widget of this class that is on screen (those hang off the game instance; the others are templates).
local function live_widget(class_name)
    for _, candidate in ipairs(FindAllOf(class_name) or {}) do
        if candidate:IsValid() and candidate:GetFullName():find("/Engine/Transient", 1, true) then
            return candidate
        end
    end
    return nil
end

local function text_of(block)
    return block:GetText():ToString()
end

local function set_text(block, text)
    if is_valid(block) and text_of(block) ~= text then
        block:SetText(to_text(text))
    end
end

local function show_dial(label)
    local dial = live_widget("WBP_DayCycleRotary_C")
    if dial == nil then
        return
    end
    local address = dial:GetAddress()
    if dial_saved == nil or dial_saved.address ~= address then
        dial_saved = { address = address, texts = {} }
        for _, field in ipairs(DAY_TEXT_FIELDS) do
            dial_saved.texts[field] = dial[field]:ToString()
        end
        dial_label = nil
    end
    if dial_label ~= label then
        dial_label = label
        for _, field in ipairs(DAY_TEXT_FIELDS) do
            dial[field] = to_text(label)
        end
    end
    -- Asked every time: the game rewrites the label when the time of day changes.
    dial:UpdateDay()
end

local function restore_dial()
    local dial = live_widget("WBP_DayCycleRotary_C")
    if dial ~= nil and dial_saved ~= nil and dial_saved.address == dial:GetAddress() then
        for _, field in ipairs(DAY_TEXT_FIELDS) do
            dial[field] = to_text(dial_saved.texts[field])
        end
        dial:UpdateDay()
    end
    dial_saved, dial_label = nil, nil
end

-- Only the quest widget's own title and description are written, and its list of goal rows is hidden as a
-- whole. The rows themselves are never touched: the game rebuilds them whenever the quest moves on, and on
-- 2026-10-05 the game crashed seconds after this code had tripped over a row that was being rebuilt.
local function show_quest(title, step, lines)
    local quest = live_widget("WBP_HUDQuest_C")
    if quest == nil or not is_valid(quest.QuestNameText) or not is_valid(quest.QuestStepText) then
        return
    end
    local address = quest:GetAddress()
    if quest_saved == nil or quest_saved.address ~= address then
        quest_saved = { address = address, title = text_of(quest.QuestNameText), step = text_of(quest.QuestStepText) }
    end
    for _, line in ipairs(lines) do
        step = step .. string.char(10) .. line
    end
    set_text(quest.QuestNameText, title)
    set_text(quest.QuestStepText, step)
    local goals = quest.GoalsContainerWidget
    if is_valid(goals) then
        goals:SetVisibility(VIS_COLLAPSED)
    end
end

local function restore_quest()
    local quest = live_widget("WBP_HUDQuest_C")
    if quest ~= nil and quest_saved ~= nil and quest_saved.address == quest:GetAddress() then
        if is_valid(quest.QuestNameText) then
            set_text(quest.QuestNameText, quest_saved.title)
        end
        if is_valid(quest.QuestStepText) then
            set_text(quest.QuestStepText, quest_saved.step)
        end
        local goals = quest.GoalsContainerWidget
        if is_valid(goals) then
            goals:SetVisibility(VIS_SELF_HIT_TEST_INVISIBLE)
        end
    end
    quest_saved = nil
end

local function refresh_hud()
    if not active then
        attempt("dial restore", restore_dial)
        attempt("quest restore", restore_quest)
        return
    end
    attempt("dial", function()
        show_dial("Wave " .. math.max(1, wave))
    end)
    attempt("quest panel", function()
        local left = wave_left
        local first = left > 0 and string.format("%d %s left in wave %d", left, left == 1 and "enemy" or "enemies", wave)
            or "Next wave incoming"
        local step = status_note ~= "" and status_note or string.format("Survive the waves. Best: wave %d.", best_wave)
        show_quest("Endless Mode", step, { first, string.format("Next reward in %d kills", math.max(0, math.floor(KILLS_PER_REWARD * team_factor() + 0.5) - kills_since_reward)),
            string.format("%d kills", kills) })
    end)
end

-- A line in the quest panel that goes away by itself.
local function note(text)
    status_note = text
    note_ticks = 12
end

local function banner(title, body)
    attempt("banner", function()
        cheat_object("BWGameplayCheats"):CenterMessage(title, body)
        banner_ticks = BANNER_TICKS
    end)
end

local function banner_tick()
    if banner_ticks > 0 then
        banner_ticks = banner_ticks - 1
        if banner_ticks == 0 then
            attempt("banner clear", function()
                cheat_object("BWGameplayCheats"):ClearCenterMessage()
            end)
        end
    end
    if note_ticks > 0 then
        note_ticks = note_ticks - 1
        if note_ticks == 0 then
            status_note = ""
        end
    end
end

-- Best wave -----------------------------------------------------------------------------------------

local function load_best()
    local file = io.open(BEST_PATH, "r")
    if file then
        best_wave = tonumber(file:read("*l") or "") or 0
        file:close()
    end
end

local function save_best()
    if wave > best_wave then
        best_wave = wave
        local file = io.open(BEST_PATH, "w")
        if file then
            file:write(tostring(best_wave) .. "\n")
            file:close()
        end
    end
end

-- Day -----------------------------------------------------------------------------------------------

local function day_actor()
    local actor = FindFirstOf("BWDayCycleActor")
    return is_valid(actor) and actor or nil
end

-- The day keeps running; when the game moves on to a later day, the counter is put back to the day the mode
-- was switched on in, so the final day never begins.
local function day_tick()
    local actor = day_actor()
    if actor == nil then
        return
    end
    local day = actor.DayNumber
    if hold_day == nil then
        hold_day = day
        log("holding the day counter at " .. tostring(hold_day))
    elseif day > hold_day then
        cheat_object("BWGameplayCheats"):SetDay(hold_day)
        log(string.format("day counter went to %d, put back to %d (now %s)", day, hold_day, tostring(actor.DayNumber)))
    end
end

-- Choice menus ------------------------------------------------------------------------------------
-- The game keeps an upgrade source for its own developer function "add upgrade points", which opens the
-- game's choice menu straight away. Its three offers are rewritten before each use: the three attributes, or
-- three random power-ups.

local function cheat_source()
    for _, component in ipairs(FindAllOf("BWUpgradeSourceComponent") or {}) do
        if component:IsValid() and component:GetFName():ToString() == "CheatUpgradeSourceComponent" then
            return component
        end
    end
    return nil
end

local function menu_open()
    for _, window in ipairs(FindAllOf("BWUpgradeChoiceWindow") or {}) do
        if window:IsValid() then
            local ok, activated = pcall(function()
                return window:IsActivated()
            end)
            if ok and activated == true then
                return true
            end
        end
    end
    return false
end

local function open_menu(kind, controller)
    local source = cheat_source()
    if source == nil then
        error("the game's upgrade source was not found")
    end
    local rows = { "powerup_strength", "powerup_agility", "powerup_intelligence" }
    if kind == "powerup" then
        local used = {}
        rows = {}
        while #rows < 3 do
            local index = math.random(#POWERUPS)
            if not used[index] then
                used[index] = true
                table.insert(rows, "powerup_" .. POWERUPS[index])
            end
        end
    end
    local written = 0
    source.AvailableUpgrades:ForEach(function(index, element)
        if rows[index] ~= nil then
            element:get().RowName = FName(rows[index])
            written = written + 1
        end
    end)
    source.OfferCount = 3
    cheat_object("BWPlayerCheats", controller):ServerAddUpgradePoints()
    log(string.format("%s menu opened (%d offers written: %s)", kind, written, table.concat(rows, ", ")))
end

local function set_paused(paused)
    attempt("pause", function()
        UEHelpers.GetGameplayStatics():SetGamePaused(local_controller(), paused)
    end)
end

local ATTRIBUTE_NAMES = { "Strength", "Agility", "Intelligence" }

-- One reward. Alone: an attribute menu, then `powerups` power-up menus, with the game paused. With other
-- players it waits for the wave to be cleared and is dropped as crystals.
local function queue_reward(powerups)
    if coop() then
        table.insert(coop_rewards, powerups)
        log(string.format("co-op reward earned (%d waiting for the end of the wave)", #coop_rewards))
        return
    end
    local host = players()[1]
    if host ~= nil then
        table.insert(menu_queue, { kind = "attribute", target = host:GetAddress() })
    end
    for _ = 1, powerups do
        table.insert(menu_queue, { kind = "powerup" })
    end
    log(string.format("reward queued: %d menu(s) waiting", #menu_queue))
end

local function load_class(package_path)
    local name = package_path:match("([^/]+)$")
    local full = package_path .. "." .. name .. "_C"
    local class = StaticFindObject(full)
    if not is_valid(class) then
        pcall(LoadAsset, package_path)
        class = StaticFindObject(full)
    end
    return is_valid(class) and class or nil
end

-- Spawns one of the game's power crystals and opens it as a cleared camp would: it shatters and the game
-- drops every player's pickups.
local function drop_crystal(package_path, location)
    local class = load_class(package_path)
    if class == nil then
        error("crystal class not found: " .. package_path)
    end
    step("spawning a crystal")
    local crystal = local_controller():GetWorld():SpawnActor(class, location, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 })
    if not is_valid(crystal) then
        error("the crystal did not spawn")
    end
    step("opening a crystal")
    crystal:OnUnlocked(crystal.LockComponent)
    step("crystal opened")
end

local function attribute_pickups()
    local found = {}
    for _, pickup in ipairs(FindAllOf("BWPlayerUpgradeShard") or {}) do
        if pickup:IsValid() and pickup:GetClass():GetFName():ToString() == ATTRIBUTE_PICKUP_CLASS then
            table.insert(found, pickup)
        end
    end
    return found
end

-- Co-op: drops the crystals of every reward earned, in a ring around one of the players.
local function drop_coop_rewards()
    local everyone = players()
    if #coop_rewards == 0 or #everyone == 0 then
        return false
    end
    local centre = everyone[math.random(#everyone)].Pawn:K2_GetActorLocation()
    local crystals = {}
    for _, powerups in ipairs(coop_rewards) do
        table.insert(crystals, ATTRIBUTE_CRYSTAL)
        for _ = 1, powerups do
            table.insert(crystals, POWERUP_CRYSTAL)
        end
    end
    local before = {}
    for _, pickup in ipairs(attribute_pickups()) do
        before[pickup:GetAddress()] = true
    end
    local start = math.random() * 2.0 * math.pi
    local dropped = 0
    for index, path in ipairs(crystals) do
        local angle = start + (index - 1) * 2.0 * math.pi / #crystals
        local spot = { X = centre.X + math.cos(angle) * CRYSTAL_DISTANCE, Y = centre.Y + math.sin(angle) * CRYSTAL_DISTANCE, Z = centre.Z - 80.0 }
        local ok, err = pcall(drop_crystal, path, spot)
        if ok then
            dropped = dropped + 1
        else
            log("crystal failed: " .. tostring(err))
        end
    end
    trim = { at = mode_ticks + TRIM_AFTER_TICKS, until_tick = mode_ticks + TRIM_GIVE_UP_TICKS, keep = #coop_rewards, before = before }
    log(string.format("co-op: %d reward(s) dropped as %d crystal(s)", #coop_rewards, dropped))
    coop_rewards = {}
    announce_to_all(string.format("Endless Mode: rewards dropped - absorb your pickups, next wave in %d seconds", COOP_REWARD_BREAK_TICKS // 2))
    return dropped > 0
end

-- Co-op: an attribute crystal gives every player three pickups; all but `keep` per player are removed.
local function trim_tick()
    if trim == nil or mode_ticks < trim.at then
        return
    end
    step("trimming spare pickups")
    local by_owner = {}
    local fresh = 0
    for _, pickup in ipairs(attribute_pickups()) do
        if not trim.before[pickup:GetAddress()] then
            local owner = pickup:GetOwner()
            if is_valid(owner) then
                local key = owner:GetAddress()
                by_owner[key] = by_owner[key] or {}
                table.insert(by_owner[key], pickup)
                fresh = fresh + 1
            end
        end
    end
    if fresh == 0 and mode_ticks < trim.until_tick then
        -- Not dropped yet; look again next tick.
        return
    end
    local removed, owners = 0, 0
    for _, pickups in pairs(by_owner) do
        owners = owners + 1
        for index = trim.keep + 1, #pickups do
            pickups[index]:K2_DestroyActor()
            removed = removed + 1
        end
    end
    log(string.format("co-op: %d attribute pickup(s) found for %d player(s), %d spare removed", fresh, owners, removed))
    trim = nil
    step("trimming done")
end

-- What a player's three attributes add up to, or nil when it cannot be read.
local function attribute_total(controller)
    local ok, total = pcall(function()
        local abilities = controller.Pawn.AbilitySystemComponent
        local attributes = StaticFindObject(PLAYER_ATTRIBUTES_PATH)
        local sum = 0.0
        for _, name in ipairs(ATTRIBUTE_NAMES) do
            sum = sum + abilities:GetAttributeCurrentValue(attributes, FName(name), 0.0)
        end
        return sum
    end)
    return ok and total or nil
end

local function player_by_address(address)
    for index, controller in ipairs(players()) do
        if controller:GetAddress() == address then
            return controller, index
        end
    end
    return nil, nil
end

-- Whether the menu that is up is finished with.
local function menu_done()
    local everyone = players()
    if menu_kind == "powerup" then
        if menu_open() then
            return false
        end
        return #everyone <= 1 or menu_ticks >= COOP_POWERUP_WAIT_TICKS
    end
    -- The attribute menu only ever goes to the host, whose menu can be seen closing.
    return not menu_open()
end

-- Shows the waiting choice menus one after the other with the game paused, so nothing can hit anyone (the
-- game closes its menu when its player is hit or moves away). Returns true while a menu is up.
local function menu_tick()
    if menu_showing then
        menu_ticks = menu_ticks + 1
        local limit = coop() and COOP_MENU_LIMIT_TICKS or MENU_TIME_LIMIT_TICKS
        if not menu_done() and menu_ticks < limit then
            return true
        end
        if coop() then
            local target = menu_target and player_by_address(menu_target) or nil
            log(string.format("co-op: %s menu over after %d ticks; attributes now %s", menu_kind, menu_ticks,
                tostring(target and attribute_total(target) or "-")))
        end
        menu_showing = false
    end
    while #menu_queue > 0 do
        local entry = table.remove(menu_queue, 1)
        menu_kind, menu_target, menu_baseline = entry.kind, entry.target, nil
        local targets = players()
        if entry.kind == "attribute" then
            -- Never to anyone but the host: see the note at COOP_POWERUP_WAIT_TICKS.
            local target, index = player_by_address(entry.target)
            targets = (target ~= nil and index == 1) and { target } or {}
        elseif coop() then
            announce_to_all("Endless Mode: everyone, choose a power-up")
        end
        local opened = 0
        for index, controller in ipairs(targets) do
            step(string.format("opening the %s menu for player %d of %d", entry.kind, index, #targets))
            local ok, err = pcall(open_menu, entry.kind, controller)
            if ok then
                opened = opened + 1
            else
                log(string.format("%s menu for player %d failed: %s", entry.kind, index, tostring(err)))
            end
        end
        step("menus opened, pausing")
        if opened > 0 then
            set_paused(true)
            menu_showing = true
            menu_ticks = 0
            return true
        end
    end
    set_paused(false)
    return false
end

-- Enemies -------------------------------------------------------------------------------------------

local function has_function(object, wanted)
    local found = false
    local class = object:GetClass()
    local depth = 0
    while is_valid(class) and depth < 16 and not found do
        pcall(function()
            class:ForEachFunction(function(fn)
                if fn:GetFName():ToString() == wanted then
                    found = true
                end
            end)
        end)
        class = class:GetSuperStruct()
        depth = depth + 1
    end
    return found
end

local function is_alive(enemy)
    local ok, component = pcall(function()
        return enemy.HealthComponent
    end)
    if ok and is_valid(component) then
        if alive_mode == nil then
            alive_mode = has_function(component, "IsAlive") and "IsAlive"
                or (has_function(component, "IsOutOfHealth") and "IsOutOfHealth" or "movement")
            log("alive check: " .. alive_mode)
        end
        if alive_mode ~= "movement" then
            local called, result = pcall(function()
                if alive_mode == "IsAlive" then
                    return component:IsAlive() == true
                end
                return component:IsOutOfHealth() ~= true
            end)
            if called then
                return result
            end
            alive_mode = "movement"
        end
    end
    -- Dead characters have their movement switched off (MOVE_None) while the body is still around.
    local moved, mode = pcall(function()
        return enemy.CharacterMovement.MovementMode
    end)
    return not moved or mode ~= 0
end

local function bosses_for(wave_number)
    if wave_number % BOSS_EVERY ~= 0 then
        return 0
    end
    if wave_number <= SINGLE_BOSS_UNTIL then
        return 1
    end
    return math.min(MAX_BOSSES, 2 + (wave_number - SINGLE_BOSS_UNTIL - BOSS_EVERY) // BOSS_COUNT_STEP)
end

-- Makes a wave's enemy as tough as its wave says.
local function scale_enemy(enemy, is_boss)
    local growth = HEALTH_GROWTH ^ math.max(0, wave - 1)
    attempt("health scaling", function()
        local abilities = enemy.AbilitySystemComponent
        local attributes = StaticFindObject(HEALTH_ATTRIBUTES_PATH)
        local maximum = abilities:GetAttributeCurrentValue(attributes, FName("MaxHealth"), -1.0)
        local target = maximum * growth
        if is_boss then
            target = math.max(target, BOSS_HEALTH * HEALTH_GROWTH ^ math.max(0, wave - BOSS_EVERY) * team_factor())
        end
        if maximum > 0.0 and target > maximum + 0.5 then
            abilities:SetAttributeBaseValue(attributes, FName("MaxHealth"), target)
            abilities:SetAttributeBaseValue(attributes, FName("Health"), target)
        end
        if is_boss then
            log(string.format("boss health %.0f -> %.0f", maximum, target))
        end
    end)
    local bonus = DAMAGE_PER_WAVE * math.max(0, wave - 1) * (is_boss and BOSS_DAMAGE_FACTOR or 1.0)
    if bonus > 0.0 then
        attempt("damage scaling", function()
            enemy.AbilitySystemComponent:SetAttributeBaseValue(StaticFindObject(COMBAT_ATTRIBUTES_PATH), FName("BaseDamage"), bonus)
        end)
    end
end

-- The highest item level among the items the game holds: what this run's weapons are at.
local function current_item_level()
    local top = 1
    for _, item in ipairs(FindAllOf("BWItemInstance") or {}) do
        if item:IsValid() then
            local ok, level = pcall(function()
                return item.InstanceData.ItemLevel
            end)
            if ok and type(level) == "number" and level > top then
                top = level
            end
        end
    end
    return top
end

-- A boss's weapon: a random one, straight into the host's inventory, at the wave's level.
local function give_boss_weapon()
    local name = WEAPONS[math.random(#WEAPONS)]
    local level = base_item_level + wave // WEAPON_WAVES_PER_LEVEL
    step("giving a boss weapon")
    cheat_object("BWPlayerCheats"):ServerAddItemToInventory(FName(name), 1, { ItemLevel = level }, false)
    local pretty = name:gsub("^Weapon_", "")
    note(string.format("Boss weapon: %s (level %d) is in your inventory", pretty, level))
    announce_to_all(string.format("Endless Mode: the boss dropped a level %d %s for the host", level, pretty))
    log(string.format("boss weapon given: %s level %d", name, level))
end

-- Moves a freshly spawned enemy off the player to a random walkable spot some way off.
local function place_away(enemy)
    attempt("spawn placing", function()
        local controller = local_controller()
        local everyone = players()
        if #everyone == 0 then
            return
        end
        local origin = everyone[math.random(#everyone)].Pawn:K2_GetActorLocation()
        local navigation = StaticFindObject("/Script/NavigationSystem.Default__NavigationSystemV1")
        for _ = 1, SPAWN_PLACE_TRIES do
            local point = {}
            local found = navigation:K2_GetRandomReachablePointInRadius(controller, origin, point, SPAWN_MAX_DISTANCE, nil, nil)
            local spot = point.RandomLocation or point
            if found and spot.X ~= nil then
                local dx, dy = spot.X - origin.X, spot.Y - origin.Y
                if math.sqrt(dx * dx + dy * dy) >= SPAWN_MIN_DISTANCE then
                    local yaw = math.deg(math.atan(-dy, -dx))
                    enemy:K2_TeleportTo({ X = spot.X, Y = spot.Y, Z = spot.Z + SPAWN_LIFT }, { Pitch = 0.0, Yaw = yaw, Roll = 0.0 })
                    placed = placed + 1
                    return
                end
            end
        end
    end)
end

local function on_kill(entry)
    kills = kills + 1
    kills_since_reward = kills_since_reward + 1
    if entry.boss then
        attempt("boss weapon", give_boss_weapon)
    end
end

-- How far a spot is from the nearest player (cm, on the ground plane).
local function distance_to_players(location, spots)
    local nearest = math.huge
    for _, spot in ipairs(spots) do
        local dx, dy = location.X - spot.X, location.Y - spot.Y
        nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy))
    end
    return nearest
end

local function player_spots()
    local spots = {}
    for _, controller in ipairs(players()) do
        table.insert(spots, controller.Pawn:K2_GetActorLocation())
    end
    return spots
end

-- Follows every enemy in the level and counts the ones that died since the last look. Returns how many
-- enemies of this mod's waves are alive.
local function watch_enemies()
    local own_alive = 0
    local seen = {}
    local spots = player_spots()
    -- Anything asked for a while ago that has not appeared is not coming.
    while #awaited > 0 and awaited[1].expires < mode_ticks do
        table.remove(awaited, 1)
    end
    for _, enemy in ipairs(FindAllOf("BWEnemyCharacter") or {}) do
        if enemy:IsValid() then
            local address = enemy:GetAddress()
            local living = is_alive(enemy)
            seen[address] = true
            local entry = tracked[address]
            if entry ~= nil and living and not entry.alive then
                -- The game reuses the actors of dead enemies. This one is somebody new.
                entry = nil
            end
            if entry == nil then
                entry = { alive = living, own = false, boss = false }
                tracked[address] = entry
                local distance = distance_to_players(enemy:K2_GetActorLocation(), spots)
                if living and #awaited > 0 and distance < OWN_SPAWN_DISTANCE then
                    entry.own = true
                    entry.boss = table.remove(awaited, 1).boss
                    wave_seen = wave_seen + 1
                    -- Only now is it one less to come.
                    if entry.boss then
                        boss_pending = math.max(0, boss_pending - 1)
                    else
                        wave_to_spawn = math.max(0, wave_to_spawn - 1)
                    end
                    step("new wave enemy: health")
                    scale_enemy(enemy, entry.boss)
                    step("new wave enemy: placing")
                    place_away(enemy)
                    step("enemies")
                elseif living then
                    -- For the log: newcomers that were not taken for the wave's, and how near the nearest was.
                    strangers = strangers + 1
                    nearest_stranger = math.min(nearest_stranger, distance)
                end
            elseif entry.alive and not living then
                entry.alive = false
                entry.own = false
                on_kill(entry)
            end
            if living then
                pcall(function()
                    local location = enemy:K2_GetActorLocation()
                    entry.x, entry.y, entry.z = location.X, location.Y, location.Z
                end)
                if entry.own then
                    own_alive = own_alive + 1
                end
            end
        end
    end
    for address, entry in pairs(tracked) do
        if not seen[address] then
            -- Gone without having been seen dead. Near a player that is a body cleaned up between two looks;
            -- far away it is the game putting a distant enemy to sleep, which is no kill.
            if entry.alive and entry.x ~= nil
                and distance_to_players({ X = entry.x, Y = entry.y }, spots) < VANISH_KILL_DISTANCE then
                on_kill(entry)
            end
            tracked[address] = nil
        end
    end
    return own_alive
end

local function wave_pool()
    local pool = {}
    for _, tier in ipairs(ENEMY_TIERS) do
        if wave >= tier.from then
            for _, name in ipairs(tier.names) do
                table.insert(pool, name)
            end
        end
    end
    return pool
end

-- Asks the game for enemies. They are put where the asking player's camera is looking, so after a request
-- that brought nothing the next one is made through the next player.
local function spawn(name, count, boss)
    attempt("spawn " .. name, function()
        local everyone = players()
        local asker = everyone[spawn_misses % math.max(1, #everyone) + 1]
        cheat_object("BWGameplayCheats", asker):Spawn(name, count)
        for _ = 1, count do
            table.insert(awaited, { boss = boss, expires = mode_ticks + AWAIT_TICKS })
        end
        wave_asked = wave_asked + count
    end)
end

local function start_wave()
    placed, wave_asked, wave_seen, strangers, nearest_stranger = 0, 0, 0, 0, math.huge
    spawn_misses, seen_at_request = 0, 0
    wave = wave + 1
    wave_to_spawn = math.floor((WAVE_BASE + WAVE_GROWTH * wave) * team_factor() + 0.5)
    wave_ticks = 0
    last_progress_tick, last_own_alive, recalled = 0, 0, false
    boss_pending = bosses_for(wave)
    save_best()
    local boss_text = boss_pending == 1 and "a boss" or (boss_pending .. " bosses")
    if boss_pending > 0 then
        banner("WAVE " .. wave, boss_pending == 1 and "A boss is coming" or (boss_pending .. " bosses are coming"))
    else
        banner("WAVE " .. wave, wave_to_spawn .. " enemies")
    end
    announce_to_all(string.format("Endless Mode: wave %d - %d enemies%s", wave, wave_to_spawn, boss_pending > 0 and (" and " .. boss_text:upper()) or ""))
    log(string.format("wave %d: %d enemies%s (%d player(s))", wave, wave_to_spawn, boss_pending > 0 and (" and " .. boss_text) or "", player_count()))
end

local function wave_tick(own_alive)
    if wave == 0 or break_ticks > 0 then
        break_ticks = break_ticks - 1
        if break_ticks <= 0 then
            start_wave()
        end
        return
    end
    wave_ticks = wave_ticks + 1
    -- The next few are asked for once the last request has been answered or given up on. What is still to
    -- come only goes down when enemies are seen arriving.
    if wave_ticks % SPAWN_EVERY_TICKS == 1 and #awaited == 0 and (boss_pending > 0 or wave_to_spawn > 0)
        and own_alive < math.floor(MAX_ALIVE * team_factor()) then
        if wave_asked > 0 then
            if wave_seen > seen_at_request then
                spawn_misses = 0
            else
                spawn_misses = spawn_misses + 1
                if spawn_misses >= MISSES_BEFORE_HINT then
                    note("Enemies arrive where the host is looking - look at the ground")
                end
            end
        end
        seen_at_request = wave_seen
        if boss_pending > 0 then
            -- One at a time, each a different one.
            local arrived_bosses = bosses_for(wave) - boss_pending
            local boss = BOSSES[((wave // BOSS_EVERY - 1 + arrived_bosses) % #BOSSES) + 1]
            spawn(boss, 1, true)
            log("boss asked for: " .. boss)
        else
            local pool = wave_pool()
            local count = math.min(SPAWN_BATCH, wave_to_spawn, math.floor(MAX_ALIVE * team_factor()) - own_alive)
            spawn(pool[math.random(#pool)], count, false)
        end
    end
    local arrived = wave_to_spawn <= 0 and boss_pending == 0
    if own_alive ~= last_own_alive then
        last_own_alive = own_alive
        last_progress_tick = wave_ticks
        recalled = false
    elseif arrived and own_alive > WAVE_LEFTOVERS and wave_ticks - last_progress_tick >= STRAGGLER_TICKS then
        -- Nothing has died for a while: whatever is left has lost the players, is stuck, or cannot be reached.
        last_progress_tick = wave_ticks
        local moved, dropped = 0, 0
        local spots = player_spots()
        for _, enemy in ipairs(FindAllOf("BWEnemyCharacter") or {}) do
            local entry = enemy:IsValid() and tracked[enemy:GetAddress()] or nil
            if entry ~= nil and entry.own and entry.alive and not entry.boss then
                if recalled then
                    -- A second quiet spell: whatever is left is no longer part of the wave, near or far.
                    entry.own = false
                    dropped = dropped + 1
                elseif distance_to_players(enemy:K2_GetActorLocation(), spots) > STRAGGLER_DISTANCE then
                    place_away(enemy)
                    moved = moved + 1
                end
            end
        end
        if moved + dropped > 0 then
            log(string.format("wave %d: %d straggler(s) brought back near the players, %d let go", wave, moved, dropped))
        end
        recalled = not recalled
    end
    if (arrived and #awaited == 0 and own_alive <= WAVE_LEFTOVERS) or wave_ticks > WAVE_TIME_LIMIT_TICKS then
        log(string.format("wave %d over: asked for %d, saw %d arrive, moved %d away from the players; %d other newcomer(s), nearest %s cm",
            wave, wave_asked, wave_seen, placed, strangers, nearest_stranger < math.huge and string.format("%.0f", nearest_stranger) or "-"))
        break_ticks = WAVE_BREAK_TICKS
        note("Wave " .. wave .. " cleared")
        if wave % BOSS_EVERY == 0 then
            -- A boss wave pays out straight away, with a second power-up.
            queue_reward(2)
            log("boss wave reward queued")
        end
        if coop() and #coop_rewards > 0 then
            local dropped = false
            attempt("co-op rewards", function()
                dropped = drop_coop_rewards()
            end)
            if dropped then
                break_ticks = COOP_REWARD_BREAK_TICKS
                note("Rewards dropped - absorb your pickups")
            end
        end
    end
end

local function reward_tick()
    local needed = math.floor(KILLS_PER_REWARD * team_factor() + 0.5)
    if kills_since_reward >= needed then
        kills_since_reward = kills_since_reward - needed
        queue_reward(1)
    end
end

-- Quest board ---------------------------------------------------------------------------------------
-- The game's quest list cannot take a new quest from Lua (its entries keep their quest in fields Lua cannot
-- reach), so the entry is a copy of the game's own list-entry widget placed under the list. Clicking it arms
-- the mode: the details pane describes endless mode, and the next mission starts it by itself.

local BOARD_TICK_MS = 100
local ENTRY_HEIGHT = 37.0
local ENDLESS_TITLE = "Endless Mode"
local NEW_LINE = string.char(10)
local ENDLESS_DESCRIPTION = "Waves of enemies without end, on the map of the quest you had picked in this list."
    .. NEW_LINE .. NEW_LINE .. "1. Survive. Every wave is bigger and tougher than the last."
    .. NEW_LINE .. "2. Every 15 kills, choose an Attribute and a Power-up."
    .. NEW_LINE .. "3. Every fifth wave brings a Boss."
    .. NEW_LINE .. "4. The days never run out. It ends when you do."

-- The bar behind a list entry, as the game colours it: plain, and for the highlighted entry.
local ENTRY_PLAIN = { R = 0.47, G = 0.47, B = 0.47, A = 1.0 }
local ENTRY_HIGHLIGHT = { R = 1.0, G = 0.77, B = 0.36, A = 1.0 }

local armed = false
-- What was built on the board screen that is open: the screen's address, the entry, and the details pane
-- whose texts were replaced (with the texts it had).
local board = nil
local started_for_level = nil
-- The quest whose map the chosen endless run will be played on (its title), once Select has been pressed.
local armed_map = nil

local function board_screen()
    local screen = live_widget("WBP_QuestSelectionScreen_C")
    if screen == nil then
        return nil
    end
    local ok, activated = pcall(function()
        return screen:IsActivated()
    end)
    return ok and activated == true and screen or nil
end

-- The game's own list entries that are on screen now, asked from the list itself. Widgets of an earlier
-- opening of the board stay in memory for a while, half taken apart; they must not be touched (the game
-- crashed on 2026-10-05 when they were).
local function real_entries(screen)
    local entries = {}
    local list = screen.QuestNameListView
    if not is_valid(list) then
        return entries
    end
    local ok, err = pcall(function()
        -- Comes back as a plain list.
        for _, item in ipairs(list:GetDisplayedEntryWidgets()) do
            -- Each item is a wrapper around the widget.
            local entry = item
            pcall(function()
                entry = item:get()
            end)
            if is_valid(entry) and is_valid(entry.QuestNameText) then
                table.insert(entries, entry)
            end
        end
    end)
    if not ok and not errors_logged["board entries"] then
        errors_logged["board entries"] = true
        log("quest board: the list's entries could not be read: " .. tostring(err))
    end
    return entries
end

local function set_highlight(entry, highlighted)
    if not is_valid(entry) then
        return
    end
    local tree = entry.WidgetTree
    local root = is_valid(tree) and tree.RootWidget or nil
    local bar = is_valid(root) and root:GetChildAt(0) or nil
    if is_valid(bar) then
        bar:SetBrushColor(highlighted and ENTRY_HIGHLIGHT or ENTRY_PLAIN)
    end
end

local function build_board(screen)
    step("board: building")
    local list = screen.QuestNameListView
    -- When this screen has been opened before, what was built then is still in place: use it again.
    local housing = list:GetParent()
    if is_valid(housing) and housing:GetFName():ToString():find("^LortEndlessFrame") then
        local box = housing:GetParent()
        local stack = is_valid(box) and box:GetChildAt(1) or nil
        local old_entry = is_valid(stack) and stack:GetChildAt(0) or nil
        local old_check = is_valid(stack) and stack:GetChildAt(1) or nil
        if is_valid(old_entry) and is_valid(old_entry.QuestNameText) and is_valid(old_check) then
            log("quest board: endless entry still in place")
            return { screen_address = screen:GetAddress(), entry = old_entry, check = old_check,
                checked = old_check:IsChecked(), pane = nil, recoloured = false }
        end
    end
    -- The list's own holder: when this screen has been opened before, the list still sits inside what was
    -- built then, which is left behind and built afresh.
    local holder = list:GetParent()
    while is_valid(holder) and holder:GetFName():ToString():find("^LortEndless") do
        holder = holder:GetParent()
    end
    local entries = real_entries(screen)
    if #entries == 0 or not is_valid(holder) then
        return nil
    end
    local suffix = tostring(os.time()) .. "_" .. tostring(screen:GetAddress())
    local tree = screen.WidgetTree
    local box = StaticConstructObject(StaticFindObject("/Script/UMG.VerticalBox"), tree, FName("LortEndlessBox_" .. suffix))
    local frame = StaticConstructObject(StaticFindObject("/Script/UMG.SizeBox"), tree, FName("LortEndlessFrame_" .. suffix))
    local library = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local controller = local_controller()
    local entry = library:Create(controller, entries[1]:GetClass(), controller)
    holder:SetContent(box)
    frame:SetHeightOverride(ENTRY_HEIGHT * list:GetNumItems())
    frame:SetContent(list)
    -- The entry lies under an invisible check box of the same size. A click toggles the check box (the game
    -- does that itself), and the mod's tick sees the change: no key or mouse hook is needed.
    local stack = StaticConstructObject(StaticFindObject("/Script/UMG.Overlay"), tree, FName("LortEndlessStack_" .. suffix))
    local check = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"), tree, FName("LortEndlessCheck_" .. suffix))
    box:AddChild(frame)
    box:AddChild(stack)
    stack:AddChildToOverlay(entry)
    local slot = stack:AddChildToOverlay(check)
    -- EHorizontalAlignment / EVerticalAlignment: 0 is fill.
    slot:SetHorizontalAlignment(0)
    slot:SetVerticalAlignment(0)
    check:SetRenderOpacity(0.0)
    entry.QuestNameText:SetText(to_text(ENDLESS_TITLE))
    -- A fresh entry starts with the grey "locked" cover showing.
    entry.DisabledOverlay:SetVisibility(VIS_COLLAPSED)
    log("quest board: endless entry added")
    return { screen_address = screen:GetAddress(), entry = entry, check = check, checked = check:IsChecked(),
        pane = nil, recoloured = false }
end

local function active_pane(screen)
    local pane = screen.DetailsPanelSwitcher:GetActiveWidget()
    return is_valid(pane) and pane or nil
end

local function restore_pane()
    if board ~= nil and board.pane ~= nil then
        local saved = board.pane
        board.pane = nil
        if is_valid(saved.widget) then
            set_text(saved.widget.QuestNameText, saved.title)
            set_text(saved.widget.QuestDescriptionText, saved.description)
            pcall(function()
                saved.widget.IngredientBox:SetVisibility(VIS_SELF_HIT_TEST_INVISIBLE)
            end)
        end
    end
end

-- Makes the board look the way `armed` says: the endless entry or the game's own selection highlighted, and
-- the details pane describing endless mode or the quest.
local function show_board_state(screen)
    step("board: active pane")
    local pane = active_pane(screen)
    if armed and pane ~= nil then
        if board.pane == nil or board.pane.address ~= pane:GetAddress() then
            step("board: restoring the old pane")
            restore_pane()
            step("board: reading the pane")
            board.pane = { widget = pane, address = pane:GetAddress(), title = text_of(pane.QuestNameText),
                description = text_of(pane.QuestDescriptionText) }
        end
        step("board: writing the pane")
        set_text(pane.QuestNameText, ENDLESS_TITLE)
        set_text(pane.QuestDescriptionText, ENDLESS_DESCRIPTION .. NEW_LINE .. NEW_LINE .. "Map: " .. board.pane.title)
        step("board: hiding the ingredient")
        pcall(function()
            pane.IngredientBox:SetVisibility(VIS_COLLAPSED)
        end)
    else
        step("board: restoring the pane")
        restore_pane()
        pane = active_pane(screen)
    end
    step("board: highlights")
    -- The game highlights its own entries; they are only touched to take the highlight away while the
    -- endless entry has it, and to give it back afterwards.
    if armed or board.recoloured then
        local quest_title = board.pane ~= nil and board.pane.title or (pane ~= nil and text_of(pane.QuestNameText) or "")
        for _, entry in ipairs(real_entries(screen)) do
            set_highlight(entry, not armed and text_of(entry.QuestNameText) == quest_title)
        end
        board.recoloured = armed
    end
    step("board: own highlight")
    set_highlight(board.entry, armed)
    step("board: done")
end

-- The quest highlighted in the game's list, as an address, or nil.
local function selected_quest(screen)
    local ok, address = pcall(function()
        local item = screen.QuestNameListView:BP_GetSelectedItem()
        return is_valid(item) and item:GetAddress() or nil
    end)
    return ok and address or nil
end

local function set_armed(value, screen)
    if armed ~= value then
        armed = value
        log(armed and "endless mode chosen at the quest board" or "endless mode no longer chosen")
    end
    if screen ~= nil and board ~= nil then
        show_board_state(screen)
    end
end

-- Keeps the entry on the board while its screen is open.
local function board_tick()
    local screen = board_screen()
    if screen == nil then
        if board ~= nil then
            local map = board.pane ~= nil and board.pane.title or nil
            restore_pane()
            board = nil
            if armed and map ~= nil then
                -- The game's own "Quest Selected: <quest>" banner is left alone. Rewording it meant going
                -- over every text block in memory, including ones being taken apart, and the game
                -- crashed on that. The quest line at the top right says "Endless Mode" instead.
                armed_map = map
            end
        end
        return
    end
    if board == nil or board.screen_address ~= screen:GetAddress() or not is_valid(board.entry)
        or not is_valid(board.check) then
        board = build_board(screen)
        if board == nil then
            return
        end
        board.selected = selected_quest(screen)
        show_board_state(screen)
        return
    end
    local checked = board.check:IsChecked()
    local selected = selected_quest(screen)
    if checked ~= board.checked then
        -- The entry was clicked: choose the mode, or un-choose it.
        board.checked = checked
        if not armed then
            -- The game's Select button only works with a quest highlighted in its list, and a freshly
            -- opened board has none: highlight the first one, whose map the run is then played on.
            attempt("board selection", function()
                local list = screen.QuestNameListView
                if selected == nil and list:GetNumItems() > 0 then
                    list:BP_SetSelectedItem(list:GetItemAt(0))
                end
            end)
            selected = selected_quest(screen)
        end
        board.selected = selected
        set_armed(not armed, screen)
    elseif armed and selected ~= board.selected then
        -- Another quest was picked in the list: that is a normal quest choice again.
        board.selected = selected
        set_armed(false, screen)
    elseif armed then
        -- Keeps the details pane on endless mode.
        show_board_state(screen)
    else
        board.selected = selected
    end
end

-- Mode ----------------------------------------------------------------------------------------------

local function stop(reason)
    if not active then
        return
    end
    active = false
    menu_queue = {}
    if menu_showing then
        menu_showing = false
        set_paused(false)
    end
    save_best()
    log("off: " .. reason)
    attempt("hud", refresh_hud)
end

local function start()
    local controller = local_controller()
    if controller == nil or #players() == 0 then
        log("no character yet")
        return
    end
    if not is_host() then
        log("not the host: the host's game runs endless mode")
        return
    end
    local actor = day_actor()
    active = true
    wave, kills, kills_since_reward = 0, 0, 0
    wave_to_spawn, wave_ticks, break_ticks, boss_pending = 0, 0, 4, 0
    hold_day, tracked, errors_logged, awaited, placed, last_world_time = nil, {}, {}, {}, 0, nil
    menu_queue, menu_showing = {}, false
    mode_ticks, coop_rewards, trim = 0, {}, nil
    day_actor_address = actor and actor:GetAddress() or nil
    note("Get ready")
    -- Enemies already in the level are followed from now on, but are not part of any wave.
    for _, enemy in ipairs(FindAllOf("BWEnemyCharacter") or {}) do
        if enemy:IsValid() then
            tracked[enemy:GetAddress()] = { alive = is_alive(enemy), own = false, boss = false }
        end
    end
    load_best()
    attempt("item level", function()
        base_item_level = current_item_level()
    end)
    log("on")
    banner("ENDLESS MODE", "Survive")
    attempt("hud", refresh_hud)
end

-- True while the game's clock stands still (the pause menu in a solo game).
local function world_paused(controller)
    local ok, now = pcall(function()
        return UEHelpers.GetGameplayStatics():GetTimeSeconds(controller)
    end)
    if not ok then
        return false
    end
    local paused = last_world_time ~= nil and now - last_world_time < 0.05
    last_world_time = now
    if paused ~= was_paused then
        was_paused = paused
        log(paused and "game paused: waves wait" or "game running again")
    end
    return paused
end

-- True in a mission (the camp's day stands still).
local function in_mission()
    local actor = day_actor()
    return actor ~= nil and actor.bPaused ~= true
end

-- Starts the mode by itself in the mission that follows choosing it at the quest board, once per level.
local function auto_start()
    local controller = local_controller()
    local actor = day_actor()
    if not armed or controller == nil or not is_valid(controller.Pawn) or actor == nil then
        return
    end
    if not in_mission() and started_for_level == nil and armed_map ~= nil then
        -- Waiting in the camp with the mode chosen: the "upcoming quest" line says so.
        step("camp: upcoming quest line")
        attempt("upcoming quest", function()
            local upcoming = live_widget("WBP_HUDUpcomingQuest_C")
            if upcoming ~= nil and is_valid(upcoming.QuestNameText) then
                set_text(upcoming.QuestNameText, "Endless Mode: " .. armed_map)
            end
        end)
        step("camp: upcoming quest line done")
    end
    if not in_mission() then
        if started_for_level ~= nil then
            -- Back in the camp after an endless run: the choice has been used up.
            started_for_level = nil
            armed = false
            armed_map = nil
            log("back in the camp: endless mode is no longer chosen")
        end
        return
    end
    if started_for_level ~= actor:GetAddress() then
        started_for_level = actor:GetAddress()
        start()
    end
end

local function tick()
    if not active then
        attempt("auto start", auto_start)
        return
    end
    local controller = local_controller()
    if controller == nil or #players() == 0 then
        stop("no character")
        return
    end
    local actor = day_actor()
    if (actor and actor:GetAddress() or nil) ~= day_actor_address then
        stop("the level changed")
        return
    end
    if menu_showing or #menu_queue > 0 then
        step("menus")
        if menu_tick() then
            step("waiting on a menu")
            return
        end
    end
    if world_paused(controller) then
        return
    end
    mode_ticks = mode_ticks + 1
    step("day")
    attempt("day", day_tick)
    local own_alive = 0
    step("enemies")
    attempt("enemies", function()
        own_alive = watch_enemies()
    end)
    step("rewards")
    attempt("rewards", reward_tick)
    step("waves")
    attempt("waves", function()
        wave_tick(own_alive)
    end)
    attempt("pickup trimming", trim_tick)
    step("display")
    wave_left = break_ticks > 0 and 0 or own_alive + wave_to_spawn + boss_pending
    banner_tick()
    attempt("hud", refresh_hud)
end

-- Timers -------------------------------------------------------------------------------------------
-- The mod registers no key or mouse hooks and uses no background-thread timers. Callbacks of those run Lua
-- on another thread than the game's, at the same time as the game thread runs this mod's Lua, and the
-- script state does not survive that for long: every crash of 2026-10-05 evening ended inside the Lua core.
-- Both loops below run on the game thread from start to finish.

local function guarded(label, fn)
    return function()
        local ok, err = pcall(fn)
        if not ok and not errors_logged[label] then
            errors_logged[label] = true
            log(label .. " failed: " .. tostring(err))
        end
        -- false: keep looping.
        return false
    end
end

local function start_loop(label, milliseconds, fn)
    local callback = guarded(label, fn)
    if type(LoopInGameThreadWithDelay) == "function" then
        local ok, err = pcall(LoopInGameThreadWithDelay, milliseconds, callback)
        if ok then
            log(label .. ": running on the game thread every " .. milliseconds .. " ms")
            return
        end
        log(label .. ": game-thread timer refused (" .. tostring(err) .. "), using the background timer")
    else
        log(label .. ": this UE4SS has no game-thread timer, using the background timer")
    end
    -- Older UE4SS: the background timer hands the same ready-made function to the game thread each time.
    LoopAsync(milliseconds, function()
        ExecuteInGameThread(callback)
        return false
    end)
end

math.randomseed(os.time())
start_loop("quest board update", BOARD_TICK_MS, board_tick)
start_loop("update", TICK_MS, tick)
log("loaded - choose Endless Mode at the quest board")
