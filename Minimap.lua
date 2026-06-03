-- Minimap.lua
-- LvlHistory — Bouton minimap
-- Clic gauche : toggle fenêtre principale
-- Clic droit  : menu contextuel (debug, reset, hide button)
-- Draggable autour de la minimap
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory.Minimap = LvlHistory.Minimap or {}
local MM = LvlHistory.Minimap

-- ─────────────────────────────────────────────
-- Constantes
-- ─────────────────────────────────────────────
local BUTTON_SIZE   = 32
local DEFAULT_ANGLE = 220

-- ─────────────────────────────────────────────
-- Position angulaire autour de la minimap
-- ─────────────────────────────────────────────

local function UpdatePosition(button, angle)
    -- Rayon +10 : standard DBIcon / RenTracker, compat ElvUI / Dominos
    local radius = (Minimap:GetWidth() / 2) + 10
    local rad    = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(rad) * radius,
        math.sin(rad) * radius)
end

-- ─────────────────────────────────────────────
-- Construction du bouton
-- Pattern identique à RenTracker (DBIcon-standard) :
--   • CreateMaskTexture() pour masques circulaires
--   • Icône 24×24 centrée
--   • Ring 52×52 ancré TOPLEFT (offset standard DBIcon)
--   • Highlight manuel _hl via OnEnter/OnLeave
--   • SetMovable(false) + SetToplevel(true)
--   • Rayon +10 (compat ElvUI / Dominos / SexyMap)
--   • Watcher MINIMAP_UPDATE_ZOOM pour recalcul dynamique
-- ─────────────────────────────────────────────

local minimapButton
local isDragging = false

