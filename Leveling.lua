-- Leveling.lua
-- LvlHistory — Logique MODE_LEVELING
-- Trackée : XP/h, zones, quêtes, donjons
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory.Leveling = LvlHistory.Leveling or {}
local L = LvlHistory.Leveling

local levelingFrame
local isRunning = false

-- XP totale accumulée sur les niveaux passés pendant la session
-- (nécessaire car UnitXP() se remet à 0 à chaque level up)
local levelXPAccumulated = 0

-- ─────────────────────────────────────────────
-- Handlers d'events
-- ─────────────────────────────────────────────

local function OnXPUpdate()
    local db = LvlHistory.db
    if not db then return end

    local currentXP   = UnitXP("player")
    local totalGained = levelXPAccumulated + (currentXP - db.session.xpAtStart)
    local elapsed     = time() - db.session.startTime

    if elapsed >= 10 then
        db.session.xph = math.floor(totalGained / elapsed * 3600)
    end

    LvlHistory.Utils.Log("XP/h: %d", db.session.xph)
end

local function OnLevelUp(newLevel)
    local db = LvlHistory.db
    if not db then return end

    -- Accumuler l'XP du niveau terminé avant que UnitXP() repart à 0
    levelXPAccumulated = levelXPAccumulated + UnitXPMax("player")
    db.session.xpAtStart = 0
    db.level = newLevel

    LvlHistory.Utils.Log("Level up -> %d | XP accumulée: %d", newLevel, levelXPAccumulated)
end

local function OnZoneChange()
    local db = LvlHistory.db
    if not db then return end

    local newZone          = GetRealZoneText() or "Unknown"
    local oldZone          = db.session.zone
    local inInst, instType = IsInInstance()

    -- N'enregistre le temps que si l'ancienne zone n'était PAS une instance.
    -- Double protection :
    --   1. db.session.zoneIsInstance : flag positionné à l'entrée de la zone précédente
    --   2. db.dgnRuns[oldZone] : si le nom figure dans les donjons connus, on ignore aussi
    local wasInstance = db.session.zoneIsInstance
        or (db.dgnRuns and db.dgnRuns[oldZone] ~= nil)
    if oldZone and oldZone ~= "" and not wasInstance then
        local elapsed = time() - (db.session.zoneEnteredAt or db.session.startTime)
        db.zones[oldZone] = (db.zones[oldZone] or 0) + elapsed
    end

    db.session.zone           = newZone
    db.session.zoneEnteredAt  = time()
    db.session.zoneIsInstance = inInst   -- mémorisé pour le prochain changement de zone

    LvlHistory.Utils.Log("Zone: %s%s", newZone, inInst and " [instance]" or "")
end

local function OnQuestTurnIn(questID)
    local db = LvlHistory.db
    if not db then return end

    db.quests.total       = (db.quests.total or 0) + 1
    db.session.questCount = (db.session.questCount or 0) + 1

    -- C_QuestLog.IsQuestRepeatable a été renommé selon les versions de WoW
    local isRepeatableFn = C_QuestLog.IsQuestRepeatable or C_QuestLog.IsRepeatableQuest
    local isDaily = questID and isRepeatableFn and isRepeatableFn(questID) or false
    if isDaily then
        db.quests.daily = (db.quests.daily or 0) + 1
    end

    LvlHistory.Bridge.Emit("onQuestTurnIn", questID, isDaily)
    LvlHistory.Utils.Log("Quête rendue (ID: %s) | Total: %d", tostring(questID), db.quests.total)
end

-- Note : le comptage des donjons (session + total) est gere de facon
-- mode-agnostique par Core.lua (dgnFrame / RecordDungeon). On n'ecoute donc
-- PAS CHALLENGE_MODE_COMPLETED ici, pour eviter un double comptage.

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────

function L.Start()
    if isRunning then return end
    isRunning = true

    levelXPAccumulated = 0

    levelingFrame = levelingFrame or CreateFrame("Frame", "LvlHistoryLevelingFrame", UIParent)
    levelingFrame:RegisterEvent("PLAYER_XP_UPDATE")
    levelingFrame:RegisterEvent("PLAYER_LEVEL_UP")
    levelingFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    levelingFrame:RegisterEvent("QUEST_TURNED_IN")

    levelingFrame:SetScript("OnEvent", function(self, event, ...)
        if      event == "PLAYER_XP_UPDATE"        then OnXPUpdate()
        elseif  event == "PLAYER_LEVEL_UP"          then OnLevelUp(...)
        elseif  event == "ZONE_CHANGED_NEW_AREA"    then OnZoneChange()
        elseif  event == "QUEST_TURNED_IN"          then OnQuestTurnIn(...)
        end
    end)

    local db = LvlHistory.db
    if db then
        db.session.zone         = GetRealZoneText() or "Unknown"
        db.session.zoneEnteredAt = time()
    end

    LvlHistory.Utils.Log("Mode LEVELING démarré")
end

function L.Stop()
    if not isRunning then return end
    isRunning = false

    if levelingFrame then
        levelingFrame:UnregisterAllEvents()
    end

    -- Flush la zone courante
    local db = LvlHistory.db
    if db and db.session.zone and db.session.zone ~= "" then
        local elapsed = time() - (db.session.zoneEnteredAt or db.session.startTime)
        db.zones[db.session.zone] = (db.zones[db.session.zone] or 0) + elapsed
    end

    LvlHistory.Utils.Log("Mode LEVELING arrêté")
end

function L.GetXPH()
    local db = LvlHistory.db
    return db and db.session.xph or 0
end

--- XP totale gagnee sur la session courante, en tenant compte des level ups.
--- (UnitXP() repart a 0 a chaque niveau, d'ou l'accumulateur.)
function L.GetSessionXP()
    local db = LvlHistory.db
    if not db then return 0 end
    return levelXPAccumulated + (UnitXP("player") - (db.session.xpAtStart or 0))
end

--- Retourne le top N des zones par temps passé
function L.GetTopZones(n)
    local db = LvlHistory.db
    if not db then return {} end

    local sorted = {}
    for zone, duration in pairs(db.zones) do
        table.insert(sorted, { zone = zone, duration = duration })
    end
    table.sort(sorted, function(a, b) return a.duration > b.duration end)

    local result = {}
    for i = 1, math.min(n or 5, #sorted) do
        result[i] = sorted[i]
    end
    return result
end
