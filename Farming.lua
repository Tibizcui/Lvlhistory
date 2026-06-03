-- Farming.lua
-- LvlHistory — Logique MODE_FARMING
-- Trackée : or/h, réputation/h, ressources, journalières, zones
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory.Farming = LvlHistory.Farming or {}
local F = LvlHistory.Farming

local farmingFrame
local isRunning = false

-- ─────────────────────────────────────────────
-- Handlers d'events
-- ─────────────────────────────────────────────

local function OnMoneyUpdate()
    local db = LvlHistory.db
    if not db then return end

    local currentGold = GetMoney()
    local lastGold    = db.session.lastGold or currentGold
    local elapsed     = time() - db.session.startTime

    -- On comptabilise UNIQUEMENT les gains (delta positif).
    -- Les achats / réparations / enchantements réduisent l'or mais
    -- ne doivent pas impacter le calcul Or/h — on les ignore.
    if currentGold > lastGold then
        local gained = currentGold - lastGold
        db.farming.goldEarned = (db.farming.goldEarned or 0) + gained
    end
    db.session.lastGold = currentGold

    if elapsed >= 10 and (db.farming.goldEarned or 0) > 0 then
        db.farming.goldPerHour = math.floor(db.farming.goldEarned / elapsed * 3600)
    end

    db.farming.gold = db.farming.goldEarned or 0

    LvlHistory.Utils.Log("Or/h: %d | Gagne session: %d",
        db.farming.goldPerHour or 0, db.farming.gold)
end

-- Helpers réputation : encapsulés pour protéger contre les APIs instables en 12.x
local function GetRepEarnedValue(data)
    -- currentReactionThreshold peut être nil sur certaines réputations 12.x
    return (data.currentReactionThreshold or 0) + (data.currentValue or 0)
end

local function IterateFactions(callback)
    -- Chemin 1 : API moderne Retail 10.x+
    if C_Reputation and C_Reputation.GetAllFactionsByCriteria then
        local ok, factionIDs = pcall(C_Reputation.GetAllFactionsByCriteria, {})
        if ok and factionIDs then
            for _, factionID in ipairs(factionIDs) do
                local data = C_Reputation.GetFactionDataByID(factionID)
                if data and not data.isHeader and data.name then
                    callback(data.name, GetRepEarnedValue(data))
                end
            end
            return
        end
    end
    -- Chemin 2 : faction regardée uniquement (fallback sûr pour Retail 12.x)
    -- GetNumFactions/GetFactionInfo sont cassés en 12.x — on les évite totalement.
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = C_Reputation.GetWatchedFactionData()
        if data and data.name then
            callback(data.name, (data.currentValue or 0))
        end
    end
end

local function OnFactionUpdate()
    local db = LvlHistory.db
    if not db then return end

    IterateFactions(function(name, earnedValue)
        local prev = db.farming.rep[name]
        if prev and prev.value and earnedValue > prev.value then
            local gained = earnedValue - prev.value
            prev.gained  = (prev.gained or 0) + gained
            prev.value   = earnedValue

            local elapsed = time() - db.session.startTime
            if elapsed >= 10 then
                prev.perHour = math.floor(prev.gained / elapsed * 3600)
            end

            LvlHistory.Bridge.Emit("onRepGain", name, gained, prev.perHour)
        elseif not prev then
            db.farming.rep[name] = { value = earnedValue, gained = 0, perHour = 0 }
        end
    end)
end

local function OnCurrencyUpdate()
    local db = LvlHistory.db
    if not db then return end

    local numCurrencies = C_CurrencyInfo.GetCurrencyListSize()
    for i = 1, numCurrencies do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and not info.isHeader and info.name then
            local name    = info.name
            local current = info.quantity

            if db.farming.currencies[name] then
                local diff = current - db.farming.currencies[name].last
                if diff > 0 then
                    db.farming.currencies[name].gained = (db.farming.currencies[name].gained or 0) + diff
                end
                db.farming.currencies[name].last = current
            else
                db.farming.currencies[name] = { last = current, gained = 0 }
            end
        end
    end
