-- UI.lua
-- LvlHistory V2 — sobre, lisible, sans caracteres speciaux
-- Tab bar horizontal | 5 panels | header + footer cleans
-- Auteur : Tibizcui | Famille : TibiSuite

LvlHistory.UI = LvlHistory.UI or {}
local UI = LvlHistory.UI

-- ─────────────────────────────────────────────
-- Constantes de mise en page
-- ─────────────────────────────────────────────
local FW = 480   -- largeur totale (etendu)
local FH = 420   -- hauteur totale (etendu)
local HDR_H  = 36
local TAB_H  = 26
local FTR_H  = 24
local CONT_H = FH - HDR_H - TAB_H - FTR_H   -- 334 px
local PAD    = 14

local COMPACT_W    = 340                       -- largeur mode reduit
local COMPACT_HALF = math.floor(COMPACT_W / 2) -- 170

-- ─────────────────────────────────────────────
-- Palette (hex → 0-1 RGB)
-- ─────────────────────────────────────────────
local C = {
    BG       = { 0.051, 0.043, 0.027, 0.97 },  -- #0d0b07
    BG_HDR   = { 0.078, 0.063, 0.035, 1    },  -- #141009
    BG_TAB   = { 0.059, 0.047, 0.027, 1    },  -- #0f0c07
    BG_FTR   = { 0.059, 0.047, 0.027, 1    },

    BORDER   = { 0.416, 0.314, 0.063, 1    },  -- #6a5010  cadre principal
    SEP      = { 0.118, 0.086, 0.031, 1    },  -- #1e1608  separateurs internes
    SEP2     = { 0.094, 0.071, 0.031, 1    },  -- #181208  lignes de rows

    GOLD     = { 0.941, 0.753, 0.251, 1    },  -- #f0c040  accent or (inchangé)
    GOLD_DIM = { 0.910, 0.878, 0.784, 1    },  -- #e8e0c8  Palette B : creme chaud (valeurs)
    DIM      = { 0.627, 0.565, 0.439, 1    },  -- #a09070  Palette B : labels lisibles
    MUTED    = { 0.439, 0.408, 0.345, 1    },  -- #706858  Palette B : sous-textes
    BLUE     = { 0.314, 0.565, 0.753, 1    },  -- #5090c0
    GREEN    = { 0.220, 0.722, 0.439, 1    },  -- #38b870
    PURPLE   = { 0.282, 0.157, 0.627, 1    },  -- #4828a0
    PURP_LT  = { 0.502, 0.376, 0.878, 1    },  -- #8060e0

    PL_LV_BG = { 0.118, 0.086, 0.282, 0.9  },  -- pill leveling bg
    PL_LV_FG = { 0.565, 0.502, 0.910, 1    },
    PL_FM_BG = { 0.047, 0.188, 0.094, 0.9  },  -- pill farming bg
    PL_FM_FG = { 0.220, 0.722, 0.439, 1    },

    BAR_BG   = { 0.102, 0.078, 0.031, 1    },  -- fond des barres
    BAR_XP   = { 0.282, 0.157, 0.627, 1    },  -- barre XP
    BAR_REP  = { 0.098, 0.439, 0.314, 1    },  -- barre reputation
}

-- Noms des onglets
local TAB_LABELS = { "Session", "Zones", "Alts", "Donjons", "Stats" }

-- ─────────────────────────────────────────────
-- Etat interne
-- ─────────────────────────────────────────────
local mainFrame
local activeTab   = 1
local panels      = {}     -- frames de contenu par tab
local tabBtns     = {}     -- { lbl, uline } par tab
local w           = {}     -- widgets dynamiques nommes
local isCollapsed = false  -- mode reduit actif
local tabBarRef   = nil    -- ref frame tab bar (pour hide/show)
local footerRef   = nil    -- ref frame footer
local contentRef  = nil    -- ref frame content area
local opacPopup   = nil    -- popup slider opacite

-- ─────────────────────────────────────────────
-- Primitives
-- ─────────────────────────────────────────────

-- Fond uni sur un frame via texture (plus leger que Backdrop)
local function FillBG(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(frame)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- Ligne horizontale
local function HLine(parent, yOff, xL, xR, col)
    col = col or C.SEP
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(col[1], col[2], col[3], 1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  xL or 0, yOff)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", xR or 0, yOff)
    t:SetHeight(1)
    return t
end

-- Ligne verticale
local function VLine(parent, xOff, yT, yB, col)
    col = col or C.SEP
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(col[1], col[2], col[3], 1)
    t:SetPoint("TOPLEFT",    parent, "TOPLEFT",    xOff, yT or 0)
    t:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", xOff, yB or 0)
    t:SetWidth(1)
    return t
end

-- FontString positionne
local function FS(parent, tmpl, anchor, ax, ay, anchorTo, anchorPt)
    local fs = parent:CreateFontString(nil, "OVERLAY", tmpl or "GameFontNormalSmall")
    fs:SetPoint(anchor, anchorTo or parent, anchorPt or anchor, ax or 0, ay or 0)
    return fs
end

-- Barre de progression (retourne fill + largeur max)
local function ProgressBar(parent, bw, bh, px, py, col)
    col = col or C.BAR_XP
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(C.BAR_BG[1], C.BAR_BG[2], C.BAR_BG[3], 1)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", px, py)
    bg:SetSize(bw, bh)

    local fill = parent:CreateTexture(nil, "ARTWORK")
    fill:SetColorTexture(col[1], col[2], col[3], 1)
    fill:SetPoint("LEFT", bg, "LEFT", 0, 0)
    fill:SetSize(1, bh)

    return fill, bw
end

-- ─────────────────────────────────────────────
-- Couleur semantique (doit être avant tout RefreshTab)
-- ─────────────────────────────────────────────

-- Applique une couleur sur un FontString selon le sens de la valeur :
-- "good"     = vert  (actif, progression)
-- "info"     = bleu  (compteur neutre)
-- "progress" = violet (objectif en cours)
-- nil/autre  = or    (valeur neutre)
-- value == 0 = muted (inactif)
local function NumColor(fs, value, kind)
    if not value or value == 0 then
        fs:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
    elseif kind == "good" then
        fs:SetTextColor(C.GREEN[1], C.GREEN[2], C.GREEN[3])
    elseif kind == "info" then
        fs:SetTextColor(C.BLUE[1], C.BLUE[2], C.BLUE[3])
    elseif kind == "progress" then
        fs:SetTextColor(C.PURP_LT[1], C.PURP_LT[2], C.PURP_LT[3])
    else
        fs:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
    end
end

-- ─────────────────────────────────────────────
-- Activation d'un onglet
-- ─────────────────────────────────────────────

local function ShowTab(idx)
    activeTab = idx
    for i, p in ipairs(panels) do p:SetShown(i == idx) end
    for i, t in ipairs(tabBtns) do
        local on = (i == idx)
        t.lbl:SetTextColor(
            on and C.GOLD[1]  or C.DIM[1],
            on and C.GOLD[2]  or C.DIM[2],
            on and C.GOLD[3]  or C.DIM[3])
        t.uline:SetShown(on)
    end
    local fn = UI["RefreshTab" .. idx]
    if fn then fn() end
end

-- ─────────────────────────────────────────────
-- HEADER
-- ─────────────────────────────────────────────

local function BuildHeader(parent)
    local hdr = CreateFrame("Frame", nil, parent)
    hdr:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    hdr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    hdr:SetHeight(HDR_H)
    FillBG(hdr, C.BG_HDR[1], C.BG_HDR[2], C.BG_HDR[3])
    HLine(hdr, -HDR_H, 0, 0, C.SEP)

    -- Titre
    local title = FS(hdr, "GameFontNormalLarge", "LEFT", 14, 0)
    title:SetTextColor(0.369, 0.886, 0.137)  -- vert (accent LvlHistory)
    title:SetText("LvlHistory")

    -- Separateur vertical
    VLine(hdr, 86, -8, -(HDR_H - 8))

    -- Info personnage (apres le separateur, avant les boutons)
    w.charMeta = FS(hdr, "GameFontNormalSmall", "LEFT", 94, 0)
    w.charMeta:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])

    -- Bouton Reduire/Agrandir
    local colBtn = CreateFrame("Button", nil, parent)
    colBtn:SetSize(18, 18)
    colBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -28, -9)
    w.colBtnLbl = colBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    w.colBtnLbl:SetAllPoints(colBtn)
    w.colBtnLbl:SetJustifyH("CENTER")
    w.colBtnLbl:SetText("-")
    w.colBtnLbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
    local colBorder = colBtn:CreateTexture(nil, "BACKGROUND")
    colBorder:SetAllPoints(colBtn)
    colBorder:SetColorTexture(C.SEP[1], C.SEP[2], C.SEP[3], 1)
    colBtn:SetScript("OnEnter", function()
        w.colBtnLbl:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        GameTooltip:SetOwner(colBtn, "ANCHOR_BOTTOM")
        GameTooltip:SetText(isCollapsed and "Agrandir" or "Reduire", 1, 1, 1)
        GameTooltip:Show()
    end)
    colBtn:SetScript("OnLeave", function()
        w.colBtnLbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
        GameTooltip:Hide()
    end)
    colBtn:SetScript("OnClick", function()
        if isCollapsed then UI.Expand() else UI.Collapse() end
    end)

    -- Bouton fermer
    local x = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    x:SetSize(22, 22)
    x:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -7)
    x:SetScript("OnClick", function() mainFrame:Hide() end)
