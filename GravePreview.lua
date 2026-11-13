local ADDON_NAME, addonNamespace = ...

local PREFIX = "|cffe0b84cGravePreview|r: "

local STATIC_GRAVEYARDS = addonNamespace and addonNamespace.GraveyardData or {}
local STATIC_BY_MAP = {}
for _, entry in ipairs(STATIC_GRAVEYARDS) do
	STATIC_BY_MAP[entry.map] = true
end

local DEFAULTS = {
	enabled = true,
}

local db
local provider
local providerAdded = false
local initialized = false
local overlay

local function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
	end
end

local function IsSecret(value)
	return type(issecretvalue) == "function" and issecretvalue(value)
end

local function CopyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			CopyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

-- Map pin -----------------------------------------------------------------

local function SetCorpseIcon(texture)
	texture:SetTexture("Interface\\Minimap\\POIIcons")

	-- The POIIcons texture layout changed between the Classic-era client and
	-- the modern/Forever client. These coordinates are the corpse icon.
	local _, _, _, toc = GetBuildInfo()
	if toc == 16001 or toc >= 100000 then
		texture:SetTexCoord(0.56640625, 0.6328125, 0.001953125, 0.03515625)
	else
		texture:SetTexCoord(0.875, 1.0, 0.0, 0.125)
	end
end

local function ShowGraveTooltip(owner)
	local data = owner.data
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText("Likely graveyard", 1, 0.82, 0)
	GameTooltip:AddLine(data and data.name or "Unknown", 1, 1, 1)

	if data and data.distance then
		GameTooltip:AddLine(string.format("~%d yd from you", math.floor(data.distance + 0.5)), 0.85, 0.85, 0.85)
	end

	GameTooltip:AddLine("Closest eligible graveyard to your current position. Zone rules can still pick a different one.", 0.65, 0.65, 0.65, true)
	GameTooltip:Show()
end

GravePreviewPinMixin = CreateFromMixins(MapCanvasPinMixin)

function GravePreviewPinMixin:OnLoad()
	self:SetScalingLimits(1, 0.8, 0.8)
	SetCorpseIcon(self.Icon)
end

function GravePreviewPinMixin:OnAcquired(data)
	self.data = data
	if self.UseFrameLevelType then
		self:UseFrameLevelType("PIN_FRAME_LEVEL_CORPSE")
	end
end

function GravePreviewPinMixin:OnMouseEnter()
	ShowGraveTooltip(self)
end

function GravePreviewPinMixin:OnMouseLeave()
	GameTooltip:Hide()
end

-- Graveyard prediction ----------------------------------------------------

local GravePreview = {}
_G.GravePreview = GravePreview

local staticWorldCache = {}

local function GetStaticWorldPosition(index, entry)
	local cached = staticWorldCache[index]
	if cached then
		return cached
	end

	local continentID, worldPos = C_Map.GetWorldPosFromMapPos(entry.map, CreateVector2D(entry.x, entry.y))
	if not worldPos then
		return nil
	end

	local worldX, worldY = worldPos:GetXY()
	if IsSecret(worldX) or IsSecret(worldY) then
		return nil
	end

	cached = { continentID = continentID, x = worldX, y = worldY }
	staticWorldCache[index] = cached
	return cached
end

local function IsStaticMapCovered(mapID)
	for _ = 1, 5 do
		if STATIC_BY_MAP[mapID] then
			return true
		end

		local mapInfo = type(C_Map.GetMapInfo) == "function" and C_Map.GetMapInfo(mapID) or nil
		mapID = mapInfo and mapInfo.parentMapID
		if not mapID or mapID == 0 then
			break
		end
	end
	return false
end