end

local function OnQuestTurnIn(questID)
    local db = LvlHistory.db
    if not db then return end

    db.quests.total       = (db.quests.total or 0) + 1
    db.session.questCount = (db.session.questCount or 0) + 1

    local isRepeatableFn = C_QuestLog.IsQuestRepeatable or C_QuestLog.IsRepeatableQuest
    local isDaily = questID and isRepeatableFn and isRepeatableFn(questID) or false
    if isDaily then
        db.quests.daily = (db.quests.daily or 0) + 1
    end

    LvlHistory.Bridge.Emit("onQuestTurnIn", questID, isDaily)
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
    db.session.zoneIsInstance = inInst

    LvlHistory.Utils.Log("Zone: %s%s", newZone, inInst and " [instance]" or "")
end

-- ─────────────────────────────────────────────
-- Init des réputations au démarrage du mode
-- ─────────────────────────────────────────────

local function SnapshotReputations()
    local db = LvlHistory.db
    if not db then return end

    -- Snapshot initial via le même itérateur sécurisé qu'OnFactionUpdate
    IterateFactions(function(name, earnedValue)
        if not db.farming.rep[name] then
            db.farming.rep[name] = { value = earnedValue, gained = 0, perHour = 0 }
        end
    end)
end

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────

function F.Start()
    if isRunning then return end
    isRunning = true

    local db = LvlHistory.db
    if db then
        local currentGold = GetMoney()
        db.session.goldAtStart   = currentGold
        db.session.lastGold      = currentGold   -- point de référence pour les deltas
        db.farming.goldEarned    = 0             -- cumul gains uniquement (pas les achats)
        db.farming.goldPerHour   = 0
        db.session.zone          = GetRealZoneText() or "Unknown"
        db.session.zoneEnteredAt = time()
        SnapshotReputations()
    end

    farmingFrame = farmingFrame or CreateFrame("Frame", "LvlHistoryFarmingFrame", UIParent)
    farmingFrame:RegisterEvent("PLAYER_MONEY")
    farmingFrame:RegisterEvent("UPDATE_FACTION")
    farmingFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    farmingFrame:RegisterEvent("QUEST_TURNED_IN")
    farmingFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    farmingFrame:SetScript("OnEvent", function(self, event, ...)
        if      event == "PLAYER_MONEY"           then OnMoneyUpdate()
        elseif  event == "UPDATE_FACTION"          then OnFactionUpdate()
        elseif  event == "CURRENCY_DISPLAY_UPDATE" then OnCurrencyUpdate()
        elseif  event == "QUEST_TURNED_IN"         then OnQuestTurnIn(...)
        elseif  event == "ZONE_CHANGED_NEW_AREA"   then OnZoneChange()
        end
    end)

    LvlHistory.Utils.Log("Mode FARMING démarré")
end

function F.Stop()
    if not isRunning then return end
    isRunning = false

    if farmingFrame then
        farmingFrame:UnregisterAllEvents()
    end

    LvlHistory.Utils.Log("Mode FARMING arrêté")
end

function F.GetSessionSummary()
    local db = LvlHistory.db
    if not db then return {} end

    return {
        goldGained  = db.farming.gold or 0,
        goldPerHour = db.farming.goldPerHour or 0,
        rep         = db.farming.rep or {},
        currencies  = db.farming.currencies or {},
        quests      = db.session.questCount or 0,
        zone        = db.session.zone,
    }
end

--- Retourne les top N réputations gagnées cette session
function F.GetTopRep(n)
    local db = LvlHistory.db
    if not db then return {} end

    local sorted = {}
    for name, data in pairs(db.farming.rep) do
        if (data.gained or 0) > 0 then
            table.insert(sorted, { name = name, gained = data.gained, perHour = data.perHour })
        end
    end
    table.sort(sorted, function(a, b) return a.gained > b.gained end)

    local result = {}
    for i = 1, math.min(n or 5, #sorted) do
        result[i] = sorted[i]
    end
    return result
end