end

-- ─────────────────────────────────────────────
-- TAB BAR
-- ─────────────────────────────────────────────

local function BuildTabBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -HDR_H)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -HDR_H)
    bar:SetHeight(TAB_H)
    FillBG(bar, C.BG_TAB[1], C.BG_TAB[2], C.BG_TAB[3])
    HLine(bar, -TAB_H, 0, 0, C.SEP)

    local tabW = math.floor(FW / #TAB_LABELS)

    for i, name in ipairs(TAB_LABELS) do
        local btn = CreateFrame("Button", nil, bar)
        btn:SetSize(tabW, TAB_H)
        btn:SetPoint("LEFT", bar, "LEFT", (i - 1) * tabW, 0)

        -- Hover bg
        local hoverTex = btn:CreateTexture(nil, "BACKGROUND")
        hoverTex:SetAllPoints(btn)
        hoverTex:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetAllPoints(btn)
        lbl:SetText(name)
        lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
        lbl:SetJustifyH("CENTER")

        -- Soulignement actif (gold, 2px, en bas)
        local uline = btn:CreateTexture(nil, "OVERLAY")
        uline:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 1)
        uline:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  6, 0)
        uline:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -6, 0)
        uline:SetHeight(2)
        uline:Hide()

        local idx = i
        btn:SetScript("OnClick", function() ShowTab(idx) end)
        btn:SetScript("OnEnter", function()
            if activeTab ~= idx then
                hoverTex:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.04)
                lbl:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
            end
        end)
        btn:SetScript("OnLeave", function()
            hoverTex:SetColorTexture(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0)
            if activeTab ~= idx then
                lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
            end
        end)

        tabBtns[i] = { lbl = lbl, uline = uline }

        -- Separateur vertical entre tabs (sauf avant le 1er)
        if i > 1 then
            VLine(bar, (i - 1) * tabW, -4, -(TAB_H - 4), C.SEP)
        end
    end
    return bar   -- ref stockee dans tabBarRef
end

-- ─────────────────────────────────────────────
-- FOOTER
-- ─────────────────────────────────────────────

local function BuildFooter(parent)
    local ftr = CreateFrame("Frame", nil, parent)
    ftr:SetPoint("BOTTOMLEFT",  parent, "BOTTOMLEFT",  0, 0)
    ftr:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    ftr:SetHeight(FTR_H)
    FillBG(ftr, C.BG_FTR[1], C.BG_FTR[2], C.BG_FTR[3])
    HLine(ftr, 0, 0, 0, C.SEP)

    w.ftrSession = FS(ftr, "GameFontNormalSmall", "LEFT", PAD, 0)
    w.ftrSession:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])

    w.ftrTotal = FS(ftr, "GameFontNormalSmall", "LEFT", PAD + 130, 0)
    w.ftrTotal:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])

    -- Bouton Opacite (centre-droit)
    local opBtn = CreateFrame("Button", nil, ftr)
    opBtn:SetSize(60, FTR_H)
    opBtn:SetPoint("RIGHT", ftr, "RIGHT", -PAD - 90, 0)
    w.opacBtnLbl = opBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    w.opacBtnLbl:SetAllPoints(opBtn)
    w.opacBtnLbl:SetJustifyH("CENTER")
    w.opacBtnLbl:SetText("Opacite")
    w.opacBtnLbl:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
    opBtn:SetScript("OnEnter", function()
        if not (opacPopup and opacPopup:IsShown()) then
            w.opacBtnLbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
        end
    end)
    opBtn:SetScript("OnLeave", function()
        if not (opacPopup and opacPopup:IsShown()) then
            w.opacBtnLbl:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
        end
    end)
    opBtn:SetScript("OnClick", function()
        if opacPopup then
            local shown = not opacPopup:IsShown()
            opacPopup:SetShown(shown)
            -- Vert si actif, muted sinon
            if shown then
                w.opacBtnLbl:SetTextColor(C.GREEN[1], C.GREEN[2], C.GREEN[3])
            else
                w.opacBtnLbl:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
            end
        end
    end)
    w.opacBtn = opBtn

    w.ftrZone = FS(ftr, "GameFontNormalSmall", "RIGHT", -PAD, 0)
    w.ftrZone:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])

    footerRef = ftr
end

-- ─────────────────────────────────────────────
-- Zone de contenu partagee
-- ─────────────────────────────────────────────

local function ContentArea(parent)
    local ca = CreateFrame("Frame", nil, parent)
    ca:SetPoint("TOPLEFT",     parent, "TOPLEFT",     0, -(HDR_H + TAB_H))
    ca:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, FTR_H)
    contentRef = ca
    return ca
end

-- ─────────────────────────────────────────────
-- TAB 1 — Session
-- ─────────────────────────────────────────────

local s1 = {}

local function BuildTabSession(ca)
    local f = CreateFrame("Frame", nil, ca)
    f:SetAllPoints(ca)

    -- Bloc de 3 stats (separes par des lignes verticales)
    local blkW = math.floor((FW - PAD * 2) / 3)
    local blkH = 72
    local blkY = -PAD
    local keys = { "main", "eta", "dur" }

    s1.blk = {}
    for i = 1, 3 do
        local xOff = PAD + (i - 1) * blkW

        -- Separateur vertical (sauf avant le 1er)
        if i > 1 then
            VLine(f, xOff, blkY, blkY - blkH, C.SEP)
        end

        local num = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        num:SetPoint("TOPLEFT", f, "TOPLEFT", xOff + 10, blkY - 10)
        num:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        local fname, fsize, fflags = num:GetFont()
        num:SetFont(fname, 18, fflags)
        -- Largeur max = largeur du bloc moins padding → pas de chevauchement
        num:SetWidth(blkW - 14)
        num:SetNonSpaceWrap(false)
        num:SetText("--")

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", xOff + 10, blkY - 34)
        lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])

        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetPoint("TOPLEFT", f, "TOPLEFT", xOff + 10, blkY - 50)
        sub:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])

        s1.blk[keys[i]] = { num = num, lbl = lbl, sub = sub }
    end

    -- Ligne de separation sous le bloc stats
    local sepY = blkY - blkH
    HLine(f, sepY, PAD, -PAD, C.SEP)

    -- Barre XP / Or
    local barY = sepY - 10
    s1.barLabel = FS(f, "GameFontNormalSmall", "TOPLEFT", PAD, barY)
    s1.barLabel:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])

    s1.barPct = FS(f, "GameFontNormalSmall", "TOPRIGHT", -PAD, barY)
    s1.barPct:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])

    s1.barFill, s1.barMaxW = ProgressBar(f, FW - PAD * 2, 6, PAD, barY - 16, C.BAR_XP)

    -- Ligne de separation
    local sep2Y = barY - 30
    HLine(f, sep2Y, PAD, -PAD, C.SEP)

    -- 3 lignes d'info (zone / quetes / or)
    local infoRows = {
        { lbl = "Zone actuelle", key = "zone"   },
        { lbl = "Quetes",        key = "quests" },
        { lbl = "Or gagne",      key = "gold"   },
    }
    s1.info = {}
    for i, row in ipairs(infoRows) do
        local y = sep2Y - (i - 1) * 22 - 8
        local lbl = FS(f, "GameFontNormalSmall", "TOPLEFT", PAD, y)
        lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
        lbl:SetText(row.lbl)

        local val = FS(f, "GameFontNormalSmall", "TOPRIGHT", -PAD, y)
        val:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
        s1.info[row.key] = val

        -- Ligne basse de la row (sauf la derniere)
        if i < #infoRows then
            HLine(f, y - 14, PAD, -PAD, C.SEP2)
        end
    end

    -- Section reputation
    local repY = sep2Y - #infoRows * 22 - 14
    HLine(f, repY, PAD, -PAD, C.SEP)

    s1.repName = FS(f, "GameFontNormalSmall", "TOPLEFT", PAD, repY - 8)
    s1.repName:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
    s1.repName:SetText("Reputation")

    s1.repStanding = FS(f, "GameFontNormalSmall", "TOPRIGHT", -PAD, repY - 8)
    s1.repStanding:SetTextColor(C.GREEN[1], C.GREEN[2], C.GREEN[3])

    s1.repFill, s1.repBarW = ProgressBar(
        f, FW - PAD * 2, 4, PAD, repY - 22, C.BAR_REP)

    return f
end

