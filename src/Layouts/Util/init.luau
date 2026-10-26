--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = {}

Util.SurfaceDetection = Schema.field(function()
	return ENV.DEFAULT_LAYOUT_SURFACE_DETECTION_METHOD
end, Types.SurfaceDetectionMethod)
Util.Population = Schema.field(function()
	return ENV.DEFAULT_LAYOUT_POPULATION_LIMIT
end, Schema.countRange)

function Util.pause(parameters: Types.Parameters, index: number)
	if index % parameters.Attributes.Layout_PauseInterval == 0 then
		parameters:Pause()
	end
end

function Util.sampleCount(range: NumberRange, random: Random): number
	return random:NextInteger(math.ceil(range.Min), math.floor(range.Max))
end

function Util.clampDimension(value: number, limit: NumberRange): number
	return math.clamp(math.floor(value), math.ceil(limit.Min), math.floor(limit.Max))
end

-- Surface layouts always use one layer in the area's X/Z plane.
function Util.grid(parameters: Types.Parameters, columns: number, rows: number): { Types.Cell }
	local size = parameters.Size
	local cellSize = size / Vector3.new(columns, 1, rows)
	local cells: { Types.Cell } = {}
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			table.insert(cells, {
				Frame = CFrame.new(-size / 2 + cellSize / 2 + Vector3.new(column, 0, row) * cellSize),
				Size = cellSize,
			})
			Util.pause(parameters, #cells)
		end
	end
	return cells
end

return Util
