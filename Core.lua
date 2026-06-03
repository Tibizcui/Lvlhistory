-- Core.lua
-- LvlHistory — Init, events globaux, gestion du mode switch
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory = LvlHistory or {}
local T = LvlHistory

-- ─────────────────────────────────────────────
-- Constantes
-- ─────────────────────────────────────────────
local ADDON_VERSION = "0.1.0"
local SAVE_INTERVAL = 300  -- sauvegarde incrémentale toutes les 5 minutes

-- Structure par défaut d'un personnage
local CHAR_DEFAULTS = {
    mode      = "leveling",
    level     = 1,
    class     = "",
    sessions  = {},
    zones        = {},
    dgnRuns      = {},          -- { ["Nom Donjon"] = count } — total persistant
    dgnDetails   = {},          -- { ["Nom||Difficulte"] = count } — détail persistant
    dgnBestKey   = {},          -- { ["Nom Donjon"] = highestKeyLevel } — meilleure clé M+
    dgnLog       = {},          -- [ { name, diff, ts } ] — historique individuel persistant
    totalPlayTime = 0,          -- secondes cumulées toutes sessions (persistant)
    _dgn         = {            -- état du run de donjon en cours (survit aux reloads)
        inInstance   = false,
        zoneName     = "",
        bossKills    = 0,
        countedByLFG = false,
        diffName     = "",      -- difficulté mémorisée au premier boss kill
    },
    quests    = { total = 0, daily = 0, list = {} },
    farming   = { gold = 0, goldPerHour = 0, rep = {}, currencies = {} },
    session   = {
        startTime     = 0,
        xpAtStart     = 0,
        goldAtStart   = 0,
        xph           = 0,
        zone          = "",
        zoneEnteredAt = 0,
        zoneIsInstance = false,   -- true quand la zone courante est une instance
        levelStart    = 1,
        questCount    = 0,
        dungeons      = 0,
    },
}

-- Structure par défaut de LvlHistoryDB
local DB_DEFAULTS = {
    version  = 1,
    chars    = {},
    settings = {
        maxStoredSessions = 500,
        minimapButton     = true,
        minimapAngle      = 220,
        sessionAlert      = true,
        debug             = false,
        alpha             = 0.97,   -- opacite du frame principal (0.3 - 1.0)
        collapsed         = false,  -- etat reduit persistant
    },
}

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function InitChar()
    local key = GetCharKey()
    LvlHistoryDB.chars = LvlHistoryDB.chars or {}

    if not LvlHistoryDB.chars[key] then
        LvlHistoryDB.chars[key] = CopyTable(CHAR_DEFAULTS)
        LvlHistoryDB.chars[key].level = UnitLevel("player")
        LvlHistoryDB.chars[key].class = select(2, UnitClass("player"))
    end

    return LvlHistoryDB.chars[key]
end

local function SetMode(db)
    local isMax = UnitLevel("player") >= GetMaxPlayerLevel()
    local oldMode = db.mode
    db.mode  = isMax and "farming" or "leveling"
    db.level = UnitLevel("player")

    if isMax then
        T.Farming.Start()
    else
        T.Leveling.Start()
    end

    T.Bridge.Emit("onModeSwitch", oldMode, db.mode)
end

local function SaveCurrentSession()
    local db = T.db
    if not db then return end

    local elapsed = time() - db.session.startTime
    if elapsed < 60 then return end

    -- Cumul de temps total joué (persistant)
    db.totalPlayTime = (db.totalPlayTime or 0) + elapsed
    db.session.startTime = time()  -- reset pour éviter le double-comptage au prochain save

    local snapshot = {
        date       = db.session.startTime,
        mode       = db.mode,
        duration   = elapsed,
        zone       = db.session.zone,
        xpGained   = (db.mode == "leveling") and (UnitXP("player") - db.session.xpAtStart) or 0,
        xph        = db.session.xph or 0,
        levelStart = db.session.levelStart or db.level,
        levelEnd   = UnitLevel("player"),
        quests     = db.session.questCount or 0,
        dungeons   = db.session.dungeons or 0,
        goldGained = math.max(0, GetMoney() - (db.session.goldAtStart or GetMoney())),
    }

    local sessions = db.sessions
    if #sessions >= LvlHistoryDB.settings.maxStoredSessions then
        table.remove(sessions, 1)
    end
    table.insert(sessions, snapshot)

    T.Bridge.Emit("onSessionEnd", snapshot)