function UI.RefreshTab1()
    local db = LvlHistory.db
    if not db or not s1.blk then return end

    local U       = LvlHistory.Utils
    local elapsed = time() - (db.session.startTime or time())
    local isLev   = (db.mode ~= "farming")

    -- Bloc 1 : XP/h ou Or/h — vert si actif, muted si vide
    local xph = db.session.xph or 0
    if isLev then
        s1.blk.main.num:SetText(U.FormatXPH(xph))
        NumColor(s1.blk.main.num, xph, xph > 0 and "good" or nil)
        s1.blk.main.lbl:SetText("XP / heure")
        s1.blk.main.sub:SetText("")
    else
        local gph = db.farming.goldPerHour or 0
        -- Afficher -- si or/h est negatif (depenses > gains en cours de session)
        if gph > 0 then
            s1.blk.main.num:SetText(U.FormatGold(gph, true))
            NumColor(s1.blk.main.num, gph, "good")
        else
            s1.blk.main.num:SetText("--")
            NumColor(s1.blk.main.num, 0, nil)
        end
        s1.blk.main.lbl:SetText("Or / heure")
        s1.blk.main.sub:SetText("")
    end

    -- Bloc 2 : ETA (violet = progression) ou quetes (bleu = info)
    if isLev then
        local xpLeft = UnitXPMax("player") - UnitXP("player")
        local eta    = xph > 0 and math.floor(xpLeft / xph * 3600) or 0
        local pct    = UnitXPMax("player") > 0
            and math.floor(UnitXP("player") / UnitXPMax("player") * 100) or 0
        s1.blk.eta.num:SetText(eta > 0 and U.FormatTime(eta, true) or "--")
        NumColor(s1.blk.eta.num, eta, "progress")
        s1.blk.eta.lbl:SetText("ETA nv " .. tostring(UnitLevel("player") + 1))
        s1.blk.eta.sub:SetText(pct .. "% accompli")
    else
        local qc = db.session.questCount or 0
        s1.blk.eta.num:SetText(tostring(qc))
        NumColor(s1.blk.eta.num, qc, "info")
        s1.blk.eta.lbl:SetText("Quetes")
        s1.blk.eta.sub:SetText("cette session")
    end

    -- Bloc 3 : duree session (or) + cumul en sub (gold vif)
    s1.blk.dur.num:SetText(U.FormatTime(elapsed, true))
    NumColor(s1.blk.dur.num, elapsed, "neutral")
    s1.blk.dur.lbl:SetText("Duree session")
    local grandTotal = (db.totalPlayTime or 0) + elapsed
    s1.blk.dur.sub:SetText(U.FormatTime(grandTotal, true) .. " au total")

    -- Barre
    if isLev then
        local pct = UnitXPMax("player") > 0
            and (UnitXP("player") / UnitXPMax("player")) or 0
        s1.barLabel:SetText("Niveau " .. tostring(UnitLevel("player")))
        s1.barPct:SetText(string.format("%d%%", math.floor(pct * 100)))
        s1.barFill:SetSize(math.max(1, math.floor(s1.barMaxW * pct)), 6)
        s1.barFill:SetColorTexture(C.BAR_XP[1], C.BAR_XP[2], C.BAR_XP[3], 1)
    else
        local goldGained = GetMoney() - (db.session.goldAtStart or GetMoney())
        s1.barLabel:SetText("Or gagne cette session")
        s1.barPct:SetText(U.FormatGold(goldGained, true))
        s1.barFill:SetSize(1, 6)
    end

    -- Info rows
    s1.info.zone:SetText(db.session.zone or GetRealZoneText() or "--")
    s1.info.zone:SetTextColor(C.BLUE[1], C.BLUE[2], C.BLUE[3])
    s1.info.quests:SetText(tostring(db.session.questCount or 0))
    local goldNet = GetMoney() - (db.session.goldAtStart or GetMoney())
    -- Ne pas afficher de valeur negative (depenses en cours de session)
    if goldNet > 0 then
        s1.info.gold:SetText(U.FormatGold(goldNet, true))
        s1.info.gold:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
    else
        s1.info.gold:SetText("--")
        s1.info.gold:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
    end

    -- Reputation
    local repName, repPct = "--", 0
    if db.farming and db.farming.rep then
        for name, data in pairs(db.farming.rep) do
            if (data.gained or 0) > 0 then
                repName = name
                repPct  = math.min((data.value or 0) / math.max(data.max or 42000, 1), 1)
                break
            end
        end
    end
    s1.repName:SetText(repName == "--" and "Reputation" or repName)
    s1.repStanding:SetText(repName == "--" and "--" or "Gagnee")
    s1.repFill:SetSize(math.max(1, math.floor(s1.repBarW * repPct)), 4)
end

-- ─────────────────────────────────────────────
-- Helper partagé : bloc de 3 stats en haut d'un panel
-- Retourne table[1..3] de { num, lbl, sub }
-- ─────────────────────────────────────────────
local SROW_H = 64   -- hauteur du bloc stats

local function StatRow(parent)
    local blkW = math.floor((FW - PAD * 2) / 3)
    local blks = {}
    for i = 1, 3 do
        local xOff = PAD + (i - 1) * blkW
        if i > 1 then VLine(parent, xOff, -PAD, -(PAD + SROW_H), C.SEP) end

        local num = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        num:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 10, -PAD - 8)
        local fn_ = num:GetFont(); num:SetFont(fn_, 18)
        num:SetWidth(blkW - 14)     -- limite le débordement sur le bloc suivant
        num:SetNonSpaceWrap(false)
        num:SetText("--")
        num:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])

        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 10, -PAD - 32)
        lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])

        local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff + 10, -PAD - 48)
        sub:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])

        blks[i] = { num = num, lbl = lbl, sub = sub }
    end
    HLine(parent, -(PAD + SROW_H), PAD, -PAD, C.SEP)
    return blks
end

-- ─────────────────────────────────────────────
-- TAB 2 — Zones
-- ─────────────────────────────────────────────

local zoneList
local s2 = {}   -- stats row widgets

local function BuildTabZones(ca)
    local f = CreateFrame("Frame", nil, ca)
    f:SetAllPoints(ca)

    s2.blks = StatRow(f)

    local scrollTop = -(PAD + SROW_H + 8)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD - 4, scrollTop)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, PAD)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FW - PAD * 2 - 22, 1)
    scroll:SetScrollChild(content)
    zoneList = content

    return f
end

function UI.RefreshTab2()
    local db = LvlHistory.db
    if not db or not zoneList then return end

    -- ── Stats row ───────────────────────────────
    if s2.blks then
        local U       = LvlHistory.Utils
        local zones   = db.zones or {}
        local zoneCount, totalDur, topZone, topDur = 0, 0, "--", 0
        for zone, dur in pairs(zones) do
            zoneCount = zoneCount + 1
            totalDur  = totalDur + dur
            if dur > topDur then topZone = zone; topDur = dur end
        end

        -- Bloc 1 : zones visitees (bleu = info)
        s2.blks[1].num:SetText(tostring(zoneCount))
        NumColor(s2.blks[1].num, zoneCount, "info")
        s2.blks[1].lbl:SetText("Zones visitees")
        s2.blks[1].sub:SetText("")

        -- Bloc 2 : temps total (or)
        s2.blks[2].num:SetText(totalDur > 0 and U.FormatTime(totalDur, true) or "--")
        NumColor(s2.blks[2].num, totalDur, "neutral")
        s2.blks[2].lbl:SetText("Temps total")
        s2.blks[2].sub:SetText("")

        -- Bloc 3 : record zone (temps + nom en sub)
        s2.blks[3].num:SetText(topDur > 0 and U.FormatTime(topDur, true) or "--")
        NumColor(s2.blks[3].num, topDur, "neutral")
        s2.blks[3].lbl:SetText("Record zone")
        s2.blks[3].sub:SetText(topZone ~= "--" and topZone or "")
    end

    -- ── Liste ───────────────────────────────────
    for _, c in ipairs({ zoneList:GetChildren() }) do
        c:Hide(); c:SetParent(UIParent)
    end

    local sorted, maxDur = {}, 1
    for zone, dur in pairs(db.zones or {}) do
        table.insert(sorted, { zone = zone, dur = dur })
        if dur > maxDur then maxDur = dur end
    end
    table.sort(sorted, function(a, b) return a.dur > b.dur end)

    local rowH  = 24
    local listW = FW - PAD * 2 - 22
    zoneList:SetHeight(math.max(#sorted * rowH, 10))

    for i, e in ipairs(sorted) do
        local row = CreateFrame("Frame", nil, zoneList)
        row:SetPoint("TOPLEFT", zoneList, "TOPLEFT", 0, -(i - 1) * rowH)
        row:SetSize(listW, rowH)

        -- Nom (top zone en gold vif, les autres en gold dim)
        local nameLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLbl:SetPoint("LEFT", row, "LEFT", 4, 0)
        if i == 1 then
            nameLbl:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        else
            nameLbl:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
        end
        nameLbl:SetText(e.zone)

        -- Barre proportionnelle (violet → or sur la top zone)
        local pct    = e.dur / maxDur
        local barClr = (i == 1) and C.GOLD or C.PURPLE
        local barBG  = row:CreateTexture(nil, "BACKGROUND")
        barBG:SetColorTexture(C.BAR_BG[1], C.BAR_BG[2], C.BAR_BG[3], 1)
        barBG:SetSize(80, 3)
        barBG:SetPoint("RIGHT", row, "RIGHT", -52, 0)

        local barFill = row:CreateTexture(nil, "ARTWORK")
        barFill:SetColorTexture(barClr[1], barClr[2], barClr[3], 1)
        barFill:SetPoint("LEFT", barBG, "LEFT", 0, 0)
        barFill:SetSize(math.max(1, math.floor(80 * pct)), 3)

        local timeLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timeLbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        timeLbl:SetTextColor(i == 1 and C.GOLD[1] or C.GOLD_DIM[1],
                             i == 1 and C.GOLD[2] or C.GOLD_DIM[2],
                             i == 1 and C.GOLD[3] or C.GOLD_DIM[3])
        timeLbl:SetText(LvlHistory.Utils.FormatTime(e.dur, true))

        if i < #sorted then HLine(row, -rowH + 1, 0, 0, C.SEP2) end
    end
end

-- ─────────────────────────────────────────────
-- TAB 3 — Alts
-- ─────────────────────────────────────────────

local altList
local s3 = {}

local function BuildTabAlts(ca)
    local f = CreateFrame("Frame", nil, ca)
    f:SetAllPoints(ca)

    s3.blks = StatRow(f)

    local scrollTop = -(PAD + SROW_H + 8)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD - 4, scrollTop)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, PAD)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FW - PAD * 2 - 22, 1)
    scroll:SetScrollChild(content)
    altList = content

    return f
