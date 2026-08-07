--[[============================================================================
  TibiMidnightUI  -  Bibliotheque d'interface commune "Flat" (facon WeeklyCompass)
  ---------------------------------------------------------------------------
  Fichier partage, identique dans les 9 addons de la suite TibiSuite.
  Identite visuelle unique : fond plat sombre, bordure fine quasi noire,
  separateurs discrets, EN-TETE avec logo, et un LISERE fin a la couleur
  d'identite du module. Fournit aussi les briques reutilisables : boutons
  d'en-tete (roue + loupe), champ de recherche, fabriques de widgets, un
  constructeur de panneau d'Options flottant et un popup de recherche.

  Protege par un numero de version : si une version identique ou plus recente
  est deja chargee par un autre addon, on garde la meilleure.

  Auteur : Tibiscui - Kirin Tor
============================================================================]]

local NS_VERSION = 8

if _G.TibiMidnight and (_G.TibiMidnight._version or 0) >= NS_VERSION then
  return
end

local UI = _G.TibiMidnight or {}
_G.TibiMidnight = UI
UI._version = NS_VERSION

-- ============================================================================
-- PALETTE PLATE  (facon WeeklyCompass) - valeurs 0-1, r,g,b,a
-- ============================================================================
UI.C = {
  BG      = { 0.060, 0.070, 0.090, 0.98 },  -- fond principal  #0F1217
  PANEL   = { 0.055, 0.063, 0.082, 0.99 },  -- fond des panneaux
  HDR     = { 0.078, 0.090, 0.114, 1.00 },  -- bandeau d'en-tete  #141922
  SEP     = { 1.000, 1.000, 1.000, 0.10 },  -- separateurs discrets (blanc 10%)
  BORDER  = { 0.000, 0.000, 0.000, 1.00 },  -- bordure fine quasi noire
  GOLD    = { 1.000, 0.843, 0.000, 1.00 },  -- accent doux pour les valeurs
  LAV     = { 0.580, 0.502, 1.000, 1.00 },  -- lavande (liens divers)
  TXT     = { 0.902, 0.910, 0.941, 1.00 },  -- texte principal
  DIM     = { 0.620, 0.650, 0.710, 1.00 },  -- texte attenue
  MUTED   = { 0.420, 0.450, 0.510, 1.00 },  -- sous-texte
  OK      = { 0.400, 0.851, 0.541, 1.00 },  -- vert "oui"
  NO      = { 0.898, 0.420, 0.420, 1.00 },  -- rouge "non"
}

function UI.Hex(r, g, b)
  return string.format("|cFF%02X%02X%02X",
    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- ============================================================================
-- NORMALISATION DE TEXTE (recherche insensible casse + accents)
-- ============================================================================
local ACCENTS = {
  ["à"]="a",["â"]="a",["ä"]="a",["á"]="a",["ã"]="a",["À"]="a",["Â"]="a",["Ä"]="a",
  ["é"]="e",["è"]="e",["ê"]="e",["ë"]="e",["É"]="e",["È"]="e",["Ê"]="e",["Ë"]="e",
  ["î"]="i",["ï"]="i",["í"]="i",["ì"]="i",["Î"]="i",["Ï"]="i",
  ["ô"]="o",["ö"]="o",["ó"]="o",["ò"]="o",["õ"]="o",["Ô"]="o",["Ö"]="o",
  ["û"]="u",["ü"]="u",["ú"]="u",["ù"]="u",["Û"]="u",["Ü"]="u",
  ["ç"]="c",["Ç"]="c",["ñ"]="n",["Ñ"]="n",
}
function UI.Normalize(s)
  if not s then return "" end
  s = tostring(s):lower()
  s = s:gsub("[\192-\255][\128-\191]*", function(ch) return ACCENTS[ch] or ch end)
  return s
end

function UI.Match(haystack, needle)
  if needle == "" then return true end
  local h = UI.Normalize(haystack)
  if h:find(needle, 1, true) then return true end
  -- Tolérance singulier/pluriel : « fragments » doit trouver « fragment ».
  -- On retire un « s » ou « x » final de la requête et on réessaie.
  if #needle > 3 then
    local last = needle:sub(-1)
    if last == "s" or last == "x" then
      if h:find(needle:sub(1, -2), 1, true) then return true end
    end
  end
  return false
end

-- ============================================================================
-- CADRE PLAT (bordure 1 px) + LISERE d'accent + LOGO d'en-tete
-- ============================================================================
-- Backdrop plat : fond uni + bordure fine de 1 pixel (comme WeeklyCompass).
function UI.FlatBackdrop()
  return {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  }
end

-- Alias de compatibilité : d'anciens appels utilisent UI.Backdrop(...)
function UI.Backdrop() return UI.FlatBackdrop() end

-- Ajoute (ou met a jour) le fin liseré colore en haut de la frame.
function UI.SetLisere(f, accent)
  if not f or not f.CreateTexture then return end
  if not f._tibiLisere then
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    t:SetHeight(2)
    f._tibiLisere = t
  end
  if accent then
    f._tibiLisere:SetColorTexture(accent[1], accent[2], accent[3], 1)
    f._tibiLisere:Show()
  else
    f._tibiLisere:Hide()
  end
end

-- Applique le fond plat + bordure fine + liseré d'accent.
--   accent  : {r,g,b} couleur d'identite (liseré). nil = pas de liseré.
--   bgTable : fond a utiliser (defaut : UI.C.BG)
function UI.SkinFrame(f, accent, bgTable)
  if f.SetBackdrop then
    f:SetBackdrop(UI.FlatBackdrop())
    local bg = bgTable or UI.C.BG
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.98)
    f:SetBackdropBorderColor(UI.C.BORDER[1], UI.C.BORDER[2], UI.C.BORDER[3], 1)
  end
  UI.SetLisere(f, accent)