end

-- ─────────────────────────────────────────────
-- Frame principale & events
-- ─────────────────────────────────────────────
local coreFrame = CreateFrame("Frame", "LvlHistoryCoreFrame", UIParent)

coreFrame:RegisterEvent("PLAYER_LOGIN")
coreFrame:RegisterEvent("PLAYER_LOGOUT")
coreFrame:RegisterEvent("PLAYER_LEVEL_UP")

coreFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Init défensive : ne jamais écraser des données existantes
        LvlHistoryDB = LvlHistoryDB or CopyTable(DB_DEFAULTS)
        LvlHistoryDB.settings = LvlHistoryDB.settings or CopyTable(DB_DEFAULTS.settings)

        local db = InitChar()
        T.db      = db
        T.charKey = GetCharKey()
        T.debug   = LvlHistoryDB.settings.debug

        -- Initialiser la session courante (non persistée entre reloads)
        db.session.startTime    = time()
        db.session.xpAtStart    = UnitXP("player")
        db.session.goldAtStart  = GetMoney()
        db.session.levelStart   = UnitLevel("player")
        db.session.zone         = GetRealZoneText() or "Unknown"
        db.session.zoneEnteredAt = time()
        db.session.questCount    = 0
        db.session.dungeons      = 0
        db.session.xph           = 0
        db.session.zoneIsInstance = IsInInstance() or false

        -- Init défensive (compatibilité avec les saves antérieures)
        db.dgnRuns    = db.dgnRuns    or {}
        db.dgnDetails = db.dgnDetails or {}
        db.dgnLog     = db.dgnLog     or {}

        -- Migration : supprimer de db.zones les noms qui correspondent à des donjons connus
        -- (données enregistrées avant l'ajout du filtre zoneIsInstance)
        for dgnName in pairs(db.dgnRuns) do
            if db.zones[dgnName] then
                db.zones[dgnName] = nil
                T.Utils.Log("Zone purgee (instance detectee) : %s", dgnName)
            end
        end
        db._dgn       = db._dgn or {
            inInstance = false, zoneName = "", bossKills = 0, countedByLFG = false,
        }

        -- Réconciliation après reload : si on était dans une instance et qu'on n'y est plus,
        -- le run peut avoir été complété entre le logout et le reload
        if db._dgn.inInstance then
            local inInst, instType = IsInInstance()
            if not inInst then
                -- Sorti de l'instance entre le logout et le reload
                if not db._dgn.countedByLFG
                    and db._dgn.bossKills > 0
                    and db._dgn.zoneName ~= "" then
                    -- Enregistrement différé (RecordDungeon sera dispo après cette init)
                    C_Timer.After(0, function()
                        if T.db then
                            T.db.dgnRuns[T.db._dgn.zoneName] =
                                (T.db.dgnRuns[T.db._dgn.zoneName] or 0) + 1
                            T.db.session.dungeons = (T.db.session.dungeons or 0) + 1
                            T.Bridge.Emit("onDungeonCompleted",
                                T.db._dgn.zoneName, T.db.dgnRuns[T.db._dgn.zoneName])
                        end
                        T.db._dgn = {
                            inInstance = false, zoneName = "", bossKills = 0, countedByLFG = false,
                        }
                    end)
                else
                    db._dgn = {
                        inInstance = false, zoneName = "", bossKills = 0, countedByLFG = false,
                    }
                end
            end
            -- Si toujours dans l'instance : on garde l'état pour continuer le run
        end

        -- Démarrer le bon mode
        SetMode(db)

        -- Bouton minimap
        T.Minimap.Init()

        -- Sauvegarde incrémentale toutes les 5 minutes
        C_Timer.NewTicker(SAVE_INTERVAL, function()
            SaveCurrentSession()
        end)

        T.Utils.Log("v%s chargé — %s — Mode: %s", ADDON_VERSION, T.charKey, db.mode)

    elseif event == "PLAYER_LOGOUT" then
        SaveCurrentSession()

    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        local db = T.db
        if not db then return end

        db.level = newLevel

        if newLevel >= GetMaxPlayerLevel() then
            T.Leveling.Stop()
            local oldMode = db.mode
            db.mode = "farming"
            T.Farming.Start()
            T.Bridge.Emit("onModeSwitch", oldMode, "farming")

            if LvlHistoryDB.settings.sessionAlert then
                print(T.Utils.Colorize("[LvlHistory]", "F0B429")
                    .. " Niveau maximum atteint — passage en mode FARMING")
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Tracking donjons (mode-agnostic)
-- Couvre : LFD (N/H/M), Mythic+ et groupes manuels
-- ─────────────────────────────────────────────

-- Accesseur sécurisé vers l'état persisté du run en cours
-- db._dgn est dans les SavedVariables — survit aux /reload
local function Dgn()
    return T.db and T.db._dgn
end

local function DgnReset()
    if T.db then
        T.db._dgn = {
            inInstance = false, zoneName = "", bossKills = 0, countedByLFG = false,
        }
    end
end

local function GetDifficultyLabel()
    -- GetInstanceInfo() : name, type, difficultyID, difficultyName, ...
    local _, _, diffID, diffName = GetInstanceInfo()
    if not diffName or diffName == "" then return "?" end
    return diffName
end

local function RecordDungeon(name, diffName)
    local db = T.db
    if not db then return end
    if not name or name == "" then return end

    diffName = diffName or GetDifficultyLabel()

    -- Total toutes difficultés
    db.dgnRuns[name]    = (db.dgnRuns[name] or 0) + 1
    db.session.dungeons = (db.session.dungeons or 0) + 1

    -- Détail par difficulté : clé "Nom||Difficulte"
    local detailKey = name .. "||" .. diffName
    db.dgnDetails[detailKey] = (db.dgnDetails[detailKey] or 0) + 1

    -- Log individuel (persistant entre sessions, plus recent en dernier)
    if not db.dgnLog then db.dgnLog = {} end
    table.insert(db.dgnLog, { name = name, diff = diffName, ts = time() })
    if #db.dgnLog > 1000 then table.remove(db.dgnLog, 1) end

    T.Bridge.Emit("onDungeonCompleted", name, db.dgnRuns[name], diffName)
    T.Utils.Log("Donjon: %s [%s] | Total: %d", name, diffName, db.dgnRuns[name])
end

local dgnFrame = CreateFrame("Frame", "LvlHistoryDgnFrame", UIParent)
dgnFrame:RegisterEvent("LFG_COMPLETION_REWARD")    -- LFD : N / H / M group finder
dgnFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED") -- Mythic+
dgnFrame:RegisterEvent("ENCOUNTER_END")            -- tout boss (groupes manuels)
dgnFrame:RegisterEvent("PLAYER_ENTERING_WORLD")    -- détection sortie d'instance

dgnFrame:SetScript("OnEvent", function(self, event, ...)

    -- ── LFD (Chercheur de donjon) ──────────────────────────────────────────
    if event == "LFG_COMPLETION_REWARD" then
        local zoneName = GetRealZoneText() or ""
        RecordDungeon(zoneName)
        local d = Dgn(); if d then d.countedByLFG = true end

    -- ── Mythic+ ────────────────────────────────────────────────────────────
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
            and C_ChallengeMode.GetActiveChallengeMapID()
        local zoneName
        if mapID then
            local info = C_ChallengeMode.GetMapUIInfo(mapID)
            zoneName = info and info.name or GetRealZoneText() or ""
        else
            zoneName = GetRealZoneText() or ""
        end
        -- Capturer le niveau de clé via GetCompletionInfo (disponible au moment de l'event)
        if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
            local _, keyLevel = C_ChallengeMode.GetCompletionInfo()
            if keyLevel and keyLevel > 0 and zoneName ~= "" then
                db.dgnBestKey = db.dgnBestKey or {}
                if not db.dgnBestKey[zoneName] or keyLevel > db.dgnBestKey[zoneName] then
                    db.dgnBestKey[zoneName] = keyLevel
                end
            end
        end
        RecordDungeon(zoneName)
        local d = Dgn(); if d then d.countedByLFG = true end

    -- ── Groupes manuels : boss tué avec succès ─────────────────────────────
    elseif event == "ENCOUNTER_END" then
        local success = select(5, ...)
        if success ~= 1 then return end

        local inInst, instType = IsInInstance()
        if not inInst or instType ~= "party" then return end

        local d = Dgn()
        if not d then return end

        -- Persisté dans db._dgn → survit au /reload
        d.inInstance = true
        d.zoneName   = GetRealZoneText() or d.zoneName
        d.bossKills  = (d.bossKills or 0) + 1
        -- Mémoriser la difficulté au premier boss (elle ne change pas en cours de run)
        if not d.diffName or d.diffName == "" then
            d.diffName = GetDifficultyLabel()
        end

    -- ── Transition de zone / sortie d'instance ─────────────────────────────
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...

        -- Au reload/login : PLAYER_LOGIN gère la réconciliation via db._dgn persisté.
        -- On ne réinitialise plus ici — l'état est dans les SavedVariables.
        if isInitialLogin or isReloadingUi then return end

        -- T.db doit être disponible (PLAYER_LOGIN déjà passé)
        local d = Dgn()
        if not d then return end

        local inInst, instType = IsInInstance()

        if d.inInstance and not inInst then
            -- Sortie d'instance — enregistrer si pas déjà compté et au moins 1 boss tué
            if not d.countedByLFG and d.bossKills > 0 and d.zoneName ~= "" then
                RecordDungeon(d.zoneName, d.diffName)
            end
            DgnReset()

        elseif inInst and instType == "party" then
            -- Entrée dans un nouveau donjon (pas un reload — géré au-dessus)
            -- Ne reset les bossKills que si on change de zone
            if d.zoneName ~= (GetRealZoneText() or "") then
                d.inInstance   = true
                d.zoneName     = GetRealZoneText() or ""
                d.bossKills    = 0
                d.countedByLFG = false
            end

        elseif not inInst then
            DgnReset()
        end
    end
end)

-- ─────────────────────────────────────────────
-- Commande slash
-- ─────────────────────────────────────────────
SLASH_LVLHISTORY1 = "/lvlh"
SlashCmdList["LVLHISTORY"] = function(msg)
    local cmd = strtrim(msg):lower()

    if cmd == "" then
        T.UI.Toggle()

    elseif cmd == "minimap" then
        T.Minimap.Toggle()
        if LvlHistoryDB then
            LvlHistoryDB.settings.minimapButton = T.Minimap.IsShown and T.Minimap.IsShown() or true
        end

    elseif cmd == "debug" then
        T.debug = not T.debug
        LvlHistoryDB.settings.debug = T.debug
        print(T.Utils.Colorize("[LvlHistory]", "F0B429") .. " Debug: " .. (T.debug and "ON" or "OFF"))

    elseif cmd == "reset" then
        print(T.Utils.Colorize("[LvlHistory]", "F0B429")
            .. " Tapez |cffFFFFFF/lvlh reset confirm|r pour confirmer la réinitialisation.")

    elseif cmd == "reset confirm" then
        LvlHistoryDB.chars[T.charKey] = nil
        ReloadUI()

    else
        print(T.Utils.Colorize("[LvlHistory]", "F0B429") .. " Commandes disponibles :")
        print("  /lvlh          — Ouvrir/Fermer la fenêtre")
        print("  /lvlh minimap  — Afficher/Masquer le bouton minimap")
        print("  /lvlh debug    — Activer/Désactiver le mode debug")
        print("  /lvlh reset    — Réinitialiser les données du personnage")
    end
end
