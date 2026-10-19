--!strict
-- Modules
local ENV = require(script.Parent.ENV)
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type Template = Types.Template
type TemplateGroup = Types.TemplateGroup
type ExtraAttributes = Types.ExtraAttributes
-- Constants
-- Private Functions
-- Class
local Util = {}

Util.print = function(...)
	if ENV.DEBUG_PRINT_ENABLED then
		print(...)
	end
end

Util.debugBox = function(parent: Instance, color: Color3): SelectionBox
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Color3 = color
	selectionBox.SurfaceColor3 = color
	selectionBox.Parent = parent
	return selectionBox
end

Util.debugRegion = function(cf: CFrame, size: Vector3, color: Color3): (Part, SelectionBox)
	local part = Instance.new("Part")
	part.CFrame = cf
	part.Size = size
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false

	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Color3 = color
	selectionBox.SurfaceColor3 = color
	selectionBox.Adornee = part
	selectionBox.Parent = part
	return part, selectionBox
end
return Util