end

function UI.RefreshTab3()
    if not altList then return end

    local chars = LvlHistoryDB and LvlHistoryDB.chars or {}
    local list  = {}
    for key, data in pairs(chars) do
        table.insert(list, { key = key, data = data })
    end
    table.sort(list, function(a, b)
        return (a.data.level or 0) > (b.data.level or 0)
    end)

    -- ── Stats row ───────────────────────────────
    if s3.blks then
        local U       = LvlHistory.Utils
        local maxLvl  = GetMaxPlayerLevel()
        local altCount, totalTime, topLvl, topName = 0, 0, 0, "--"
        for _, entry in ipairs(list) do
            altCount  = altCount + 1
            totalTime = totalTime + (entry.data.totalPlayTime or 0)
            local lvl = entry.data.level or 0
            if lvl > topLvl then
                topLvl  = lvl
                topName = entry.key:match("^([^%-]+)") or entry.key
            end
        end

        -- Bloc 1 : alts suivis (bleu)
        s3.blks[1].num:SetText(tostring(altCount))
        NumColor(s3.blks[1].num, altCount, "info")
        s3.blks[1].lbl:SetText("Alts suivis")
        s3.blks[1].sub:SetText("")

        -- Bloc 2 : niveau max (vert si max level, violet sinon)
        s3.blks[2].num:SetText(topLvl > 0 and tostring(topLvl) or "--")
        NumColor(s3.blks[2].num, topLvl, topLvl >= maxLvl and "good" or "progress")
        s3.blks[2].lbl:SetText("Niveau max")
        s3.blks[2].sub:SetText(topName ~= "--" and topName or "")

        -- Bloc 3 : temps cumule tous persos (or)
        s3.blks[3].num:SetText(totalTime > 0 and U.FormatTime(totalTime, true) or "--")
        NumColor(s3.blks[3].num, totalTime, "neutral")
        s3.blks[3].lbl:SetText("Temps cumule")
        s3.blks[3].sub:SetText("tous persos")
    end

    -- ── Liste ───────────────────────────────────
    for _, c in ipairs({ altList:GetChildren() }) do
        c:Hide(); c:SetParent(UIParent)
    end

    local rowH   = 52
    local listW  = FW - PAD * 2 - 22
    local maxLvl = GetMaxPlayerLevel()
    altList:SetHeight(math.max(#list * (rowH + 4), 10))

    for i, entry in ipairs(list) do
        local lvl   = entry.data.level or 0
        local isMax = lvl >= maxLvl
        local pct   = math.min(lvl / maxLvl, 1)
        local mode  = entry.data.mode or "leveling"

        local row = CreateFrame("Frame", nil, altList)
        row:SetPoint("TOPLEFT", altList, "TOPLEFT", 0, -(i - 1) * (rowH + 4))
        row:SetSize(listW, rowH)

        -- Separateur haut (sauf premier)
        if i > 1 then
            HLine(row, 0, 0, 0, C.SEP)
        end

        -- Initiales
        local initBox = CreateFrame("Frame", nil, row)
        initBox:SetSize(34, 34)
        initBox:SetPoint("LEFT", row, "LEFT", 0, 0)
        FillBG(initBox, C.BG_HDR[1], C.BG_HDR[2], C.BG_HDR[3])
        local borderT = initBox:CreateTexture(nil, "BORDER")
        borderT:SetAllPoints(initBox)
        borderT:SetColorTexture(C.SEP[1], C.SEP[2], C.SEP[3], 1)

        local initLbl = initBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        initLbl:SetAllPoints(initBox)
        initLbl:SetJustifyH("CENTER")
        initLbl:SetJustifyV("MIDDLE")
        initLbl:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        -- Initiales : 2 premiers caracteres du nom (avant le tiret realm)
        local firstName = entry.key:match("^([^%-]+)") or entry.key
        initLbl:SetText(string.upper(string.sub(firstName, 1, 2)))

        -- Nom
        local nameLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -6)
        nameLbl:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
        nameLbl:SetText(entry.key)

        -- Info : mode + temps total joué
        local totalT  = entry.data.totalPlayTime or 0
        local infoLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoLbl:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -22)
        infoLbl:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
        infoLbl:SetText(string.format("%s  —  %s",
            mode == "farming" and "Farming" or "Leveling",
            totalT > 0 and LvlHistory.Utils.FormatTime(totalT, true) or "--"))

        -- Barre de niveau
        local barW    = listW - 44 - 54
        local barClr  = isMax and C.GREEN or C.PURP_LT
        local barBG   = row:CreateTexture(nil, "BACKGROUND")
        barBG:SetColorTexture(C.BAR_BG[1], C.BAR_BG[2], C.BAR_BG[3], 1)
        barBG:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -38)
        barBG:SetSize(barW, 2)

        local barFill = row:CreateTexture(nil, "ARTWORK")
        barFill:SetColorTexture(barClr[1], barClr[2], barClr[3], 0.9)
        barFill:SetPoint("LEFT", barBG, "LEFT", 0, 0)
        barFill:SetSize(math.max(1, math.floor(barW * pct)), 2)

        -- Niveau (droite)
        local lvlLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lvlLbl:SetPoint("RIGHT", row, "RIGHT", 0, -4)
        if isMax then
            lvlLbl:SetText("|cff38b870" .. tostring(lvl) .. "|r")
        else
            lvlLbl:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
            lvlLbl:SetText(tostring(lvl))
        end

        -- (temps total déjà affiché dans la ligne info, on ne le duplique pas)
    end
end

-- ─────────────────────────────────────────────
-- TAB 4 — Donjons  (architecture SkyMythicHistory)
-- Lignes pre-construites au build, SetWidth() au refresh.
-- Pas de recreation de frames → zero garbage.
-- ─────────────────────────────────────────────

local WHITE_TEX    = "Interface\\Buttons\\WHITE8x8"
local MAX_DGN_ROWS = 10
local DGN_ROW_H    = 30
local DGN_BAR_H    = 8
local DGN_TITLE_H  = 32
-- rowW = FW - PAD*2 - 22 = 430
-- Layout : 6(L) + nameW(dyn) + 8 + 80(bar) + 8 + statusW(dyn) + 8 + 36(diff) + 8 + 54(time) + 6 + 24(count) + right
local DGN_NAME_W   = 110
local DGN_STATUS_W = 60
local DGN_COUNT_W  = 24
local DGN_BAR_W    = 80
local DGN_DIFF_W   = 36
local DGN_TIME_W   = 54

-- ── Palette photo (vert / jaune / rouge) ────────────────────
-- Heroique → vert  (= "Timed"    dans la photo)
-- Mythique → jaune (= "OverTime" dans la photo)
-- M+       → rouge (= "Abandon"  dans la photo)
-- Normal   → gris  (fond neutre)
local DGN_COLORS = {
    NORMAL  = { 0.600, 0.600, 0.600, 1 },
    HEROIC  = { 0.118, 0.867, 0.118, 1 },
    MYTHIC  = { 1.000, 0.780, 0.000, 1 },
    MP      = { 0.902, 0.255, 0.255, 1 },
    UNKNOWN = { 0.400, 0.600, 0.800, 1 },
}