end

-- Ajoute un petit logo en haut a gauche (une seule fois).
--   path : chemin de texture WoW SANS extension (WoW resout .tga/.blp)
function UI.AddHeaderLogo(f, path, size)
  if not f or not f.CreateTexture or f._tibiLogo or not path then return f and f._tibiLogo end
  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetSize(size or 18, size or 18)
  t:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  t:SetTexture(path)
  f._tibiLogo = t
  return t
end

-- ============================================================================
-- BOUTON GENERIQUE (texte) - style plat
-- ============================================================================
function UI.MakeButton(parent, w, h, text)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetBackdrop(UI.FlatBackdrop())
  b:SetBackdropColor(1, 1, 1, 0.05)
  b:SetBackdropBorderColor(1, 1, 1, 0.12)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetAllPoints()
  fs:SetText(text or "")
  b._label = fs
  b:SetScript("OnEnter", function(s) s:SetBackdropColor(1, 1, 1, 0.10); s:SetBackdropBorderColor(1, 1, 1, 0.25) end)
  b:SetScript("OnLeave", function(s) s:SetBackdropColor(1, 1, 1, 0.05); s:SetBackdropBorderColor(1, 1, 1, 0.12) end)
  return b
end

-- ============================================================================
-- BOUTON D'EN-TETE (roue, loupe, croix...) - plat, sans bordure
-- ============================================================================
function UI.HeaderIcon(parent, glyph, tooltip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetText(glyph)
  b._label = fs
  fs:SetAlpha(0.75)
  b:SetScript("OnEnter", function(s)
    s._label:SetAlpha(1)
    if tooltip then
      GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.95)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(s) s._label:SetAlpha(0.75); GameTooltip:Hide() end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

-- ============================================================================
-- CONTROLES D'EN-TETE LISIBLES : case "Rechercher..." + bouton "Options"
-- Remplace les glyphes Unicode (carres vides en jeu) par du texte lisible et
-- une vraie texture de loupe Blizzard. Ancres au-dessus du coin haut-droit.
--   cfg = { accent={r,g,b}, onOptions=fn, onSearch=fn }
-- ============================================================================
-- Champ de recherche INLINE : on tape dedans, les resultats apparaissent en
-- direct dans un popup deroulant juste en dessous (pas de fenetre separee).
--   cfg = { accent={r,g,b}, provider=fn, width=, placeholder= }
--   provider(requeteNormalisee) -> { {text=, onClick=}, ... }
--   Renvoie { box, drop, Show, Hide, Toggle, SetFocus }
function UI.MakeSearchField(parent, cfg)
  cfg = cfg or {}
  local W = cfg.width or 150
  local DW = cfg.dropWidth or math.max(W, 260)  -- largeur du popup de résultats
  local accent = cfg.accent or UI.C.LAV

  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetSize(W, 20)
  box:SetBackdrop(UI.FlatBackdrop())
  box:SetBackdropColor(0.02, 0.01, 0.04, 0.95)
  box:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.8)
  box:SetAutoFocus(false)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 18, 0, 0)

  local mag = box:CreateTexture(nil, "OVERLAY")
  mag:SetSize(12, 12); mag:SetPoint("RIGHT", -4, 0)
  mag:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

  local ph = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ph:SetPoint("LEFT", 6, 0); ph:SetText(cfg.placeholder or "Rechercher...")

  -- Popup de resultats (deroulant)
  local drop = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  drop:SetFrameStrata("FULLSCREEN_DIALOG")
  UI.SkinFrame(drop, accent, UI.C.PANEL)
  drop:Hide()

  -- Place le popup (largeur fixe DW) : sous le champ ou au-dessus si pas la place,
  -- et aligné du côté où il reste de la place à l'écran (jamais coupé par un bord).
  local function placeDrop(h)
    drop:ClearAllPoints()
    drop:SetWidth(DW)
    local up = false
    local roomBelow = box:GetBottom()
    if roomBelow and roomBelow < (h + 10) then up = true end
    local cx = box:GetCenter()
    local scx = (UIParent:GetWidth() or 1024) / 2
    local rightSide = (cx and cx > scx)  -- champ à droite -> popup vers la gauche
    local vA = up and "BOTTOM" or "TOP"
    local vR = up and "TOP" or "BOTTOM"
    local vy = up and 2 or -2
    if rightSide then
      drop:SetPoint(vA .. "RIGHT", box, vR .. "RIGHT", 0, vy)
    else
      drop:SetPoint(vA .. "LEFT", box, vR .. "LEFT", 0, vy)
    end
  end

  local scroll = CreateFrame("ScrollFrame", nil, drop, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -24, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(DW - 30, 10)
  scroll:SetScrollChild(content)

  local rows = {}
  local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 4, -4); empty:SetText("Aucun résultat.")

  local function render(qraw)
    for _, r in ipairs(rows) do r:Hide() end
    local q = UI.Normalize(qraw or "")
    if q == "" then drop:Hide(); return end
    local results = {}
    if cfg.provider then
      local ok, res = pcall(cfg.provider, q)
      if ok and type(res) == "table" then results = res end
    end
    empty:SetShown(#results == 0)
    local y = -4
    for i, item in ipairs(results) do
      local r = rows[i]
      if not r then
        r = UI.MakeButton(content, DW - 34, 34, "")
        r._label:ClearAllPoints()
        r._label:SetPoint("LEFT", 6, 0); r._label:SetPoint("RIGHT", -6, 0); r._label:SetJustifyH("LEFT")
        if r._label.SetWordWrap then r._label:SetWordWrap(true) end
        rows[i] = r
      end
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
      r._label:SetText(item.text or "")
      r:SetScript("OnClick", function()
        if item.onClick then pcall(item.onClick) end
        box:SetText(""); drop:Hide(); box:ClearFocus()
      end)
      r:Show(); y = y - 36
    end
    content:SetHeight(math.max(-y + 4, 24))
    local visH = math.min(math.max(#results, 1), 8) * 36 + 12
    drop:SetHeight(visH)
    placeDrop(visH)
    drop:Show()
  end

  box:SetScript("OnTextChanged", function(s) ph:SetShown(s:GetText() == "") render(s:GetText()) end)
  box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus(); drop:Hide() end)
  box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
  box:SetScript("OnEditFocusLost", function()
    -- Quitter le champ (clic dans le jeu, etc.) efface la recherche et ferme le popup.
    C_Timer.After(0.20, function()
      if not box:HasFocus() then
        box:SetText(""); ph:SetShown(true); drop:Hide()
      end
    end)
  end)

  local h = { box = box, drop = drop }
  h.Show = function() box:Show() end
  h.Hide = function() box:Hide(); drop:Hide() end
  h.Toggle = function() if box:IsShown() then h.Hide() else box:Show(); box:SetFocus() end end
  h.SetFocus = function() box:SetFocus() end
  return h
end

function UI.AddHeaderControls(frame, cfg)
  cfg = cfg or {}
  if frame._tibiControls then return frame._tibiControls end
  local accent = cfg.accent or UI.C.LAV
  local ctrls = {}

  -- Bouton Options (texte lisible)
  local opt = UI.MakeButton(frame, 66, 20, "")
  opt._label:SetText(UI.Hex(accent[1], accent[2], accent[3]) .. "Options|r")
  opt:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -2, 3)
  if cfg.onOptions then opt:SetScript("OnClick", cfg.onOptions) end
  ctrls.options = opt

  -- Champ de recherche inline (resultats en popup en direct)
  if cfg.provider then
    local field = UI.MakeSearchField(frame, { accent = accent, provider = cfg.provider, width = 150 })
    field.box:SetPoint("RIGHT", opt, "LEFT", -4, 0)
    ctrls.search = field
  end

  frame._tibiControls = ctrls
  return ctrls
end

-- ============================================================================
-- CHAMP DE RECHERCHE (loupe qui ouvre/ferme une EditBox) - usage libre
-- ============================================================================
function UI.AttachSearch(parent, anchorTo, onChanged)
  local icon = UI.HeaderIcon(parent, "\226\140\149", "Rechercher")
  if anchorTo then icon:SetPoint("RIGHT", anchorTo, "LEFT", -4, 0)
  else icon:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -34, -8) end

  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetSize(150, 22)
  box:SetPoint("RIGHT", icon, "LEFT", -4, 0)
  box:SetBackdrop(UI.FlatBackdrop())
  box:SetBackdropColor(1, 1, 1, 0.06)
  box:SetBackdropBorderColor(1, 1, 1, 0.15)
  box:SetAutoFocus(false)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 6, 0, 0)
  box:Hide()

  box:SetScript("OnTextChanged", function(self) if onChanged then onChanged(UI.Normalize(self:GetText())) end end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); self:Hide(); if onChanged then onChanged("") end end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  local handle = { icon = icon, box = box }
  handle.Toggle = function()
    if box:IsShown() then box:SetText(""); box:Hide(); if onChanged then onChanged("") end
    else box:Show(); box:SetFocus() end
  end
  icon:SetScript("OnClick", handle.Toggle)
  return handle
