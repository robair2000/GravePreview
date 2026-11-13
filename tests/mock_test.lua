-- Offline smoke test for GravePreview. Not loaded by WoW.

local function Vector(x, y)
	return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

function CreateFromMixins(mixin)
	local result = {}
	for key, value in pairs(mixin or {}) do
		result[key] = value
	end
	return result
end

MapCanvasPinMixin = {
	SetScalingLimits = function() end,
	UseFrameLevelType = function() end,
}

MapCanvasDataProviderMixin = {
	OnAdded = function(self, map) self.owningMap = map end,
	GetMap = function(self) return self.owningMap end,
}

local pinCounter = 0
local fakeMap = {
	mapID = 1415,
	GetMapID = function(self) return self.mapID end,
	RemoveAllPinsByTemplate = function(self) self.pin = nil end,
	AcquirePin = function(self, template, data)
		pinCounter = pinCounter + 1
		local pin = {
			Icon = {
				SetTexture = function() end,
				SetTexCoord = function() end,
			},
			SetPosition = function(self, x, y) self.x, self.y = x, y end,
			SetScript = function(self, name, func) self[name] = func end,
			Show = function(self) self.shown = true end,
			IsShown = function(self) return self.shown end,
		}
		for key, value in pairs(GravePreviewPinMixin) do
			pin[key] = value
		end
		pin:OnLoad()
		pin:OnAcquired(data)
		pin:SetPosition(data.mapPosition:GetXY())
		self.pin = pin
		return pin
	end,
}

WorldMapFrame = {
	shown = true,
	provider = nil,
	AddDataProvider = function(self, dataProvider)
		self.provider = dataProvider
		dataProvider:OnAdded(fakeMap)
		dataProvider:RefreshAllData()
	end,
	HookScript = function() end,
	IsShown = function(self) return self.shown end,
	GetMapID = function(self) return fakeMap:GetMapID() end,
	GetCanvasScale = function() return 2 end,
}

local graveyards = {
	{ name = "Near GY", graveyardID = 1, position = Vector(10, 0), isGraveyardSelectable = false },
	{ name = "Far GY", graveyardID = 2, position = Vector(100, 0), isGraveyardSelectable = false },
}

local unitPositionResult = { 0, 0, 0, 0 }

C_Map = {
	GetBestMapForUnit = function() return 1415 end,
	GetWorldPosFromMapPos = function(mapID, mapPosition)
		local x, y = mapPosition:GetXY()
		return 0, Vector(x, y)
	end,
	GetMapPosFromWorldPos = function(continentID, worldPosition, displayMapID)
		local x, y = worldPosition:GetXY()
		return displayMapID, Vector(x / 200, y / 200)
	end,
	GetMapInfo = function() return nil end,
}

C_DeathInfo = {
	GetGraveyardsForMap = function() return graveyards end,
}

function UnitPosition() return unpack(unitPositionResult) end
function UnitFactionGroup() return "Horde" end
function CreateVector2D(x, y) return Vector(x, y) end
function GetBuildInfo() return "1.60.1", "70888", nil, 16001 end

C_Timer = {
	NewTicker = function()
		return { Cancel = function() end }
	end,
}

SlashCmdList = {}
DEFAULT_CHAT_FRAME = {
	AddMessage = function(self, message)
		print("[CHAT] " .. message)
	end,
}

GameTooltip = {
	SetOwner = function() end,
	SetText = function() end,
	AddLine = function() end,
	Show = function() end,
	Hide = function() end,
}

local fakeCanvas = {
	width = 1000,
	height = 800,
	GetWidth = function(self) return self.width end,
	GetHeight = function(self) return self.height end,
}

WorldMapFrame.GetCanvas = function() return fakeCanvas end

local eventFrame
function CreateFrame(kind, name, parent, template)
	local widget = {
		name = name,
		parent = parent,
		shown = true,
		events = {},
		RegisterEvent = function(self, event) self.events[event] = true end,
		SetScript = function(self, script, func) self[script] = func end,
		SetSize = function(self, width, height) self.width, self.height = width, height end,
		SetScale = function(self, scale) self.scale = scale end,
		GetScale = function(self) return self.scale or 1 end,
		EnableMouse = function() end,
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false end,
		IsShown = function(self) return self.shown end,
		GetParent = function(self) return self.parent end,
		ClearAllPoints = function(self) self.point = nil end,
		SetPoint = function(self, ...) self.point = { ... } end,
		SetFrameLevel = function(self, level) self.frameLevel = level end,
		CreateTexture = function()
			return {
				SetTexture = function() end,
				SetTexCoord = function() end,
				SetAllPoints = function() end,
			}
		end,
	}
	if name then
		_G[name] = widget
	end
	if not eventFrame then
		eventFrame = widget
	end
	return widget
end

local chunk = assert(loadfile("C:\\Users\\robai\\Documents\\Standaardproject\\GravePreview\\GravePreview.lua"))
chunk("GravePreview")

assert(eventFrame, "event frame was not created")
eventFrame.OnEvent(eventFrame, "ADDON_LOADED", "GravePreview")

assert(WorldMapFrame.provider, "world map data provider was not added")
assert(type(SlashCmdList.GRAVEPREVIEW) == "function", "slash command was not registered")

local data = GravePreview.GetLikelyGraveyard(1415)
assert(data, "no graveyard was predicted")
assert(data.name == "Near GY", "expected Near GY, got " .. tostring(data.name))
assert(math.abs(data.distance - 10) < 0.01, "expected distance 10, got " .. tostring(data.distance))
print("PREDICT:", data.name, string.format("%.1f yd", data.distance))

