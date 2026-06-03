-- Bridge.lua
-- LvlHistory — Communication optionnelle avec la TibiSuite
-- Principe : LvlHistory est émetteur, les autres addons sont abonnés optionnels.
-- Aucune dépendance obligatoire — lecture seule vers l'extérieur.
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory = LvlHistory or {}
LvlHistory.Bridge = LvlHistory.Bridge or {}
local B = LvlHistory.Bridge

-- ─────────────────────────────────────────────
-- Registre de callbacks
-- ─────────────────────────────────────────────

local hooks = {
    onRepGain     = {},  -- (factionName, gained, perHour)
    onQuestTurnIn = {},  -- (questID, isDaily)
    onModeSwitch  = {},  -- (oldMode, newMode)
    onSessionEnd  = {},  -- (sessionSnapshot)
}

--- Enregistre un callback sur un événement LvlHistory
--- @param event string      — clé du hook (ex: "onRepGain")
--- @param addonName string  — nom de l'addon abonné (pour debug)
--- @param fn function       — callback à appeler
function B.Register(event, addonName, fn)
    if not hooks[event] then
        LvlHistory.Utils.LogError("Bridge.Register : event inconnu '%s' (demandé par %s)", event, addonName)
        return
    end
    table.insert(hooks[event], { name = addonName, fn = fn })
    LvlHistory.Utils.Log("Bridge : %s abonné à '%s'", addonName, event)
end

--- Émet un événement vers tous les abonnés (appel interne uniquement)
--- pcall isole chaque abonné — une erreur d'un addon tiers ne casse pas LvlHistory.
function B.Emit(event, ...)
    if not hooks[event] then return end
    for _, subscriber in ipairs(hooks[event]) do
        local ok, err = pcall(subscriber.fn, ...)
        if not ok then
            LvlHistory.Utils.LogError("Bridge.Emit '%s' → %s : %s", event, subscriber.name, tostring(err))
        end
    end
end

-- ─────────────────────────────────────────────
-- Exemple d'intégration côté RenTracker
-- (à placer dans RenTracker, pas ici)
-- ─────────────────────────────────────────────
--[[
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "LvlHistory" then
        LvlHistory.Bridge.Register("onRepGain", "RenTracker", function(faction, gained, perHour)
            RenTracker.OnLvlHistoryRepGain(faction, gained, perHour)
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
--]]

-- ─────────────────────────────────────────────
-- Exemple d'intégration côté dailyTracker
-- (à placer dans dailyTracker, pas ici)
-- ─────────────────────────────────────────────
--[[
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "LvlHistory" then
        LvlHistory.Bridge.Register("onQuestTurnIn", "dailyTracker", function(questID, isDaily)
            if isDaily then
                dailyTracker.OnLvlHistoryDaily(questID)
            end
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
--]]
