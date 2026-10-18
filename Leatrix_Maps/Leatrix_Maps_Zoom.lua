
	----------------------------------------------------------------------
	-- Leatrix Maps Zoom
	-- Map zoom and pan feature, adapted from Magnify-WotLK
	----------------------------------------------------------------------

	local ADDON_NAME, _ = ...
	LeaMapsZoom = {}

	----------------------------------------------------------------------
	-- Constants
	----------------------------------------------------------------------

	LeaMapsZoom.MIN_ZOOM = 1.0

	-- 0.2-3.0 map scale (see LeaMapsLC:ApplyMapScale)
	LeaMapsZoom.MINIMODE_MIN_ZOOM = 0.2 / WORLDMAP_WINDOWED_SIZE
	LeaMapsZoom.MINIMODE_MAX_ZOOM = 3.0 / WORLDMAP_WINDOWED_SIZE
	LeaMapsZoom.MINIMODE_ZOOM_STEP = 0.1

	LeaMapsZoom.WORLDMAP_POI_MIN_X = 12
	LeaMapsZoom.WORLDMAP_POI_MIN_Y = -12
	LeaMapsZoom.worldmapPoiMaxX = nil
	LeaMapsZoom.worldmapPoiMaxY = nil

	LeaMapsZoom.PLAYER_ARROW_SIZE = 16
	LeaMapsZoom.GROUP_ICON_SIZE = 20

	LeaMapsZoom.ENABLEPERSISTZOOM_DEFAULT  = false
	LeaMapsZoom.ENABLEOLDPARTYICONS_DEFAULT = false
	LeaMapsZoom.MAXZOOM_DEFAULT            = 4.0
	LeaMapsZoom.MAXZOOM_SLIDER_MIN         = 2.0
	LeaMapsZoom.MAXZOOM_SLIDER_MAX         = 10.0
	LeaMapsZoom.MAXZOOM_SLIDER_STEP        = 0.5
	LeaMapsZoom.ZOOMSTEP_DEFAULT           = 0.1
	LeaMapsZoom.ZOOMSTEP_SLIDER_MIN        = 0.01
	LeaMapsZoom.ZOOMSTEP_SLIDER_MAX        = 0.5
	LeaMapsZoom.ZOOMSTEP_SLIDER_STEP       = 0.01

	-- Previous state for persist-zoom feature
	LeaMapsZoom.PreviousState = {
		panX  = 0,
		panY  = 0,
		scale = 1,
		zone  = 0,
	}

	-- Saved options (persisted via SavedVariables in the TOC)
	MagnifyOptions = {
		enablePersistZoom   = false,
		enableOldPartyIcons = false,
		maxZoom             = LeaMapsZoom.MAXZOOM_DEFAULT,
		zoomStep            = LeaMapsZoom.ZOOMSTEP_DEFAULT,
	}

	----------------------------------------------------------------------
	-- Local utilities
	----------------------------------------------------------------------

	local function updatePointRelativeTo(frame, newRelativeFrame)
		local currentPoint, _f, currentRelativePoint, currentOffsetX, currentOffsetY = frame:GetPoint()
		frame:ClearAllPoints()
		frame:SetPoint(currentPoint, newRelativeFrame, currentRelativePoint, currentOffsetX, currentOffsetY)
	end

	-- Move Questie's map button onto the non-zooming scroll frame, keeping Questie's corner, offset and level
	local QUESTIE_BUTTON_SHIFT_LEFT = 24

	local function pinQuestieWorldMapButton(button)
		local point, relativeFrame, relativePoint, offsetX, offsetY = button:GetPoint(1)
		if not point or relativeFrame == WorldMapScrollFrame then return end
		if point:find("RIGHT") then
			offsetX = offsetX - QUESTIE_BUTTON_SHIFT_LEFT
		end
		local frameLevel = button:GetFrameLevel()
		if button:GetParent() ~= WorldMapScrollFrame then
			button:SetParent(WorldMapScrollFrame)
		end
		button:ClearAllPoints()
		button:SetPoint(point, WorldMapScrollFrame, relativePoint, offsetX, offsetY)
		button:SetFrameLevel(frameLevel)
	end

	local function resizePOI(poiButton)
		if poiButton then
			local _, _, _, x, y = poiButton:GetPoint()
			local mapsterScale = 1
			local mapster, mapsterPoiScale = LeaMapsZoom.GetMapster("poiScale")
			if mapster then
				mapster.WorldMapFrame_DisplayQuestPOI = function() end
			end
			if x ~= nil and y ~= nil then
				local s = WORLDMAP_SETTINGS.size / WorldMapDetailFrame:GetEffectiveScale() * (mapsterScale or 1)
				local posX = x * 1 / s
				local posY = y * 1 / s
				poiButton:SetScale(s)
				poiButton:SetPoint("CENTER", poiButton:GetParent(), "TOPLEFT", posX, posY)
				if posY > LeaMapsZoom.WORLDMAP_POI_MIN_Y then
					posY = LeaMapsZoom.WORLDMAP_POI_MIN_Y
				elseif LeaMapsZoom.worldmapPoiMaxY and posY < LeaMapsZoom.worldmapPoiMaxY then
					posY = LeaMapsZoom.worldmapPoiMaxY
				end
				if posX < LeaMapsZoom.WORLDMAP_POI_MIN_X then
					posX = LeaMapsZoom.WORLDMAP_POI_MIN_X
				elseif LeaMapsZoom.worldmapPoiMaxX and posX > LeaMapsZoom.worldmapPoiMaxX then
					posX = LeaMapsZoom.worldmapPoiMaxX
				end
			end
		end
	end

	local function isFrameOnWorldMap(frame)
		local current = frame
		while current do
			if current == WorldMapFrame or current == WorldMapScrollFrame or
			   current == WorldMapDetailFrame or current == WorldMapButton or
			   current == WorldMapPOIFrame then
				return true
			end
			if not current.GetParent then break end
			local nextParent = current:GetParent()
			if nextParent == current then break end
			current = nextParent
		end
		return false
	end

	local function isCloseEnough(a, b, epsilon)
		return math.abs((a or 0) - (b or 0)) <= (epsilon or 0.01)
	end

	local function isCornerPoint(point)
		return point == "TOPLEFT" or point == "TOPRIGHT" or
		       point == "BOTTOMLEFT" or point == "BOTTOMRIGHT"
	end

	local function isQuestieMapCornerButton(frameObject, point, relativeFrame, relativePoint, offsetX, offsetY)
		if frameObject.__magnifyQuestieCornerLocked then return true end
		if relativeFrame ~= WorldMapButton then return false end
		if not isCornerPoint(point) or not isCornerPoint(relativePoint) then return false end
		if type(offsetX) ~= "number" or type(offsetY) ~= "number" then return false end
		return math.abs(offsetX) <= 40 and math.abs(offsetY) <= 40
	end

	local function lockQuestieMapCornerButton(frameObject, point, relativePoint, offsetX, offsetY, detailFrameScale)
		if isCloseEnough(detailFrameScale, 1, 0.02) then
			frameObject.__magnifyQuestieCornerBaseX = offsetX
			frameObject.__magnifyQuestieCornerBaseY = offsetY
		elseif not frameObject.__magnifyQuestieCornerBaseX or not frameObject.__magnifyQuestieCornerBaseY then
			frameObject.__magnifyQuestieCornerBaseX = offsetX
			frameObject.__magnifyQuestieCornerBaseY = offsetY
		end
		frameObject.__magnifyQuestieCornerPoint         = frameObject.__magnifyQuestieCornerPoint or point
		frameObject.__magnifyQuestieCornerRelativePoint = frameObject.__magnifyQuestieCornerRelativePoint or relativePoint
		frameObject.__magnifyQuestieCornerLocked        = true

		local lockPoint         = frameObject.__magnifyQuestieCornerPoint or point
		local lockRelativePoint = frameObject.__magnifyQuestieCornerRelativePoint or relativePoint
		local lockX             = frameObject.__magnifyQuestieCornerBaseX or offsetX
		local lockY             = frameObject.__magnifyQuestieCornerBaseY or offsetY
		local _, currentRelativeFrame, currentRelativePoint, currentX, currentY = frameObject:GetPoint(1)

		if frameObject:GetParent() ~= WorldMapScrollFrame or
		   currentRelativeFrame ~= WorldMapScrollFrame or
		   currentRelativePoint ~= lockRelativePoint or
		   not isCloseEnough(currentX, lockX, 0.05) or
		   not isCloseEnough(currentY, lockY, 0.05) then
			frameObject:SetParent(WorldMapScrollFrame)
			frameObject:ClearAllPoints()
			frameObject:SetPoint(lockPoint, WorldMapScrollFrame, lockRelativePoint, lockX, lockY)
		end
		frameObject:SetScale(1)
	end

	local function getAnchorPointCoordinates(point, width, height)
		if point == "TOPLEFT"     then return 0,           0
		elseif point == "TOP"     then return width / 2,   0
		elseif point == "TOPRIGHT" then return width,      0
		elseif point == "LEFT"    then return 0,           -height / 2
		elseif point == "CENTER"  then return width / 2,   -height / 2
		elseif point == "RIGHT"   then return width,       -height / 2
		elseif point == "BOTTOMLEFT"  then return 0,       -height
		elseif point == "BOTTOM"  then return width / 2,   -height
		elseif point == "BOTTOMRIGHT" then return width,   -height
		end
		return 0, 0
	end

	local function clamp(number, minValue, maxValue)
		if number < minValue then return minValue
		elseif number > maxValue then return maxValue
		end
		return number
	end

	local function getQuestieVisibleBounds(anchorFrame)
		local left   = 0
		local right  = anchorFrame:GetWidth() or 0
		local top    = 0
		local bottom = -(anchorFrame:GetHeight() or 0)

		if anchorFrame == WorldMapButton or anchorFrame == WorldMapDetailFrame then
			local detailFrameScale = WorldMapDetailFrame:GetScale()
			if detailFrameScale and detailFrameScale > 0 then
				local scrollLeft    = WorldMapScrollFrame:GetHorizontalScroll() or 0
				local scrollTop     = WorldMapScrollFrame:GetVerticalScroll() or 0
				local visibleWidth  = WorldMapScrollFrame:GetWidth() or 0
				local visibleHeight = WorldMapScrollFrame:GetHeight() or 0
				left   = scrollLeft * detailFrameScale
				right  = left + visibleWidth
				top    = -(scrollTop * detailFrameScale)
				bottom = top - visibleHeight
			end
		end
		return left, right, bottom, top
	end

	local function clampQuestieMapPinOffset(frameObject, anchorFrame, point, relativePoint, offsetX, offsetY)
		if not frameObject or not anchorFrame or not point or not relativePoint then
			return offsetX, offsetY
		end
		if not anchorFrame.GetWidth or not anchorFrame.GetHeight or
		   not frameObject.GetWidth or not frameObject.GetHeight then
			return offsetX, offsetY
		end
		local anchorWidth  = anchorFrame:GetWidth() or 0
		local anchorHeight = anchorFrame:GetHeight() or 0
		if anchorWidth <= 0 or anchorHeight <= 0 then return offsetX, offsetY end

		local frameWidth  = frameObject:GetWidth() or 0
		local frameHeight = frameObject:GetHeight() or 0
		local relativePointX, relativePointY = getAnchorPointCoordinates(relativePoint, anchorWidth, anchorHeight)
		local pointX, pointY = getAnchorPointCoordinates(point, frameWidth, frameHeight)
		local absoluteX = relativePointX + offsetX
		local absoluteY = relativePointY + offsetY

		local left, right, bottom, top = getQuestieVisibleBounds(anchorFrame)
		local minX = left + pointX
		local maxX = right - (frameWidth - pointX)
		if maxX < minX then minX = (left + right) / 2; maxX = minX end
		local minY = bottom + frameHeight + pointY
		local maxY = top + pointY
		if maxY < minY then minY = (bottom + top) / 2; maxY = minY end

		local clampedX = clamp(absoluteX, minX, maxX)
		local clampedY = clamp(absoluteY, minY, maxY)
		return clampedX - relativePointX, clampedY - relativePointY
	end

	----------------------------------------------------------------------
	-- Questie pin management
	----------------------------------------------------------------------

	-- Questie manages its own pins
	function LeaMapsZoom.SetQuestieWorldMapPinsVisible(isVisible)
	end

	function LeaMapsZoom.SyncQuestieWorldMapPins(forceRescan)
	end

	----------------------------------------------------------------------
	-- Scroll / pan helpers
	----------------------------------------------------------------------

	function LeaMapsZoom.PersistMapScrollAndPan()
		LeaMapsZoom.PreviousState.panX  = WorldMapScrollFrame:GetHorizontalScroll()
		LeaMapsZoom.PreviousState.panY  = WorldMapScrollFrame:GetVerticalScroll()
		LeaMapsZoom.PreviousState.scale = WorldMapDetailFrame:GetScale()
		LeaMapsZoom.PreviousState.zone  = GetCurrentMapZone()
	end

	function LeaMapsZoom.AfterScrollOrPan()
		LeaMapsZoom.PersistMapScrollAndPan()
		if WORLDMAP_SETTINGS.selectedQuest then
			WorldMapBlobFrame:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, false)
			WorldMapBlobFrame:DrawQuestBlob(WORLDMAP_SETTINGS.selectedQuestId, true)
		end
	end

	function LeaMapsZoom.ResizeQuestPOIs()
		-- Bounds are not set until SetDetailFrameScale has run
		if not LeaMapsZoom.worldmapPoiMaxY then return end
		local QUEST_POI_MAX_TYPES  = 4
		local POI_TYPE_MAX_BUTTONS = 25
		for i = 1, QUEST_POI_MAX_TYPES do
			for j = 1, POI_TYPE_MAX_BUTTONS do
				resizePOI(_G["poiWorldMapPOIFrame" .. i .. "_" .. j])
			end
		end
		if QUEST_POI_SWAP_BUTTONS then
			resizePOI(QUEST_POI_SWAP_BUTTONS["WorldMapPOIFrame"])
		end
	end

	function LeaMapsZoom.SetPOIMaxBounds()
		LeaMapsZoom.worldmapPoiMaxY = WorldMapDetailFrame:GetHeight() * -WORLDMAP_SETTINGS.size + 12
		LeaMapsZoom.worldmapPoiMaxX = WorldMapDetailFrame:GetWidth()  *  WORLDMAP_SETTINGS.size + 12
	end

	----------------------------------------------------------------------
	-- Core zoom API
	----------------------------------------------------------------------

	function LeaMapsZoom.SetDetailFrameScale(num)
		WorldMapDetailFrame:SetScale(num)
		LeaMapsZoom.SetPOIMaxBounds()

		WorldMapPOIFrame:SetScale(1 / WORLDMAP_SETTINGS.size)
		WorldMapBlobFrame:SetScale(num)

		WorldMapPlayer:SetScale(1 / WorldMapDetailFrame:GetScale())
		WorldMapDeathRelease:SetScale(1 / WorldMapDetailFrame:GetScale())
		WorldMapCorpse:SetScale(1 / WorldMapDetailFrame:GetScale())

		local numFlags = GetNumBattlefieldFlagPositions()
		for i = 1, numFlags do
			local flagFrameName = "WorldMapFlag" .. i
			if _G[flagFrameName] then
				_G[flagFrameName]:SetScale(1 / WorldMapDetailFrame:GetScale())
			end
		end
		for i = 1, MAX_PARTY_MEMBERS do
			if _G["WorldMapParty" .. i] then
				_G["WorldMapParty" .. i]:SetScale(1 / WorldMapDetailFrame:GetScale())
			end
		end
		for i = 1, MAX_RAID_MEMBERS do
			if _G["WorldMapRaid" .. i] then
				_G["WorldMapRaid" .. i]:SetScale(1 / WorldMapDetailFrame:GetScale())
			end
		end
		for i = 1, #MAP_VEHICLES do
			if MAP_VEHICLES[i] then
				MAP_VEHICLES[i]:SetScale(1 / WorldMapDetailFrame:GetScale())
			end
		end

		WorldMapFrame_OnEvent(WorldMapFrame, "DISPLAY_SIZE_CHANGED")
		if WorldMapFrame_UpdateQuests() > 0 then
			LeaMapsZoom.RedrawSelectedQuest()
		end
	end

	----------------------------------------------------------------------
	-- Optional addon integration
	----------------------------------------------------------------------

	function LeaMapsZoom.GetElvUI()
		if ElvUI and ElvUI[1] then return ElvUI[1] end
		return nil
	end

	function LeaMapsZoom.GetMapster(configName)
		if LibStub and LibStub:GetLibrary("AceAddon-3.0", true) then
			local mapster = LibStub:GetLibrary("AceAddon-3.0"):GetAddon("Mapster", true)
			if not mapster then return mapster, nil end
			if mapster.db and mapster.db.profile then
				return mapster, mapster.db.profile[configName]
			end
		end
		return nil, nil
	end

	function LeaMapsZoom.ElvUI_SetupWorldMapFrame()
		local worldMap = LeaMapsZoom.GetElvUI():GetModule("WorldMap")
		if not worldMap then return end
		if worldMap.coordsHolder and worldMap.coordsHolder.playerCoords then
			updatePointRelativeTo(worldMap.coordsHolder.playerCoords, WorldMapScrollFrame)
		end
		if WorldMapDetailFrame.backdrop then
			WorldMapDetailFrame.backdrop:Hide()
			local _, worldMapRelativeFrame = WorldMapFrame.backdrop
			if worldMapRelativeFrame == WorldMapDetailFrame then
				updatePointRelativeTo(WorldMapFrame.backdrop, WorldMapScrollFrame)
			end
		end
		if WorldMapFrame.backdrop then
			WorldMapFrame.backdrop.Point = function() return end
			WorldMapFrame.backdrop:ClearAllPoints()
			if WorldMapZoneMinimapDropDown:IsVisible() then
				WorldMapFrame.backdrop:SetPoint("TOPLEFT", WorldMapZoneMinimapDropDown, "TOPLEFT", -20, 40)
			else
				WorldMapFrame.backdrop:SetPoint("TOPLEFT", WorldMapTitleButton, "TOPLEFT", 0, 0)
			end
			WorldMapFrame.backdrop:SetPoint("BOTTOM", WorldMapQuestShowObjectives, "BOTTOM", 0, 0)
			WorldMapFrame.backdrop:SetPoint("RIGHT", WorldMapFrameCloseButton, "RIGHT", 0, 0)
		end
	end

	----------------------------------------------------------------------
	-- Frame setup (called on every OnShow and map-size change)
	----------------------------------------------------------------------

	function LeaMapsZoom.SetupWorldMapFrame()
		WorldMapScrollFrameScrollBar:Hide()
		WorldMapFrame:EnableMouse(true)
		WorldMapScrollFrame:EnableMouse(true)
		WorldMapScrollFrame.panning = false
		WorldMapScrollFrame.moved   = false

		if WORLDMAP_SETTINGS.size == WORLDMAP_QUESTLIST_SIZE then
			WorldMapScrollFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
			WorldMapTrackQuest:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOMLEFT", 8, 4)
		elseif WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
			WorldMapTrackQuest:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOMLEFT", 16, -9)
			WorldMapFrame:SetPoint("TOPLEFT", WorldMapScreenAnchor, 0, 0)
			WorldMapFrame:SetScale(WorldMapScreenAnchor.preferredMinimodeScale)
			WorldMapFrame:SetMovable("true")
			WorldMapTitleButton:Show()
			WorldMapTitleButton:ClearAllPoints()
			WorldMapFrameTitle:Show()
			WorldMapFrameTitle:ClearAllPoints()
			WorldMapFrameTitle:SetPoint("CENTER", WorldMapTitleButton, "CENTER", 32, 0)
			if WORLDMAP_SETTINGS.advanced then
				WorldMapScrollFrame:SetPoint("TOPLEFT", 19, -42)
				WorldMapTitleButton:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 13, 0)
			else
				WorldMapScrollFrame:SetPoint("TOPLEFT", 37, -66)
				WorldMapTitleButton:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 13, -14)
			end
		else
			WorldMapScrollFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOPLEFT", 11, -70.5)
			WorldMapTrackQuest:SetPoint("BOTTOMLEFT", WorldMapPositioningGuide, "BOTTOMLEFT", 16, -9)
		end

		WorldMapScrollFrame:SetScale(WORLDMAP_SETTINGS.size)

		LeaMapsZoom.SetDetailFrameScale(1)
		WorldMapDetailFrame:SetAllPoints(WorldMapScrollFrame)
		WorldMapScrollFrame:SetHorizontalScroll(0)
		WorldMapScrollFrame:SetVerticalScroll(0)

		if MagnifyOptions.enablePersistZoom and GetCurrentMapZone() == LeaMapsZoom.PreviousState.zone then
			LeaMapsZoom.SetDetailFrameScale(LeaMapsZoom.PreviousState.scale)
			WorldMapScrollFrame:SetHorizontalScroll(LeaMapsZoom.PreviousState.panX)
			WorldMapScrollFrame:SetVerticalScroll(LeaMapsZoom.PreviousState.panY)
		end

		WorldMapButton:SetScale(1)
		WorldMapButton:SetAllPoints(WorldMapDetailFrame)
		WorldMapButton:SetParent(WorldMapDetailFrame)

		WorldMapPOIFrame:SetParent(WorldMapDetailFrame)
		WorldMapBlobFrame:SetParent(WorldMapDetailFrame)
		WorldMapBlobFrame:ClearAllPoints()
		WorldMapBlobFrame:SetAllPoints(WorldMapDetailFrame)

		WorldMapPlayer:SetParent(WorldMapDetailFrame)

		-- Questie parents its map button to WorldMapButton, which now zooms; re-pin after every Questie layout pass
		local questieButton = Questie_WorldMapButton
		if questieButton then
			if not questieButton.leaMapsPinHooked then
				questieButton.leaMapsPinHooked = true
				hooksecurefunc(questieButton, "SetScale", pinQuestieWorldMapButton)
			end
			pinQuestieWorldMapButton(questieButton)
		end

		updatePointRelativeTo(WorldMapQuestScrollFrame,       WorldMapScrollFrame)
		updatePointRelativeTo(WorldMapQuestDetailScrollFrame, WorldMapScrollFrame)

		if LeaMapsZoom.GetElvUI() then
			LeaMapsZoom.ElvUI_SetupWorldMapFrame()
		end
	end

	----------------------------------------------------------------------
	-- Mouse handlers
	----------------------------------------------------------------------

	function LeaMapsZoom.WorldMapScrollFrame_OnPan(cursorX, cursorY)
		local dX = WorldMapScrollFrame.cursorX - cursorX
		local dY = cursorY - WorldMapScrollFrame.cursorY
		dX = dX / this:GetEffectiveScale()
		dY = dY / this:GetEffectiveScale()
		if abs(dX) >= 1 or abs(dY) >= 1 then
			WorldMapScrollFrame.moved = true
			local x = max(0, dX + WorldMapScrollFrame.x)
			x = min(x, WorldMapScrollFrame.maxX)
			WorldMapScrollFrame:SetHorizontalScroll(x)
			local y = max(0, dY + WorldMapScrollFrame.y)
			y = min(y, WorldMapScrollFrame.maxY)
			WorldMapScrollFrame:SetVerticalScroll(y)
			LeaMapsZoom.AfterScrollOrPan()
		end
	end

	function LeaMapsZoom.WorldMapScrollFrame_OnMouseWheel()
		-- Ctrl+scroll in mini mode: zoom the whole frame
		if IsControlKeyDown() and WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
			local oldScale = WorldMapFrame:GetScale()
			local newScale = oldScale + arg1 * LeaMapsZoom.MINIMODE_ZOOM_STEP
			newScale = max(LeaMapsZoom.MINIMODE_MIN_ZOOM, newScale)
			newScale = min(LeaMapsZoom.MINIMODE_MAX_ZOOM, newScale)
			WorldMapFrame:SetScale(newScale)
			WorldMapScreenAnchor.preferredMinimodeScale = newScale
			return
		end

		local oldScrollH = this:GetHorizontalScroll()
		local oldScrollV = this:GetVerticalScroll()

		local cursorX, cursorY = GetCursorPosition()
		cursorX = cursorX / this:GetEffectiveScale()
		cursorY = cursorY / this:GetEffectiveScale()

		local frameX = cursorX - this:GetLeft()
		local frameY = this:GetTop() - cursorY

		local oldScale = WorldMapDetailFrame:GetScale()
		local newScale = oldScale * (1.0 + arg1 * MagnifyOptions.zoomStep)
		newScale = max(LeaMapsZoom.MIN_ZOOM, newScale)
		newScale = min(MagnifyOptions.maxZoom, newScale)

		LeaMapsZoom.SetDetailFrameScale(newScale)

		this.maxX = ((WorldMapDetailFrame:GetWidth()  * newScale) - this:GetWidth())  / newScale
		this.maxY = ((WorldMapDetailFrame:GetHeight() * newScale) - this:GetHeight()) / newScale
		this.zoomedIn = WorldMapDetailFrame:GetScale() > LeaMapsZoom.MIN_ZOOM

		local centerX    = oldScrollH + frameX / oldScale
		local centerY    = oldScrollV + frameY / oldScale
		local newScrollH = centerX - frameX / newScale
		local newScrollV = centerY - frameY / newScale

		newScrollH = min(max(0, newScrollH), this.maxX)
		newScrollV = min(max(0, newScrollV), this.maxY)

		this:SetHorizontalScroll(newScrollH)
		this:SetVerticalScroll(newScrollV)
		LeaMapsZoom.AfterScrollOrPan()
	end

	function LeaMapsZoom.WorldMapButton_OnMouseDown()
		if arg1 == "LeftButton" and WorldMapScrollFrame.zoomedIn then
			WorldMapScrollFrame.panning  = true
			local x, y = GetCursorPosition()
			WorldMapScrollFrame.cursorX  = x
			WorldMapScrollFrame.cursorY  = y
			WorldMapScrollFrame.x        = WorldMapScrollFrame:GetHorizontalScroll()
			WorldMapScrollFrame.y        = WorldMapScrollFrame:GetVerticalScroll()
			WorldMapScrollFrame.moved    = false
		end
	end

	function LeaMapsZoom.WorldMapButton_OnMouseUp()
		WorldMapScrollFrame.panning = false
		if not WorldMapScrollFrame.moved then
			WorldMapButton_OnClick(WorldMapButton, arg1)
			LeaMapsZoom.SetDetailFrameScale(LeaMapsZoom.MIN_ZOOM)
			WorldMapScrollFrame:SetHorizontalScroll(0)
			WorldMapScrollFrame:SetVerticalScroll(0)
			LeaMapsZoom.AfterScrollOrPan()
			WorldMapScrollFrame.zoomedIn = false
		end
		WorldMapScrollFrame.moved = false
	end

	----------------------------------------------------------------------
	-- OnUpdate: player/party/vehicle positions (runs every frame)
	----------------------------------------------------------------------

	function LeaMapsZoom.WorldMapButton_OnUpdate(self, elapsed)
		local x, y = GetCursorPosition()
		x = x / self:GetEffectiveScale()
		y = y / self:GetEffectiveScale()

		local centerX, centerY = self:GetCenter()
		local width  = self:GetWidth()
		local height = self:GetHeight()
		local adjustedY = (centerY + (height / 2) - y) / height
		local adjustedX = (x - (centerX - (width / 2))) / width

		local name, fileName, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY
		if self:IsMouseOver() then
			name, fileName, texPercentageX, texPercentageY, textureX, textureY, scrollChildX, scrollChildY =
				UpdateMapHighlight(adjustedX, adjustedY)
		end

		WorldMapFrame.areaName = name
		if not WorldMapFrame.poiHighlight then
			WorldMapFrameAreaLabel:SetText(name)
		end
		if fileName then
			WorldMapHighlight:SetTexCoord(0, texPercentageX, 0, texPercentageY)
			WorldMapHighlight:SetTexture("Interface\\WorldMap\\" .. fileName .. "\\" .. fileName .. "Highlight")
			textureX    = textureX    * width
			textureY    = textureY    * height
			scrollChildX = scrollChildX * width
			scrollChildY = -scrollChildY * height
			if textureX > 0 and textureY > 0 then
				WorldMapHighlight:SetWidth(textureX)
				WorldMapHighlight:SetHeight(textureY)
				WorldMapHighlight:SetPoint("TOPLEFT", "WorldMapDetailFrame", "TOPLEFT", scrollChildX, scrollChildY)
				WorldMapHighlight:Show()
			end
		else
			WorldMapHighlight:Hide()
		end

		-- Player position
		UpdateWorldMapArrowFrames()
		local playerX, playerY = GetPlayerMapPosition("player")
		if playerX == 0 and playerY == 0 then
			ShowWorldMapArrowFrame(nil)
			WorldMapPing:Hide()
			WorldMapPlayer:Hide()
		else
			playerX = playerX * WorldMapDetailFrame:GetWidth()  * WorldMapDetailFrame:GetScale() * WORLDMAP_SETTINGS.size
			playerY = -playerY * WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale() * WORLDMAP_SETTINGS.size
			PositionWorldMapArrowFrame("CENTER", "WorldMapDetailFrame", "TOPLEFT", playerX, playerY)
			ShowWorldMapArrowFrame(nil)
			WorldMapPlayer:SetAllPoints(PlayerArrowFrame)
			WorldMapPlayer.Icon:SetRotation(PlayerArrowFrame:GetFacing())
			-- Divide out the windowed map shrink to match BCA sizes
			local _, mapsterArrowScale = LeaMapsZoom.GetMapster("arrowScale")
			local arrowSize = LeaMapsZoom.PLAYER_ARROW_SIZE * (mapsterArrowScale or 1) / WORLDMAP_SETTINGS.size
			WorldMapPlayer.Icon:SetSize(arrowSize, arrowSize)
			WorldMapPlayer:Show()
		end

		-- Party / raid positions
		local playerCount = 0
		if GetNumRaidMembers() > 0 then
			for i = 1, MAX_PARTY_MEMBERS do _G["WorldMapParty" .. i]:Hide() end
			for i = 1, MAX_RAID_MEMBERS do
				local unit = "raid" .. i
				local partyX, partyY = GetPlayerMapPosition(unit)
				local partyMemberFrame = _G["WorldMapRaid" .. (playerCount + 1)]
				if (partyX == 0 and partyY == 0) or UnitIsUnit(unit, "player") then
					partyMemberFrame:Hide()
				else
					partyX = partyX * WorldMapDetailFrame:GetWidth()  * WorldMapDetailFrame:GetScale()
					partyY = -partyY * WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale()
					partyMemberFrame:SetPoint("CENTER", "WorldMapDetailFrame", "TOPLEFT", partyX, partyY)
					partyMemberFrame.name = nil
					partyMemberFrame.unit = unit
					LeaMapsZoom.ColorWorldMapPartyMemberFrame(partyMemberFrame, unit)
					partyMemberFrame:Show()
					playerCount = playerCount + 1
				end
			end
		else
			for i = 1, MAX_PARTY_MEMBERS do
				local partyX, partyY = GetPlayerMapPosition("party" .. i)
				local partyMemberFrame = _G["WorldMapParty" .. i]
				if partyX == 0 and partyY == 0 then
					partyMemberFrame:Hide()
				else
					partyX = partyX * WorldMapButton:GetWidth()  * WorldMapDetailFrame:GetScale()
					partyY = -partyY * WorldMapButton:GetHeight() * WorldMapDetailFrame:GetScale()
					partyMemberFrame:SetPoint("CENTER", "WorldMapButton", "TOPLEFT", partyX, partyY)
					LeaMapsZoom.ColorWorldMapPartyMemberFrame(partyMemberFrame, "party" .. i)
					partyMemberFrame:Show()
				end
			end
		end

		-- BG team members
		local numTeamMembers = GetNumBattlefieldPositions()
		for i = playerCount + 1, MAX_RAID_MEMBERS do
			local partyX, partyY, name = GetBattlefieldPosition(i - playerCount)
			local partyMemberFrame = _G["WorldMapRaid" .. i]
			if partyX == 0 and partyY == 0 then
				partyMemberFrame:Hide()
			else
				partyX = partyX * WorldMapDetailFrame:GetWidth()  * WorldMapDetailFrame:GetScale()
				partyY = -partyY * WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale()
				partyMemberFrame:SetPoint("CENTER", "WorldMapDetailFrame", "TOPLEFT", partyX, partyY)
				partyMemberFrame.name  = name
				partyMemberFrame.unit  = nil
				partyMemberFrame.colorIcon:Hide()
				partyMemberFrame.icon:Show()
				partyMemberFrame:Show()
			end
		end

		-- Battlefield flags
		local numFlags = GetNumBattlefieldFlagPositions()
		for i = 1, numFlags do
			local flagX, flagY, flagToken = GetBattlefieldFlagPosition(i)
			local flagFrameName = "WorldMapFlag" .. i
			local flagFrame     = _G[flagFrameName]
			if flagX == 0 and flagY == 0 then
				flagFrame:Hide()
			else
				flagX = flagX * WorldMapDetailFrame:GetWidth()  * WorldMapDetailFrame:GetScale()
				flagY = -flagY * WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale()
				flagFrame:SetPoint("CENTER", "WorldMapDetailFrame", "TOPLEFT", flagX, flagY)
				_G[flagFrameName .. "Texture"]:SetTexture("Interface\\WorldStateFrame\\" .. flagToken)
				flagFrame:Show()
			end
		end
		for i = numFlags + 1, NUM_WORLDMAP_FLAGS do
			_G["WorldMapFlag" .. i]:Hide()
		end

		-- Corpse
		local corpseX, corpseY = GetCorpseMapPosition()
		if corpseX == 0 and corpseY == 0 then
			WorldMapCorpse:Hide()
		else
			corpseX = corpseX * WorldMapDetailFrame:GetWidth()  * WorldMapDetailFrame:GetScale()
			corpseY = -corpseY * WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale()
			WorldMapCorpse:SetPoint("CENTER", "WorldMapDetailFrame", "TOPLEFT", corpseX, corpseY)
			WorldMapCorpse:Show()
		end

		-- Death release
		local deathReleaseX, deathReleaseY = GetDeathReleasePosition()
		if (deathReleaseX == 0 and deathReleaseY == 0) or UnitIsGhost("player") then
			WorldMapDeathRelease:Hide()
		else
			deathReleaseX = deathReleaseX * WorldMapDetailFrame:GetWidth()  * WorldMapDetailFrame:GetScale()
			deathReleaseY = -deathReleaseY * WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale()
			WorldMapDeathRelease:SetPoint("CENTER", "WorldMapDetailFrame", "TOPLEFT", deathReleaseX, deathReleaseY)
			WorldMapDeathRelease:Show()
		end

		-- Vehicles
		local numVehicles
		if GetCurrentMapContinent() == WORLDMAP_WORLD_ID or
		   (GetCurrentMapContinent() ~= -1 and GetCurrentMapZone() == 0) then
			numVehicles = 0
		else
			numVehicles = GetNumBattlefieldVehicles()
		end
		local totalVehicles = #MAP_VEHICLES
		local index = 0
		for i = 1, numVehicles do
			if i > totalVehicles then
				local vehicleName = "WorldMapVehicles" .. i
				MAP_VEHICLES[i] = CreateFrame("FRAME", vehicleName, WorldMapButton, "WorldMapVehicleTemplate")
				MAP_VEHICLES[i].texture = _G[vehicleName .. "Texture"]
			end
			local vehicleX, vehicleY, unitName, isPossessed, vehicleType, orientation, isPlayer, isAlive =
				GetBattlefieldVehicleInfo(i)
			if vehicleX and isAlive and not isPlayer and VEHICLE_TEXTURES[vehicleType] then
				local mapVehicleFrame = MAP_VEHICLES[i]
				vehicleX = vehicleX * WorldMapDetailFrame:GetWidth()  * WorldMapDetailFrame:GetScale()
				vehicleY = -vehicleY * WorldMapDetailFrame:GetHeight() * WorldMapDetailFrame:GetScale()
				mapVehicleFrame.texture:SetRotation(orientation)
				mapVehicleFrame.texture:SetTexture(WorldMap_GetVehicleTexture(vehicleType, isPossessed))
				mapVehicleFrame:SetPoint("CENTER", "WorldMapDetailFrame", "TOPLEFT", vehicleX, vehicleY)
				mapVehicleFrame:SetWidth(VEHICLE_TEXTURES[vehicleType].width)
				mapVehicleFrame:SetHeight(VEHICLE_TEXTURES[vehicleType].height)
				mapVehicleFrame.name = unitName
				mapVehicleFrame:Show()
				index = i
			else
				MAP_VEHICLES[i]:Hide()
			end
		end
		if index < totalVehicles then
			for i = index + 1, totalVehicles do MAP_VEHICLES[i]:Hide() end
		end

		if WorldMapScrollFrame.panning then
			LeaMapsZoom.WorldMapScrollFrame_OnPan(GetCursorPosition())
		end
	end

	----------------------------------------------------------------------
	-- Misc helpers
	----------------------------------------------------------------------

	function LeaMapsZoom.RedrawSelectedQuest()
		if WORLDMAP_SETTINGS.selectedQuestId then
			WorldMapFrame_SelectQuestById(WORLDMAP_SETTINGS.selectedQuestId)
		else
			WorldMapFrame_SelectQuestFrame(_G["WorldMapQuestFrame1"])
		end
	end

	function LeaMapsZoom.ColorWorldMapPartyMemberFrame(partyMemberFrame, unit)
		local classColor = RAID_CLASS_COLORS[select(2, UnitClass(unit))]
		if classColor and not MagnifyOptions.enableOldPartyIcons then
			local size = LeaMapsZoom.GROUP_ICON_SIZE / WORLDMAP_SETTINGS.size
			partyMemberFrame.colorIcon:SetSize(size, size)
			partyMemberFrame.colorIcon:Show()
			partyMemberFrame.icon:Hide()
			partyMemberFrame.colorIcon:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
		else
			partyMemberFrame.colorIcon:Hide()
			partyMemberFrame.icon:Show()
		end
	end

	function LeaMapsZoom.SetGroupIconSize(size)
		LeaMapsZoom.GROUP_ICON_SIZE = size
	end

	function LeaMapsZoom.CreateClassColorIcon(partyMemberFrame)
		if partyMemberFrame then
			partyMemberFrame.colorIcon = partyMemberFrame:CreateTexture(nil, "ARTWORK")
			partyMemberFrame.colorIcon:SetSize(LeaMapsZoom.GROUP_ICON_SIZE, LeaMapsZoom.GROUP_ICON_SIZE)
			partyMemberFrame.colorIcon:SetPoint("CENTER")
			partyMemberFrame.colorIcon:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Leatrix_Maps_Icon")
			partyMemberFrame.icon:Hide()
		end
	end

	----------------------------------------------------------------------
	-- Initialization (called from Leatrix_Maps.lua MainFunc)
	----------------------------------------------------------------------

	function LeaMapsZoom.OnFirstLoad()
		-- Ensure option defaults
		MagnifyOptions.enablePersistZoom   = MagnifyOptions.enablePersistZoom   or LeaMapsZoom.ENABLEPERSISTZOOM_DEFAULT
		MagnifyOptions.enableOldPartyIcons = MagnifyOptions.enableOldPartyIcons or LeaMapsZoom.ENABLEOLDPARTYICONS_DEFAULT
		MagnifyOptions.maxZoom             = MagnifyOptions.maxZoom             or LeaMapsZoom.MAXZOOM_DEFAULT
		MagnifyOptions.zoomStep            = MagnifyOptions.zoomStep            or LeaMapsZoom.ZOOMSTEP_DEFAULT

		WorldMapScrollFrame:SetScrollChild(WorldMapDetailFrame)
		WorldMapScrollFrame:SetScript("OnMouseWheel", LeaMapsZoom.WorldMapScrollFrame_OnMouseWheel)
		WorldMapButton:SetScript("OnMouseDown", LeaMapsZoom.WorldMapButton_OnMouseDown)
		WorldMapButton:SetScript("OnMouseUp",   LeaMapsZoom.WorldMapButton_OnMouseUp)
		WorldMapDetailFrame:SetParent(WorldMapScrollFrame)

		WorldMapFrameAreaFrame:SetParent(WorldMapFrame)
		WorldMapFrameAreaFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL)
		WorldMapFrameAreaFrame:SetPoint("TOP", WorldMapScrollFrame, "TOP", 0, -10)

		-- Disable the ping effect (doesn't work correctly when zoomed)
		WorldMapPing.Show = function() return end
		WorldMapPing:SetModelScale(0)

		-- Higher-resolution player arrow that clips correctly when panned
		WorldMapPlayer.Icon = WorldMapPlayer:CreateTexture(nil, "ARTWORK")
		WorldMapPlayer.Icon:SetSize(LeaMapsZoom.PLAYER_ARROW_SIZE, LeaMapsZoom.PLAYER_ARROW_SIZE)
		WorldMapPlayer.Icon:SetPoint("CENTER", 0, 0)
		WorldMapPlayer.Icon:SetTexture(
			"Interface\\AddOns\\" .. ADDON_NAME .. "\\textures\\WorldMapArrow")

		hooksecurefunc("WorldMapFrame_SetFullMapView",  LeaMapsZoom.SetupWorldMapFrame)
		hooksecurefunc("WorldMapFrame_SetQuestMapView", LeaMapsZoom.SetupWorldMapFrame)
		hooksecurefunc("WorldMap_ToggleSizeDown",       LeaMapsZoom.SetupWorldMapFrame)
		hooksecurefunc("WorldMap_ToggleSizeUp",         LeaMapsZoom.SetupWorldMapFrame)
		hooksecurefunc("WorldMapFrame_UpdateQuests",    LeaMapsZoom.ResizeQuestPOIs)
		hooksecurefunc("WorldMapFrame_SetPOIMaxBounds", LeaMapsZoom.SetPOIMaxBounds)

		hooksecurefunc("WorldMapQuestShowObjectives_AdjustPosition", function()
			if WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then
				WorldMapQuestShowObjectives:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOMRIGHT",
					-30 - WorldMapQuestShowObjectivesText:GetWidth(), -9)
			else
				WorldMapQuestShowObjectives:SetPoint("BOTTOMRIGHT", WorldMapPositioningGuide, "BOTTOMRIGHT",
					-15 - WorldMapQuestShowObjectivesText:GetWidth(), 4)
			end
		end)

		WorldMapScreenAnchor:StartMoving()
		WorldMapScreenAnchor:SetPoint("TOPLEFT", 10, -118)
		WorldMapScreenAnchor:StopMovingOrSizing()
		WorldMapScreenAnchor.preferredMinimodeScale =
			1 + (0.4 * WorldMapFrame:GetHeight() / WorldFrame:GetHeight())

		-- Title button drag — move the whole frame (keeps anchor in sync)
		WorldMapTitleButton:SetScript("OnDragStart", function()
			WorldMapScreenAnchor:ClearAllPoints()
			WorldMapFrame:ClearAllPoints()
			WorldMapFrame:StartMoving()
		end)
		WorldMapTitleButton:SetScript("OnDragStop", function()
			WorldMapFrame:StopMovingOrSizing()
			WorldMapScreenAnchor:StartMoving()
			WorldMapScreenAnchor:SetPoint("TOPLEFT", WorldMapFrame)
			WorldMapScreenAnchor:StopMovingOrSizing()
		end)

		WorldMapButton:SetScript("OnUpdate", LeaMapsZoom.WorldMapButton_OnUpdate)

		-- Wrap Blizzard's OnShow so SetupWorldMapFrame fires on every map open
		local original_WorldMapFrame_OnShow = WorldMapFrame:GetScript("OnShow")
		WorldMapFrame:SetScript("OnShow", function(self)
			original_WorldMapFrame_OnShow(self)
			LeaMapsZoom.SetupWorldMapFrame()
		end)

		-- Colour party/raid icons by class
		for i = 1, MAX_RAID_MEMBERS do
			LeaMapsZoom.CreateClassColorIcon(_G["WorldMapParty" .. i])
			LeaMapsZoom.CreateClassColorIcon(_G["WorldMapRaid"  .. i])
		end
	end

