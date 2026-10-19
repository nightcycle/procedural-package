--!strict
-- Modules
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type Template = Types.Template
type TemplateGroup = Types.TemplateGroup
type ExtraAttributes = Types.ExtraAttributes
type Bounds = Types.Bounds
-- Constants
-- Private Functions
-- Class
local Util = {}

function Util.getGrid(size: Vector3, count: number, parameters: Parameters): Vector3
	if parameters.Attributes.RandomPlacement == "Line" then
		return Vector3.new(count, 1, 1)
	end
	local x, y, z = 1, 1, 1
	local iterations = 0
	while x * y * z < count do
		local width = size.X / x
		local height = if parameters.Attributes.GeneratedAlignment == "Center" then size.Y / y else 0
		local depth = size.Z / z
		if width >= height and width >= depth then
			x += 1
		elseif height >= depth then
			y += 1
		else
			z += 1
		end
		iterations += 1
		if iterations % parameters.Attributes.PauseInterval == 0 then
			parameters:Pause()
		end
	end
	return Vector3.new(x, y, z)
end
return Util