-- ── UpdateDgnRowBar — copie de UpdateDungeonRowBar (SkyMythicHistory) ──
-- Seul le SetWidth change ; aucun nouveau frame n'est cree.
local function UpdateDgnRowBar(row, d, maxCount)
    -- fill = largeur totale de la barre (entier, plafonne a DGN_BAR_W)
    local fill = maxCount > 0
        and math.min(DGN_BAR_W, math.floor(DGN_BAR_W * d.count / maxCount))
        or 0
    -- Segments : entiers, somme == fill
    local function sw(n)
        return d.count > 0 and math.floor(fill * n / d.count) or 0
    end
    local nw, hw, myw, mpw = sw(d.normal), sw(d.heroic), sw(d.mythic), sw(d.mp)
    -- Le dernier pixel perdu va sur le segment le plus grand
    local used = nw + hw + myw + mpw
    local rest = fill - used
    if rest > 0 then
        if d.heroic  >= d.mythic and d.heroic  >= d.mp and d.heroic  >= d.normal then hw  = hw  + rest
        elseif d.mythic >= d.mp  and d.mythic  >= d.normal                        then myw = myw + rest
        elseif d.mp     >= d.normal                                                then mpw = mpw + rest
        else                                                                            nw  = nw  + rest
        end
    end
    row.BarN:SetWidth(nw)
    row.BarH:ClearAllPoints()
    row.BarH:SetPoint("TOPLEFT", row.BarN, "TOPRIGHT", 0, 0)
    row.BarH:SetWidth(hw)
    row.BarMy:ClearAllPoints()
    row.BarMy:SetPoint("TOPLEFT", row.BarH, "TOPRIGHT", 0, 0)
    row.BarMy:SetWidth(myw)
    row.BarMP:ClearAllPoints()
    row.BarMP:SetPoint("TOPLEFT", row.BarMy, "TOPRIGHT", 0, 0)
    row.BarMP:SetWidth(mpw)
end

-- ── CreateDgnRow — copie de CreateStatsDungeonRow (SkyMythicHistory) ───
local function CreateDgnRow(parent, index, rowW)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, -(DGN_TITLE_H + (index - 1) * DGN_ROW_H))
    row:SetSize(rowW, DGN_ROW_H)
    row:Hide()

    if index % 2 == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE_TEX)
        bg:SetVertexColor(0.07, 0.07, 0.07, 1)
    end

    -- Nom
    row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.Name:SetPoint("LEFT", 6, 0)
    row.Name:SetWidth(DGN_NAME_W)
    row.Name:SetNonSpaceWrap(false)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])

    -- Bar holder (fond + 4 segments, copies de SkyMythicHistory)
    local barHolder = CreateFrame("Frame", nil, row)
    barHolder:SetSize(DGN_BAR_W, DGN_BAR_H)
    barHolder:SetPoint("LEFT", row, "LEFT", 6 + DGN_NAME_W + 8, 0)
    local barBg = barHolder:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture(WHITE_TEX)
    barBg:SetVertexColor(0.08, 0.07, 0.05, 1)

    local function MakeSeg(col, anchor)
        local t = barHolder:CreateTexture(nil, "ARTWORK")
        t:SetTexture(WHITE_TEX)
        t:SetVertexColor(col[1], col[2], col[3], 0.87)
        t:SetHeight(DGN_BAR_H)
        t:SetWidth(0)
        if anchor then
            t:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
        else
            t:SetPoint("TOPLEFT")
        end
        return t
    end
    row.BarN  = MakeSeg(DGN_COLORS.NORMAL,  nil)
    row.BarH  = MakeSeg(DGN_COLORS.HEROIC,  row.BarN)
    row.BarMy = MakeSeg(DGN_COLORS.MYTHIC,  row.BarH)
    row.BarMP = MakeSeg(DGN_COLORS.MP,      row.BarMy)
    row.BarHolder = barHolder

    -- Status "H:5  M:1" (couleurs = segments, sans N:X)
    row.Status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.Status:SetPoint("LEFT", barHolder, "RIGHT", 8, 0)
    row.Status:SetWidth(DGN_STATUS_W)
    row.Status:SetNonSpaceWrap(false)
    row.Status:SetJustifyH("LEFT")

    -- Difficulte : meilleure cle timee (ex: "+7")
    row.Diff = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Diff:SetWidth(DGN_DIFF_W)
    row.Diff:SetJustifyH("CENTER")
    row.Diff:SetNonSpaceWrap(false)
    row.Diff:SetTextColor(0.94, 0.75, 0.25, 1)

    -- Meilleur temps (ex: "18:42")
    row.Time = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.Time:SetWidth(DGN_TIME_W)
    row.Time:SetJustifyH("CENTER")
    row.Time:SetNonSpaceWrap(false)
    row.Time:SetTextColor(0.22, 0.72, 0.44, 1)

    -- Count (rose/saumon, far right — copie de SkyMythicHistory)
    row.Count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Count:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.Count:SetTextColor(0.95, 0.42, 0.42, 1)

    -- Separateur bas
    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(WHITE_TEX)
    sep:SetVertexColor(C.SEP2[1], C.SEP2[2], C.SEP2[3], 1)
    sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    sep:SetHeight(1)

    return row
end

local dgnList
local dgnRows = {}
local s4      = {}

local function BuildTabDungeons(ca)
    local f = CreateFrame("Frame", nil, ca)
    f:SetAllPoints(ca)

    s4.blks = StatRow(f)

    local scrollTop = -(PAD + SROW_H + 8)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD - 4, scrollTop)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, PAD)

    local rowW    = FW - PAD * 2 - 22
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(rowW, DGN_TITLE_H + MAX_DGN_ROWS * DGN_ROW_H)
    scroll:SetScrollChild(content)
    dgnList = content

    -- Titre permanent (cree une seule fois au build)
    local secTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -10)
    secTitle:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
    secTitle:SetText("Donjons les plus joues")
    local titleLine = content:CreateTexture(nil, "ARTWORK")
    titleLine:SetTexture(WHITE_TEX)
    titleLine:SetVertexColor(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.35)
    titleLine:SetPoint("BOTTOMLEFT",  secTitle, "BOTTOMLEFT",  0, -3)
    titleLine:SetPoint("BOTTOMRIGHT", secTitle, "BOTTOMRIGHT", 0, -3)
    titleLine:SetHeight(1)

    -- En-tetes colonnes droite
    local hdrDiff = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrDiff:SetPoint("TOPLEFT", content, "TOPLEFT",
        6 + DGN_NAME_W + 8 + DGN_BAR_W + 8 + DGN_STATUS_W + 8, -6)
    hdrDiff:SetWidth(DGN_DIFF_W)
    hdrDiff:SetJustifyH("CENTER")
    hdrDiff:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
    hdrDiff:SetText("Diff.")

    local hdrTime = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrTime:SetPoint("TOPLEFT", hdrDiff, "TOPRIGHT", 8, 0)
    hdrTime:SetWidth(DGN_TIME_W)
    hdrTime:SetJustifyH("CENTER")
    hdrTime:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
    hdrTime:SetText("Tps")

    -- Pre-construire MAX_DGN_ROWS lignes (cachees, comme SkyMythicHistory)
    dgnRows = {}
    for i = 1, MAX_DGN_ROWS do
        dgnRows[i] = CreateDgnRow(content, i, rowW)
    end

    return f
end