local function BuildButton()
    -- ── Cadre principal ────────────────────────────────────────────
    minimapButton = CreateFrame("Button", "LvlHistoryMinimapButton", Minimap)
    minimapButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetMovable(false)
    minimapButton:EnableMouse(true)
    minimapButton:SetClampedToScreen(true)
    minimapButton:SetToplevel(true)

    -- ── Couche 1 : icône custom avec mask circulaire (ARTWORK) ─────
    -- Icône 24×24 — taille standard des icônes minimap Blizzard.
    -- CreateMaskTexture() est l'API moderne (remplace SetMask).
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    icon:SetSize(24, 24)
    icon:SetTexture("Interface\\AddOns\\LvlHistory\\Media\\icon")
    local mask = minimapButton:CreateMaskTexture()
    mask:SetAllPoints(icon)
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(mask)

    -- ── Couche 2 : ring doré Blizzard (OVERLAY) ────────────────────
    -- Offset TOPLEFT + 52×52 : pattern exact DBIcon / addons Blizzard.
    local ring = minimapButton:CreateTexture(nil, "OVERLAY")
    ring:SetSize(52, 52)
    ring:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- ── Couche 3 : highlight au survol (ARTWORK géré manuellement) ─
    -- On ne pas utiliser le layer HIGHLIGHT natif : il ignore les masks.
    -- Deux textures ARTWORK pilotées via OnEnter/OnLeave.
    local hl = minimapButton:CreateTexture(nil, "ARTWORK")
    hl:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
    hl:SetSize(20, 20)
    hl:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    hl:SetVertexColor(1, 1, 1, 0.25)
    hl:SetAlpha(0) -- caché par défaut
    local hlMask = minimapButton:CreateMaskTexture()
    hlMask:SetAllPoints(hl)
    hlMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    hl:AddMaskTexture(hlMask)
    minimapButton._hl = hl

    -- ── Tooltip + highlight ────────────────────────────────────────
    minimapButton:SetScript("OnEnter", function(self)
        if self._hl then self._hl:SetAlpha(1) end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(LvlHistory.Utils.Colorize("LvlHistory", "F0B429"))
        GameTooltip:AddLine(" ")

        local db = LvlHistory.db
        if db then
            GameTooltip:AddDoubleLine("Mode",
                LvlHistory.Utils.ModeLabel(db.mode), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine("Niveau",
                tostring(db.level or UnitLevel("player")), 0.7, 0.7, 0.7, 1, 1, 1)

            if db.mode == "leveling" then
                GameTooltip:AddDoubleLine("XP/h",
                    LvlHistory.Utils.FormatXPH(db.session.xph), 0.7, 0.7, 0.7, 1, 1, 1)
            else
                GameTooltip:AddDoubleLine("Or/h",
                    LvlHistory.Utils.FormatGold(db.farming.goldPerHour, true),
                    0.7, 0.7, 0.7, 1, 1, 1)
            end

            local elapsed = time() - (db.session.startTime or time())
            GameTooltip:AddDoubleLine("Session",
                LvlHistory.Utils.FormatTime(elapsed, true), 0.7, 0.7, 0.7, 1, 1, 1)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFD700Clic gauche|r : Ouvrir/Fermer", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("|cFFFFD700Clic droit|r  : Options",       0.7, 0.7, 0.7)
        GameTooltip:AddLine("|cFFFFD700Glisser|r     : Repositionner", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function(self)
        if self._hl then self._hl:SetAlpha(0) end
        GameTooltip:Hide()
    end)

    -- ── Position initiale ──────────────────────────────────────────
    -- Restaurée depuis la DB (220° = bas-gauche par défaut, comme DBIcon)
    local savedAngle = (LvlHistoryDB and LvlHistoryDB.settings and LvlHistoryDB.settings.minimapAngle)
        or DEFAULT_ANGLE
    UpdatePosition(minimapButton, savedAngle)

    -- Repositionne si la minimap change de taille (ElvUI, Dominos, etc.)
    minimapButton:SetScript("OnShow", function()
        local angle = (LvlHistoryDB and LvlHistoryDB.settings and LvlHistoryDB.settings.minimapAngle)
            or DEFAULT_ANGLE
        UpdatePosition(minimapButton, angle)
    end)

    -- ── Drag orbital ───────────────────────────────────────────────
    -- Angle calculé en temps réel via atan2 depuis le centre de la minimap.
    -- SetMovable(false) : WoW ne gère pas le déplacement librement.
    minimapButton:RegisterForDrag("LeftButton")

    minimapButton:SetScript("OnDragStart", function(self)
        isDragging = true
        self:SetScript("OnUpdate", function()
            local mx, my  = Minimap:GetCenter()
            local uiScale = UIParent:GetEffectiveScale()
            local cx, cy  = GetCursorPosition()
            local angle = math.deg(math.atan2(
                (cy / uiScale) - my,
                (cx / uiScale) - mx
            ))
            if LvlHistoryDB and LvlHistoryDB.settings then
                LvlHistoryDB.settings.minimapAngle = angle
            end
            UpdatePosition(self, angle)
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    -- ── Watcher MINIMAP_UPDATE_ZOOM ────────────────────────────────
    -- Certains addons (Dominos, SexyMap) redimensionnent la minimap.
    -- On recalcule le rayon à chaque changement de zoom/taille.
    local resizeWatcher = CreateFrame("Frame")
    resizeWatcher:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    resizeWatcher:SetScript("OnEvent", function()
        local angle = (LvlHistoryDB and LvlHistoryDB.settings and LvlHistoryDB.settings.minimapAngle)
            or DEFAULT_ANGLE
        UpdatePosition(minimapButton, angle)
    end)

    -- ── Clics ──────────────────────────────────────────────────────
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    minimapButton:SetScript("OnClick", function(self, button)
        if isDragging then return end

        if button == "LeftButton" then
            LvlHistory.UI.Toggle()
        elseif button == "RightButton" then
            MM.ShowContextMenu(self)
        end
    end)
end

-- ─────────────────────────────────────────────
-- Menu contextuel (clic droit)
-- ─────────────────────────────────────────────

local contextMenu

function MM.ShowContextMenu(anchor)
    if not contextMenu then
        contextMenu = CreateFrame("Frame", "LvlHistoryContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    local menuList = {
        {
            text         = LvlHistory.Utils.Colorize("LvlHistory", "F0B429"),
            isTitle      = true,
            notCheckable = true,
        },
        {
            text         = "Ouvrir / Fermer",
            notCheckable = true,
            func         = function() LvlHistory.UI.Toggle() end,
        },
        {
            text         = "Debug : " .. (LvlHistory.debug and "|cff2ECC71ON|r" or "|cffFF4444OFF|r"),
            notCheckable = true,
            func         = function()
                LvlHistory.debug = not LvlHistory.debug
                if LvlHistoryDB and LvlHistoryDB.settings then
                    LvlHistoryDB.settings.debug = LvlHistory.debug
                end
                CloseDropDownMenus()
            end,
        },
        {
            text         = "Masquer le bouton",
            notCheckable = true,
            func         = function()
                MM.Hide()
                if LvlHistoryDB and LvlHistoryDB.settings then
                    LvlHistoryDB.settings.minimapButton = false
                end
                CloseDropDownMenus()
                LvlHistory.Utils.Log("Bouton masqué — /lvlh minimap pour réafficher")
            end,
        },
        { text = " ", notCheckable = true, disabled = true },
        {
            text         = "|cffFF4444Réinitialiser ce perso|r",
            notCheckable = true,
            func         = function()
                CloseDropDownMenus()
                print(LvlHistory.Utils.Colorize("[LvlHistory]", "F0B429")
                    .. " Tapez |cffFFFFFF/lvlh reset confirm|r pour confirmer.")
            end,
        },
    }

    EasyMenu(menuList, contextMenu, anchor, 0, 0, "MENU")
end

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────

function MM.Show()
    if not minimapButton then BuildButton() end
    minimapButton:Show()
end

function MM.Hide()
    if minimapButton then minimapButton:Hide() end
end

function MM.Toggle()
    if not minimapButton then
        MM.Show()
        return
    end
    if minimapButton:IsShown() then
        MM.Hide()
    else
        MM.Show()
    end
end

function MM.IsShown()
    return minimapButton and minimapButton:IsShown() or false
end

--- Appelé par Core.lua après PLAYER_LOGIN
function MM.Init()
    local show = true
    if LvlHistoryDB and LvlHistoryDB.settings then
        show = LvlHistoryDB.settings.minimapButton ~= false
    end
    if show then MM.Show() end
end
