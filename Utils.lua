-- Utils.lua
-- LvlHistory — Fonctions utilitaires partagées
-- Chargé en PREMIER par le .toc — aucune dépendance externe
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory = LvlHistory or {}
LvlHistory.Utils = LvlHistory.Utils or {}
local U = LvlHistory.Utils

-- ─────────────────────────────────────────────
-- Formatage des nombres
-- ─────────────────────────────────────────────

--- Formate un grand nombre avec séparateur de milliers
--- Ex : 1512000 → "1 512 000"
function U.FormatNumber(n)
    if not n or n == 0 then return "0" end
    n = math.floor(n)
    local s = tostring(n)
    local result = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return result:match("^%s*(.-)%s*$")
end

--- Formate une durée en secondes
--- @param seconds number
--- @param short boolean — si true, retourne "Xh XXm" (sans secondes)
function U.FormatTime(seconds, short)
    if not seconds or seconds <= 0 then
        return short and "0m" or "0s"
    end
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60

    if short then
        if h > 0 then
            return string.format("%dh %02dm", h, m)
        else
            return string.format("%dm", m)
        end
    else
        if h > 0 then
            return string.format("%dh %02dm %02ds", h, m, s)
        elseif m > 0 then
            return string.format("%dm %02ds", m, s)
        else
            return string.format("%ds", s)
        end
    end
end

--- Formate un montant en cuivres WoW → "X po Y pa Z pc"
--- @param copper number — montant en cuivres (GetMoney())
--- @param compact boolean — si true, retourne "X.XX po"
function U.FormatGold(copper, compact)
    if not copper then return "0 po" end

    local isNeg = copper < 0
    copper = math.abs(math.floor(copper))

    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    local prefix = isNeg and "-" or ""

    if compact then
        local total = gold + silver / 100
        return string.format("%s%.2f po", prefix, total)
    end

    if gold > 0 then
        return string.format("%s%s|cffFFD700po|r %d|cffc0c0c0pa|r %d|cffb87333pc|r",
            prefix, U.FormatNumber(gold), silver, bronze)
    elseif silver > 0 then
        return string.format("%s%d|cffc0c0c0pa|r %d|cffb87333pc|r", prefix, silver, bronze)
    else
        return string.format("%s%d|cffb87333pc|r", prefix, bronze)
    end
end

--- Formate un XP/h pour affichage
function U.FormatXPH(xph)
    if not xph or xph == 0 then return "— XP/h" end
    xph = math.floor(xph)
    if xph >= 1000000 then
        return string.format("%.1f M XP/h", xph / 1000000)
    elseif xph >= 1000 then
        return string.format("%s K XP/h", U.FormatNumber(math.floor(xph / 1000)))
    else
        return string.format("%d XP/h", xph)
    end
end

-- ─────────────────────────────────────────────
-- Couleurs & texte
-- ─────────────────────────────────────────────

--- Entoure un texte d'un color code WoW (hex RRGGBB)
function U.Colorize(text, hex)
    return string.format("|cff%s%s|r", hex, tostring(text))
end

--- Retourne le label coloré du mode courant
function U.ModeLabel(mode)
    if mode == "farming" then
        return U.Colorize("● FARMING", "F0B429")
    else
        return U.Colorize("● LEVELING", "2ECC71")
    end
end

-- ─────────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────────

--- Copie profonde d'une table (fallback si CopyTable WoW n'est pas dispo)
function U.DeepCopy(orig)
    if CopyTable then return CopyTable(orig) end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = (type(v) == "table") and U.DeepCopy(v) or v
    end
    return copy
end

--- Compte le nombre d'entrées d'une table hash
function U.TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ─────────────────────────────────────────────
-- Debug
-- ─────────────────────────────────────────────

--- Print conditionnel — uniquement si LvlHistory.debug est true
function U.Log(fmt, ...)
    if not LvlHistory.debug then return end
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    print(U.Colorize("[LvlHistory]", "F0B429") .. " " .. msg)
end

--- Print d'erreur — toujours visible
function U.LogError(fmt, ...)
    local msg = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    print(U.Colorize("[LvlHistory] ERREUR:", "FF4444") .. " " .. msg)
end