-- RefreshTab4 — pattern SkyMythicHistory:RefreshStatsView
-- Seul le texte et SetWidth changent. Aucun frame/texture recree.
function UI.RefreshTab4()
    local db = LvlHistory.db
    if not db or not dgnList or #dgnRows == 0 then return end

    -- ── Construire les donnees par donjon ────────────────────────────────────
    -- { [name] = { total, normal, heroic, mythic, mp } }
    local byDungeon = {}
    for key, count in pairs(db.dgnDetails or {}) do
        local name, diff = key:match("^(.+)||(.+)$")
        if name and diff then
            local d = byDungeon[name]
            if not d then
                d = { total=0, normal=0, heroic=0, mythic=0, mp=0 }
                byDungeon[name] = d
            end
            d.total = d.total + count
            local dl = diff:lower()
            if     dl:find("%+")                             then d.mp     = d.mp     + count
            elseif dl:find("mythique") or dl:find("mythic")  then d.mythic = d.mythic + count
            elseif dl:find("hero")                            then d.heroic = d.heroic + count
            elseif dl:find("normal")                          then d.normal = d.normal + count
            else                                                   d.heroic = d.heroic + count
            end
        end
    end
    -- Fallback dgnRuns si dgnDetails vide (donnees anterieures a dgnDetails)
    if not next(byDungeon) then
        for name, count in pairs(db.dgnRuns or {}) do
            byDungeon[name] = { total=count, normal=0, heroic=count, mythic=0, mp=0 }
        end
    end

    -- ── Stats row ───────────────────────────────────────────────────────────
    if s4.blks then
        local totalRuns, topName, topCount = 0, "--", 0
        for name, d in pairs(byDungeon) do
            totalRuns = totalRuns + d.total
            if d.total > topCount then topName = name; topCount = d.total end
        end
        local sess = db.session.dungeons or 0
        s4.blks[1].num:SetText(tostring(totalRuns))
        NumColor(s4.blks[1].num, totalRuns, "info")
        s4.blks[1].lbl:SetText("Total completes")
        s4.blks[1].sub:SetText("")
        s4.blks[2].num:SetText(tostring(sess))
        NumColor(s4.blks[2].num, sess, "good")
        s4.blks[2].lbl:SetText("Cette session")
        s4.blks[2].sub:SetText("")
        s4.blks[3].num:SetText(topCount > 0 and ("x"..topCount) or "--")
        NumColor(s4.blks[3].num, topCount, "neutral")
        s4.blks[3].lbl:SetText("Donjon favori")
        s4.blks[3].sub:SetText(topName ~= "--" and topName or "")
    end

    -- ── Trier par total DESC ─────────────────────────────────────────────────
    local sorted, maxRuns = {}, 1
    for name, d in pairs(byDungeon) do
        if name and d and d.total then
            table.insert(sorted, { name=name, count=d.total,
                normal=d.normal, heroic=d.heroic, mythic=d.mythic, mp=d.mp })
            if d.total > maxRuns then maxRuns = d.total end
        end
    end
    table.sort(sorted, function(a, b)
        if not a or not b then return false end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)

    -- ── Mesure dynamique de la largeur des noms ──────────────────────────────
    -- On mesure la largeur naturelle de chaque nom pour eviter les chevauchements.
    local bestKeyDB = db.dgnBestKey or {}
    local measFS = dgnList:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    measFS:SetWidth(0)  -- sans contrainte = texte non tronque
    local maxNamePx = DGN_NAME_W
    for _, d in ipairs(sorted) do
        measFS:SetText(d.name)
        local w = math.ceil(measFS:GetStringWidth())
        if w > maxNamePx then maxNamePx = w end
    end
    measFS:Hide()
    -- Clamp : min 100, max 220 (evite un nom ultra-long de tout ecraser)
    local nameW = math.max(100, math.min(220, maxNamePx + 4))

    -- Recalculer les largeurs des autres colonnes en fonction de nameW
    -- Layout : 6(L) + nameW + 8 + DGN_BAR_W + 8 + statusW + 8 + DGN_DIFF_W + 8 + DGN_TIME_W + 6 + DGN_COUNT_W + 10(R)
    local rowW     = FW - PAD * 2 - 22
    local fixed    = 6 + 8 + DGN_BAR_W + 8 + 8 + DGN_DIFF_W + 8 + DGN_TIME_W + 6 + DGN_COUNT_W + 10
    local statusW  = math.max(40, rowW - fixed - nameW)

    -- Helper : formate des millisecondes en "m:ss"
    local function FmtMs(ms)
        local s = math.floor(ms / 1000)
        return string.format("%d:%02d", math.floor(s / 60), s % 60)
    end

    -- Table nom→mapChallengeModeID depuis l'API Blizzard
    local mapNameToID = {}
    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
            local name = C_ChallengeMode.GetMapUIInfo(mapID)
            if name and name ~= "" then
                mapNameToID[name] = mapID
            end
        end
    end

    -- ── Mise a jour des lignes pre-construites ───────────────────────────────
    local maxDungCount = (sorted[1] and sorted[1].count) or 1
    local visibleRows  = 0
    for i, row in ipairs(dgnRows) do
        local d = sorted[i]
        if d then
            -- Repositionner les colonnes selon nameW mesure
            row.Name:SetWidth(nameW)
            row.BarHolder:ClearAllPoints()
            row.BarHolder:SetPoint("LEFT", row, "LEFT", 6 + nameW + 8, 0)
            row.Status:SetWidth(statusW)

            -- Colonnes Diff et Time (ancres apres Status)
            row.Diff:ClearAllPoints()
            row.Diff:SetPoint("LEFT", row.Status, "RIGHT", 8, 0)
            row.Time:ClearAllPoints()
            row.Time:SetPoint("LEFT", row.Diff, "RIGHT", 8, 0)

            -- Nom : 1er en or vif, les autres en or dim
            row.Name:SetText(d.name)
            if i == 1 then
                row.Name:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
            else
                row.Name:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
            end
            -- Count (rose/saumon, far right)
            row.Count:SetText(tostring(d.count))

            -- Status : H:X  M+:X (sans M:X ni N:X)
            local parts = {}
            if d.heroic > 0 then
                table.insert(parts, "|cff1edd1eH:" .. d.heroic .. "|r")
            end
            if d.mp > 0 then
                table.insert(parts, "|cffe64040M+:" .. d.mp .. "|r")
            end
            row.Status:SetText(table.concat(parts, " "))

            -- ── Difficulte et Temps depuis les donnees Blizzard ──────────────
            local mapID   = mapNameToID[d.name]
            local bestRun = nil
            if mapID and C_MythicPlus and C_MythicPlus.GetSeasonBestForMap then
                bestRun = C_MythicPlus.GetSeasonBestForMap(mapID)
            end

            if bestRun and bestRun.keystoneLevel and bestRun.keystoneLevel > 0 then
                -- Donnees live Blizzard
                row.Diff:SetText("+" .. bestRun.keystoneLevel)
                row.Diff:SetTextColor(0.94, 0.75, 0.25, 1)
                local ms = bestRun.completionMilliseconds
                if ms and ms > 0 then
                    row.Time:SetText(FmtMs(ms))
                    row.Time:SetTextColor(0.22, 0.72, 0.44, 1)
                else
                    row.Time:SetText("--")
                    row.Time:SetTextColor(0.44, 0.41, 0.35, 1)
                end
            else
                -- Fallback : donnees stockees par LvlHistory
                local bt = (db.dgnBestTime or {})[d.name]
                if bt and bt.key and bt.key > 0 then
                    row.Diff:SetText("+" .. bt.key)
                    row.Diff:SetTextColor(0.63, 0.57, 0.44, 1)
                    if bt.ms and bt.ms > 0 then
                        row.Time:SetText(FmtMs(bt.ms))
                        row.Time:SetTextColor(0.22, 0.72, 0.44, 1)
                    else
                        row.Time:SetText("--")
                        row.Time:SetTextColor(0.44, 0.41, 0.35, 1)
                    end
                else
                    row.Diff:SetText("--")
                    row.Diff:SetTextColor(0.44, 0.41, 0.35, 1)
                    row.Time:SetText("--")
                    row.Time:SetTextColor(0.44, 0.41, 0.35, 1)
                end
            end

            -- Barres (SetWidth seulement — aucune texture recree)
            UpdateDgnRowBar(row, d, maxDungCount)
            row:Show()
            visibleRows = visibleRows + 1
        else
            row:Hide()
        end
    end

    -- Hauteur du scroll adapte au nombre de lignes visibles
    local h = DGN_TITLE_H + visibleRows * DGN_ROW_H
    dgnList:SetHeight(math.max(h, DGN_TITLE_H + DGN_ROW_H))
end

-- ─────────────────────────────────────────────
-- TAB 5 — Stats
-- ─────────────────────────────────────────────

local s5 = {}

local function BuildTabStats(ca)
    local f = CreateFrame("Frame", nil, ca)
    f:SetAllPoints(ca)

    -- 3 blocs stats (temps total / quetes / donjons)
    local blkW = math.floor((FW - PAD * 2) / 3)
    local blkH = 64
    local blkY = -PAD
    local skeys = { "time", "quests", "dgn" }

    s5.blk = {}
    for i = 1, 3 do
        local xOff = PAD + (i - 1) * blkW
        if i > 1 then VLine(f, xOff, blkY, blkY - blkH, C.SEP) end

        local num = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        num:SetPoint("TOPLEFT", f, "TOPLEFT", xOff + 10, blkY - 10)
        num:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        local fn_, fsize_ = num:GetFont()
        num:SetFont(fn_, 18)
        num:SetText("--")

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", xOff + 10, blkY - 34)
        lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])

        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sub:SetPoint("TOPLEFT", f, "TOPLEFT", xOff + 10, blkY - 50)
        sub:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])

        s5.blk[skeys[i]] = { num = num, lbl = lbl, sub = sub }
    end

    -- Separateur + Records
    local recY = blkY - blkH - 4
    HLine(f, recY, PAD, -PAD, C.SEP)

    local recTitle = FS(f, "GameFontNormalSmall", "TOPLEFT", PAD, recY - 8)
    recTitle:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
    recTitle:SetText("Records")

    local recDefs = {
        { lbl = "Meilleur XP/h",       key = "bestXPH"   },
        { lbl = "XP/h moyen",          key = "avgXPH"    },
        { lbl = "Sessions totales",    key = "sessions"  },
        { lbl = "Meilleure session",   key = "bestSess"  },
        { lbl = "Zone favorite",       key = "topZone"   },
        { lbl = "Or total gagne",      key = "totalGold" },
        { lbl = "Record or / session", key = "bestGold"  },
        { lbl = "Record donjons / session", key = "bestDgn" },
    }
    s5.rec = {}
    for i, row in ipairs(recDefs) do
        local y = recY - 8 - i * 22
        local lbl = FS(f, "GameFontNormalSmall", "TOPLEFT", PAD, y)
        lbl:SetTextColor(C.MUTED[1], C.MUTED[2], C.MUTED[3])
        lbl:SetText(row.lbl)

        local val = FS(f, "GameFontNormalSmall", "TOPRIGHT", -PAD, y)
        val:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
        s5.rec[row.key] = val

        if i < #recDefs then
            HLine(f, y - 14, PAD, -PAD, C.SEP2)
        end
    end

    return f
end