end

-- ============================================================================
-- REGISTRE DE RECHERCHE GLOBALE
-- ============================================================================
UI.searchProviders = UI.searchProviders or {}
function UI.RegisterSearch(key, label, fn) UI.searchProviders[key] = { label = label, fn = fn } end

-- Recherche globale : interroge TOUS les modules inscrits et ENTRELACE leurs
-- résultats (un de chaque module à tour de rôle), pour qu'aucun addon ne
-- monopolise la liste et que tout le contenu de la suite soit représenté.
function UI.RunGlobalSearch(query)
  local q = UI.Normalize(query)
  if q == "" then return {} end

  local perModule, keys = {}, {}
  for key, prov in pairs(UI.searchProviders) do
    local ok, res = pcall(prov.fn, q)
    if ok and type(res) == "table" and #res > 0 then
      for _, item in ipairs(res) do item._module = prov.label or key end
      perModule[key] = res
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)  -- ordre stable des modules

  local out, i, added = {}, 1, true
  while added and #out < 300 do
    added = false
    for _, key in ipairs(keys) do
      local item = perModule[key][i]
      if item then out[#out + 1] = item; added = true end
    end
    i = i + 1
  end
  return out
end

-- ============================================================================
-- EN-TETE COMMUN (bandeau + logo + titre a l'accent + bouton fermer)
-- Utilise par les panneaux d'options et les popups de recherche.
-- ============================================================================
local function BuildHeader(f, cfg)
  UI.SkinFrame(f, cfg.accent, cfg.bg or UI.C.PANEL)

  local hdr = f:CreateTexture(nil, "ARTWORK")
  hdr:SetColorTexture(UI.C.HDR[1], UI.C.HDR[2], UI.C.HDR[3], 1)
  hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)
  hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -3)
  hdr:SetHeight(32)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  if cfg.logo then
    local logo = f:CreateTexture(nil, "OVERLAY")
    logo:SetSize(20, 20)
    logo:SetPoint("LEFT", hdr, "LEFT", 10, 0)
    logo:SetTexture(cfg.logo)
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  else
    title:SetPoint("LEFT", hdr, "LEFT", 12, 0)
  end
  title:SetText(cfg.title or "")
  if cfg.accent then title:SetTextColor(cfg.accent[1], cfg.accent[2], cfg.accent[3]) end

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)
  return hdr
