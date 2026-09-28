
	----------------------------------------------------------------------
	-- 	Leatrix Maps 3.0.188 - WoW 3.3.5a Backport by Fivebuttons
	----------------------------------------------------------------------

	-- 10:Func, 20:Comm, 30:Evnt, 40:Panl

	-- Create global table
	_G.LeaMapsDB = _G.LeaMapsDB or {}

	-- Create local tables
	local LeaMapsLC, LeaMapsCB, LeaDropList, LeaConfigList, LeaLockList = {}, {}, {}, {}, {}
	_G.LeaMapsLC = LeaMapsLC  -- expose for Reveal.lua and other modules

	-- Version
	LeaMapsLC["AddonVer"] = "3.0.188-335"

	-- Get locale table
	local void, Leatrix_Maps = ...
	local L = Leatrix_Maps.L


	-- Check for addons
	if IsAddOnLoaded("ElvUI") then LeaMapsLC.ElvUI = unpack(ElvUI) end
	if IsAddOnLoaded("Carbonite") then LeaMapsLC.Carbonite = true end
	if IsAddOnLoaded("Demodal") then LeaMapsLC.Demodal = true end

	-- Set bindings translations
	_G.BINDING_NAME_LEATRIX_MAPS_GLOBAL_TOGGLE = L["Toggle panel"]

	----------------------------------------------------------------------
	-- 3.3.5 API Compatibility Layer
	----------------------------------------------------------------------

	-- ConvertRGBtoColorString does not exist in 3.3.5a
	if not ConvertRGBtoColorString then
		function ConvertRGBtoColorString(color)
			return string.format("|cff%02x%02x%02x",
				math.floor((color.r or 0) * 255 + 0.5),
				math.floor((color.g or 0) * 255 + 0.5),
				math.floor((color.b or 0) * 255 + 0.5))
		end
	end

	-- Zone name -> C_Map mapID lookup (for Icons data keyed by mapID)
	local zoneNameToMapID = {
		-- Eastern Kingdoms
		["Alterac Mountains"]    = 16,
		["Arathi Highlands"]     = 17,
		["Badlands"]             = 18,
		["Blasted Lands"]        = 20,
		["Burning Steppes"]      = 30,
		["Deadwind Pass"]        = 33,
		["Dun Morogh"]           = 28,
		["Duskwood"]             = 35,
		["Eastern Plaguelands"]  = 24,
		["Elwynn Forest"]        = 31,
		["Eversong Woods"]       = 463,
		["Ghostlands"]           = 464,
		["Hillsbrad Foothills"]  = 25,
		["Ironforge"]            = 342,
		["Isle of Quel'Danas"]   = 500,
		["Loch Modan"]           = 36,
		["Redridge Mountains"]   = 37,
		["Searing Gorge"]        = 29,
		["Silverpine Forest"]    = 22,
		["Stormwind City"]       = 302,
		["Stranglethorn Vale"]   = 38,
		["Swamp of Sorrows"]     = 39,
		["The Hinterlands"]      = 27,
		["Tirisfal Glades"]      = 21,
		["Undercity"]            = 383,
		["Westfall"]             = 40,
		["Western Plaguelands"]  = 23,
		["Wetlands"]             = 41,
		-- Kalimdor
		["Ashenvale"]            = 44,
		["Azshara"]              = 182,
		["Azuremyst Isle"]       = 465,
		["Bloodmyst Isle"]       = 477,
		["Darkshore"]            = 43,
		["Darnassus"]            = 382,
		["Desolace"]             = 102,
		["Durotar"]              = 5,
		["Dustwallow Marsh"]     = 142,
		["Felwood"]              = 183,
		["Feralas"]              = 122,
		["Moonglade"]            = 242,
		["Mulgore"]              = 10,
		["Orgrimmar"]            = 322,
		["Silithus"]             = 262,
		["Stonetalon Mountains"] = 82,
		["Tanaris"]              = 162,
		["Teldrassil"]           = 42,
		["The Barrens"]          = 12,
		["Thousand Needles"]     = 62,
		["Thunder Bluff"]        = 363,
		["Un'Goro Crater"]       = 202,
		["Winterspring"]         = 282,
		-- Outland
		["Blade's Edge Mountains"] = 476,
		["Hellfire Peninsula"]   = 466,
		["Nagrand"]              = 478,
		["Netherstorm"]          = 480,
		["Shadowmoon Valley"]    = 474,
		["Shattrath City"]       = 482,
		["Terokkar Forest"]      = 479,
		["Zangarmarsh"]          = 468,
		-- Northrend
		["Borean Tundra"]        = 487,
		["Crystalsong Forest"]   = 511,
		["Dalaran"]              = 505,
		["Dragonblight"]         = 489,
		["Grizzly Hills"]        = 491,
		["Howling Fjord"]        = 492,
		["Icecrown"]             = 493,
		["Sholazar Basin"]       = 494,
		["The Storm Peaks"]      = 496,
		["Storm Peaks"]          = 496,
		["Wintergrasp"]          = 502,
		["Zul'Drak"]             = 497,
	}

	-- mapID -> {continent, zoneIndex} built dynamically from GetMapZones at login
	local mapIDToCZ = {}

	-- Get current map area ID using WotLK native API
	local function GetCurrentMapID()
		local areaID = GetCurrentMapAreaID()
		if areaID and areaID > 0 then
			return areaID
		end
		return nil
	end

	-- Navigate to a mapID (continent/zone expressed as C_Map IDs)
	local function NavigateToMapID(mapID)
		local cz = mapIDToCZ[mapID]
		if cz then
			SetMapZoom(cz[1], cz[2])
		end
	end

	-- Pin vertex colors for fallback (non-atlas) types
	local pinColors = {
		["Spirit"]   = {0.1, 0.9, 0.1},
		["Arrow"]    = {1.0, 0.9, 0.0},
	}

	-- Atlas texture (objecticonsatlas.blp bundled in Leatrix_Maps/textures)
	-- UV data matches WDM addon's _data.lua atlasIcons table.
	-- Format: {width, height, left, right, top, bottom, texture, hitWidth, hitHeight}
	local wdmAtlasTex = "Interface\\AddOns\\Leatrix_Maps\\textures\\objecticonsatlas"
	local arrowTex    = "Interface\\AddOns\\Leatrix_Maps\\textures\\ZoneCrossingArrow"
	local flatTex     = "Interface\\ChatFrame\\ChatFrameBackground"
	local atlasIconData = {
		["Dungeon"]                     = {32, 32, 0.198242,  0.247070,  0.313477, 0.362305},
		["Raid"]                        = {32, 32, 0.198242,  0.247070,  0.364258, 0.413086},
		["TaxiNode_Alliance"]           = {21, 21, 0.534180,  0.565430,  0.535156, 0.566406},
		["TaxiNode_Horde"]              = {21, 21, 0.534180,  0.565430,  0.568359, 0.599609},
		["TaxiNode_Neutral"]            = {21, 21, 0.534180,  0.565430,  0.601562, 0.632812},
		["TaxiNode_Continent_Alliance"] = {28, 28, 0.778320,  0.840820,  0.127930, 0.190430},
		["TaxiNode_Continent_Horde"]    = {28, 28, 0.907227,  0.969727,  0.127930, 0.190430},
		["TaxiNode_Continent_Neutral"]  = {28, 28, 0.133789,  0.196289,  0.256836, 0.319336},
		["Spirit"]                      = {32, 32, 827/1024,  859/1024,  655/1024, 687/1024, "Interface\\AddOns\\Leatrix_Maps\\textures\\objecticonsatlas2"},
		-- Zone crossing arrows get their own texture rather than an atlas region.
		-- SetRotation replaces whatever SetTexCoord set with the whole file, so a
		-- rotated icon has to own its texture. Drawn at 64x64 (the arrow itself is
		-- 33x39 of that, the rest is padding it turns through); the pin frame stays
		-- 33x39 so the click target does not grow.
		["Arrow"]                       = {64, 64, 0, 1, 0, 1, arrowTex, 33, 39},
	}

	-- Active pin texture objects (reused across refreshes)
	local activePins = {}
	local pinCounter = 0

	----------------------------------------------------------------------
	-- L00: Leatrix Maps
	----------------------------------------------------------------------

	-- Main function
	function LeaMapsLC:MainFunc()

		----------------------------------------------------------------------
		-- Build mapID -> {continent, zoneIndex} lookup dynamically
		----------------------------------------------------------------------

		for cont = 1, 4 do
			local zones = {GetMapZones(cont)}
			for zi, zoneName in ipairs(zones) do
				local mapID = zoneNameToMapID[zoneName]
				if mapID then
					mapIDToCZ[mapID] = {cont, zi}
				end
			end
		end

		----------------------------------------------------------------------
		-- Basic world map setup
		----------------------------------------------------------------------

		-- Handle open and close the map for sticky map frame
		if LeaMapsLC["UseDefaultMap"] == "On" or LeaMapsLC["StickyMapFrame"] == "Off" then
			table.insert(UISpecialFrames, "WorldMapFrame")
		end

		-- WorldMapBlobFrame is a QuestPOIFrame, which is natively protected.
		-- Detach the blob just before lockdown starts (PLAYER_REGEN_DISABLED
		-- still allows it) and reattach it afterwards (same approach as Mapster).
		-- While detached, calls that would be blocked are recorded instead.
		if WorldMapBlobFrame then
			local blob = WorldMapBlobFrame
			local blobDetached, blobShown, blobParent, blobScale, blobPoints
			local function noop() end
			local blobEvent = CreateFrame("Frame")
			blobEvent:RegisterEvent("PLAYER_REGEN_DISABLED")
			blobEvent:RegisterEvent("PLAYER_REGEN_ENABLED")
			blobEvent:SetScript("OnEvent", function(self, event)
				if event == "PLAYER_REGEN_DISABLED" and not blobDetached then
					blobDetached = true
					blobShown  = blob:IsShown()
					blobParent = blob:GetParent()
					blobScale  = blob:GetScale()
					blobPoints = {}
					for i = 1, blob:GetNumPoints() do
						blobPoints[i] = {blob:GetPoint(i)}
					end
					blob:Hide()
					blob:SetParent(UIParent)
					blob:ClearAllPoints()
					-- Dummy position off screen so blob calculations still work
					blob:SetPoint("TOP", UIParent, "BOTTOM")
					blob.Show = function() blobShown = true end
					blob.Hide = function() blobShown = false end
					blob.SetParent = function(_, parent) blobParent = parent end
					blob.SetScale = function(_, scale) blobScale = scale end
					blob.ClearAllPoints = noop
					blob.SetPoint = noop
					blob.SetAllPoints = noop
				elseif event == "PLAYER_REGEN_ENABLED" and blobDetached then
					blobDetached = nil
					blob.Show, blob.Hide, blob.SetParent, blob.SetScale = nil, nil, nil, nil
					blob.ClearAllPoints, blob.SetPoint, blob.SetAllPoints = nil, nil, nil
					blob:SetParent(blobParent)
					blob:SetScale(blobScale)
					blob:ClearAllPoints()
					for i = 1, #blobPoints do
						blob:SetPoint(unpack(blobPoints[i]))
					end
					blob.xRatio = nil -- force hit recalculations
					if blobShown then
						blob:Show()
						if WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuest then
							blob:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, false)
							blob:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, true)
						end
					end
				end
			end)
		end

		-- Hide Track Quest checkbox (it's not needed)
		if WorldMapTrackQuest then
			WorldMapTrackQuest:ClearAllPoints()
			WorldMapTrackQuest.SetPoint = function() return end
			WorldMapTrackQuest:SetHitRectInsets(0, 0, 0, 0)
		end
		if WorldMapTrackQuestText then
			WorldMapTrackQuestText:SetText("")
		end

		-- Hide Quest Objectives checkbox (it's in the configuration panel)
		if WorldMapQuestShowObjectives then
			WorldMapQuestShowObjectives:SetHitRectInsets(0, 0, 0, 0)
			WorldMapQuestShowObjectives:ClearAllPoints()
			WorldMapQuestShowObjectives.SetPoint = function() return end
		end
		if WorldMapQuestShowObjectivesText then
			WorldMapQuestShowObjectivesText:SetText("")
		end

		-- Set full opacity by default. WotLK 3.3.5a does not reset SetAlpha on each
		-- OnShow, so a single call at init time is sufficient (Mapster uses same approach).
		-- The SetMapOpacity feature below overrides this with the user's chosen value.
		WorldMapFrame:SetAlpha(1)

		-- Initialise map zoom feature (Leatrix_Maps_Zoom.lua)
		LeaMapsZoom.OnFirstLoad()

		-- Initialise fog-of-war reveal feature (Leatrix_Maps_Reveal.lua)
		LeaMapsFC.Setup()

		-- Unlock map frame
		if WorldMapTitleDropDown_ToggleLock then
			WorldMapTitleDropDown_ToggleLock()
		end

		-- Remove right-click from title bar
		if WorldMapTitleButton then
			WorldMapTitleButton:RegisterForClicks("LeftButtonDown")
		end

		-- Get player faction
		local playerFaction = UnitFactionGroup("player")

		-- Hide world map dropdown menus to prevent taint (we use our own)
		local menuTempFrame = CreateFrame("FRAME")
		menuTempFrame:Hide()
		if WorldMapContinentDropDown then WorldMapContinentDropDown:SetParent(menuTempFrame) end
		if WorldMapZoneDropDown then WorldMapZoneDropDown:SetParent(menuTempFrame) end
		if WorldMapZoomOutButton then WorldMapZoomOutButton:SetParent(menuTempFrame) end
		if WorldMapZoneMinimapDropDown then WorldMapZoneMinimapDropDown:SetParent(menuTempFrame) end

		-- Hide right-click to zoom out button and magnifying glass
		if WorldMapZoomOutButton then WorldMapZoomOutButton:Hide() end
		if WorldMapMagnifyingGlassButton then WorldMapMagnifyingGlassButton:Hide() end

		----------------------------------------------------------------------
		-- Map appearance
		----------------------------------------------------------------------

		-- Suppress the world blackout overlay
		if BlackoutWorld then BlackoutWorld:Hide() end

		-- Permanently hide title button + zone-name label; block re-show hooks
		local function PermanentlyHide(f)
			if f then f:Hide(); f.Show = function() end end
		end
		PermanentlyHide(WorldMapTitleButton)
		PermanentlyHide(WorldMapFrameTitle)

		-- Hide the mini-map stone-border frames and prevent Blizzard restoring them
		PermanentlyHide(WorldMapFrameMiniBorderLeft)
		PermanentlyHide(WorldMapFrameMiniBorderRight)

		-- Hide the maximize button (map is always windowed, matching TBC Classic behaviour)
		PermanentlyHide(WorldMapFrameSizeUpButton)

		-- Kill all default Blizzard decorations on the frame layers
		WorldMapFrame:DisableDrawLayer("BACKGROUND")
		WorldMapFrame:DisableDrawLayer("ARTWORK")
		WorldMapFrame:DisableDrawLayer("OVERLAY")

		local mapBorder = WorldMapScrollFrame:CreateTexture(nil, "BACKGROUND")
		mapBorder:SetPoint("TOPLEFT",     WorldMapScrollFrame, "TOPLEFT",     -5,  5)
		mapBorder:SetPoint("BOTTOMRIGHT", WorldMapScrollFrame, "BOTTOMRIGHT",  5, -5)
		mapBorder:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		mapBorder:SetVertexColor(0, 0, 0, 0.5)

		if WorldMapFrameCloseButton then
			WorldMapFrameCloseButton:ClearAllPoints()
			-- UIPanelCloseButton is 32x32 in 3.3.5a; the Classic artwork is smaller
			WorldMapFrameCloseButton:SetSize(18, 18)
			WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WorldMapScrollFrame, "TOPRIGHT", 0, 0)
			WorldMapFrameCloseButton:SetFrameLevel(5000)
			WorldMapFrameCloseButton.SetPoint = function() end
		end
		if WorldMapButton and WorldMapFrameCloseButton then
			local closeSpacer = CreateFrame("Frame", nil, WorldMapButton)
			closeSpacer:SetSize(WorldMapFrameCloseButton:GetWidth(), WorldMapFrameCloseButton:GetHeight())
			closeSpacer:SetPoint("TOPRIGHT", WorldMapButton, "TOPRIGHT", 0, 0)
			closeSpacer:Show()
		end

		----------------------------------------------------------------------
		-- Show objectives
		----------------------------------------------------------------------

		local function DoShowObjectivesFunc()
			if LeaMapsLC["ShowObjectives"] == "On" then
				SetCVar("questPOI", "1")
			else
				SetCVar("questPOI", "0")
			end
		end

		LeaMapsCB["ShowObjectives"]:HookScript("OnClick", DoShowObjectivesFunc)
		DoShowObjectivesFunc()

		----------------------------------------------------------------------
		-- Show zone dropdown menu
		----------------------------------------------------------------------

		if LeaMapsLC["ShowZoneMenu"] == "On" then

			-- Continent translations
			L["Eastern Kingdoms"] = POSTMASTER_PIPE_EASTERNKINGDOMS or "Eastern Kingdoms"
			L["Kalimdor"] = POSTMASTER_PIPE_KALIMDOR or "Kalimdor"
			L["Outland"] = POSTMASTER_PIPE_OUTLAND or "Outland"
			L["Northrend"] = POSTMASTER_PIPE_NORTHREND or "Northrend"


			local outerFrame = CreateFrame("FRAME", nil, WorldMapFrame)
			outerFrame:SetSize(360, 20)
			outerFrame:SetPoint("TOPLEFT", WorldMapScrollFrame, "TOPLEFT", 3, 15)
			outerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
			outerFrame:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
			-- Helper: build zone table for a continent
			local function BuildContinentTable(continentIndex, continentName, continentMapID)
				local t, s = {}, {}
				local zones = {GetMapZones(continentIndex)}
				for zi, zoneName in ipairs(zones) do
					tinsert(t, {zonename = zoneName, continent = continentIndex, zoneindex = zi})
					tinsert(s, zoneName)
				end
				table.sort(s, function(a, b) return a < b end)
				table.sort(t, function(a, b) return a.zonename < b.zonename end)
				tinsert(s, 1, continentName)
				tinsert(t, 1, {zonename = continentName, continent = continentIndex, zoneindex = 0})
				return t, s
			end

			-- Build tables for each continent
			local mapEasternTable, mapEasternString = BuildContinentTable(1, L["Eastern Kingdoms"], 1415)
			local mapKalimdorTable, mapKalimdorString = BuildContinentTable(2, L["Kalimdor"], 1414)
			local mapOutlandTable, mapOutlandString = BuildContinentTable(3, L["Outland"], 1945)
			local mapNorthrendTable, mapNorthrendString = BuildContinentTable(4, L["Northrend"], 113)

			-- Continent dropdown
			local mapContinentTable, mapContinentString = {}, {}
			tinsert(mapContinentString, L["Eastern Kingdoms"])
			tinsert(mapContinentTable, {zonename = L["Eastern Kingdoms"], continent = 1, zoneindex = 0})
			tinsert(mapContinentString, L["Kalimdor"])
			tinsert(mapContinentTable, {zonename = L["Kalimdor"], continent = 2, zoneindex = 0})
			tinsert(mapContinentString, L["Outland"])
			tinsert(mapContinentTable, {zonename = L["Outland"], continent = 3, zoneindex = 0})
			tinsert(mapContinentString, L["Northrend"])
			tinsert(mapContinentTable, {zonename = L["Northrend"], continent = 4, zoneindex = 0})

			-- Initialize dropdown state variables
			LeaMapsLC["ZoneMapNoneMenu"] = 1
			LeaMapsLC["ZoneMapEasternMenu"] = 1
			LeaMapsLC["ZoneMapKalimdorMenu"] = 1
			LeaMapsLC["ZoneMapOutlandMenu"] = 1
			LeaMapsLC["ZoneMapNorthrendMenu"] = 1
			LeaMapsLC["ZoneMapContinentMenu"] = 1

			-- Create dropdowns — continent first so zone dds can anchor to its right edge
			local cond = LeaMapsLC:CreateDropDown("ZoneMapContinentMenu", "", WorldMapFrame, 180, "TOP", -80, -35, mapContinentString, "")
			cond:ClearAllPoints()
			cond:SetPoint("TOPLEFT", outerFrame, "TOPLEFT", 0, 0)

			local nodd = LeaMapsLC:CreateDropDown("ZoneMapNoneMenu", "", WorldMapFrame, 180, "TOP", -80, -35, {"---"}, "")
			nodd:ClearAllPoints()
			nodd:SetPoint("TOPLEFT", cond, "TOPRIGHT", 0, 0)
			nodd.btn:Disable()

			local ekdd = LeaMapsLC:CreateDropDown("ZoneMapEasternMenu", "", WorldMapFrame, 180, "TOP", -80, -35, mapEasternString, "")
			ekdd:ClearAllPoints()
			ekdd:SetPoint("TOPLEFT", cond, "TOPRIGHT", 0, 0)

			local kmdd = LeaMapsLC:CreateDropDown("ZoneMapKalimdorMenu", "", WorldMapFrame, 180, "TOP", -80, -35, mapKalimdorString, "")
			kmdd:ClearAllPoints()
			kmdd:SetPoint("TOPLEFT", cond, "TOPRIGHT", 0, 0)

			local otdd = LeaMapsLC:CreateDropDown("ZoneMapOutlandMenu", "", WorldMapFrame, 180, "TOP", -80, -35, mapOutlandString, "")
			otdd:ClearAllPoints()
			otdd:SetPoint("TOPLEFT", cond, "TOPRIGHT", 0, 0)

			local nrdd = LeaMapsLC:CreateDropDown("ZoneMapNorthrendMenu", "", WorldMapFrame, 180, "TOP", -80, -35, mapNorthrendString, "")
			nrdd:ClearAllPoints()
			nrdd:SetPoint("TOPLEFT", cond, "TOPRIGHT", 0, 0)

			-- Lift all zone dropdowns above WorldMapButton (FULLSCREEN child that eats clicks)
			local ddScale = 0.85  -- adjust to taste
			for _, _dd in ipairs({nodd, ekdd, kmdd, otdd, nrdd, cond}) do
				_dd:SetScale(ddScale)
				end
			-- Place WorldMapLevelDropDown (Dalaran/dungeon floors) on the same row
			if WorldMapLevelDropDown then
				WorldMapLevelDropDown:ClearAllPoints()
				WorldMapLevelDropDown:SetPoint("TOPLEFT", ekdd, "TOPRIGHT", -10, -18)
				WorldMapLevelDropDown:SetScale(ddScale)
			end

			local _ddLevel = outerFrame:GetFrameLevel() + 1
			for _, _dd in ipairs({nodd, ekdd, kmdd, otdd, nrdd, cond}) do
				_dd:SetFrameStrata("FULLSCREEN_DIALOG")
				_dd:SetFrameLevel(_ddLevel)
			end
			if WorldMapLevelDropDown then
				WorldMapLevelDropDown:SetFrameStrata("FULLSCREEN_DIALOG")
				WorldMapLevelDropDown:SetFrameLevel(_ddLevel)
			end

			-- Navigate when zone dropdown selection changes
			local function NavZone(tbl, k)
				local entry = tbl[k]
				if entry then
					SetMapZoom(entry.continent, entry.zoneindex)
				end
			end

			LeaMapsCB["ListFrameZoneMapEasternMenu"]:HookScript("OnHide", function()
				NavZone(mapEasternTable, LeaMapsLC["ZoneMapEasternMenu"])
			end)
			LeaMapsCB["ListFrameZoneMapKalimdorMenu"]:HookScript("OnHide", function()
				NavZone(mapKalimdorTable, LeaMapsLC["ZoneMapKalimdorMenu"])
			end)
			LeaMapsCB["ListFrameZoneMapOutlandMenu"]:HookScript("OnHide", function()
				NavZone(mapOutlandTable, LeaMapsLC["ZoneMapOutlandMenu"])
			end)
			LeaMapsCB["ListFrameZoneMapNorthrendMenu"]:HookScript("OnHide", function()
				NavZone(mapNorthrendTable, LeaMapsLC["ZoneMapNorthrendMenu"])
			end)

			-- Continent dropdown selects zone sub-dropdown
			LeaMapsCB["ListFrameZoneMapContinentMenu"]:HookScript("OnHide", function()
				ekdd:Hide(); kmdd:Hide(); otdd:Hide(); nrdd:Hide(); nodd:Hide()
				local sel = LeaMapsLC["ZoneMapContinentMenu"]
				if sel == 1 then
					ekdd:Show()
					NavZone(mapEasternTable, LeaMapsLC["ZoneMapEasternMenu"])
				elseif sel == 2 then
					kmdd:Show()
					NavZone(mapKalimdorTable, LeaMapsLC["ZoneMapKalimdorMenu"])
				elseif sel == 3 then
					otdd:Show()
					NavZone(mapOutlandTable, LeaMapsLC["ZoneMapOutlandMenu"])
				elseif sel == 4 then
					nrdd:Show()
					NavZone(mapNorthrendTable, LeaMapsLC["ZoneMapNorthrendMenu"])
				end
			end)

			-- Synchronise dropdown display with current map
			local function SetMapControls()
				ekdd:Hide(); kmdd:Hide(); otdd:Hide(); nodd:Hide(); nrdd:Hide(); cond:Hide()
				LeaMapsCB["ListFrameZoneMapEasternMenu"]:Hide()
				LeaMapsCB["ListFrameZoneMapKalimdorMenu"]:Hide()
				LeaMapsCB["ListFrameZoneMapOutlandMenu"]:Hide()
				LeaMapsCB["ListFrameZoneMapNorthrendMenu"]:Hide()
				LeaMapsCB["ListFrameZoneMapContinentMenu"]:Hide()
				LeaMapsCB["ListFrameZoneMapNoneMenu"]:Hide()

				local curCont = GetCurrentMapContinent()
				local curZone = GetCurrentMapZone()

				local function matchCont(tbl, dd, contSel)
					for k, v in ipairs(tbl) do
						if v.continent == curCont and v.zoneindex == curZone then
							LeaMapsLC[dd] = k
							return true
						end
					end
					return false
				end

				if curCont == 1 then
					matchCont(mapEasternTable, "ZoneMapEasternMenu", 1)
					ekdd:Show()
					LeaMapsLC["ZoneMapContinentMenu"] = 1; cond:Show()
				elseif curCont == 2 then
					matchCont(mapKalimdorTable, "ZoneMapKalimdorMenu", 2)
					kmdd:Show()
					LeaMapsLC["ZoneMapContinentMenu"] = 2; cond:Show()
				elseif curCont == 3 then
					matchCont(mapOutlandTable, "ZoneMapOutlandMenu", 3)
					otdd:Show()
					LeaMapsLC["ZoneMapContinentMenu"] = 3; cond:Show()
				elseif curCont == 4 then
					matchCont(mapNorthrendTable, "ZoneMapNorthrendMenu", 4)
					nrdd:Show()
					LeaMapsLC["ZoneMapContinentMenu"] = 4; cond:Show()
				else
					nodd:Show()
					LeaMapsLC["ZoneMapContinentMenu"] = 1; cond:Show()
				end
			end

			-- Hook WORLD_MAP_UPDATE event and OnShow
			local mapUpdateFrame = CreateFrame("FRAME")
			mapUpdateFrame:RegisterEvent("WORLD_MAP_UPDATE")
			mapUpdateFrame:SetScript("OnEvent", SetMapControls)
			WorldMapFrame:HookScript("OnShow", SetMapControls)

			-- ElvUI: apply skin to our custom zone dropdowns
			if LeaMapsLC.ElvUI then
				local E = LeaMapsLC.ElvUI
				if E.private and E.private.skins and E.private.skins.blizzard and
				   E.private.skins.blizzard.enable and E.private.skins.blizzard.worldmap then
					local S = E:GetModule("Skins")
					if S then
						S:HandleDropDownBox(cond)
						S:HandleDropDownBox(ekdd)
						S:HandleDropDownBox(kmdd)
						S:HandleDropDownBox(otdd)
						S:HandleDropDownBox(nrdd)
						S:HandleDropDownBox(nodd)
					end
				end
			end

		end

		if WorldMapLevelDropDown and LeaMapsLC["ShowZoneMenu"] ~= "On" then
			WorldMapLevelDropDown:ClearAllPoints()
			WorldMapLevelDropDown:SetPoint("TOPLEFT", WorldMapScrollFrame, "TOPLEFT", -10, -4)
			WorldMapLevelDropDown:SetScale(0.85)
			WorldMapLevelDropDown:SetFrameStrata("FULLSCREEN_DIALOG")
			WorldMapLevelDropDown:SetFrameLevel((WorldMapButton:GetFrameLevel() or 0) + 10)
		end

		----------------------------------------------------------------------
		-- Auto change zones
		----------------------------------------------------------------------

		if LeaMapsLC["AutoChangeZones"] == "On" then

			local prevContinent, prevZone = nil, nil

			local function SyncMapToPlayer()
				SetMapToCurrentZone()
				local newCont = GetCurrentMapContinent()
				local newZone = GetCurrentMapZone()
				if newCont and newZone and newZone > 0 then
					prevContinent = newCont
					prevZone = newZone
				end
			end

			local zoneEvent = CreateFrame("FRAME")
			zoneEvent:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			zoneEvent:RegisterEvent("ZONE_CHANGED")
			zoneEvent:RegisterEvent("ZONE_CHANGED_INDOORS")
			zoneEvent:SetScript("OnEvent", function()
				-- If the map was showing the player zone before, follow the player
				if prevContinent then
					local dispCont = GetCurrentMapContinent()
					local dispZone = GetCurrentMapZone()
					if dispCont == prevContinent and dispZone == prevZone then
						SyncMapToPlayer()
					end
				end
				SetMapToCurrentZone()
				prevContinent = GetCurrentMapContinent()
				prevZone = GetCurrentMapZone()
			end)

		end

		----------------------------------------------------------------------
		-- Unlock map frame
		----------------------------------------------------------------------

		-- Create configuration panel
		local UnlockMapPanel = LeaMapsLC:CreatePanel("Unlock map frame", "UnlockMapPanel")

		-- Add controls
		LeaMapsLC:MakeTx(UnlockMapPanel, "Settings", 16, -72)
		LeaMapsLC:MakeWD(UnlockMapPanel, "Drag any border of the map frame to move it.  Use the Reset button below to restore the default position.", 16, -92, 430)

		-- Back to Main Menu button
		UnlockMapPanel.b:HookScript("OnClick", function()
			UnlockMapPanel:Hide()
			LeaMapsLC["PageF"]:Show()
		end)

		-- Reset button
		UnlockMapPanel.r:HookScript("OnClick", function()
			LeaMapsCB["resetMapPosBtn"]:Click()
			UnlockMapPanel:Hide(); UnlockMapPanel:Show()
		end)

		-- Show panel when config button is clicked
		LeaMapsCB["UnlockMapFrameBtn"]:HookScript("OnClick", function()
			UnlockMapPanel:Show()
			LeaMapsLC["PageF"]:Hide()
		end)

		----------------------------------------------------------------------
		-- Show zone levels (WDM-style: appended to WorldMapFrameAreaLabel)
		----------------------------------------------------------------------

		do
			-- Zone name -> {minLevel, maxLevel[, minFish]}
			-- Mirrors WDM zonelevel.lua data with fishing added where known
			local zoneData = {
				-- Cities / no-level zones (minLevel=0 → always gray)
				["Moonglade"]                = {0,  0},
				["Ironforge"]                = {0,  80},
				["Silvermoon City"]          = {0,  80},
				["Stormwind City"]           = {0,  80},
				["Undercity"]                = {0,  80},
				["Darnassus"]                = {0,  80},
				["Orgrimmar"]                = {0,  80},
				["The Exodar"]               = {0,  80},
				["Thunder Bluff"]            = {0,  80},
				["Shattrath City"]           = {0,  80},
				["Dalaran"]                  = {0,  80},
				-- Eastern Kingdoms
				["Dun Morogh"]               = {1,  10,  "1"},
				["Elwynn Forest"]            = {1,  10,  "1"},
				["Eversong Woods"]           = {1,  10},
				["Tirisfal Glades"]          = {1,  10,  "1"},
				["Ghostlands"]               = {10, 20,  "1"},
				["Loch Modan"]               = {10, 20,  "1"},
				["Silverpine Forest"]        = {10, 20,  "1"},
				["Westfall"]                 = {10, 20,  "1"},
				["Redridge Mountains"]       = {15, 25,  "55"},
				["Hillsbrad Foothills"]      = {20, 30,  "55"},
				["Wetlands"]                 = {20, 30,  "55"},
				["Alterac Mountains"]        = {30, 40,  "130"},
				["Arathi Highlands"]         = {30, 40,  "130"},
				["Stranglethorn Vale"]       = {30, 45,  "130 (205)"},
				["Badlands"]                 = {35, 45},
				["Swamp of Sorrows"]         = {35, 45,  "130"},
				["Searing Gorge"]            = {43, 50},
				["The Hinterlands"]          = {45, 50},
				["Blasted Lands"]            = {45, 55},
				["Burning Steppes"]          = {50, 58,  "330"},
				["Western Plaguelands"]      = {51, 58,  "330"},
				["Blackrock Mountain"]       = {52, 60},
				["Eastern Plaguelands"]      = {53, 60,  "330"},
				["Deadwind Pass"]            = {55, 60,  "330"},
				["Isle of Quel'Danas"]       = {70, 70},
				["Plaguelands: The Scarlet Enclave"] = {55, 58},
				-- Kalimdor
				["Azuremyst Isle"]           = {1,  10,  "1"},
				["Durotar"]                  = {1,  10,  "1"},
				["Mulgore"]                  = {1,  10,  "1"},
				["Teldrassil"]               = {1,  10,  "1"},
				["Bloodmyst Isle"]           = {10, 20,  "1"},
				["Darkshore"]                = {10, 20,  "1"},
				["The Barrens"]              = {10, 25,  "1"},
				["Stonetalon Mountains"]     = {15, 27,  "55"},
				["Ashenvale"]                = {18, 30,  "55"},
				["Duskwood"]                 = {18, 30,  "55"},
				["Thousand Needles"]         = {25, 35,  "130"},
				["Desolace"]                 = {30, 40,  "130"},
				["Dustwallow Marsh"]         = {35, 45,  "130"},
				["Feralas"]                  = {40, 50,  "205 (330)"},
				["Tanaris"]                  = {40, 50,  "205"},
				["Azshara"]                  = {48, 55,  "205 (330)"},
				["Felwood"]                  = {48, 55,  "205"},
				["Un'Goro Crater"]           = {48, 55,  "205"},
				["Silithus"]                 = {55, 60,  "330"},
				["Winterspring"]             = {53, 60,  "330"},
				-- Outland
				["Hellfire Peninsula"]       = {58, 63,  "305 (355)"},
				["Zangarmarsh"]              = {60, 64},
				["Terokkar Forest"]          = {62, 65,  "355 (405)"},
				["Nagrand"]                  = {64, 67,  "280"},
				["Blade's Edge Mountains"]   = {65, 68},
				["Netherstorm"]              = {67, 70},
				["Shadowmoon Valley"]        = {67, 70,  "280"},
				-- Northrend
				["Borean Tundra"]            = {68, 72,  "380 (475)"},
				["Howling Fjord"]            = {68, 72,  "380 (475)"},
				["Dragonblight"]             = {71, 74,  "380 (475)"},
				["Grizzly Hills"]            = {73, 75,  "380 (475)"},
				["Zul'Drak"]                 = {74, 77},
				["Crystalsong Forest"]       = {74, 76},
				["Sholazar Basin"]           = {76, 78,  "430 (525)"},
				["Hrothgar's Landing"]       = {77, 80},
				["Icecrown"]                 = {77, 80},
				["The Storm Peaks"]          = {77, 80},
				["Wintergrasp"]              = {77, 80,  "430 (525)"},
			}

			-- WDM-style color selection based on player vs zone levels
			local function GetLevelColor(minLvl, maxLvl)
				if minLvl <= 0 then return GRAY_FONT_COLOR_CODE end
				local pLevel = UnitLevel("player")
				local lvh = (pLevel < 60) and (minLvl - 2) or (minLvl - 1)
				if pLevel < lvh then
					return RED_FONT_COLOR_CODE
				elseif pLevel > maxLvl + 3 then
					return GRAY_FONT_COLOR_CODE
				elseif pLevel >= maxLvl and pLevel <= maxLvl + 3 then
					return GREEN_FONT_COLOR_CODE
				elseif pLevel > minLvl and pLevel < maxLvl then
					return YELLOW_FONT_COLOR_CODE
				else
					return ORANGE_FONT_COLOR_CODE
				end
			end

			-- Hook WorldMapButton OnUpdate to inject level (and optionally fishing)
			-- into WorldMapFrameAreaLabel, exactly like WDM does.
			-- The lookup only matches plain zone names; once the text is annotated
			-- subsequent calls return early and the annotation persists until the
			-- next map/zone change resets the label to a clean name.
			WorldMapButton:HookScript("OnUpdate", function()
				if LeaMapsLC["ShowZoneLevels"] ~= "On" then return end
				local text = WorldMapFrameAreaLabel:GetText()
				if not text or text == "" then return end
				local data = zoneData[text]
				if not data then return end

				local minLvl, maxLvl = data[1], data[2]
				local color = GetLevelColor(minLvl, maxLvl)
				local newText
				if minLvl == maxLvl then
					newText = text .. " " .. color .. "(" .. maxLvl .. ")" .. FONT_COLOR_CODE_CLOSE
				else
					newText = text .. " " .. color .. "(" .. minLvl .. "-" .. maxLvl .. ")" .. FONT_COLOR_CODE_CLOSE
				end

				if LeaMapsLC["ShowFishingLevels"] == "On" and data[3] then
					newText = newText .. "  " .. L["Fishing"] .. ": " .. data[3]
				end

				WorldMapFrameAreaLabel:SetText(newText)
			end)

			-- When fishing is toggled, force a label reset so the change takes
			-- effect immediately without waiting for a zone transition.
			local function ForceAreaLabelReset()
				if WorldMapFrame:IsShown() then
					WorldMapFrame_Update()
				end
			end

			-- Update when options change
			LeaMapsCB["ShowZoneLevels"]:HookScript("OnClick", ForceAreaLabelReset)

			-- Create configuration panel
			local levelFrame = LeaMapsLC:CreatePanel("Show zone levels", "levelFrame")
			LeaMapsLC:MakeTx(levelFrame, "Settings", 16, -72)
			LeaMapsLC:MakeCB(levelFrame, "ShowFishingLevels", "Show minimum fishing skill levels", 16, -92, false, "If checked, the minimum fishing skill levels will be shown.")

			LeaMapsCB["ShowFishingLevels"]:HookScript("OnClick", ForceAreaLabelReset)

			levelFrame.b:HookScript("OnClick", function()
				levelFrame:Hide()
				LeaMapsLC["PageF"]:Show()
			end)
			levelFrame.r:HookScript("OnClick", function()
				LeaMapsLC["ShowFishingLevels"] = "On"
				levelFrame:Hide(); levelFrame:Show()
			end)
			LeaMapsCB["ShowZoneLevelsBtn"]:HookScript("OnClick", function()
				if IsShiftKeyDown() and IsControlKeyDown() then
					LeaMapsLC["ShowFishingLevels"] = "On"
					if levelFrame:IsShown() then levelFrame:Hide(); levelFrame:Show() end
				else
					levelFrame:Show()
					LeaMapsLC["PageF"]:Hide()
				end
			end)
		end

		----------------------------------------------------------------------
		-- Show coordinates (no reload required)
		----------------------------------------------------------------------

		do
			-- Cursor coordinates frame
			local cCursor = CreateFrame("Frame", nil, WorldMapFrame)
			cCursor:SetPoint("BOTTOMLEFT", 73, 7)
			cCursor:SetSize(200, 16)
			cCursor.x = cCursor:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			cCursor.x:SetJustifyH("LEFT")
			cCursor.x:SetAllPoints()
			cCursor.x:SetText(L["Cursor"] .. ": 88.8, 88.8")
			cCursor:SetWidth(cCursor.x:GetStringWidth() + 30)

			-- Player coordinates frame
			local cPlayer = CreateFrame("Frame", nil, WorldMapFrame)
			cPlayer:SetPoint("BOTTOMRIGHT", -46, 7)
			cPlayer:SetSize(200, 16)
			cPlayer.x = cPlayer:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			cPlayer.x:SetJustifyH("LEFT")
			cPlayer.x:SetAllPoints()
			cPlayer.x:SetText(L["Player"] .. ": 88.8, 88.8")
			cPlayer:SetWidth(cPlayer.x:GetStringWidth() + 30)

			local cPlayerTime = -1

			-- Get cursor position normalized over WorldMapDetailFrame (0-1)
			local function GetMapCursorPosition()
				local scale = WorldMapDetailFrame:GetEffectiveScale()
				local cx, cy = GetCursorPosition()
				local width, height = WorldMapDetailFrame:GetSize()
				if not width or width == 0 or height == 0 then return nil, nil end
				local centerX, centerY = WorldMapDetailFrame:GetCenter()
				if not centerX then return nil, nil end
				local rx = (cx / scale - (centerX - width * 0.5)) / width
				local ry = (centerY + height * 0.5 - cy / scale) / height
				return rx, ry
			end

			local lastCursorRx, lastCursorRy, lastPx, lastPy

			cPlayer:SetScript("OnUpdate", function(self, elapsed)
				if cPlayerTime > 0.1 or cPlayerTime == -1 then
					-- Cursor coordinates
					if MouseIsOver(WorldMapDetailFrame) then
						local rx, ry = GetMapCursorPosition()
						if rx and ry and rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then
							local cx = floor(rx * 1000 + 0.5) / 10
							local cy = floor(ry * 1000 + 0.5) / 10
							if cx ~= lastCursorRx or cy ~= lastCursorRy then
								lastCursorRx, lastCursorRy = cx, cy
								cCursor.x:SetFormattedText("%s: %.1f, %.1f", L["Cursor"], cx, cy)
							end
						else
							if lastCursorRx then
								lastCursorRx, lastCursorRy = nil, nil
								cCursor.x:SetFormattedText("%s:", L["Cursor"])
							end
						end
					else
						if lastCursorRx then
							lastCursorRx, lastCursorRy = nil, nil
							cCursor.x:SetFormattedText("%s:", L["Cursor"])
						end
					end
				end
				if cPlayerTime > 0.2 or cPlayerTime == -1 then
					-- Player coordinates
					local px, py = GetPlayerMapPosition("player")
					if px and py and (px ~= 0 or py ~= 0) then
						local nx = floor(px * 1000 + 0.5) / 10
						local ny = floor(py * 1000 + 0.5) / 10
						if nx ~= lastPx or ny ~= lastPy then
							lastPx, lastPy = nx, ny
							cPlayer.x:SetFormattedText("%s: %.1f, %.1f", L["Player"], nx, ny)
						end
					else
						if lastPx then
							lastPx, lastPy = nil, nil
							cPlayer.x:SetFormattedText("%s:", L["Player"])
						end
					end
					cPlayerTime = 0
				end
				cPlayerTime = cPlayerTime + elapsed
			end)

			local function SetupCoords()
				if LeaMapsLC["ShowCoords"] == "On" then
					cCursor:Show(); cPlayer:Show()
				else
					cCursor:Hide(); cPlayer:Hide()
				end
			end

			LeaMapsCB["ShowCoords"]:HookScript("OnClick", SetupCoords)
			SetupCoords()

			-- Dark bar at the bottom of the map canvas housing the coords (matches TBC Classic)
			local cFrame = CreateFrame("FRAME", nil, WorldMapScrollFrame)
			cFrame:SetPoint("BOTTOMLEFT",  WorldMapScrollFrame, "BOTTOMLEFT",  0, 0)
			cFrame:SetPoint("BOTTOMRIGHT", WorldMapScrollFrame, "BOTTOMRIGHT", 0, 0)
			cFrame:SetHeight(17)
			cFrame.t = cFrame:CreateTexture(nil, "BACKGROUND")
			cFrame.t:SetAllPoints()
			cFrame.t:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
			cFrame.t:SetVertexColor(0, 0, 0, 0.5)

			-- Inset matches TBC Classic, which keeps the coords well clear of the corners
			cCursor:SetParent(cFrame)
			cCursor:ClearAllPoints()
			cCursor:SetPoint("BOTTOMLEFT", cFrame, "BOTTOMLEFT", 73, 0)

			cPlayer:SetParent(cFrame)
			cPlayer:ClearAllPoints()
			cPlayer:SetPoint("BOTTOMRIGHT", cFrame, "BOTTOMRIGHT", -46, 0)

			local function SetupCoordsBar()
				if LeaMapsLC["ShowCoords"] == "On" then
					cFrame:Show()
				else
					cFrame:Hide()
				end
			end
			LeaMapsCB["ShowCoords"]:HookScript("OnClick", SetupCoordsBar)
			SetupCoordsBar()
		end

		----------------------------------------------------------------------
		-- Map position (movable/unlockable world map frame)
		----------------------------------------------------------------------

		-- Remove frame management by UI panel system entirely. With no "area"
		-- attribute, ShowUIPanel/HideUIPanel fall back to plain Show/Hide, so
		-- opening other panels (character frame etc.) never repositions the
		-- map and opening the map never pushes other panels around.
		local function DetachMapFromUIPanels()
			WorldMapFrame:SetAttribute("UIPanelLayout-defined", true)
			WorldMapFrame:SetAttribute("UIPanelLayout-area", nil)
			WorldMapFrame:SetAttribute("UIPanelLayout-pushable", nil)
			WorldMapFrame:SetAttribute("UIPanelLayout-allowOtherPanels", true)
			WorldMapFrame:SetAttribute("UIPanelLayout-whileDead", true)
			-- Keep the map above standard panels (character frame is MEDIUM)
			WorldMapFrame:SetFrameStrata("HIGH")
			-- SetFrameStrata cascades to children, so this drags WorldMapTooltip
			-- down from TOOLTIP into HIGH, where the map artwork (WorldMapDetailFrame,
			-- level 89) draws over it: unit tooltips were built and shown correctly
			-- but rendered behind the map. Blizzard re-asserts TOOLTIP in
			-- WorldMap_ToggleSizeUp, but our ToggleSizeDown hook below runs after it.
			for _, tip in ipairs({WorldMapTooltip, WorldMapCompareTooltip1, WorldMapCompareTooltip2}) do
				tip:SetFrameStrata("TOOLTIP")
			end
		end
		UIPanelWindows["WorldMapFrame"] = nil
		DetachMapFromUIPanels()

		-- Blizzard re-registers the map as a "center" panel inside
		-- WorldMap_ToggleSizeDown, so detach again after every call
		hooksecurefunc("WorldMap_ToggleSizeDown", DetachMapFromUIPanels)

		-- Enable movement (mirrors Mapster approach)
		WorldMapFrame:SetMovable(true)
		WorldMapFrame:SetToplevel(true)
		WorldMapFrame:SetClampedToScreen(false)
		WorldMapFrame:RegisterForDrag("LeftButton")
		WorldMapFrame:SetScript("OnDragStart", function()
			if LeaMapsLC["UnlockMapFrame"] == "On" and
			   WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
				WorldMapFrame:StartMoving()
			end
		end)
		WorldMapFrame:SetScript("OnDragStop", function()
			WorldMapFrame:StopMovingOrSizing()
			WorldMapFrame:SetUserPlaced(false)
			LeaMapsLC["MapPosA"], void, LeaMapsLC["MapPosR"], LeaMapsLC["MapPosX"], LeaMapsLC["MapPosY"] = WorldMapFrame:GetPoint()
			if WorldMapTitleButton_OnDragStop then WorldMapTitleButton_OnDragStop() end
		end)

		-- Force windowed map mode on every show; Blizzard respects this CVar
		-- to open the map in mini/windowed size instead of fullscreen
		if not GetCVarBool("miniWorldMap") then
			SetCVar("miniWorldMap", "1")
		end

		-- The CVar alone only takes effect through ToggleWorldMap; other open
		-- paths (quest log, minimap button) can still show the map fullscreen.
		-- Switch to windowed now and enforce it whenever the map is shown.
		if WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
			WorldMap_ToggleSizeDown()
		end
		WorldMapFrame:HookScript("OnShow", function()
			if WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
				WorldMap_ToggleSizeDown()
			end
		end)

		-- Restore saved scale and position every time the map is shown
		WorldMapFrame:HookScript("OnShow", function()
			if LeaMapsDB["MapScale"] then
				WorldMapFrame:SetScale(LeaMapsDB["MapScale"])
			end
			WorldMapFrame:ClearAllPoints()
			WorldMapFrame:SetPoint(LeaMapsLC["MapPosA"], UIParent, LeaMapsLC["MapPosR"], LeaMapsLC["MapPosX"], LeaMapsLC["MapPosY"])
			if WorldMapTitleButton_OnDragStop then WorldMapTitleButton_OnDragStop() end
		end)

		-- ElvUI: restore mouse (ElvUI noops EnableMouse) and hide its backdrop
		if LeaMapsLC.ElvUI then
			hooksecurefunc(WorldMapFrame, "Show", function()
				if not WorldMapFrame:IsMouseEnabled() then
					WorldMapFrame:EnableMouse(true)
				end
			end)
			WorldMapFrame:HookScript("OnShow", function()
				if WorldMapFrame.backdrop then WorldMapFrame.backdrop:Hide() end
				if WorldMapDetailFrame and WorldMapDetailFrame.backdrop then
					WorldMapDetailFrame.backdrop:Hide()
				end
			end)
		end

		-- Carbonite fix
		if LeaMapsLC.Carbonite then
			hooksecurefunc(WorldMapFrame, "Show", function()
				if Nx and Nx.db and Nx.db.profile and Nx.db.profile.Map and Nx.db.profile.Map.MaxOverride == false then
					WorldMapFrame:ClearAllPoints()
					WorldMapFrame:SetPoint(LeaMapsLC["MapPosA"], UIParent, LeaMapsLC["MapPosR"], LeaMapsLC["MapPosX"], LeaMapsLC["MapPosY"])
					if WorldMapTitleButton_OnDragStop then WorldMapTitleButton_OnDragStop() end
				end
			end)
		end

		----------------------------------------------------------------------
		-- Set map opacity (simplified: no movement fader, just SetAlpha)
		----------------------------------------------------------------------

		-- ElvUI: lock SetMapOpacity if ElvUI's worldmap module is active (they conflict)
		if LeaMapsLC.ElvUI then
			local E = LeaMapsLC.ElvUI
			if E.private and E.private.worldmap and E.private.worldmap.enable then
			LeaLockList["SetMapOpacity"] = true
			end
		end

		if LeaMapsLC["SetMapOpacity"] == "On" and not LeaLockList["SetMapOpacity"] then

			local alphaFrame = LeaMapsLC:CreatePanel("Set map opacity", "alphaFrame")

			LeaMapsLC:MakeTx(alphaFrame, "Settings", 16, -72)
			LeaMapsLC:MakeWD(alphaFrame, "Set map opacity.", 16, -92)
			LeaMapsLC:MakeSL(alphaFrame, "stationaryOpacity", "Opacity", "Drag to set the map opacity.", 0.1, 1, 0.1, 36, -142, "%.1f")

			local function SetMapOpacity()
				LeaMapsCB["stationaryOpacity"].f:SetFormattedText("%.0f%%", LeaMapsLC["stationaryOpacity"] * 100)
				WorldMapFrame:SetAlpha(LeaMapsLC["stationaryOpacity"])
			end

			LeaMapsCB["stationaryOpacity"]:HookScript("OnValueChanged", SetMapOpacity)
			WorldMapFrame:HookScript("OnShow", SetMapOpacity)
			SetMapOpacity()

			----------------------------------------------------------------------
			-- Fade when moving
			----------------------------------------------------------------------

			LeaMapsLC:MakeTx(alphaFrame, "Fade when moving", 16, -185)
			LeaMapsLC:MakeWD(alphaFrame, "Fade the map while you are moving.", 16, -205)
			LeaMapsLC:MakeCB(alphaFrame, "FadeOnMove", "Enable fade when moving", 16, -225, false, "If checked, the map will fade to the opacity below while you are moving.")
			LeaMapsLC:MakeSL(alphaFrame, "movingOpacity", "Moving opacity", "Drag to set the map opacity while moving.", 0.1, 1, 0.1, 36, -285, "%.1f")

			LeaMapsCB["movingOpacity"]:HookScript("OnValueChanged", function()
				LeaMapsCB["movingOpacity"].f:SetFormattedText("%.0f%%", LeaMapsLC["movingOpacity"] * 100)
			end)

			local AceTimer = LibStub("AceTimer-3.0")
			local movingTimer

			local function CheckMovement()
				if not WorldMapFrame:IsShown() then return end
				local baseAlpha  = LeaMapsLC["stationaryOpacity"] or 1
				local targetAlpha = LeaMapsLC["movingOpacity"] or 0.3
				if GetUnitSpeed("player") ~= 0 and not WorldMapFrame:IsMouseOver() then
					UIFrameFadeOut(WorldMapFrame, 0.3, WorldMapFrame:GetAlpha(), targetAlpha)
					if WorldMapBlobFrame then
						WorldMapBlobFrame:SetFillAlpha(128 * targetAlpha)
						WorldMapBlobFrame:SetBorderAlpha(192 * targetAlpha)
					end
				else
					UIFrameFadeIn(WorldMapFrame, 0.3, WorldMapFrame:GetAlpha(), baseAlpha)
					if WorldMapBlobFrame then
						WorldMapBlobFrame:SetFillAlpha(128)
						WorldMapBlobFrame:SetBorderAlpha(192)
					end
				end
			end

			local function UpdateFadeOnMove()
				if LeaMapsLC["FadeOnMove"] == "On" then
					if not movingTimer then
						movingTimer = AceTimer:ScheduleRepeatingTimer(CheckMovement, 0.2)
					end
					LeaMapsCB["movingOpacity"]:Enable()
				else
					if movingTimer then
						AceTimer:CancelTimer(movingTimer)
						movingTimer = nil
					end
					-- Reset moving opacity to 100% and restore stationary alpha.
					LeaMapsLC["movingOpacity"] = 1.0
					LeaMapsCB["movingOpacity"]:SetValue(1.0)
					LeaMapsCB["movingOpacity"]:Disable()
					WorldMapFrame:SetAlpha(LeaMapsLC["stationaryOpacity"] or 1)
					if WorldMapBlobFrame then
						WorldMapBlobFrame:SetFillAlpha(128)
						WorldMapBlobFrame:SetBorderAlpha(192)
					end
				end
			end

			LeaMapsCB["FadeOnMove"]:HookScript("OnClick", UpdateFadeOnMove)
			UpdateFadeOnMove()

			----------------------------------------------------------------------

			alphaFrame.b:HookScript("OnClick", function()
				alphaFrame:Hide()
				LeaMapsLC["PageF"]:Show()
			end)
			alphaFrame.r:HookScript("OnClick", function()
				LeaMapsLC["stationaryOpacity"] = 1.0
				LeaMapsLC["FadeOnMove"] = "On"
				LeaMapsLC["movingOpacity"] = 0.5
				SetMapOpacity()
				UpdateFadeOnMove()
				alphaFrame:Hide(); alphaFrame:Show()
			end)
			LeaMapsCB["SetMapOpacityBtn"]:HookScript("OnClick", function()
				if IsShiftKeyDown() and IsControlKeyDown() then
					LeaMapsLC["stationaryOpacity"] = 1.0
					LeaMapsLC["FadeOnMove"] = "Off"
					LeaMapsLC["movingOpacity"] = 0.3
					SetMapOpacity()
					UpdateFadeOnMove()
					if alphaFrame:IsShown() then alphaFrame:Hide(); alphaFrame:Show() end
				else
					alphaFrame:Show()
					LeaMapsLC["PageF"]:Hide()
				end
			end)
		end

		----------------------------------------------------------------------
		-- Show points of interest (manual textures on WorldMapDetailFrame)
		----------------------------------------------------------------------

		do
			local PinData = Leatrix_Maps["Icons"]

			-- Pool of pin frames for reuse
			local pinPool = {}

			local function AcquirePin()
				local pin = table.remove(pinPool)
				if not pin then
					pinCounter = pinCounter + 1
					local n = "LeaMapsAtlasPOI" .. pinCounter
					pin = CreateFrame("Button", n, WorldMapButton)
					pin:SetSize(32, 32)
					pin:RegisterForClicks("LeftButtonUp")
					pin.tex = pin:CreateTexture(n .. "Texture", "BACKGROUND")
					pin.tex:SetWidth(16)
					pin.tex:SetHeight(16)
					pin.tex:SetPoint("CENTER", 0, 0)
					pin.tex:SetTexture(wdmAtlasTex)
					pin.glow = pin:CreateTexture(n .. "GlowTexture", "OVERLAY")
					pin.glow:SetAllPoints(pin.tex)
					pin.glow:SetTexture(wdmAtlasTex)
					pin.glow:SetBlendMode("ADD")
					pin.glow:SetAlpha(0)
					pin.hi = pin:CreateTexture(n .. "HighlightTexture", "HIGHLIGHT")
					pin.hi:SetAllPoints(pin.tex)
					pin.hi:SetTexture(wdmAtlasTex)
					pin.hi:SetBlendMode("ADD")
					pin.hi:SetAlpha(0.4)
				end
				pin:Show()
				return pin
			end

			local function ReleasePin(pin)
				pin:Hide()
				pin:ClearAllPoints()
				pin:SetScript("OnEnter", nil)
				pin:SetScript("OnLeave", nil)
				pin:SetScript("OnMouseUp", nil)
				table.insert(pinPool, pin)
			end

			local function ReleaseAllPins()
				for i = #activePins, 1, -1 do
					ReleasePin(activePins[i])
					activePins[i] = nil
				end
			end

			local function PositionPin(pin)
				local zoom = WorldMapDetailFrame:GetScale()
				if not zoom or zoom <= 0 then zoom = 1 end
				pin:SetScale(1 / zoom)
				pin:ClearAllPoints()
				pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", pin.px * zoom, pin.py * zoom)
			end

			local function RescaleAllPins()
				for i = 1, #activePins do
					PositionPin(activePins[i])
				end
			end

			local function RefreshPOI()
				ReleaseAllPins()
				if LeaMapsLC["ShowPointsOfInterest"] ~= "On" then return end

				local mapID = GetCurrentMapID()
				if not mapID or not PinData[mapID] then return end

				local mapW = WorldMapDetailFrame:GetWidth()
				local mapH = WorldMapDetailFrame:GetHeight()
				if not mapW or mapW == 0 then return end

				local count = #PinData[mapID]
				for i = 1, count do
					local pinInfo = PinData[mapID][i]
					if not pinInfo then break end

					local pType = pinInfo[1]
					local show = false

					if LeaMapsLC["ShowDungeonIcons"] == "On" and (pType == "Dungeon" or pType == "Raid" or pType == "Dunraid") then
						show = true
					elseif LeaMapsLC["ShowTravelPoints"] == "On" and playerFaction == "Alliance" and (pType == "FlightA" or pType == "FlightN" or pType == "TravelA" or pType == "TravelN") then
						show = true
					elseif LeaMapsLC["ShowTravelPoints"] == "On" and playerFaction == "Horde" and (pType == "FlightH" or pType == "FlightN" or pType == "TravelH" or pType == "TravelN") then
						show = true
					elseif LeaMapsLC["ShowTravelOpposing"] == "On" and playerFaction == "Alliance" and (pType == "FlightH" or pType == "TravelH") then
						show = true
					elseif LeaMapsLC["ShowTravelOpposing"] == "On" and playerFaction == "Horde" and (pType == "FlightA" or pType == "TravelA") then
						show = true
					elseif LeaMapsLC["ShowSpiritHealers"] == "On" and pType == "Spirit" then
						show = true
					elseif LeaMapsLC["ShowZoneCrossings"] == "On" and pType == "Arrow" then
						show = true
					end

					if show then
						local pin = AcquirePin()

						-- Position (pinInfo[2] = x%, pinInfo[3] = y%)
						local px = (pinInfo[2] / 100) * mapW
						local py = -(pinInfo[3] / 100) * mapH
						-- Anchor CENTER, not TOPLEFT. The pin is resized below from the
						-- atlas data, so a fixed corner offset puts every icon size in a
						-- different spot. Same idiom as WorldMap_UpdateLandmarks.
						pin.px, pin.py = px, py
						PositionPin(pin)

						-- Apply atlas icon or fallback colored square
						local atlasIcon = atlasIconData[pinInfo[6]]
						if atlasIcon then
							local iw, ih = atlasIcon[1], atlasIcon[2]
							local l, r, t, b = atlasIcon[3], atlasIcon[4], atlasIcon[5], atlasIcon[6]
							local tex = atlasIcon[7] or wdmAtlasTex
							local hitW, hitH = atlasIcon[8] or iw, atlasIcon[9] or ih
							-- Zone crossing arrows carry their facing (radians) in field 12
							local rot = (pType == "Arrow") and (pinInfo[12] or 0) or 0
							pin:SetSize(hitW, hitH)
							pin.tex:SetSize(iw, ih)
							pin.tex:SetTexture(tex)
							pin.tex:SetVertexColor(1, 1, 1, 1)
							pin.tex:SetTexCoord(l, r, t, b)
							pin.glow:SetTexture(tex)
							pin.glow:SetTexCoord(l, r, t, b)
							pin.glow:SetAlpha(0)
							pin.hi:SetTexture(tex)
							pin.hi:SetTexCoord(l, r, t, b)
							pin.hi:SetAlpha(0.4)
							-- Rotate last: SetRotation and SetTexCoord both write the same
							-- coordinates and the later call wins. Only whole-texture icons
							-- may take this branch; on an atlas region SetRotation would
							-- throw the region away and draw the entire sheet. The
							-- SetTexCoord calls above also clear rotation left on a pooled
							-- pin by a previous arrow.
							if rot ~= 0 then
								pin.tex:SetRotation(rot)
								pin.glow:SetRotation(rot)
								pin.hi:SetRotation(rot)
							end
						else
							pin.tex:SetTexture(flatTex)
							pin.tex:SetTexCoord(0, 1, 0, 1)
							pin.glow:SetTexture("")
							pin.glow:SetAlpha(0)
							pin.hi:SetTexture("")
							pin.hi:SetAlpha(0)
							local col = pinColors[pType]
							if col then
								pin.tex:SetVertexColor(col[1], col[2], col[3], 1)
							else
								pin.tex:SetVertexColor(1, 1, 1, 1)
							end
							pin.tex:SetRotation(0)
							pin.tex:SetSize(14, 14)
							pin:SetSize(14, 14)
						end

						-- Build tooltip: name line
						local nameText = pinInfo[4] or ""
						-- Level range (always shown for dungeons/raids)
						local isDungeon = (pType == "Dungeon" or pType == "Raid" or pType == "Dunraid")
						if isDungeon and pinInfo[7] and pinInfo[8] then
							local playerLevel = UnitLevel("player")
							local dMin, dMax = pinInfo[7], pinInfo[8]
							local color
							if playerLevel < dMin then
								color = GetQuestDifficultyColor(dMin)
							elseif playerLevel > dMax then
								color = GetQuestDifficultyColor(dMax - 2)
							else
								color = QuestDifficultyColors["difficult"]
							end
							local cs = ConvertRGBtoColorString(color)
							if dMin ~= dMax then
								nameText = nameText .. " " .. cs .. "(" .. dMin .. "-" .. dMax .. ")" .. FONT_COLOR_CODE_CLOSE
							else
								nameText = nameText .. " " .. cs .. "(" .. dMax .. ")" .. FONT_COLOR_CODE_CLOSE
							end
						end
						-- Store data on pin (name used by WorldMapPOI_OnEnter)
						pin.name = nameText
						pin.description = nil
						pin.zoneCrossingMapID = (pType == "Arrow") and pinInfo[13] or nil

						-- Tooltip + glow handled by Blizzard's WorldMapPOI handlers;
						-- they use self.name / self.description and fade the named GlowTexture.
						pin:SetScript("OnEnter", WorldMapPOI_OnEnter)
						pin:SetScript("OnLeave", WorldMapPOI_OnLeave)

						-- Zone crossing click
						pin:SetScript("OnMouseUp", function(self, btn)
							if btn == "LeftButton" and self.zoneCrossingMapID then
								NavigateToMapID(self.zoneCrossingMapID)
							end
						end)

						tinsert(activePins, pin)
					end
				end
			end

			-- Refresh POI when map changes or options change
			local poiUpdateFrame = CreateFrame("FRAME")
			poiUpdateFrame:RegisterEvent("WORLD_MAP_UPDATE")
			poiUpdateFrame:SetScript("OnEvent", RefreshPOI)
			WorldMapFrame:HookScript("OnShow", RefreshPOI)
			WorldMapFrame:HookScript("OnHide", ReleaseAllPins)

			-- Re-apply the counter-scale on every zoom change.  Wrapping the zoom
			-- module from here rather than editing it keeps Leatrix_Maps_Zoom.lua
			-- line-for-line comparable with the Magnify original it was ported from.
			local ZoomSetDetailFrameScale = LeaMapsZoom.SetDetailFrameScale
			LeaMapsZoom.SetDetailFrameScale = function(num)
				ZoomSetDetailFrameScale(num)
				RescaleAllPins()
			end

			-- Configuration panel
			local poiFrame = LeaMapsLC:CreatePanel("Show points of interest", "poiFrame")
			LeaMapsLC:MakeTx(poiFrame, "Settings", 16, -72)
			LeaMapsLC:MakeCB(poiFrame, "ShowDungeonIcons", "Show dungeons and raids", 16, -92, false, "If checked, dungeons and raids will be shown.")
			LeaMapsLC:MakeCB(poiFrame, "ShowTravelPoints", "Show travel points for same faction", 16, -112, false, "If checked, travel points for the same faction will be shown.")
			LeaMapsLC:MakeCB(poiFrame, "ShowTravelOpposing", "Show travel points for opposing faction", 16, -132, false, "If checked, travel points for the opposing faction will be shown.")
			LeaMapsLC:MakeCB(poiFrame, "ShowZoneCrossings", "Show zone crossings", 16, -152, false, "If checked, zone crossings will be shown.")
			LeaMapsLC:MakeCB(poiFrame, "ShowSpiritHealers", "Show spirit healers", 16, -172, false, "If checked, spirit healers will be shown.")

			local function SetPointsOfInterest()
				RefreshPOI()
			end

			LeaMapsCB["ShowPointsOfInterest"]:HookScript("OnClick", SetPointsOfInterest)
			LeaMapsCB["ShowDungeonIcons"]:HookScript("OnClick", SetPointsOfInterest)
			LeaMapsCB["ShowTravelPoints"]:HookScript("OnClick", SetPointsOfInterest)
			LeaMapsCB["ShowTravelOpposing"]:HookScript("OnClick", SetPointsOfInterest)
			LeaMapsCB["ShowSpiritHealers"]:HookScript("OnClick", SetPointsOfInterest)
			LeaMapsCB["ShowZoneCrossings"]:HookScript("OnClick", SetPointsOfInterest)
			LeaMapsCB["ShowZoneLevels"]:HookScript("OnClick", SetPointsOfInterest)

			poiFrame.b:HookScript("OnClick", function()
				poiFrame:Hide()
				LeaMapsLC["PageF"]:Show()
			end)
			poiFrame.r:HookScript("OnClick", function()
				LeaMapsLC["ShowDungeonIcons"] = "On"
				LeaMapsLC["ShowTravelPoints"] = "On"
				LeaMapsLC["ShowTravelOpposing"] = "Off"
				LeaMapsLC["ShowSpiritHealers"] = "Off"
				LeaMapsLC["ShowZoneCrossings"] = "On"
				SetPointsOfInterest()
				poiFrame:Hide(); poiFrame:Show()
			end)
			LeaMapsCB["ShowPointsOfInterestBtn"]:HookScript("OnClick", function()
				if IsShiftKeyDown() and IsControlKeyDown() then
					LeaMapsLC["ShowDungeonIcons"] = "On"
					LeaMapsLC["ShowTravelPoints"] = "On"
					LeaMapsLC["ShowTravelOpposing"] = "Off"
					LeaMapsLC["ShowSpiritHealers"] = "Off"
					LeaMapsLC["ShowZoneCrossings"] = "On"
					SetPointsOfInterest()
					if poiFrame:IsShown() then poiFrame:Hide(); poiFrame:Show() end
				else
					poiFrame:Show()
					LeaMapsLC["PageF"]:Hide()
				end
			end)
		end

		----------------------------------------------------------------------
		-- Show unexplored areas
		----------------------------------------------------------------------

		do

			local tintFrame = LeaMapsLC:CreatePanel("Show unexplored areas", "tintFrame")

			LeaMapsLC:MakeTx(tintFrame, "Settings", 16, -72)
			LeaMapsLC:MakeWD(tintFrame, "Choose how areas you have not discovered yet are shown.", 16, -92)
			LeaMapsLC:MakeCB(tintFrame, "RevTint", "Tint unexplored areas", 16, -122, false, "If checked, areas you have not discovered yet will be tinted with the colour below.  Areas you have discovered are always shown normally.")
			LeaMapsLC:MakeSL(tintFrame, "tintRed", "Red", "Drag to set the amount of red.", 0, 1, 0.1, 36, -182, "%.1f")
			LeaMapsLC:MakeSL(tintFrame, "tintGreen", "Green", "Drag to set the amount of green.", 0, 1, 0.1, 36, -232, "%.1f")
			LeaMapsLC:MakeSL(tintFrame, "tintBlue", "Blue", "Drag to set the amount of blue.", 0, 1, 0.1, 206, -182, "%.1f")
			LeaMapsLC:MakeSL(tintFrame, "tintAlpha", "Opacity", "Drag to set the opacity.", 0.1, 1, 0.1, 206, -232, "%.1f")

			-- Preview colour block
			local prvTitle = LeaMapsLC:MakeWD(tintFrame, "Preview", 386, -160)
			tintFrame.preview = tintFrame:CreateTexture(nil, "ARTWORK")
			tintFrame.preview:SetSize(50, 50)
			tintFrame.preview:SetPoint("TOPLEFT", prvTitle, "TOPLEFT", 0, -20)

			local function SetTintCol()
				-- 3.3.5a has no SetColorTexture, SetTexture takes the colour directly
				tintFrame.preview:SetTexture(LeaMapsLC["tintRed"], LeaMapsLC["tintGreen"], LeaMapsLC["tintBlue"], LeaMapsLC["tintAlpha"])

				-- Show slider values as percentages
				LeaMapsCB["tintRed"].f:SetFormattedText("%.0f%%", LeaMapsLC["tintRed"] * 100)
				LeaMapsCB["tintGreen"].f:SetFormattedText("%.0f%%", LeaMapsLC["tintGreen"] * 100)
				LeaMapsCB["tintBlue"].f:SetFormattedText("%.0f%%", LeaMapsLC["tintBlue"] * 100)
				LeaMapsCB["tintAlpha"].f:SetFormattedText("%.0f%%", LeaMapsLC["tintAlpha"] * 100)

				-- Enable the colour controls only while tinting is enabled
				local enabled = LeaMapsLC["RevTint"] == "On"
				for k, field in pairs({"tintRed", "tintGreen", "tintBlue", "tintAlpha"}) do
					if enabled then
						LeaMapsCB[field]:Enable(); LeaMapsCB[field]:SetAlpha(1.0)
					else
						LeaMapsCB[field]:Disable(); LeaMapsCB[field]:SetAlpha(0.3)
					end
				end
				if enabled then
					prvTitle:SetAlpha(1.0); tintFrame.preview:SetAlpha(1.0)
				else
					prvTitle:SetAlpha(0.3); tintFrame.preview:SetAlpha(0.3)
				end

				-- Recolour the overlays already on screen
				LeaMapsFC.ApplyTint()
			end

			LeaMapsCB["RevTint"]:HookScript("OnClick", SetTintCol)
			LeaMapsCB["tintRed"]:HookScript("OnValueChanged", SetTintCol)
			LeaMapsCB["tintGreen"]:HookScript("OnValueChanged", SetTintCol)
			LeaMapsCB["tintBlue"]:HookScript("OnValueChanged", SetTintCol)
			LeaMapsCB["tintAlpha"]:HookScript("OnValueChanged", SetTintCol)
			SetTintCol()

			tintFrame.b:HookScript("OnClick", function()
				tintFrame:Hide()
				LeaMapsLC["PageF"]:Show()
			end)
			tintFrame.r:HookScript("OnClick", function()
				LeaMapsLC["RevTint"] = "On"
				LeaMapsLC["tintRed"] = 0.6
				LeaMapsLC["tintGreen"] = 0.6
				LeaMapsLC["tintBlue"] = 1
				LeaMapsLC["tintAlpha"] = 1
				SetTintCol()
				tintFrame:Hide(); tintFrame:Show()
			end)
			LeaMapsCB["RevealMapsBtn"]:HookScript("OnClick", function()
				if IsShiftKeyDown() and IsControlKeyDown() then
					LeaMapsLC["RevTint"] = "On"
					LeaMapsLC["tintRed"] = 0.6
					LeaMapsLC["tintGreen"] = 0.6
					LeaMapsLC["tintBlue"] = 1
					LeaMapsLC["tintAlpha"] = 1
					SetTintCol()
					if tintFrame:IsShown() then tintFrame:Hide(); tintFrame:Show() end
				else
					tintFrame:Show()
					LeaMapsLC["PageF"]:Hide()
				end
			end)
		end

		----------------------------------------------------------------------
		-- Show minimap icon
		----------------------------------------------------------------------

		do
			local function MiniBtnClickFunc()
				if InterfaceOptionsFrame:IsShown() or VideoOptionsFrame:IsShown() or ChatConfigFrame:IsShown() then return end
				if LeaMapsLC:IsMapsShowing() then
					LeaMapsLC["PageF"]:Hide()
					LeaMapsLC:HideConfigPanels()
				else
					LeaMapsLC["PageF"]:Show()
				end
			end

			local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("Leatrix_Maps", {
				type = "data source",
				text = "Leatrix Maps",
				icon = "Interface\\AddOns\\Leatrix_Maps\\textures\\HelpIcon-Bug",
				OnClick = function(self, btn)
					MiniBtnClickFunc()
				end,
				OnTooltipShow = function(tooltip)
					if not tooltip or not tooltip.AddLine then return end
					tooltip:AddLine("Leatrix Maps")
				end,
			})

			local icon = LibStub("LibDBIcon-1.0", true)
			icon:Register("Leatrix_Maps", miniButton, LeaMapsDB)

			local function SetLibDBIconFunc()
				if LeaMapsLC["ShowMinimapIcon"] == "On" then
					LeaMapsDB["hide"] = false
					icon:Show("Leatrix_Maps")
				else
					LeaMapsDB["hide"] = true
					icon:Hide("Leatrix_Maps")
				end
			end

			LeaMapsCB["ShowMinimapIcon"]:HookScript("OnClick", SetLibDBIconFunc)
			SetLibDBIconFunc()

			-- Force map redraw when RevealMaps is toggled (mirrors Mapster OnEnable/OnDisable)
			LeaMapsCB["RevealMaps"]:HookScript("OnClick", function()
				if WorldMapFrame:IsShown() then
					WorldMapFrame_Update()
				end
			end)
		end

		----------------------------------------------------------------------
		-- Create panel in game options panel
		----------------------------------------------------------------------

		do
			local interPanel = CreateFrame("FRAME")
			interPanel.name = "Leatrix Maps"

			local maintitle = LeaMapsLC:MakeTx(interPanel, "Leatrix Maps", 0, 0)
			maintitle:SetFont(maintitle:GetFont(), 72)
			maintitle:ClearAllPoints()
			maintitle:SetPoint("TOP", 0, -72)

			local expTitle = LeaMapsLC:MakeTx(interPanel, "Wrath of the Lich King (3.3.5a)", 0, 0)
			expTitle:SetFont(expTitle:GetFont(), 24)
			expTitle:ClearAllPoints()
			expTitle:SetPoint("TOP", 0, -152)

			local subTitle = LeaMapsLC:MakeTx(interPanel, "www.leatrix.com", 0, 0)
			subTitle:SetFont(subTitle:GetFont(), 20)
			subTitle:ClearAllPoints()
			subTitle:SetPoint("BOTTOM", 0, 72)

			local slashTitle = LeaMapsLC:MakeTx(interPanel, "/ltm", 0, 0)
			slashTitle:SetFont(slashTitle:GetFont(), 72)
			slashTitle:ClearAllPoints()
			slashTitle:SetPoint("BOTTOM", subTitle, "TOP", 0, 40)

			local pTex = interPanel:CreateTexture(nil, "BACKGROUND")
			pTex:SetAllPoints()
			pTex:SetTexture("Interface\\GLUES\\Models\\UI_MainMenu\\swordgradient2")
			pTex:SetAlpha(0.2)
			pTex:SetTexCoord(0, 1, 1, 0)

			InterfaceOptions_AddCategory(interPanel)
		end

		----------------------------------------------------------------------
		-- Add zone map dropdown to main panel (battlefield minimap toggle)
		----------------------------------------------------------------------

		do
			LeaMapsLC:CreateDropDown("ZoneMapMenu", "Zone Map", LeaMapsLC["PageF"], 146, "TOPLEFT", 16, -392, {L["Never"], L["Battlegrounds"], L["Always"]}, L["Choose where the zone map should be shown."])

			local function SetZoneMapStyle()
				local zoneMapSetting = LeaMapsLC["ZoneMapMenu"]
				SetCVar("showBattlefieldMinimap", zoneMapSetting - 1)
				_G.SHOW_BATTLEFIELD_MINIMAP = zoneMapSetting - 1
				if zoneMapSetting == 1 then
					-- Never: always hide
					if BattlefieldMapFrame then BattlefieldMapFrame:Hide() end
				elseif zoneMapSetting == 2 then
					-- Battlegrounds only: show only when in a matching instance
					if BattlefieldMap_LoadUI then BattlefieldMap_LoadUI() end
					if DoesInstanceTypeMatchBattlefieldMapSettings and DoesInstanceTypeMatchBattlefieldMapSettings() then
						if BattlefieldMapFrame then BattlefieldMapFrame:Show() end
					else
						if BattlefieldMapFrame then BattlefieldMapFrame:Hide() end
					end
				elseif zoneMapSetting == 3 then
					-- Always: load and show unconditionally
					if BattlefieldMap_LoadUI then BattlefieldMap_LoadUI() end
					if BattlefieldMapFrame then BattlefieldMapFrame:Show() end
				end
			end

			SetZoneMapStyle()
			LeaMapsCB["ListFrameZoneMapMenu"]:HookScript("OnHide", function()
				SetZoneMapStyle()
				LeaMapsLC:ReloadCheck()
			end)
		end

		----------------------------------------------------------------------
		-- Resize handle — bottom-left drag (ported from Leatrix Maps TBC Classic)
		-- Only visible when "Unlock map frame" is enabled.
		----------------------------------------------------------------------

		do
			local mapLeft, mapTop, mapNormalScale, mapEffectiveScale, moveDistance = 0, 0, 1, 1, 0

		
			local function SaveMapScale()
				local scale = WorldMapFrame:GetScale()
				LeaMapsDB["MapScale"] = scale
				WorldMapScreenAnchor.preferredMinimodeScale = scale
				if WorldMapFrame:IsShown() and WorldMapFrame_UpdateQuests() > 0 then
					LeaMapsZoom.RedrawSelectedQuest()
				end
			end

			local function GetScaleDist()
				local x, y = GetCursorPosition()
				x = x / mapEffectiveScale - mapLeft
				y = mapTop - y / mapEffectiveScale
				return math.sqrt(x * x + y * y)
			end

			-- Handle frame (visible grip icon)
			local scaleHandle = CreateFrame("Frame", nil, WorldMapFrame)
			scaleHandle:SetSize(16, 16)
			scaleHandle:SetAlpha(0.5)
			scaleHandle:SetPoint("BOTTOMRIGHT", WorldMapScrollFrame, "BOTTOMRIGHT", 0, 0)
			scaleHandle:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 15)

			local scaleHandleTex = scaleHandle:CreateTexture(nil, "OVERLAY")
			scaleHandleTex:SetAllPoints()
			scaleHandleTex:SetTexture([[Interface\Buttons\UI-AutoCastableOverlay]])
			scaleHandleTex:SetTexCoord(0.619, 0.760, 0.612, 0.762)
			scaleHandleTex:SetDesaturated(true)

			-- Mouse-capture frame (sits on top of handle, expands to UIParent during drag)
			local scaleMouse = CreateFrame("Frame", nil, WorldMapFrame)
			scaleMouse:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 20)
			scaleMouse:SetAllPoints(scaleHandle)
			scaleMouse:EnableMouse(true)
			scaleMouse:SetHitRectInsets(-20, 0, -20, 0)

			scaleMouse:SetScript("OnEnter", function() scaleHandleTex:SetDesaturated(false) end)
			scaleMouse:SetScript("OnLeave", function() scaleHandleTex:SetDesaturated(true)  end)

			scaleMouse:SetScript("OnMouseDown", function(frame)
				mapLeft          = WorldMapFrame:GetLeft()
				mapTop           = WorldMapFrame:GetTop()
				mapNormalScale   = WorldMapFrame:GetScale()
				mapEffectiveScale = WorldMapFrame:GetEffectiveScale()
				moveDistance     = GetScaleDist()
				if moveDistance < 1 then moveDistance = 1 end
				frame:SetScript("OnUpdate", function()
					local scale = GetScaleDist() / moveDistance * mapNormalScale
					scale = math.max(0.4, math.min(2.0, scale))
					WorldMapFrame:SetScale(scale)
					local s = mapNormalScale / scale
					WorldMapFrame:ClearAllPoints()
					WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
						mapLeft * s, (mapTop - UIParent:GetHeight() / mapNormalScale) * s)
				end)
				frame:SetAllPoints(UIParent)
			end)
			scaleMouse:SetScript("OnMouseUp", function(frame)
				frame:SetScript("OnUpdate", nil)
				frame:SetAllPoints(scaleHandle)
				SaveMapScale()
				LeaMapsLC["MapPosA"], void, LeaMapsLC["MapPosR"], LeaMapsLC["MapPosX"], LeaMapsLC["MapPosY"] = WorldMapFrame:GetPoint()
			end)

			-- Show/hide handle: only in windowed (mini) mode when unlocked
			local function UpdateScaleHandle()
				if LeaMapsLC["UnlockMapFrame"] == "On" and
				   WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
					scaleHandle:Show(); scaleMouse:Show()
				else
					scaleHandle:Hide(); scaleMouse:Hide()
				end
			end
			LeaMapsCB["UnlockMapFrame"]:HookScript("OnClick", UpdateScaleHandle)
			WorldMapFrame:HookScript("OnShow", UpdateScaleHandle)
			UpdateScaleHandle()

			-- Ctrl+mouse wheel scaling in the zoom module changes the frame scale too
			WorldMapScrollFrame:HookScript("OnMouseWheel", function()
				if IsControlKeyDown() and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
					SaveMapScale()
				end
			end)

			-- Restore scale from previous session
			if LeaMapsDB["MapScale"] then
				WorldMapFrame:SetScale(LeaMapsDB["MapScale"])
				WorldMapScreenAnchor.preferredMinimodeScale = LeaMapsDB["MapScale"]
			end
		end

		----------------------------------------------------------------------
		-- Final code
		----------------------------------------------------------------------

		-- Show first run message
		if not LeaMapsDB["FirstRunMessageSeen"] then
			LeaMapsLC:Print(L["Enter"] .. " |cff00ff00" .. "/ltm" .. "|r " .. L["or click the minimap button to open Leatrix Maps."])
			LeaMapsDB["FirstRunMessageSeen"] = true
		end

		-- Release memory
		LeaMapsLC.MainFunc = nil

	end

	----------------------------------------------------------------------
	-- L10: Functions
	----------------------------------------------------------------------

	-- Add textures to panels
	function LeaMapsLC:CreateBar(name, parent, width, height, anchor, r, g, b, alp, tex)
		local ft = parent:CreateTexture(nil, "BORDER")
		ft:SetTexture(tex)
		ft:SetSize(width, height)
		ft:SetPoint(anchor)
		ft:SetVertexColor(r, g, b, alp)
		if name == "MainTexture" then
			ft:SetTexCoord(0.09, 1, 0, 1)
		end
	end

	-- Create a configuration panel
	function LeaMapsLC:CreatePanel(title, globref)
		local Side = CreateFrame("Frame", nil, UIParent)
		_G["LeaMapsGlobalPanel_" .. globref] = Side
		table.insert(UISpecialFrames, "LeaMapsGlobalPanel_" .. globref)
		tinsert(LeaConfigList, Side)

		Side:Hide()
		Side:SetSize(470, 480)
		Side:SetClampedToScreen(true)
		Side:SetFrameStrata("FULLSCREEN_DIALOG")
		Side:SetFrameLevel(20)

		Side.t = Side:CreateTexture(nil, "BACKGROUND")
		Side.t:SetAllPoints()
		Side.t:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
		Side.t:SetVertexColor(0.05, 0.05, 0.05)
		Side.t:SetAlpha(0.9)

		Side.c = CreateFrame("Button", nil, Side, "UIPanelCloseButton")
		Side.c:SetSize(30, 30)
		Side.c:SetPoint("TOPRIGHT", 0, 0)
		Side.c:SetScript("OnClick", function() Side:Hide() end)

		Side.r = LeaMapsLC:CreateButton("ResetButton", Side, "Reset", "BOTTOMLEFT", 16, 60, 25, "Click to reset the settings on this page.")
		Side.b = LeaMapsLC:CreateButton("BackButton", Side, "Back to Main Menu", "BOTTOMRIGHT", -16, 60, 25, "Click to return to the main menu.")

		local reloadb = LeaMapsLC:CreateButton("ConfigReload", Side, "Reload", "BOTTOMRIGHT", -16, 10, 25, LeaMapsCB["ReloadUIButton"].tiptext)
		LeaMapsLC:LockItem(reloadb, true)
		reloadb:SetScript("OnClick", ReloadUI)

		reloadb.f = reloadb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		reloadb.f:SetHeight(32)
		reloadb.f:SetPoint("RIGHT", reloadb, "LEFT", -10, 0)
		reloadb.f:SetText(LeaMapsCB["ReloadUIButton"].f:GetText())
		reloadb.f:Hide()

		LeaMapsCB["ReloadUIButton"]:HookScript("OnEnable", function()
			LeaMapsLC:LockItem(reloadb, false)
			reloadb.f:Show()
		end)
		LeaMapsCB["ReloadUIButton"]:HookScript("OnDisable", function()
			LeaMapsLC:LockItem(reloadb, true)
			reloadb.f:Hide()
		end)

		LeaMapsLC:CreateBar("FootTexture", Side, 470, 48, "BOTTOM", 0.5, 0.5, 0.5, 1.0, "Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated.png")
		LeaMapsLC:CreateBar("MainTexture", Side, 470, 433, "TOPRIGHT", 0.7, 0.7, 0.7, 0.7, "Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated.png")

		Side:EnableMouse(true)
		Side:SetMovable(true)
		Side:RegisterForDrag("LeftButton")
		Side:SetScript("OnDragStart", Side.StartMoving)
		Side:SetScript("OnDragStop", function()
			Side:StopMovingOrSizing()
			Side:SetUserPlaced(false)
			LeaMapsLC["MainPanelA"], void, LeaMapsLC["MainPanelR"], LeaMapsLC["MainPanelX"], LeaMapsLC["MainPanelY"] = Side:GetPoint()
		end)

		Side:SetScript("OnShow", function()
			Side:ClearAllPoints()
			Side:SetPoint(LeaMapsLC["MainPanelA"], UIParent, LeaMapsLC["MainPanelR"], LeaMapsLC["MainPanelX"], LeaMapsLC["MainPanelY"])
		end)

		Side.f = Side:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		Side.f:SetPoint("TOPLEFT", 16, -16)
		Side.f:SetText(L[title])

		Side.v = Side:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		Side.v:SetHeight(32)
		Side.v:SetPoint("TOPLEFT", Side.f, "BOTTOMLEFT", 0, -8)
		Side.v:SetPoint("RIGHT", Side, -32, 0)
		Side.v:SetJustifyH("LEFT"); Side.v:SetJustifyV("TOP")
		Side.v:SetText(L["Configuration Panel"])

		LeaMapsLC["PageF"]:HookScript("OnShow", function()
			if Side:IsShown() then LeaMapsLC["PageF"]:Hide() end
		end)

		return Side
	end

	-- Hide configuration panels
	function LeaMapsLC:HideConfigPanels()
		for k, v in pairs(LeaConfigList) do
			v:Hide()
		end
	end

	-- Find out if Leatrix Maps is showing
	function LeaMapsLC:IsMapsShowing()
		if LeaMapsLC["PageF"]:IsShown() then return true end
		for k, v in pairs(LeaConfigList) do
			if v:IsShown() then return true end
		end
	end

	-- Load a string variable (On/Off)
	function LeaMapsLC:LoadVarChk(var, def)
		if LeaMapsDB[var] and type(LeaMapsDB[var]) == "string" and (LeaMapsDB[var] == "On" or LeaMapsDB[var] == "Off") then
			LeaMapsLC[var] = LeaMapsDB[var]
		else
			LeaMapsLC[var] = def
			LeaMapsDB[var] = def
		end
	end

	-- Load a numeric variable
	function LeaMapsLC:LoadVarNum(var, def, valmin, valmax)
		if LeaMapsDB[var] and type(LeaMapsDB[var]) == "number" and LeaMapsDB[var] >= valmin and LeaMapsDB[var] <= valmax then
			LeaMapsLC[var] = LeaMapsDB[var]
		else
			LeaMapsLC[var] = def
			LeaMapsDB[var] = def
		end
	end

	-- Load an anchor variable
	function LeaMapsLC:LoadVarAnc(var, def)
		local valid = {CENTER=1,TOP=1,BOTTOM=1,LEFT=1,RIGHT=1,TOPLEFT=1,TOPRIGHT=1,BOTTOMLEFT=1,BOTTOMRIGHT=1}
		if LeaMapsDB[var] and type(LeaMapsDB[var]) == "string" and valid[LeaMapsDB[var]] then
			LeaMapsLC[var] = LeaMapsDB[var]
		else
			LeaMapsLC[var] = def
			LeaMapsDB[var] = def
		end
	end

	-- Checkbox tooltip
	function LeaMapsLC:TipSee()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		local parent = self:GetParent()
		local pscale = parent:GetEffectiveScale()
		local gscale = UIParent:GetEffectiveScale()
		local tscale = GameTooltip:GetEffectiveScale()
		local gap = ((UIParent:GetRight() * gscale) - (parent:GetRight() * pscale))
		if gap < (250 * tscale) then
			GameTooltip:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
		else
			GameTooltip:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
		end
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	end

	-- Button/dropdown tooltip
	function LeaMapsLC:ShowTooltip()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		local parent = LeaMapsLC["PageF"]
		local pscale = parent:GetEffectiveScale()
		local gscale = UIParent:GetEffectiveScale()
		local tscale = GameTooltip:GetEffectiveScale()
		local gap = ((UIParent:GetRight() * gscale) - (LeaMapsLC["PageF"]:GetRight() * pscale))
		if gap < (250 * tscale) then
			GameTooltip:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0)
		else
			GameTooltip:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
		end
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	end

	-- Print text
	function LeaMapsLC:Print(text)
		DEFAULT_CHAT_FRAME:AddMessage(L[text] or text, 1.0, 0.85, 0.0)
	end

	-- Lock/unlock an item
	-- 3.3.5a: Disable() on anonymous UIPanelButtonTemplate buttons crashes (Left/Middle/Right nil)
	-- Use EnableMouse + alpha instead.
	function LeaMapsLC:LockItem(item, lock)
		if lock then
			item:EnableMouse(false)
			item:SetAlpha(0.3)
		else
			item:EnableMouse(true)
			item:SetAlpha(1.0)
		end
	end

	-- Lock state for configuration buttons
	function LeaMapsLC:LockOption(option, item, reloadreq)
		if reloadreq then
			if LeaMapsLC[option] ~= LeaMapsDB[option] or LeaMapsLC[option] == "Off" then
				LeaMapsLC:LockItem(LeaMapsCB[item], true)
			else
				LeaMapsLC:LockItem(LeaMapsCB[item], false)
			end
		else
			if LeaMapsLC[option] == "Off" then
				LeaMapsLC:LockItem(LeaMapsCB[item], true)
			else
				LeaMapsLC:LockItem(LeaMapsCB[item], false)
			end
		end
	end

	-- Set lock state for all configuration buttons
	function LeaMapsLC:SetDim()
		LeaMapsLC:LockOption("ShowPointsOfInterest", "ShowPointsOfInterestBtn", false)
		LeaMapsLC:LockOption("ShowZoneLevels", "ShowZoneLevelsBtn", false)
		LeaMapsLC:LockOption("UnlockMapFrame", "UnlockMapFrameBtn", false)
		LeaMapsLC:LockOption("SetMapOpacity", "SetMapOpacityBtn", true)
		LeaMapsLC:LockOption("RevealMaps", "RevealMapsBtn", false)
	end

	-- Create a standard button
	function LeaMapsLC:CreateButton(name, frame, label, anchor, x, y, height, tip)
		local mbtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		LeaMapsCB[name] = mbtn
		mbtn:SetHeight(height)
		mbtn:SetPoint(anchor, x, y)
		mbtn:SetHitRectInsets(0, 0, 0, 0)
		mbtn:SetText(L[label] or label)

		mbtn.f = mbtn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		mbtn.f:SetText(L[label] or label)
		mbtn:SetWidth(mbtn.f:GetStringWidth() + 20)

		mbtn.tiptext = L[tip] or tip
		mbtn:SetScript("OnEnter", LeaMapsLC.TipSee)
		mbtn:SetScript("OnLeave", GameTooltip_Hide)

		mbtn:SetNormalTexture("Interface\\AddOns\\Leatrix_Maps\\textures\\Leatrix_Maps.blp")
		mbtn:GetNormalTexture():SetTexCoord(0, 1, 0.25, 0.5)
		mbtn:SetHighlightTexture("Interface\\AddOns\\Leatrix_Maps\\textures\\Leatrix_Maps.blp")
		mbtn:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.25)

		-- 3.3.5a: anonymous buttons don't expose Left/Middle/Right template children; skip these hooks
		mbtn:HookScript("OnShow", function()
			if mbtn.Left then mbtn.Left:Hide(); mbtn.Middle:Hide(); mbtn.Right:Hide() end
		end)

		return mbtn
	end

	-- Create a dropdown menu
	function LeaMapsLC:CreateDropDown(ddname, label, parent, width, anchor, x, y, items, tip)
		tinsert(LeaDropList, ddname)
		LeaMapsLC[ddname .. "Table"] = items

		local frame = CreateFrame("FRAME", nil, parent)
		frame:SetWidth(width); frame:SetHeight(42)
		frame:SetPoint("BOTTOMLEFT", parent, anchor, x, y)

		local dd = CreateFrame("Frame", nil, frame)
		dd:SetPoint("BOTTOMLEFT", -16, -8); dd:SetPoint("BOTTOMRIGHT", 15, -4); dd:SetHeight(32)
		frame.dd = dd

		local lt = dd:CreateTexture(nil, "ARTWORK")
		lt:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
		lt:SetTexCoord(0, 0.1953125, 0, 1); lt:SetPoint("TOPLEFT", dd, 0, 17); lt:SetWidth(25); lt:SetHeight(64)

		local rt = dd:CreateTexture(nil, "BORDER")
		rt:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
		rt:SetTexCoord(0.8046875, 1, 0, 1); rt:SetPoint("TOPRIGHT", dd, 0, 17); rt:SetWidth(25); rt:SetHeight(64)

		local mt = dd:CreateTexture(nil, "BORDER")
		mt:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
		mt:SetTexCoord(0.1953125, 0.8046875, 0, 1); mt:SetPoint("LEFT", lt, "RIGHT"); mt:SetPoint("RIGHT", rt, "LEFT"); mt:SetHeight(64)

		local lf = dd:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		lf:SetPoint("TOPLEFT", frame, 0, 0); lf:SetPoint("TOPRIGHT", frame, -5, 0)
		lf:SetJustifyH("LEFT"); lf:SetText(L[label] or label)

		local value = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		value:SetPoint("LEFT", lt, 26, 2); value:SetPoint("RIGHT", rt, -43, 0)
		value:SetJustifyH("LEFT"); value:SetWordWrap(false)
		dd:SetScript("OnShow", function() value:SetText(LeaMapsLC[ddname .. "Table"][LeaMapsLC[ddname]]) end)

		local dbtn = CreateFrame("Button", nil, dd)
		dbtn:SetPoint("TOPRIGHT", rt, -16, -18); dbtn:SetWidth(24); dbtn:SetHeight(24)
		dbtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
		dbtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
		dbtn:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
		dbtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
		dbtn:GetHighlightTexture():SetBlendMode("ADD")
		if tip and tip ~= "" then
			dbtn.tiptext = tip
			dbtn:SetScript("OnEnter", LeaMapsLC.ShowTooltip)
			dbtn:SetScript("OnLeave", GameTooltip_Hide)
		end
		frame.btn = dbtn
		dd.Button = dbtn

		-- Dropdown list (no BackdropTemplate needed in 3.3.5 - SetBackdrop works directly)
		local ddlist = CreateFrame("Frame", nil, frame)
		LeaMapsCB["ListFrame" .. ddname] = ddlist
		ddlist:SetPoint("TOP", 0, -42)
		ddlist:SetWidth(frame:GetWidth())
		ddlist:SetHeight((#items * 16) + 16 + 16)
		ddlist:SetFrameStrata("FULLSCREEN_DIALOG")
		-- Level must be relative to the parent and re-applied on show. The zone
		-- dropdowns are lifted to WorldMapFrame's level + 11 after creation, and
		-- Blizzard's WorldMapFrame_ResetFrameLevels shifts them again on every map
		-- resize. A fixed level left the open list far below its own parent, so it
		-- popped up underneath the map.
		ddlist:SetFrameLevel(frame:GetFrameLevel() + 5)
		ddlist:SetScript("OnShow", function(list)
			list:SetFrameLevel(list:GetParent():GetFrameLevel() + 5)
		end)
		ddlist:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = false, tileSize = 0, edgeSize = 32,
			insets = {left=4, right=4, top=4, bottom=4}
		})
		ddlist:Hide()
		frame.bg = ddlist

		parent:HookScript("OnHide", function() ddlist:Hide() end)

		local ddlistchk = CreateFrame("FRAME", nil, ddlist)
		ddlistchk:SetHeight(16); ddlistchk:SetWidth(16)
		ddlistchk.t = ddlistchk:CreateTexture(nil, "ARTWORK")
		ddlistchk.t:SetAllPoints()
		ddlistchk.t:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
		ddlistchk.t:SetTexCoord(0, 0.5, 0.5, 1.0)

		for k, v in pairs(items) do
			local dditem = CreateFrame("Button", nil, LeaMapsCB["ListFrame" .. ddname])
			LeaMapsCB["Drop" .. ddname .. k] = dditem
			dditem:Show()
			dditem:SetWidth(ddlist:GetWidth() - 22)
			dditem:SetHeight(16)
			dditem:SetPoint("TOPLEFT", 12, -k * 16)

			dditem.f = dditem:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			dditem.f:SetPoint("LEFT", 16, 0)
			dditem.f:SetText(items[k])
			dditem.f:SetWordWrap(false)
			dditem.f:SetJustifyH("LEFT")
			dditem.f:SetWidth(ddlist:GetWidth() - 36)

			dditem.t = dditem:CreateTexture(nil, "BACKGROUND")
			dditem.t:SetAllPoints()
			dditem.t:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
			dditem.t:SetVertexColor(0.3, 0.3, 0.0)
			dditem.t:SetAlpha(0.8)
			dditem.t:Hide()

			dditem:SetScript("OnEnter", function() dditem.t:Show() end)
			dditem:SetScript("OnLeave", function() dditem.t:Hide() end)
			dditem:SetScript("OnClick", function()
				LeaMapsLC[ddname] = k
				value:SetText(LeaMapsLC[ddname .. "Table"][k])
				ddlist:Hide()
			end)

			dbtn:SetScript("OnClick", function()
				if ddlist:IsShown() then
					ddlist:Hide()
				else
					ddlist:Show()
					ddlistchk:SetPoint("TOPLEFT", 10, select(5, LeaMapsCB["Drop" .. ddname .. LeaMapsLC[ddname]]:GetPoint()))
					ddlistchk:Show()
				end
				for void2, v2 in pairs(LeaDropList) do
					if v2 ~= ddname then
						LeaMapsCB["ListFrame" .. v2]:Hide()
					end
				end
			end)

			dbtn:SetHitRectInsets(-width + 28, 0, 0, 0)
		end

		return frame
	end

	-- Set reload button status
	function LeaMapsLC:ReloadCheck()
		if  (LeaMapsLC["ShowZoneMenu"]    ~= LeaMapsDB["ShowZoneMenu"])
		or  (LeaMapsLC["SetMapOpacity"]   ~= LeaMapsDB["SetMapOpacity"])
		or  (LeaMapsLC["StickyMapFrame"]  ~= LeaMapsDB["StickyMapFrame"])
		or  (LeaMapsLC["AutoChangeZones"] ~= LeaMapsDB["AutoChangeZones"])
		or  (LeaMapsLC["ZoneMapMenu"]     ~= LeaMapsDB["ZoneMapMenu"])
		then
			LeaMapsLC:LockItem(LeaMapsCB["ReloadUIButton"], false)
			LeaMapsCB["ReloadUIButton"].f:Show()
		else
			LeaMapsLC:LockItem(LeaMapsCB["ReloadUIButton"], true)
			LeaMapsCB["ReloadUIButton"].f:Hide()
		end
	end

	-- Create a subheading
	function LeaMapsLC:MakeTx(frame, title, x, y)
		local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		text:SetPoint("TOPLEFT", x, y)
		text:SetText(L[title] or title)
		return text
	end

	-- Create descriptive text
	function LeaMapsLC:MakeWD(frame, title, x, y, width)
		local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		text:SetPoint("TOPLEFT", x, y)
		text:SetJustifyH("LEFT")
		text:SetText(L[title] or title)
		if width then
			text:SetWidth(width)
		else
			if text:GetWidth() > 402 then
				text:SetWidth(402)
				text:SetWordWrap(false)
			end
		end
		return text
	end

	-- Create a checkbox control
	function LeaMapsLC:MakeCB(parent, field, caption, x, y, reload, tip)
		local Cbox = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
		LeaMapsCB[field] = Cbox
		Cbox:SetPoint("TOPLEFT", x, y)
		Cbox:SetScript("OnEnter", LeaMapsLC.TipSee)
		Cbox:SetScript("OnLeave", GameTooltip_Hide)

		Cbox.f = Cbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		Cbox.f:SetPoint("LEFT", 24, 0)
		if reload then
			Cbox.f:SetText((L[caption] or caption) .. "*")
			Cbox.tiptext = (L[tip] or tip) .. "|n|n* " .. (L["Requires UI reload."] or "Requires UI reload.")
		else
			Cbox.f:SetText(L[caption] or caption)
			Cbox.tiptext = L[tip] or tip
		end
		Cbox.f:SetJustifyH("LEFT")
		Cbox.f:SetWordWrap(false)

		if parent == LeaMapsLC["PageF"] then
			if Cbox.f:GetWidth() > 156 then Cbox.f:SetWidth(156) end
			if Cbox.f:GetStringWidth() > 156 then
				Cbox:SetHitRectInsets(0, -146, 0, 0)
			else
				Cbox:SetHitRectInsets(0, -Cbox.f:GetStringWidth() + 4, 0, 0)
			end
		else
			if Cbox.f:GetWidth() > 322 then Cbox.f:SetWidth(322) end
			if Cbox.f:GetStringWidth() > 322 then
				Cbox:SetHitRectInsets(0, -312, 0, 0)
			else
				Cbox:SetHitRectInsets(0, -Cbox.f:GetStringWidth() + 4, 0, 0)
			end
		end

		Cbox:SetScript("OnShow", function(self)
			self:SetChecked(LeaMapsLC[field] == "On")
		end)

		Cbox:SetScript("OnClick", function()
			if Cbox:GetChecked() then
				LeaMapsLC[field] = "On"
			else
				LeaMapsLC[field] = "Off"
			end
			LeaMapsLC:SetDim()
			LeaMapsLC:ReloadCheck()
		end)
	end

	-- Create configuration gear button
	function LeaMapsLC:CfgBtn(name, parent)
		local CfgBtn = CreateFrame("BUTTON", nil, parent)
		LeaMapsCB[name] = CfgBtn
		CfgBtn:SetWidth(20)
		CfgBtn:SetHeight(20)
		CfgBtn:SetPoint("LEFT", parent.f, "RIGHT", 0, 0)

		CfgBtn.t = CfgBtn:CreateTexture(nil, "BORDER")
		CfgBtn.t:SetAllPoints()
		CfgBtn.t:SetTexture("Interface\\WorldMap\\Gear_64.png")
		CfgBtn.t:SetTexCoord(0, 0.50, 0, 0.50)
		CfgBtn.t:SetVertexColor(1.0, 0.82, 0, 1.0)

		CfgBtn:SetHighlightTexture("Interface\\WorldMap\\Gear_64.png")
		CfgBtn:GetHighlightTexture():SetTexCoord(0, 0.50, 0, 0.50)

		CfgBtn.tiptext = L["Click to configure the settings for this option."]
		CfgBtn:SetScript("OnEnter", LeaMapsLC.ShowTooltip)
		CfgBtn:SetScript("OnLeave", GameTooltip_Hide)
	end

	-- Create a slider control
	function LeaMapsLC:MakeSL(frame, field, label, caption, low, high, step, x, y, form)
		local Slider = CreateFrame("Slider", "LeaMapsGlobalSlider" .. field, frame, "OptionssliderTemplate")
		LeaMapsCB[field] = Slider
		Slider:SetMinMaxValues(low, high)
		Slider:SetValueStep(step)
		Slider:EnableMouseWheel(true)
		Slider:SetPoint("TOPLEFT", x, y)
		Slider:SetWidth(100)
		Slider:SetHeight(20)
		Slider:SetHitRectInsets(0, 0, 0, 0)
		Slider.tiptext = L[caption] or caption
		Slider:SetScript("OnEnter", LeaMapsLC.TipSee)
		Slider:SetScript("OnLeave", GameTooltip_Hide)

		_G[Slider:GetName() .. "Low"]:SetText("")
		_G[Slider:GetName() .. "High"]:SetText("")
		_G[Slider:GetName() .. "Text"]:SetText(L[label] or label)

		Slider.f = Slider:CreateFontString(nil, "BACKGROUND")
		Slider.f:SetFontObject("GameFontHighlight")
		Slider.f:SetPoint("LEFT", Slider, "RIGHT", 12, 0)
		Slider.f:SetFormattedText("%.2f", Slider:GetValue())

		Slider:SetScript("OnMouseWheel", function(self, arg1)
			if Slider:IsEnabled() then
				local s = step * arg1
				local v = self:GetValue()
				if s > 0 then self:SetValue(min(v + s, high)) else self:SetValue(max(v + s, low)) end
			end
		end)

		Slider:SetScript("OnValueChanged", function(self, value)
			local value = floor((value - low) / step + 0.5) * step + low
			Slider.f:SetFormattedText(form, value)
			LeaMapsLC[field] = value
		end)

		Slider:SetScript("OnShow", function(self)
			self:SetValue(LeaMapsLC[field])
		end)
	end

	----------------------------------------------------------------------
	-- Stop error frame
	----------------------------------------------------------------------

	local stopFrame = CreateFrame("FRAME", nil, UIParent)
	stopFrame:ClearAllPoints()
	stopFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	stopFrame:SetSize(370, 150)
	stopFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	stopFrame:SetFrameLevel(500)
	stopFrame:SetClampedToScreen(true)
	stopFrame:EnableMouse(true)
	stopFrame:SetMovable(true)
	stopFrame:Hide()
	stopFrame:RegisterForDrag("LeftButton")
	stopFrame:SetScript("OnDragStart", stopFrame.StartMoving)
	stopFrame:SetScript("OnDragStop", function()
		stopFrame:StopMovingOrSizing()
		stopFrame:SetUserPlaced(false)
	end)

	stopFrame.t = stopFrame:CreateTexture(nil, "BACKGROUND")
	stopFrame.t:SetAllPoints()
	stopFrame.t:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	stopFrame.t:SetVertexColor(0.05, 0.05, 0.05)
	stopFrame.t:SetAlpha(0.9)

	stopFrame.mt = stopFrame:CreateTexture(nil, "BORDER")
	stopFrame.mt:SetTexture("Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated.png")
	stopFrame.mt:SetSize(370, 103)
	stopFrame.mt:SetPoint("TOPRIGHT")
	stopFrame.mt:SetVertexColor(0.5, 0.5, 0.5, 1.0)

	stopFrame.ft = stopFrame:CreateTexture(nil, "BORDER")
	stopFrame.ft:SetTexture("Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated.png")
	stopFrame.ft:SetSize(370, 48)
	stopFrame.ft:SetPoint("BOTTOM")
	stopFrame.ft:SetVertexColor(0.5, 0.5, 0.5, 1.0)

	LeaMapsLC:MakeTx(stopFrame, "Leatrix Maps", 16, -12)
	LeaMapsLC:MakeWD(stopFrame, "A stop error has occurred but no need to worry.  It can happen from time to time.  Click the reload button to resolve it.", 16, -32, 338)

	local stopRelBtn = LeaMapsLC:CreateButton("StopReloadButton", stopFrame, "Reload", "BOTTOMRIGHT", -16, 10, 25, "")
	stopRelBtn:SetScript("OnClick", ReloadUI)
	stopRelBtn.f = stopRelBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	stopRelBtn.f:SetHeight(32)
	stopRelBtn.f:SetPoint("RIGHT", stopRelBtn, "LEFT", -10, 0)
	stopRelBtn.f:SetText(L["Your UI needs to be reloaded."])
	stopRelBtn:Hide(); stopRelBtn:Show()

	local stopFrameClose = CreateFrame("Button", nil, stopFrame, "UIPanelCloseButton")
	stopFrameClose:SetSize(30, 30)
	stopFrameClose:SetPoint("TOPRIGHT", 0, 0)

	----------------------------------------------------------------------
	-- L20: Commands
	----------------------------------------------------------------------

	local function SlashFunc(str)
		local str, arg1 = strsplit(" ", string.lower((str or ""):gsub("%s+", " ")))
		if str and str ~= "" then
			if str == "reset" then
				LeaMapsLC["MainPanelA"], LeaMapsLC["MainPanelR"], LeaMapsLC["MainPanelX"], LeaMapsLC["MainPanelY"] = "CENTER", "CENTER", 0, 0
				if LeaMapsLC["PageF"]:IsShown() then LeaMapsLC["PageF"]:Hide(); LeaMapsLC["PageF"]:Show() end
				return
			elseif str == "wipe" then
				wipe(LeaMapsDB)
				LeaMapsLC["NoSaveSettings"] = true
				ReloadUI()
			elseif str == "nosave" then
				LeaMapsLC.EventFrame:UnregisterEvent("PLAYER_LOGOUT")
				LeaMapsLC:Print("Leatrix Maps will not overwrite LeaMapsDB at next logout.")
				return
			elseif str == "map" then
				-- Print or navigate to map
				if not arg1 then
					local cont = GetCurrentMapContinent()
					local zone = GetCurrentMapZone()
					local name = GetMapInfo() or "?"
					LeaMapsLC:Print("Map: " .. name .. " (cont=" .. tostring(cont) .. " zone=" .. tostring(zone) .. ")")
				else
					-- Try to navigate by zone name
					local target = arg1
					for name, mid in pairs(zoneNameToMapID) do
						if name:lower():find(target, 1, true) then
							NavigateToMapID(mid)
							LeaMapsLC:Print("Navigating to: " .. name)
							return
						end
					end
					LeaMapsLC:Print("Zone not found.")
				end
				return
			elseif str == "help" then
				LeaMapsLC:Print("Leatrix Maps " .. LeaMapsLC["AddonVer"])
				LeaMapsLC:Print("/ltm reset - Reset panel position.")
				LeaMapsLC:Print("/ltm wipe - Wipe all settings and reload.")
				LeaMapsLC:Print("/ltm map - Show current map info.")
				LeaMapsLC:Print("/ltm help - Show this information.")
				return
			else
				LeaMapsLC:Print("Invalid command.  Enter /ltm help for help.")
				return
			end
		else
			if InterfaceOptionsFrame:IsShown() or VideoOptionsFrame:IsShown() or ChatConfigFrame:IsShown() then return end
			if LeaMapsLC:IsMapsShowing() then
				LeaMapsLC["PageF"]:Hide()
				LeaMapsLC:HideConfigPanels()
			else
				LeaMapsLC["PageF"]:Show()
			end
		end
	end

	_G.SLASH_Leatrix_Maps1 = "/ltm"
	_G.SLASH_Leatrix_Maps2 = "/leamaps"

	SlashCmdList["Leatrix_Maps"] = function(self)
		SlashFunc(self)
		RunScript("ACTIVE_CHAT_EDIT_BOX = ACTIVE_CHAT_EDIT_BOX")
		RunScript("LAST_ACTIVE_CHAT_EDIT_BOX = LAST_ACTIVE_CHAT_EDIT_BOX")
	end

	----------------------------------------------------------------------
	-- L30: Events
	----------------------------------------------------------------------

	local eFrame = CreateFrame("FRAME")
	LeaMapsLC.EventFrame = eFrame
	eFrame:RegisterEvent("ADDON_LOADED")
	eFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eFrame:RegisterEvent("PLAYER_LOGOUT")
	eFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	eFrame:SetScript("OnEvent", function(self, event, arg1)

		if event == "ADDON_LOADED" and arg1 == "Leatrix_Maps" then

			-- Mechanics
			LeaMapsLC:LoadVarChk("ShowZoneMenu", "Off")
			LeaMapsLC:LoadVarChk("UnlockMapFrame", "On")
			LeaMapsLC:LoadVarAnc("MapPosA", "CENTER")
			LeaMapsLC:LoadVarAnc("MapPosR", "CENTER")
			LeaMapsLC:LoadVarNum("MapPosX", 0, -5000, 5000)
			LeaMapsLC:LoadVarNum("MapPosY", 20, -5000, 5000)
			LeaMapsLC:LoadVarChk("SetMapOpacity", "On")
			LeaMapsLC:LoadVarNum("stationaryOpacity", 1, 0.1, 1)
			LeaMapsLC:LoadVarChk("FadeOnMove", "On")
			LeaMapsLC:LoadVarNum("movingOpacity", 0.5, 0.1, 1)
			LeaMapsLC:LoadVarChk("StickyMapFrame", "Off")
			LeaMapsLC:LoadVarChk("AutoChangeZones", "Off")

			-- Elements
			LeaMapsLC:LoadVarChk("ShowPointsOfInterest", "On")
			LeaMapsLC:LoadVarChk("ShowDungeonIcons", "On")
			LeaMapsLC:LoadVarChk("ShowTravelPoints", "On")
			LeaMapsLC:LoadVarChk("ShowTravelOpposing", "Off")
			LeaMapsLC:LoadVarChk("ShowSpiritHealers", "Off")
			LeaMapsLC:LoadVarChk("ShowZoneCrossings", "On")
			LeaMapsLC:LoadVarChk("ShowZoneLevels", "On")
			LeaMapsLC:LoadVarChk("ShowFishingLevels", "On")
			LeaMapsLC:LoadVarChk("ShowCoords", "On")
			LeaMapsLC:LoadVarChk("ShowObjectives", "On")

			-- More
			LeaMapsLC:LoadVarNum("ZoneMapMenu", 1, 1, 3)
			LeaMapsLC:LoadVarChk("ShowMinimapIcon", "On")
			LeaMapsLC:LoadVarChk("RevealMaps", "Off")
			LeaMapsLC:LoadVarChk("RevTint", "On")
			LeaMapsLC:LoadVarNum("tintRed", 0.6, 0, 1)
			LeaMapsLC:LoadVarNum("tintGreen", 0.6, 0, 1)
			LeaMapsLC:LoadVarNum("tintBlue", 1, 0, 1)
			LeaMapsLC:LoadVarNum("tintAlpha", 1, 0.1, 1)

			-- Panel position
			LeaMapsLC:LoadVarAnc("MainPanelA", "CENTER")
			LeaMapsLC:LoadVarAnc("MainPanelR", "CENTER")
			LeaMapsLC:LoadVarNum("MainPanelX", 0, -5000, 5000)
			LeaMapsLC:LoadVarNum("MainPanelY", 0, -5000, 5000)

			LeaMapsLC:SetDim()

			if not LeaMapsDB["minimapPos"] then
				LeaMapsDB["minimapPos"] = 204
			end

		elseif event == "PLAYER_ENTERING_WORLD" then
			LeaMapsLC:MainFunc()
			eFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")

		elseif event == "PLAYER_LOGOUT" and not LeaMapsLC["NoSaveSettings"] then
			-- Mechanics
			LeaMapsDB["ShowZoneMenu"] = LeaMapsLC["ShowZoneMenu"]
			LeaMapsDB["UnlockMapFrame"] = LeaMapsLC["UnlockMapFrame"]
			LeaMapsDB["MapPosA"] = LeaMapsLC["MapPosA"]
			LeaMapsDB["MapPosR"] = LeaMapsLC["MapPosR"]
			LeaMapsDB["MapPosX"] = LeaMapsLC["MapPosX"]
			LeaMapsDB["MapPosY"] = LeaMapsLC["MapPosY"]
			LeaMapsDB["SetMapOpacity"] = LeaMapsLC["SetMapOpacity"]
			LeaMapsDB["stationaryOpacity"] = LeaMapsLC["stationaryOpacity"]
			LeaMapsDB["FadeOnMove"] = LeaMapsLC["FadeOnMove"]
			LeaMapsDB["movingOpacity"] = LeaMapsLC["movingOpacity"]
			LeaMapsDB["StickyMapFrame"] = LeaMapsLC["StickyMapFrame"]
			LeaMapsDB["AutoChangeZones"] = LeaMapsLC["AutoChangeZones"]

			-- Elements
			LeaMapsDB["ShowPointsOfInterest"] = LeaMapsLC["ShowPointsOfInterest"]
			LeaMapsDB["ShowDungeonIcons"] = LeaMapsLC["ShowDungeonIcons"]
			LeaMapsDB["ShowTravelPoints"] = LeaMapsLC["ShowTravelPoints"]
			LeaMapsDB["ShowTravelOpposing"] = LeaMapsLC["ShowTravelOpposing"]
			LeaMapsDB["ShowSpiritHealers"] = LeaMapsLC["ShowSpiritHealers"]
			LeaMapsDB["ShowZoneCrossings"] = LeaMapsLC["ShowZoneCrossings"]
			LeaMapsDB["ShowZoneLevels"] = LeaMapsLC["ShowZoneLevels"]
			LeaMapsDB["ShowFishingLevels"] = LeaMapsLC["ShowFishingLevels"]
			LeaMapsDB["ShowCoords"] = LeaMapsLC["ShowCoords"]
			LeaMapsDB["ShowObjectives"] = LeaMapsLC["ShowObjectives"]

			-- More
			LeaMapsDB["ZoneMapMenu"] = LeaMapsLC["ZoneMapMenu"]
			LeaMapsDB["ShowMinimapIcon"] = LeaMapsLC["ShowMinimapIcon"]
			LeaMapsDB["RevealMaps"] = LeaMapsLC["RevealMaps"]
			LeaMapsDB["RevTint"] = LeaMapsLC["RevTint"]
			LeaMapsDB["tintRed"] = LeaMapsLC["tintRed"]
			LeaMapsDB["tintGreen"] = LeaMapsLC["tintGreen"]
			LeaMapsDB["tintBlue"] = LeaMapsLC["tintBlue"]
			LeaMapsDB["tintAlpha"] = LeaMapsLC["tintAlpha"]

			-- Panel
			LeaMapsDB["MainPanelA"] = LeaMapsLC["MainPanelA"]
			LeaMapsDB["MainPanelR"] = LeaMapsLC["MainPanelR"]
			LeaMapsDB["MainPanelX"] = LeaMapsLC["MainPanelX"]
			LeaMapsDB["MainPanelY"] = LeaMapsLC["MainPanelY"]

		elseif event == "ADDON_ACTION_FORBIDDEN" and arg1 == "Leatrix_Maps" then
			StaticPopup_Hide("ADDON_ACTION_FORBIDDEN")
			stopFrame:Show()
		end
	end)

	----------------------------------------------------------------------
	-- L40: Panel
	----------------------------------------------------------------------

	local PageF = CreateFrame("Frame", nil, UIParent)
	_G["LeaMapsGlobalPanel"] = PageF
	table.insert(UISpecialFrames, "LeaMapsGlobalPanel")

	LeaMapsLC["PageF"] = PageF
	PageF:SetSize(470, 480)
	PageF:Hide()
	PageF:SetFrameStrata("FULLSCREEN_DIALOG")
	PageF:SetFrameLevel(20)
	PageF:SetClampedToScreen(true)
	PageF:EnableMouse(true)
	PageF:SetMovable(true)
	PageF:RegisterForDrag("LeftButton")
	PageF:SetScript("OnDragStart", PageF.StartMoving)
	PageF:SetScript("OnDragStop", function()
		PageF:StopMovingOrSizing()
		PageF:SetUserPlaced(false)
		LeaMapsLC["MainPanelA"], void, LeaMapsLC["MainPanelR"], LeaMapsLC["MainPanelX"], LeaMapsLC["MainPanelY"] = PageF:GetPoint()
	end)

	PageF.t = PageF:CreateTexture(nil, "BACKGROUND")
	PageF.t:SetAllPoints()
	PageF.t:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	PageF.t:SetVertexColor(0.05, 0.05, 0.05)
	PageF.t:SetAlpha(0.9)

	local MainTexture = PageF:CreateTexture(nil, "BORDER")
	MainTexture:SetTexture("Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated.png")
	MainTexture:SetSize(470, 433)
	MainTexture:SetPoint("TOPRIGHT")
	MainTexture:SetVertexColor(0.7, 0.7, 0.7, 0.7)
	MainTexture:SetTexCoord(0.09, 1, 0, 1)

	local FootTexture = PageF:CreateTexture(nil, "BORDER")
	FootTexture:SetTexture("Interface\\ACHIEVEMENTFRAME\\UI-GuildAchievement-Parchment-Horizontal-Desaturated.png")
	FootTexture:SetSize(470, 48)
	FootTexture:SetPoint("BOTTOM")
	FootTexture:SetVertexColor(0.5, 0.5, 0.5, 1.0)

	PageF:SetScript("OnShow", function()
		PageF:ClearAllPoints()
		PageF:SetPoint(LeaMapsLC["MainPanelA"], UIParent, LeaMapsLC["MainPanelR"], LeaMapsLC["MainPanelX"], LeaMapsLC["MainPanelY"])
	end)

	PageF.mt = PageF:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	PageF.mt:SetPoint("TOPLEFT", 16, -16)
	PageF.mt:SetText("Leatrix Maps")

	PageF.v = PageF:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	PageF.v:SetHeight(32)
	PageF.v:SetPoint("TOPLEFT", PageF.mt, "BOTTOMLEFT", 0, -8)
	PageF.v:SetPoint("RIGHT", PageF, -32, 0)
	PageF.v:SetJustifyH("LEFT"); PageF.v:SetJustifyV("TOP")
	if PageF.v.SetNonSpaceWrap then PageF.v:SetNonSpaceWrap(true) end
	PageF.v:SetText(L["WC"] .. " " .. LeaMapsLC["AddonVer"])

	-- Reload button
	local reloadb = LeaMapsLC:CreateButton("ReloadUIButton", PageF, "Reload", "BOTTOMRIGHT", -16, 10, 25, "Your UI needs to be reloaded for some of the changes to take effect.")
	LeaMapsLC:LockItem(reloadb, true)
	reloadb:SetScript("OnClick", ReloadUI)

	reloadb.f = reloadb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	reloadb.f:SetHeight(32)
	reloadb.f:SetPoint("RIGHT", reloadb, "LEFT", -10, 0)
	reloadb.f:SetText(L["Your UI needs to be reloaded."])
	reloadb.f:Hide()

	-- Close button
	local CloseB = CreateFrame("Button", nil, PageF, "UIPanelCloseButton")
	CloseB:SetSize(30, 30)
	CloseB:SetPoint("TOPRIGHT", 0, 0)

	----------------------------------------------------------------------
	-- Panel content (left column)
	----------------------------------------------------------------------

	LeaMapsLC:MakeTx(PageF, "Appearance", 16, -72)
	LeaMapsLC:MakeCB(PageF, "ShowZoneMenu", "Show zone menus", 16, -92, true, "If checked, zone and continent dropdown menus will be shown in the map frame.")
	LeaMapsLC:MakeCB(PageF, "SetMapOpacity", "Set map opacity", 16, -112, true, "If checked, you will be able to set the opacity of the map.")

	LeaMapsLC:MakeTx(PageF, "System", 16, -152)
	LeaMapsLC:MakeCB(PageF, "UnlockMapFrame", "Unlock map frame", 16, -172, false, "If checked, you can move the map by dragging any border.")
	LeaMapsLC:MakeCB(PageF, "AutoChangeZones", "Auto change zones", 16, -192, true, "If checked, when your character changes zones, the map will automatically change to the new zone.")
	LeaMapsLC:MakeCB(PageF, "StickyMapFrame", "Sticky map frame", 16, -212, true, "If checked, the map frame will remain open until you close it.")

	----------------------------------------------------------------------
	-- Panel content (right column)
	----------------------------------------------------------------------

	LeaMapsLC:MakeTx(PageF, "Elements", 225, -72)
	LeaMapsLC:MakeCB(PageF, "ShowPointsOfInterest", "Show points of interest", 225, -92, false, "If checked, points of interest will be shown.")
	LeaMapsLC:MakeCB(PageF, "ShowZoneLevels", "Show zone levels", 225, -112, false, "If checked, zone and dungeon level ranges will be shown.")
	LeaMapsLC:MakeCB(PageF, "ShowCoords", "Show coordinates", 225, -132, false, "If checked, coordinates will be shown.")
	LeaMapsLC:MakeCB(PageF, "ShowObjectives", "Show objectives", 225, -152, false, "If checked, quest objectives will be shown.")

	LeaMapsLC:MakeTx(PageF, "More", 225, -192)
	LeaMapsLC:MakeCB(PageF, "ShowMinimapIcon", "Show minimap button", 225, -212, false, "If checked, the minimap button will be shown.")
	LeaMapsLC:MakeCB(PageF, "RevealMaps", "Show unexplored areas", 225, -232, false, "If checked, fog of war will be cleared from all zone maps.")

	-- Configuration gear buttons
	LeaMapsLC:CfgBtn("ShowPointsOfInterestBtn", LeaMapsCB["ShowPointsOfInterest"])
	LeaMapsLC:CfgBtn("ShowZoneLevelsBtn", LeaMapsCB["ShowZoneLevels"])
	LeaMapsLC:CfgBtn("UnlockMapFrameBtn", LeaMapsCB["UnlockMapFrame"])
	LeaMapsLC:CfgBtn("SetMapOpacityBtn", LeaMapsCB["SetMapOpacity"])
	LeaMapsLC:CfgBtn("RevealMapsBtn", LeaMapsCB["RevealMaps"])

	-- Reset map position button
	local resetMapPosBtn = LeaMapsLC:CreateButton("resetMapPosBtn", PageF, "Reset Map Layout", "BOTTOMLEFT", 16, 10, 25, "Click to reset the position of the map frame.")
	resetMapPosBtn:HookScript("OnClick", function()
		LeaMapsLC["MapPosA"], LeaMapsLC["MapPosR"], LeaMapsLC["MapPosX"], LeaMapsLC["MapPosY"] = "CENTER", "CENTER", 0, 20
		WorldMapFrame:ClearAllPoints()
		WorldMapFrame:SetPoint(LeaMapsLC["MapPosA"], UIParent, LeaMapsLC["MapPosR"], LeaMapsLC["MapPosX"], LeaMapsLC["MapPosY"])
		if WorldMapTitleButton_OnDragStop then WorldMapTitleButton_OnDragStop() end
		LeaMapsLC:SetDim()
		LeaMapsLC["PageF"]:Hide(); LeaMapsLC["PageF"]:Show()
	end)

	----------------------------------------------------------------------
	-- Zoom settings sub-panel
	----------------------------------------------------------------------

	do
		local zoomFrame = LeaMapsLC:CreatePanel("Map Zoom", "zoomFrame")

		LeaMapsLC:MakeTx(zoomFrame, "Settings", 16, -72)
		LeaMapsLC:MakeWD(zoomFrame, "Configure the map zoom and pan feature.", 16, -92)

		local persistCB = CreateFrame("CheckButton", "LeaMapsZoomPersistCB", zoomFrame, "ChatConfigCheckButtonTemplate")
		persistCB:SetPoint("TOPLEFT", 16, -132)
		_G[persistCB:GetName() .. "Text"]:SetText("Persist zoom when reopening map")
		persistCB.tiptext = "Maintain zoom level when re-opening the map in the same zone."
		persistCB:SetScript("OnEnter", LeaMapsLC.TipSee)
		persistCB:SetScript("OnLeave", GameTooltip_Hide)
		persistCB:SetScript("OnShow", function(self) self:SetChecked(MagnifyOptions.enablePersistZoom) end)
		persistCB:SetScript("OnClick", function(self)
			MagnifyOptions.enablePersistZoom = self:GetChecked() and true or false
		end)

		local oldIconsCB = CreateFrame("CheckButton", "LeaMapsZoomOldIconsCB", zoomFrame, "ChatConfigCheckButtonTemplate")
		oldIconsCB:SetPoint("TOPLEFT", 16, -162)
		_G[oldIconsCB:GetName() .. "Text"]:SetText("Uncoloured party icons")
		oldIconsCB.tiptext = "Disable coloured class icons for party members on the map."
		oldIconsCB:SetScript("OnEnter", LeaMapsLC.TipSee)
		oldIconsCB:SetScript("OnLeave", GameTooltip_Hide)
		oldIconsCB:SetScript("OnShow", function(self) self:SetChecked(MagnifyOptions.enableOldPartyIcons) end)
		oldIconsCB:SetScript("OnClick", function(self)
			MagnifyOptions.enableOldPartyIcons = self:GetChecked() and true or false
		end)

		LeaMapsLC:MakeTx(zoomFrame, "Maximum zoom", 16, -205)
		local maxZoomSlider = CreateFrame("Slider", "LeaMapsZoomMaxZoomSlider", zoomFrame, "OptionsSliderTemplate")
		maxZoomSlider:SetMinMaxValues(LeaMapsZoom.MAXZOOM_SLIDER_MIN, LeaMapsZoom.MAXZOOM_SLIDER_MAX)
		maxZoomSlider:SetValueStep(LeaMapsZoom.MAXZOOM_SLIDER_STEP)
		maxZoomSlider:SetWidth(250)
		maxZoomSlider:SetPoint("TOPLEFT", 36, -225)
		_G[maxZoomSlider:GetName() .. "Text"]:SetText("")
		_G[maxZoomSlider:GetName() .. "Low"]:SetText(string.format("%.1f", LeaMapsZoom.MAXZOOM_SLIDER_MIN))
		_G[maxZoomSlider:GetName() .. "High"]:SetText(string.format("%.1f", LeaMapsZoom.MAXZOOM_SLIDER_MAX))
		maxZoomSlider:SetScript("OnShow", function(self)
			self:SetValue(MagnifyOptions.maxZoom or LeaMapsZoom.MAXZOOM_DEFAULT)
			_G[self:GetName() .. "Low"]:SetText(string.format("%.1fx", MagnifyOptions.maxZoom or LeaMapsZoom.MAXZOOM_DEFAULT))
		end)
		maxZoomSlider:SetScript("OnValueChanged", function(self)
			MagnifyOptions.maxZoom = self:GetValue()
			_G[self:GetName() .. "Low"]:SetText(string.format("%.1fx", self:GetValue()))
		end)

		LeaMapsLC:MakeTx(zoomFrame, "Zoom speed", 16, -270)
		local zoomStepSlider = CreateFrame("Slider", "LeaMapsZoomStepSlider", zoomFrame, "OptionsSliderTemplate")
		zoomStepSlider:SetMinMaxValues(LeaMapsZoom.ZOOMSTEP_SLIDER_MIN, LeaMapsZoom.ZOOMSTEP_SLIDER_MAX)
		zoomStepSlider:SetValueStep(LeaMapsZoom.ZOOMSTEP_SLIDER_STEP)
		zoomStepSlider:SetWidth(250)
		zoomStepSlider:SetPoint("TOPLEFT", 36, -290)
		_G[zoomStepSlider:GetName() .. "Text"]:SetText("")
		_G[zoomStepSlider:GetName() .. "Low"]:SetText(string.format("%.2f", LeaMapsZoom.ZOOMSTEP_SLIDER_MIN))
		_G[zoomStepSlider:GetName() .. "High"]:SetText(string.format("%.2f", LeaMapsZoom.ZOOMSTEP_SLIDER_MAX))
		zoomStepSlider:SetScript("OnShow", function(self)
			self:SetValue(MagnifyOptions.zoomStep or LeaMapsZoom.ZOOMSTEP_DEFAULT)
			_G[self:GetName() .. "Low"]:SetText(string.format("%.2f", MagnifyOptions.zoomStep or LeaMapsZoom.ZOOMSTEP_DEFAULT))
		end)
		zoomStepSlider:SetScript("OnValueChanged", function(self)
			MagnifyOptions.zoomStep = self:GetValue()
			_G[self:GetName() .. "Low"]:SetText(string.format("%.2f", self:GetValue()))
		end)

		zoomFrame.b:HookScript("OnClick", function()
			zoomFrame:Hide()
			LeaMapsLC["PageF"]:Show()
		end)
		zoomFrame.r:HookScript("OnClick", function()
			MagnifyOptions.enablePersistZoom   = LeaMapsZoom.ENABLEPERSISTZOOM_DEFAULT
			MagnifyOptions.enableOldPartyIcons = LeaMapsZoom.ENABLEOLDPARTYICONS_DEFAULT
			MagnifyOptions.maxZoom             = LeaMapsZoom.MAXZOOM_DEFAULT
			MagnifyOptions.zoomStep            = LeaMapsZoom.ZOOMSTEP_DEFAULT
			zoomFrame:Hide(); zoomFrame:Show()
		end)

		LeaMapsLC:MakeTx(PageF, "Zoom", 225, -272)
		local zoomBtn = LeaMapsLC:CreateButton("ZoomSettingsBtn", PageF, "Configure...", "TOPLEFT", 249, -302, 25, "Click to configure the map zoom settings.")
		zoomBtn:HookScript("OnClick", function()
			zoomFrame:Show()
			LeaMapsLC["PageF"]:Hide()
		end)
	end