function UI.RefreshTab5()
    local db = LvlHistory.db
    if not db or not s5.blk then return end

    local U        = LvlHistory.Utils
    local sessions = db.sessions or {}
    local totalT, totalXPH, cntXPH, bestXPH, bestDur = 0, 0, 0, 0, 0
    local totalGold, bestGold, bestDgn = 0, 0, 0

    for _, s in ipairs(sessions) do
        totalT = totalT + (s.duration or 0)
        -- XP
        if s.mode == "leveling" and (s.xph or 0) > 0 then
            totalXPH = totalXPH + s.xph
            cntXPH   = cntXPH + 1
            if s.xph > bestXPH then bestXPH = s.xph end
        end
        if (s.duration or 0) > bestDur then bestDur = s.duration end
        -- Or (nouveau champ)
        local sg = s.goldGained or 0
        if sg > 0 then
            totalGold = totalGold + sg
            if sg > bestGold then bestGold = sg end
        end
        -- Donjons (nouveau champ)
        local sd = s.dungeons or 0
        if sd > bestDgn then bestDgn = sd end
    end

    local elapsed    = time() - (db.session.startTime or time())
    local grandTotal = (db.totalPlayTime or 0) + elapsed

    local dgnTotal = 0
    for _, cnt in pairs(db.dgnRuns or {}) do dgnTotal = dgnTotal + cnt end

    local topZone, topZoneT = "--", 0
    for zone, dur in pairs(db.zones or {}) do
        if dur > topZoneT then topZone = zone; topZoneT = dur end
    end

    s5.blk.time.num:SetText(U.FormatTime(grandTotal, true))
    NumColor(s5.blk.time.num, grandTotal, "neutral")
    s5.blk.time.lbl:SetText("Temps total")
    s5.blk.time.sub:SetText(#sessions .. " sessions")

    local qt = db.quests.total or 0
    s5.blk.quests.num:SetText(tostring(qt))
    NumColor(s5.blk.quests.num, qt, "info")
    s5.blk.quests.lbl:SetText("Quetes totales")

    s5.blk.dgn.num:SetText(tostring(dgnTotal))
    NumColor(s5.blk.dgn.num, dgnTotal, dgnTotal > 0 and "good" or nil)
    s5.blk.dgn.lbl:SetText("Donjons totaux")

    if s5.rec then
        s5.rec.bestXPH:SetText(bestXPH > 0 and U.FormatXPH(bestXPH) or "--")
        s5.rec.avgXPH:SetText(cntXPH > 0
            and U.FormatXPH(math.floor(totalXPH / cntXPH)) or "--")
        s5.rec.sessions:SetText(#sessions > 0
            and string.format("%d  —  moy. %s", #sessions,
                U.FormatTime(math.floor(totalT / #sessions), true))
            or "--")
        s5.rec.bestSess:SetText(bestDur > 0 and U.FormatTime(bestDur, true) or "--")
        s5.rec.topZone:SetText(topZone)
        s5.rec.totalGold:SetText(totalGold > 0 and U.FormatGold(totalGold, true) or "--")
        s5.rec.bestGold:SetText(bestGold  > 0 and U.FormatGold(bestGold,  true) or "--")
        s5.rec.bestDgn:SetText(bestDgn   > 0 and tostring(bestDgn) or "--")
    end
end

-- Forward declaration : RefreshCompactBody est définie plus bas
-- mais appelée par RefreshGlobal — on déclare le slot local ici
local RefreshCompactBody

-- ─────────────────────────────────────────────
-- Refresh global (header + footer)
-- ─────────────────────────────────────────────

local function RefreshGlobal()
    local db = LvlHistory.db
    if not db then return end

    local U     = LvlHistory.Utils
    local isLev = (db.mode ~= "farming")

    -- Char meta
    if w.charMeta then
        w.charMeta:SetText(string.format("%s   Lv %d",
            UnitName("player") or "--",
            UnitLevel("player")))
    end

    -- Footer
    local elapsed = time() - (db.session.startTime or time())
    if w.ftrSession then
        local grandTotal = (db.totalPlayTime or 0) + elapsed
        w.ftrSession:SetText("Session  " .. U.FormatTime(elapsed, true))
        w.ftrTotal:SetText("Total  " .. U.FormatTime(grandTotal, true))
        w.ftrZone:SetText(db.session.zone or GetRealZoneText() or "--")
    end

    -- Stats grille compacte (mode reduit Option B)
    if isCollapsed then
        RefreshCompactBody()
    end
end

-- ─────────────────────────────────────────────
-- Mode reduit / Collapse — Option B (grille 2x2)
-- ─────────────────────────────────────────────

local COMPACT_BODY_H = 66   -- hauteur du corps compact
local compactBody    = nil  -- frame grille 2x2, ref globale

local function BuildCompactBody(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, -HDR_H)
    f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -HDR_H)
    f:SetHeight(COMPACT_BODY_H)
    FillBG(f, C.BG[1], C.BG[2], C.BG[3])
    HLine(f, -COMPACT_BODY_H, 0, 0, C.SEP)

    -- Separateur vertical central
    VLine(f, COMPACT_HALF, -6, -(COMPACT_BODY_H - 6), C.SEP)
    -- Separateur horizontal central
    local hMid = f:CreateTexture(nil, "ARTWORK")
    hMid:SetColorTexture(C.SEP[1], C.SEP[2], C.SEP[3], 1)
    hMid:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, -math.floor(COMPACT_BODY_H / 2))
    hMid:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -math.floor(COMPACT_BODY_H / 2))
    hMid:SetHeight(1)

    local half    = COMPACT_HALF
    local cellH   = math.floor(COMPACT_BODY_H / 2)
    local cells   = {
        { x = 0,    y = 0,      col = C.GREEN   },  -- XP/h  (haut gauche)
        { x = half, y = 0,      col = C.GOLD_DIM },  -- Duree (haut droit)
        { x = 0,    y = -cellH, col = C.BLUE    },  -- Quetes (bas gauche)
        { x = half, y = -cellH, col = C.BLUE    },  -- Zone   (bas droit)
    }
    w.cCells = {}
    for i, cell in ipairs(cells) do
        local num = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        num:SetPoint("TOPLEFT", f, "TOPLEFT", cell.x + PAD, cell.y - 8)
        local fn_ = num:GetFont(); num:SetFont(fn_, 16)
        num:SetTextColor(cell.col[1], cell.col[2], cell.col[3])
        num:SetText("--")

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", cell.x + PAD, cell.y - 28)
        lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])

        w.cCells[i] = { num = num, lbl = lbl }
    end
    w.cCells[1].lbl:SetText("XP / heure")
    w.cCells[2].lbl:SetText("Duree")
    w.cCells[3].lbl:SetText("Quetes")
    w.cCells[4].lbl:SetText("Zone")

    f:Hide()
    compactBody = f
    return f
end

-- Helper : tronque une chaine si trop longue
local function Trunc(s, max)
    if not s then return "--" end
    if #s > max then return string.sub(s, 1, max - 2) .. ".." end
    return s
end