local function AddStaticCandidates(candidates, posX, posY, continentID, faction)
	if not continentID or IsSecret(continentID) then
		return false
	end

	local added = false
	for index, entry in ipairs(STATIC_GRAVEYARDS) do
		local include = entry.side == nil or entry.side == "N"
			or not faction
			or (entry.side == "A" and faction == "Alliance")
			or (entry.side == "H" and faction == "Horde")

		if include then
			local world = GetStaticWorldPosition(index, entry)
			if world and world.continentID == continentID then
				local dx, dy = world.x - posX, world.y - posY
				candidates[#candidates + 1] = {
					name = entry.name or entry.zone or "Spirit Healer",
					graveyardID = nil,
					continentID = continentID,
					worldX = world.x,
					worldY = world.y,
					distanceSq = dx * dx + dy * dy,
					selectable = true,
					staticMap = entry.map,
					side = entry.side,
				}
				added = true
			end
		end
	end

	return added
end

local function SelectStaticCandidates(candidates, zoneMaps, factionSide)
	local sameFaction, neutral, inZone = {}, {}, {}

	for _, candidate in ipairs(candidates) do
		if zoneMaps[candidate.staticMap] then
			inZone[#inZone + 1] = candidate
			if factionSide and candidate.side == factionSide then
				sameFaction[#sameFaction + 1] = candidate
			elseif candidate.side == "N" or candidate.side == nil then
				neutral[#neutral + 1] = candidate
			end
		end
	end

	if #sameFaction > 0 then
		return sameFaction
	elseif #neutral > 0 then
		return neutral
	elseif #inZone > 0 then
		return inZone
	end
	return candidates
end

local function AddWorldSafeLocCandidates(candidates, posX, posY, continentID)
	if type(C_WorldSafeLocsUIInternal) ~= "table"
		or type(C_WorldSafeLocsUIInternal.GetWorldSafeLocs) ~= "function"
		or not continentID
		or IsSecret(continentID) then
		return false
	end

	local worldSafeLocs = C_WorldSafeLocsUIInternal.GetWorldSafeLocs()
	if not worldSafeLocs then
		return false
	end

	local added = false
	for _, info in ipairs(worldSafeLocs) do
		if info.loc and info.continent == continentID then
			local x, y
			if info.loc.GetXYZ then
				x, y = info.loc:GetXYZ()
			else
				x, y = info.loc.x, info.loc.y
			end

			if x and y and not IsSecret(x) and not IsSecret(y) then
				local dx, dy = x - posX, y - posY
				candidates[#candidates + 1] = {
					name = info.name,
					graveyardID = nil,
					continentID = continentID,
					worldX = x,
					worldY = y,
					distanceSq = dx * dx + dy * dy,
					selectable = true,
				}
				added = true
			end
		end
	end

	return added
end

function GravePreview.GetLikelyGraveyard(displayMapID)
	if not db or not db.enabled then
		return nil
	end

	-- UnitPosition is only available outdoors. In instances and battlegrounds
	-- the client hides player coordinates from addons.
	local posY, posX, _, unitMapID = UnitPosition("player")
	if not posX or not posY or IsSecret(posX) or IsSecret(posY) then
		return nil
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	if not mapID then
		return nil
	end

	local candidates = {}
	local anySelectable = false

	local faction = UnitFactionGroup("player")
	local factionSide = faction == "Alliance" and "A" or faction == "Horde" and "H" or nil

	local zoneMaps = { [mapID] = true }
	local parentMapID = mapID
	for _ = 1, 3 do
		local mapInfo = type(C_Map.GetMapInfo) == "function" and C_Map.GetMapInfo(parentMapID) or nil
		parentMapID = mapInfo and mapInfo.parentMapID
		if not parentMapID or parentMapID == 0 then
			break
		end
		zoneMaps[parentMapID] = true
	end

	-- The bundled Forever data works while alive, unlike some of the
	-- C_DeathInfo queries. It covers all open-world spirit healers. Only use
	-- it when the current map (or a parent) is in the dataset, so new zones
	-- do not get matched to an unrelated old-world graveyard.
	local usedStatic = false
	if IsStaticMapCovered(mapID) then
		usedStatic = AddStaticCandidates(candidates, posX, posY, unitMapID, faction)
	end

	if not usedStatic then
		local graveyards, graveyardMapID
		for _ = 1, 5 do
			local mapGraveyards = C_DeathInfo.GetGraveyardsForMap(mapID)
			if mapGraveyards and #mapGraveyards > 0 then
				graveyards = mapGraveyards
				graveyardMapID = mapID
				break
			end

			local mapInfo = type(C_Map.GetMapInfo) == "function" and C_Map.GetMapInfo(mapID) or nil
			mapID = mapInfo and mapInfo.parentMapID
			if not mapID or mapID == 0 then
				break
			end
		end

		for _, graveyard in ipairs(graveyards or {}) do
			local continentID, worldPos = C_Map.GetWorldPosFromMapPos(graveyardMapID, graveyard.position)
			if worldPos then
				local worldX, worldY = worldPos:GetXY()
				if not IsSecret(worldX) and not IsSecret(worldY) then
					local dx, dy = worldX - posX, worldY - posY
					local distanceSq = dx * dx + dy * dy

					candidates[#candidates + 1] = {
						name = graveyard.name,
						graveyardID = graveyard.graveyardID,
						continentID = continentID,
						worldX = worldX,
						worldY = worldY,
						distanceSq = distanceSq,
						selectable = graveyard.isGraveyardSelectable,
					}

					if graveyard.isGraveyardSelectable then
						anySelectable = true
					end
				end
			end
		end

		if #candidates == 0 then
			AddWorldSafeLocCandidates(candidates, posX, posY, unitMapID)
		end
	end

	local pool = candidates
	if usedStatic then
		pool = SelectStaticCandidates(candidates, zoneMaps, factionSide)
	end

	local best
	for _, candidate in ipairs(pool) do
		if not anySelectable or candidate.selectable then
			if not best or candidate.distanceSq < best.distanceSq then
				best = candidate
			end
		end
	end

	if not best then
		return nil
	end

	local result = {
		name = best.name,
		graveyardID = best.graveyardID,
		distance = math.sqrt(best.distanceSq),
		continentID = best.continentID,
		worldX = best.worldX,
		worldY = best.worldY,
	}

	if displayMapID then
		local pinMapID, mapPosition = C_Map.GetMapPosFromWorldPos(
			best.continentID,
			CreateVector2D(best.worldX, best.worldY),
			displayMapID
		)
		if mapPosition and pinMapID == displayMapID then
			result.mapPosition = mapPosition
		end
	end

	return result
end

-- World map data provider -------------------------------------------------

local function CreateProvider()
	if not MapCanvasDataProviderMixin or not CreateFromMixins then
		return nil
	end

	local dataProvider = CreateFromMixins(MapCanvasDataProviderMixin)

	function dataProvider:RemoveAllData()
		self.pin = nil
		local map = self:GetMap()
		if map then
			map:RemoveAllPinsByTemplate("GravePreviewPinTemplate")
		end
	end

	function dataProvider:UpdatePin()
		local map = self:GetMap()
		if not map then
			return
		end

		-- OpenMap draws a stitched map over Blizzard's. Its own API places our
		-- plain canvas overlay above the stitched art instead.
		if OpenMapAPI and type(OpenMapAPI.IsStitched) == "function" and OpenMapAPI.IsStitched() then
			self:RemoveAllData()
			return
		end

		local displayMapID = map:GetMapID()
		if not displayMapID then
			return
		end

		local data = GravePreview.GetLikelyGraveyard(displayMapID)
		if not data or not data.mapPosition then
			self:RemoveAllData()
			return
		end

		local mapX, mapY = data.mapPosition:GetXY()
		if IsSecret(mapX) or IsSecret(mapY) then
			self:RemoveAllData()
			return
		end

		if not self.pin then
			self.pin = map:AcquirePin("GravePreviewPinTemplate", data)
		end

		self.pin.data = data
		self.pin:SetPosition(mapX, mapY)
		self.pin:Show()
	end

	function dataProvider:RefreshAllData()
		self:RemoveAllData()
		self:UpdatePin()
	end

	function dataProvider:OnShow()
		self:RefreshAllData()
	end

	function dataProvider:OnHide()
		self:RemoveAllData()
	end

	function dataProvider:OnMapChanged()
		self:RefreshAllData()
	end

	return dataProvider
end

-- OpenMap stitched-map overlay -------------------------------------------

local function OpenMapIsStitched()
	return OpenMapAPI and type(OpenMapAPI.IsStitched) == "function" and OpenMapAPI.IsStitched()
end

local function UpdateOverlay()
	if not OpenMapIsStitched() then
		if overlay then
			overlay:Hide()
		end
		return
	end

	if not WorldMapFrame or not WorldMapFrame:IsShown() then
		if overlay then
			overlay:Hide()
		end
		return
	end

	local canvas = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
	if not canvas then
		return
	end

	if overlay and overlay:GetParent() ~= canvas then
		overlay:Hide()
		overlay = nil
	end

	if not overlay then
		overlay = CreateFrame("Frame", "GravePreviewOverlay", canvas)
		overlay:SetSize(28, 28)
		overlay:EnableMouse(true)

		local icon = overlay:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		SetCorpseIcon(icon)

		overlay.Icon = icon
		overlay:SetScript("OnEnter", function(self)
			ShowGraveTooltip(self)
		end)
		overlay:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	local data = GravePreview.GetLikelyGraveyard(nil)
	if not data then
		overlay:Hide()
		return
	end

	local x, y = OpenMapAPI.CanvasFromWorldPos(data.continentID, data.worldX, data.worldY)
	if not x or not y then
		overlay:Hide()
		return
	end

	-- The stitched canvas is scaled when OpenMap zooms. Counter-scale the
	-- overlay so the corpse icon keeps its screen size, exactly like a map pin.
	local canvasScale = WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()
		or (canvas.GetScale and canvas:GetScale())
		or 1
	if not canvasScale or canvasScale <= 0 then
		canvasScale = 1
	end
	overlay:SetScale(1 / canvasScale)

	local overlayScale = overlay:GetScale()
	if not overlayScale or overlayScale <= 0 then
		overlayScale = 1
	end

	overlay:ClearAllPoints()
	overlay:SetPoint("CENTER", canvas, "TOPLEFT",
		(canvas:GetWidth() * x) / overlayScale,
		-(canvas:GetHeight() * y) / overlayScale)
	overlay:SetFrameLevel((OpenMapAPI.ArtTopLevel and OpenMapAPI.ArtTopLevel() or 1) + 10)
	overlay.data = data
	overlay:Show()
end

GravePreview.UpdateOverlay = UpdateOverlay

local function EnsureProvider()
	if not initialized then
		return
	end

	if not provider then
		provider = CreateProvider()
	end
	if not provider then
		return
	end

	if providerAdded then
		if WorldMapFrame and WorldMapFrame:IsShown() then
			provider:RefreshAllData()
		end
		return
	end

	if not WorldMapFrame or not WorldMapFrame.AddDataProvider then
		return
	end

	WorldMapFrame:AddDataProvider(provider)
	providerAdded = true

	if WorldMapFrame:IsShown() then
		provider:RefreshAllData()
	end
end

-- Slash commands ----------------------------------------------------------

local function PrintStatus()
	local pin = provider and provider.pin
	Print(("enabled=%s provider=%s pin=%s"):format(
		tostring(db and db.enabled),
		tostring(providerAdded),
		tostring(pin and pin:IsShown())
	))
end

local function PrintDebug()
	local playerMapID = C_Map.GetBestMapForUnit("player")
	local displayMapID = WorldMapFrame and WorldMapFrame:GetMapID() or playerMapID
	local posY, posX, _, unitMapID = UnitPosition("player")

	Print("debug:")
	Print(("  playerMap=%s displayMap=%s unitMap=%s"):format(
		tostring(playerMapID),
		tostring(displayMapID),
		tostring(unitMapID)
	))
	Print(("  x=%s y=%s provider=%s"):format(tostring(posX), tostring(posY), tostring(providerAdded)))

	local graveyards = playerMapID and C_DeathInfo.GetGraveyardsForMap(playerMapID) or {}
	Print(("  graveyards on player map: %d"):format(#graveyards))
	Print(("  static entries=%d covered=%s"):format(
		#STATIC_GRAVEYARDS,
		tostring(playerMapID and IsStaticMapCovered(playerMapID) or false)
	))

	Print(("  OpenMap stitched=%s"):format(tostring(OpenMapIsStitched())))

	local data = GravePreview.GetLikelyGraveyard(displayMapID)
	if data then
		if data.mapPosition then
			local x, y = data.mapPosition:GetXY()
			Print(("  chosen=%s id=%s distance=%.1f mapPos=%.4f,%.4f"):format(
				tostring(data.name),
				tostring(data.graveyardID),
				data.distance,
				x,
				y
			))
		else
			Print(("  chosen=%s id=%s distance=%.1f world=%.1f,%.1f"):format(
				tostring(data.name),
				tostring(data.graveyardID),
				data.distance,
				data.worldX or 0,
				data.worldY or 0
			))
		end
	else
		Print("  chosen=none")
	end
end

local function HandleSlash(message)
	local command, rest = (message or ""):match("^(%S*)%s*(.-)$")
	command = (command or ""):lower()
	rest = (rest or ""):lower()

	if command == "" or command == "help" then
		Print("commands:")
		Print("  /gpreview on | off   enable or disable")
		Print("  /gpreview update     refresh the map pin")
		Print("  /gpreview status     print the current state")
		Print("  /gpreview debug      print detection details")
	elseif command == "on" or command == "enable" then
		db.enabled = true
		Print("enabled.")
		if provider and WorldMapFrame and WorldMapFrame:IsShown() then
			provider:RefreshAllData()
		end
	elseif command == "off" or command == "disable" then
		db.enabled = false
		if provider then
			provider:RemoveAllData()
		end
		Print("disabled.")
	elseif command == "update" then
		if provider and WorldMapFrame and WorldMapFrame:IsShown() then
			provider:RefreshAllData()
		end
		Print("updated.")
	elseif command == "status" then
		PrintStatus()
	elseif command == "debug" then
		PrintDebug()
	else
		Print(("unknown command '%s'. Type /gpreview help."):format(command))
	end
end

-- Initialization ----------------------------------------------------------

local function Initialize()
	if initialized then
		return
	end
	initialized = true

	if type(GravePreviewDB) ~= "table" then
		GravePreviewDB = {}
	end
	db = GravePreviewDB
	CopyDefaults(db, DEFAULTS)

	SLASH_GRAVEPREVIEW1 = "/gravepreview"
	SLASH_GRAVEPREVIEW2 = "/gpreview"
	SlashCmdList["GRAVEPREVIEW"] = HandleSlash

	EnsureProvider()

	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(0.25, function()
			if not WorldMapFrame or not WorldMapFrame:IsShown() then
				return
			end
			if providerAdded and provider then
				provider:UpdatePin()
			end
			UpdateOverlay()
		end)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("WORLD_MAP_OPEN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			Initialize()
		elseif arg1 == "Blizzard_WorldMap" or arg1 == "Blizzard_MapCanvas" then
			EnsureProvider()
		end
	elseif event == "PLAYER_LOGIN" or event == "WORLD_MAP_OPEN" then
		EnsureProvider()
	end
end)