end

-- ============================================================================
-- CONSTRUCTEUR DE PANNEAU D'OPTIONS FLOTTANT
--   UI.CreateOptionsPanel{ name=, title=, accent={r,g,b}, logo="chemin" }
--   Methodes : :Section :Note :Check :Slider :Color :Button :Show :Hide :Toggle
-- ============================================================================
function UI.CreateOptionsPanel(cfg)
  cfg = cfg or {}
  local accent = cfg.accent

  local f = CreateFrame("Frame", cfg.name, UIParent, "BackdropTemplate")
  f:SetSize(320, 460)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  BuildHeader(f, cfg)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -42)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(280, 10)
  scroll:SetScrollChild(content)

  local panel = { frame = f, content = content, _y = -6, _refresh = {} }
  local function advance(h) panel._y = panel._y - h end
  local function fit() content:SetHeight(math.max(-panel._y + 10, 10)) end

  local function accentText(txt)
    if accent then return UI.Hex(accent[1], accent[2], accent[3]) .. txt .. "|r" end
    return UI.Hex(UI.C.GOLD[1], UI.C.GOLD[2], UI.C.GOLD[3]) .. txt .. "|r"
  end

  function panel:Section(text)
    local s = content:CreateTexture(nil, "ARTWORK")
    s:SetColorTexture(UI.C.SEP[1], UI.C.SEP[2], UI.C.SEP[3], UI.C.SEP[4])
    s:SetSize(264, 1)
    s:SetPoint("TOPLEFT", content, "TOPLEFT", 4, panel._y - 4)
    local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, panel._y - 10)
    fs:SetText(accentText(text))
    advance(30); fit(); return self
  end

  function panel:Note(text)
    local fs = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    fs:SetWidth(260); fs:SetJustifyH("LEFT"); fs:SetText(text)
    advance((fs:GetStringHeight() or 12) + 10); fit(); return self
  end

  function panel:Check(label, getFn, setFn, tooltip)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, panel._y)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 4, 0); t:SetText(label)
    cb:SetChecked(getFn())
    cb:SetScript("OnClick", function(s) setFn(s:GetChecked() and true or false) end)
    if tooltip then
      cb:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(tooltip, nil, nil, nil, nil, true); GameTooltip:Show() end)
      cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    panel._refresh[#panel._refresh + 1] = function() cb:SetChecked(getFn()) end
    advance(28); fit(); return self
  end

  function panel:Slider(label, minV, maxV, step, getFn, setFn)
    local cap = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cap:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    local function setCap(v) cap:SetText(label .. " : " .. UI.Hex(UI.C.GOLD[1],UI.C.GOLD[2],UI.C.GOLD[3]) .. tostring(v) .. "|r") end
    setCap(getFn())
    local sl = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    sl:SetWidth(250)
    sl:SetPoint("TOPLEFT", content, "TOPLEFT", 10, panel._y - 18)
    sl:SetMinMaxValues(minV, maxV); sl:SetValueStep(step); sl:SetObeyStepOnDrag(true)
    sl:SetValue(getFn())
    if sl.Low then sl.Low:SetText("") end
    if sl.High then sl.High:SetText("") end
    if sl.Text then sl.Text:SetText("") end
    sl:SetScript("OnValueChanged", function(_, v) v = math.floor(v / step + 0.5) * step; setCap(v); setFn(v) end)
    panel._refresh[#panel._refresh + 1] = function() sl:SetValue(getFn()); setCap(getFn()) end
    advance(52); fit(); return self
  end

  function panel:Color(label, getFn, setFn)
    local b = UI.MakeButton(content, 250, 22, label)
    b:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    local sw = b:CreateTexture(nil, "OVERLAY")
    sw:SetSize(14, 14); sw:SetPoint("RIGHT", -6, 0)
    local function refresh() local c = getFn(); sw:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    refresh()
    b:SetScript("OnClick", function()
      local c = getFn(); local r, g, bl, a = c[1], c[2], c[3], c[4] or 1
      local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = a; if ColorPickerFrame.GetColorAlpha then na = ColorPickerFrame:GetColorAlpha() end
        setFn(nr, ng, nb, na); refresh()
      end
      local info = { swatchFunc = apply, opacityFunc = apply, hasOpacity = true, r = r, g = g, b = bl, opacity = a,
        cancelFunc = function() setFn(r, g, bl, a); refresh() end }
      if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info)
      else ColorPickerFrame.func = apply; ColorPickerFrame.opacityFunc = apply; ColorPickerFrame.cancelFunc = info.cancelFunc
        ColorPickerFrame.hasOpacity = true; ColorPickerFrame.opacity = a; ColorPickerFrame:SetColorRGB(r, g, bl); ColorPickerFrame:Show() end
    end)
    panel._refresh[#panel._refresh + 1] = refresh
    advance(28); fit(); return self
  end

  function panel:Button(label, onClick)
    local b = UI.MakeButton(content, 250, 24, label)
    b:SetPoint("TOPLEFT", content, "TOPLEFT", 6, panel._y)
    b:SetScript("OnClick", onClick)
    advance(30); fit(); return self
  end

  function panel:Refresh() for _, fn in ipairs(panel._refresh) do pcall(fn) end end
  function panel:Show() panel:Refresh(); f:Show() end
  function panel:Hide() f:Hide() end
  function panel:IsShown() return f:IsShown() end
  function panel:Toggle() if f:IsShown() then f:Hide() else panel:Show() end end
  f:SetScript("OnShow", function() panel:Refresh() end)
  return panel
end

-- ============================================================================
-- POPUP DE RECHERCHE  (recherche locale d'un module, ou globale)
--   UI.CreateSearchPopup{ name=, title=, accent={r,g,b}, logo=, provider=fn }
-- ============================================================================
function UI.CreateSearchPopup(cfg)
  cfg = cfg or {}
  local f = CreateFrame("Frame", cfg.name, UIParent, "BackdropTemplate")
  f:SetSize(360, 400)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  BuildHeader(f, cfg)

  local box = CreateFrame("EditBox", nil, f, "BackdropTemplate")
  box:SetSize(330, 26)
  box:SetPoint("TOP", 0, -42)
  box:SetBackdrop(UI.FlatBackdrop())
  box:SetBackdropColor(1, 1, 1, 0.06)
  box:SetBackdropBorderColor(1, 1, 1, 0.15)
  box:SetAutoFocus(true)
  box:SetFontObject("GameFontHighlight")
  box:SetTextInsets(8, 8, 0, 0)
  box:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -78)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(300, 10)
  scroll:SetScrollChild(content)

  local rows = {}
  local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 4, -6)
  empty:SetText("Tapez pour rechercher.")

  local function render(query)
    for _, r in ipairs(rows) do r:Hide() end
    local q = UI.Normalize(query or "")
    local results = {}
    if q ~= "" and cfg.provider then
      local ok, res = pcall(cfg.provider, q)
      if ok and type(res) == "table" then results = res end
    end
    empty:SetShown(#results == 0)
    empty:SetText(q == "" and "Tapez pour rechercher." or "Aucun résultat.")
    local y = -6
    for i, item in ipairs(results) do
      local r = rows[i]
      if not r then
        r = UI.MakeButton(content, 290, 24, "")
        r._label:ClearAllPoints(); r._label:SetPoint("LEFT", 8, 0); r._label:SetPoint("RIGHT", -8, 0); r._label:SetJustifyH("LEFT")
        rows[i] = r
      end
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
      r._label:SetText(item.text or "")
      r:SetScript("OnClick", function() if item.onClick then pcall(item.onClick) end end)
      r:Show(); y = y - 28
    end
    content:SetHeight(math.max(-y + 10, 10))
  end

  box:SetScript("OnTextChanged", function(s) render(s:GetText()) end)
  f:SetScript("OnShow", function() box:SetFocus(); render(box:GetText() or "") end)

  local handle = { frame = f }
  handle.Show = function() f:Show() end
  handle.Hide = function() f:Hide() end
  handle.Toggle = function() if f:IsShown() then f:Hide() else f:Show() end end
  return handle
end

-- Fin de TibiMidnightUI