local mapX, mapY = data.mapPosition:GetXY()
assert(math.abs(mapX - 0.05) < 0.001 and math.abs(mapY - 0.0) < 0.001, "unexpected map position")

-- The fake AddDataProvider calls RefreshAllData, which should have acquired a pin.
assert(fakeMap.pin, "provider did not acquire a pin")
assert(fakeMap.pin.shown, "pin was not shown")
assert(fakeMap.pin.data.name == "Near GY", "pin data is wrong")
print("PIN:", fakeMap.pin.data.name, fakeMap.pin.x, fakeMap.pin.y)

-- Walking away from the near graveyard should choose the far one.
unitPositionResult = { 0, 150, 0, 0 }
data = GravePreview.GetLikelyGraveyard(1415)
assert(data and data.name == "Far GY", "expected Far GY after moving, got " .. tostring(data and data.name))
print("PREDICT AFTER MOVE:", data.name, string.format("%.1f yd", data.distance))

-- Restricted position (instance/BG) must produce no pin.
unitPositionResult = { nil, nil, nil, nil }
assert(GravePreview.GetLikelyGraveyard(1415) == nil, "restricted position should return nil")

-- A different displayed map must not place the pin on the wrong map.
unitPositionResult = { 0, 0, 0, 0 }
local oldGetMapPos = C_Map.GetMapPosFromWorldPos
C_Map.GetMapPosFromWorldPos = function() return 9999, Vector(0.5, 0.5) end
local wrongMapData = GravePreview.GetLikelyGraveyard(1415)
assert(wrongMapData and not wrongMapData.mapPosition, "wrong display map should have no mapPosition")
C_Map.GetMapPosFromWorldPos = oldGetMapPos

-- If the current map has no graveyards, walk up to the parent map.
unitPositionResult = { 0, 0, 0, 0 }
C_Map.GetMapInfo = function(mapID)
	return { parentMapID = 1414 }
end
C_DeathInfo.GetGraveyardsForMap = function(mapID)
	if mapID == 1414 then
		return graveyards
	end
	return {}
end
data = GravePreview.GetLikelyGraveyard(1415)
assert(data and data.name == "Near GY", "parent map fallback failed")
print("PARENT FALLBACK:", data.name)

-- OpenMap stitched-map overlay.
OpenMapAPI = {
	IsStitched = function() return true end,
	CanvasFromWorldPos = function(continent, x, y) return 0.5, 0.5 end,
	ArtTopLevel = function() return 100 end,
}
GravePreview.UpdateOverlay()
assert(GravePreviewOverlay, "OpenMap overlay was not created")
assert(GravePreviewOverlay:IsShown(), "OpenMap overlay was not shown")
assert(GravePreviewOverlay:GetParent() == fakeCanvas, "overlay parent is wrong")
assert(GravePreviewOverlay.frameLevel == 110, "overlay frame level is wrong: " .. tostring(GravePreviewOverlay.frameLevel))
assert(math.abs(GravePreviewOverlay:GetScale() - 0.5) < 0.001, "overlay scale is wrong: " .. tostring(GravePreviewOverlay:GetScale()))
assert(GravePreviewOverlay.point[1] == "CENTER" and GravePreviewOverlay.point[4] == 1000 and GravePreviewOverlay.point[5] == -800,
	"overlay position is wrong")
print("OPENMAP OVERLAY:", GravePreviewOverlay.point[4], GravePreviewOverlay.point[5], "scale", GravePreviewOverlay:GetScale(), "level", GravePreviewOverlay.frameLevel)

-- When OpenMap is stitched, the Blizzard pin must step aside.
OpenMapAPI.IsStitched = function() return false end
WorldMapFrame.provider:RefreshAllData()
assert(fakeMap.pin, "expected a Blizzard pin before the stitched check")
OpenMapAPI.IsStitched = function() return true end
WorldMapFrame.provider:UpdatePin()
assert(fakeMap.pin == nil, "Blizzard pin should be removed when OpenMap is stitched")

-- And the overlay hides when the stitched map is off.
OpenMapAPI.IsStitched = function() return false end
GravePreview.UpdateOverlay()
assert(not GravePreviewOverlay:IsShown(), "overlay should hide when OpenMap is not stitched")

-- If GetGraveyardsForMap returns nothing (as it does in some open-world
-- states), fall back to the WorldSafeLocs list.
C_DeathInfo.GetGraveyardsForMap = function() return {} end
C_WorldSafeLocsUIInternal = {
	GetWorldSafeLocs = function()
		return {
			{ name = "WorldSafe Near", continent = 0, loc = { GetXYZ = function() return 5, 0, 0 end } },
			{ name = "WorldSafe Far", continent = 0, loc = { GetXYZ = function() return 200, 0, 0 end } },
			{ name = "Other Continent", continent = 1, loc = { GetXYZ = function() return 1, 1, 1 end } },
		}
	end,
}
unitPositionResult = { 0, 0, 0, 0 }
data = GravePreview.GetLikelyGraveyard(1415)
assert(data and data.name == "WorldSafe Near", "WorldSafeLocs fallback failed: " .. tostring(data and data.name))
print("WORLDSAFELOCS FALLBACK:", data.name, string.format("%.1f yd", data.distance))

-- Slash commands should not throw.
OpenMapAPI.IsStitched = function() return true end
SlashCmdList.GRAVEPREVIEW("status")
SlashCmdList.GRAVEPREVIEW("debug")
SlashCmdList.GRAVEPREVIEW("off")
assert(not GravePreviewDB.enabled, "off command did not disable")
SlashCmdList.GRAVEPREVIEW("on")
assert(GravePreviewDB.enabled, "on command did not enable")

print("ALL SMOKE TESTS PASSED")
