--[[============================================================================
  LvlHistory - Intégration TibiSuite "Midnight"  (ajout non destructif)
  Cet addon utilisait une palette brune : on l'harmonise en Midnight (FULLSKIN).
============================================================================]]

local FRAME    = "LvlHistoryMainFrame"
local ACCENT   = { 0.369, 0.886, 0.137 }   -- vert (logo #5EE223)
local LOGO     = "Interface\\AddOns\\LvlHistory\\Media\\icon"
local KEY      = "Lvl"
local FULLSKIN = true

local function GetUI() return _G.TibiMidnight end
local function Settings() local db = _G.LvlHistoryDB; return db and db.settings end

-- ---------------------------------------------------------------- Options
local panel
local function BuildOptions()
  local ui = GetUI(); if not ui then return nil end
  if panel then return panel end
  panel = ui.CreateOptionsPanel({
    name = "LvlHistoryOptionsMidnight",
    title = "|cFF9480FFLvlHistory|r  Options", accent = ACCENT })

  panel:Section("Fenêtre")
  panel:Button("Ouvrir / fermer", function()
    if _G.LvlHistory_Toggle then _G.LvlHistory_Toggle() end
  end)
  panel:Button("Recentrer la fenêtre", function()
    local f = _G[FRAME]; if f then f:ClearAllPoints(); f:SetPoint("CENTER") end
  end)
  panel:Slider("Opacité (%)", 30, 100, 5,
    function() local s = Settings(); return math.floor(((s and s.alpha) or 0.97) * 100 + 0.5) end,
    function(v)
      local s = Settings(); if s then s.alpha = v / 100 end
      local f = _G[FRAME]; if f then f:SetAlpha(v / 100) end
    end)

  panel:Note("Astuce : clic droit sur la vignette Lvl Hist dans la barre TibiSuite ouvre aussi ces options.")
  return panel
end

function LvlHistory_OpenOptions()
  local p = BuildOptions(); if p then p:Toggle() end
end

-- ---------------------------------------------------------------- Recherche
-- On cherche parmi les personnages suivis et, si presentes, leurs zones.
local function provider(q)
  local out, ui = {}, GetUI()
  local db = _G.LvlHistoryDB
  if not ui or type(db) ~= "table" or type(db.chars) ~= "table" then return out end
  for key, char in pairs(db.chars) do
    local label = (type(char) == "table" and char.name) or key
    if ui.Match(label, q) then
      out[#out + 1] = { text = tostring(label),
        onClick = function()
          local f = _G[FRAME]
          if _G.LvlHistory_Toggle and (not f or not f:IsShown()) then _G.LvlHistory_Toggle() end
        end }
    end
    if type(char) == "table" and type(char.zones) == "table" then
      for zname in pairs(char.zones) do
        if type(zname) == "string" and ui.Match(zname, q) then
          out[#out + 1] = { text = zname .. "  |cff808080" .. tostring(label) .. "|r",
            onClick = function()
              local f = _G[FRAME]
              if _G.LvlHistory_Toggle and (not f or not f:IsShown()) then _G.LvlHistory_Toggle() end
            end }
        end
      end
    end
    if #out >= 60 then return out end
  end
  return out
end

local searchPopup
local function OpenSearch()
  local ui = GetUI(); if not ui then return end
  if not searchPopup then
    searchPopup = ui.CreateSearchPopup({
      name = "LvlHistorySearchPopup",
      title = "|cFF9480FFLvlHistory|r  Recherche", accent = ACCENT, logo = LOGO, provider = provider })
  end
  searchPopup.Toggle()
end

-- ---------------------------------------------------------- Attache & skin
local function Decorate()
  local ui = GetUI(); local f = _G[FRAME]
  if not (ui and f) then return end
  if not f._tibiSkinned then
    ui.SkinFrame(f, ACCENT)
    f._tibiSkinned = true
  end
  if f._tibiControls then return end
  ui.AddHeaderControls(f, {
    accent = ACCENT,
    onOptions = function() LvlHistory_OpenOptions() end,
    provider = provider,
  })
end

-- Inscription immediate au registre de recherche globale
-- (le provider lit les donnees a la volee ; plus fiable que PLAYER_LOGIN seul)
do local _u = GetUI(); if _u and _u.RegisterSearch then _u.RegisterSearch(KEY, "Lvl Hist", provider) end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  local ui = GetUI()
  if ui and ui.RegisterSearch then ui.RegisterSearch(KEY, "Lvl Hist", provider) end
  C_Timer.After(1.0, Decorate)
  C_Timer.After(3.0, Decorate)
end)