RefreshCompactBody = function()
    if not compactBody or not w.cCells then return end
    local db = LvlHistory.db
    if not db then return end
    local U       = LvlHistory.Utils
    local isLev   = (db.mode ~= "farming")
    local elapsed = time() - (db.session.startTime or time())

    -- ── Helper local : remplir une cellule ──────
    local function Cell(idx, numStr, lblStr, col)
        w.cCells[idx].num:SetText(numStr or "--")
        w.cCells[idx].lbl:SetText(lblStr or "")
        if col then
            w.cCells[idx].num:SetTextColor(col[1], col[2], col[3])
        else
            w.cCells[idx].num:SetTextColor(C.GOLD_DIM[1], C.GOLD_DIM[2], C.GOLD_DIM[3])
        end
    end

    -- ── Contenu selon l'onglet actif ────────────

    if activeTab == 1 then
        -- SESSION : XP/h | Duree | Quetes | Zone
        if isLev then
            Cell(1, U.FormatXPH(db.session.xph or 0), "XP / heure", C.GREEN)
        else
            Cell(1, U.FormatGold(db.farming.goldPerHour or 0, true), "Or / heure", C.GOLD)
        end
        Cell(2, U.FormatTime(elapsed, true), "Duree", C.GOLD_DIM)
        local qc = db.session.questCount or 0
        Cell(3, tostring(qc), "Quetes", qc > 0 and C.BLUE or C.MUTED)
        Cell(4, Trunc(db.session.zone or GetRealZoneText(), 16), "Zone", C.BLUE)

    elseif activeTab == 2 then
        -- ZONES : Zones visitees | Temps total | Zone favorite | Duree record
        local zones = db.zones or {}
        local zoneCount, totalDur, topZone, topDur = 0, 0, "--", 0
        for z, dur in pairs(zones) do
            zoneCount = zoneCount + 1
            totalDur  = totalDur + dur
            if dur > topDur then topZone = z; topDur = dur end
        end
        Cell(1, tostring(zoneCount), "Zones visitees", zoneCount > 0 and C.BLUE or C.MUTED)
        Cell(2, totalDur > 0 and U.FormatTime(totalDur, true) or "--", "Temps total", C.GOLD_DIM)
        Cell(3, Trunc(topZone, 14), "Zone favorite", C.GOLD)
        Cell(4, topDur > 0 and U.FormatTime(topDur, true) or "--", "Duree record", C.GOLD_DIM)

    elseif activeTab == 3 then
        -- ALTS : Alts suivis | Niveau max | Temps cumule | Top perso
        local chars = LvlHistoryDB and LvlHistoryDB.chars or {}
        local altCount, totalTime, topLvl, topName = 0, 0, 0, "--"
        for key, data in pairs(chars) do
            altCount  = altCount + 1
            totalTime = totalTime + (data.totalPlayTime or 0)
            if (data.level or 0) > topLvl then
                topLvl  = data.level or 0
                topName = key:match("^([^%-]+)") or key
            end
        end
        local maxLvl = GetMaxPlayerLevel()
        Cell(1, tostring(altCount), "Alts suivis", altCount > 0 and C.BLUE or C.MUTED)
        Cell(2, topLvl > 0 and tostring(topLvl) or "--", "Niveau max",
            topLvl >= maxLvl and C.GREEN or C.PURP_LT)
        Cell(3, totalTime > 0 and U.FormatTime(totalTime, true) or "--", "Temps cumule", C.GOLD_DIM)
        Cell(4, Trunc(topName, 14), "Top perso", C.GOLD)

    elseif activeTab == 4 then
        -- DONJONS : Cette session | Total | Donjon favori | Fois
        local sessCount  = db.session.dungeons or 0
        local totalCount = #(db.dgnLog or {})
        local topName, topCount = "--", 0
        for name, cnt in pairs(db.dgnRuns or {}) do
            if cnt > topCount then topName = name; topCount = cnt end
        end
        Cell(1, tostring(sessCount), "Cette session", sessCount > 0 and C.GREEN or C.MUTED)
        Cell(2, tostring(totalCount), "Total", totalCount > 0 and C.BLUE or C.MUTED)
        Cell(3, Trunc(topName, 14), "Favori", C.GOLD)
        Cell(4, topCount > 0 and ("x" .. topCount) or "--", "Fois joue", C.GOLD_DIM)

    elseif activeTab == 5 then
        -- STATS : Temps total | Quetes | Donjons | Sessions
        local grandTotal = (db.totalPlayTime or 0) + elapsed
        local qt         = (db.quests and db.quests.total) or 0
        local dgnTotal   = 0
        for _, cnt in pairs(db.dgnRuns or {}) do dgnTotal = dgnTotal + cnt end
        local sessCount  = #(db.sessions or {})
        Cell(1, U.FormatTime(grandTotal, true), "Temps total", C.GOLD_DIM)
        Cell(2, tostring(qt), "Quetes totales", qt > 0 and C.BLUE or C.MUTED)
        Cell(3, tostring(dgnTotal), "Donjons totaux", dgnTotal > 0 and C.GREEN or C.MUTED)
        Cell(4, tostring(sessCount), "Sessions", sessCount > 0 and C.GOLD_DIM or C.MUTED)
    end
end

function UI.Collapse()
    if not mainFrame then return end
    isCollapsed = true
    mainFrame:SetSize(COMPACT_W, HDR_H + COMPACT_BODY_H)
    if tabBarRef   then tabBarRef:Hide()   end
    if contentRef  then contentRef:Hide()  end
    if footerRef   then footerRef:Hide()   end
    if compactBody then compactBody:Show() end
    RefreshCompactBody()
    if w.colBtnLbl then w.colBtnLbl:SetText("+") end
    if LvlHistoryDB and LvlHistoryDB.settings then
        LvlHistoryDB.settings.collapsed = true
    end
end

function UI.Expand()
    if not mainFrame then return end
    isCollapsed = false
    mainFrame:SetSize(FW, FH)
    if tabBarRef   then tabBarRef:Show()   end
    if contentRef  then contentRef:Show()  end
    if footerRef   then footerRef:Show()   end
    if compactBody then compactBody:Hide() end
    if w.colBtnLbl then w.colBtnLbl:SetText("-") end
    if LvlHistoryDB and LvlHistoryDB.settings then
        LvlHistoryDB.settings.collapsed = false
    end
end

-- ─────────────────────────────────────────────
-- Popup slider d'opacite
-- ─────────────────────────────────────────────

local function BuildOpacityPopup(parent)
    local pop = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    pop:SetSize(180, 48)
    -- Ancre sur le bouton Opacite dans le footer (w.opacBtn cree avant)
    pop:SetPoint("BOTTOMLEFT", w.opacBtn, "TOPLEFT", -8, 4)
    pop:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 4, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    pop:SetBackdropColor(C.BG_HDR[1], C.BG_HDR[2], C.BG_HDR[3], 1)
    pop:SetBackdropBorderColor(C.BORDER[1], C.BORDER[2], C.BORDER[3], 1)
    pop:SetFrameStrata("TOOLTIP")
    pop:Hide()

    local lbl = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)
    lbl:SetTextColor(C.DIM[1], C.DIM[2], C.DIM[3])
    lbl:SetText("Opacite")

    local valLbl = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valLbl:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -10, -8)
    valLbl:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])

    local slider = CreateFrame("Slider", "LvlHistoryOpacSlider", pop, "OptionsSliderTemplate")
    slider:SetPoint("BOTTOMLEFT",  pop, "BOTTOMLEFT",  14, 8)
    slider:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -14, 8)
    slider:SetHeight(16)
    slider:SetMinMaxValues(30, 100)
    slider:SetValueStep(1)

    -- Appliquer la valeur sauvee
    local savedAlpha = LvlHistoryDB and LvlHistoryDB.settings
        and LvlHistoryDB.settings.alpha or 0.97
    slider:SetValue(math.floor(savedAlpha * 100))
    valLbl:SetText(math.floor(savedAlpha * 100) .. "%")

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val)
        local alpha = val / 100
        mainFrame:SetAlpha(alpha)
        valLbl:SetText(val .. "%")
        if LvlHistoryDB and LvlHistoryDB.settings then
            LvlHistoryDB.settings.alpha = alpha
        end
    end)

    -- Masquer les labels par defaut du template
    if _G["LvlHistoryOpacSliderLow"]  then _G["LvlHistoryOpacSliderLow"]:SetText("")  end
    if _G["LvlHistoryOpacSliderHigh"] then _G["LvlHistoryOpacSliderHigh"]:SetText("") end
    if _G["LvlHistoryOpacSliderText"] then _G["LvlHistoryOpacSliderText"]:SetText("") end

    opacPopup = pop
end

-- ─────────────────────────────────────────────
-- Construction du frame principal
-- ─────────────────────────────────────────────

local function Build()
    mainFrame = CreateFrame("Frame", "LvlHistoryMainFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate")
    mainFrame:SetSize(FW, FH)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop",  mainFrame.StopMovingOrSizing)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:Hide()

    -- Fond + bordure principale
    mainFrame:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    mainFrame:SetBackdropColor(C.BG[1], C.BG[2], C.BG[3], C.BG[4])
    mainFrame:SetBackdropBorderColor(C.BORDER[1], C.BORDER[2], C.BORDER[3], 1)

    -- Restaure l'opacite sauvegardee des l'ouverture
    local savedAlpha = (LvlHistoryDB and LvlHistoryDB.settings
        and LvlHistoryDB.settings.alpha) or 0.97
    mainFrame:SetAlpha(savedAlpha)

    -- Rafraichissement live : met a jour le chrono, l'XP/h et l'onglet actif
    -- environ une fois par seconde tant que la fenetre est ouverte.
    mainFrame:SetScript("OnUpdate", function(self, e)
        self._acc = (self._acc or 0) + e
        if self._acc < 1 then return end
        self._acc = 0
        if not self:IsShown() then return end
        RefreshGlobal()
        if isCollapsed then return end
        local fn = UI["RefreshTab" .. activeTab]
        if fn then fn() end
    end)

    BuildHeader(mainFrame)
    tabBarRef = BuildTabBar(mainFrame)
    BuildFooter(mainFrame)
    BuildOpacityPopup(mainFrame)

    local ca = ContentArea(mainFrame)

    local builders = {
        BuildTabSession,
        BuildTabZones,
        BuildTabAlts,
        BuildTabDungeons,
                BuildTabStats,
    }
    for i, builder in ipairs(builders) do
        panels[i] = builder(ca)
    end

    ShowTab(1)
end

-- ─────────────────────────────────────────────
-- API publique
-- ─────────────────────────────────────────────

function UI.Show()
    if not mainFrame then Build() end
    mainFrame:Show()
    -- Restaure l'etat reduit sauvegarde (grille compacte 2x2)
    if LvlHistoryDB and LvlHistoryDB.settings
        and LvlHistoryDB.settings.collapsed and not isCollapsed then
        UI.Collapse()
    end
    UI.RefreshTab1()
end

function UI.Hide()
    if mainFrame then mainFrame:Hide() end
end

function UI.Toggle()
    if not mainFrame then
        UI.Show()
        return
    end
    if mainFrame:IsShown() then
        UI.Hide()
    else
        UI.Show()
    end
end

function UI.Init()
    -- Le frame est construit à la première ouverture (lazy build)
end

-- Fonction globale appelée par TibiSuite
function LvlHistory_Toggle()
    LvlHistory.UI.Toggle()
end
