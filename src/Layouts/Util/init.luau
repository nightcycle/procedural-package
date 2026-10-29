--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = {}

Util.Padding = Schema.field(function()
	return ENV.DEFAULT_SOURCE_PADDING
end, function(value)
	return typeof(value) == "UDim"
		and Schema.nonNegative(value.Scale)
		and value.Scale < 0.5
		and Schema.nonNegative(value.Offset)
end)
Util.SurfaceDetection = Schema.field(function()
	return ENV.DEFAULT_LAYOUT_SURFACE_DETECTION_METHOD
end, Types.SurfaceDetectionMethod)
Util.Population = Schema.field(function()
	return ENV.DEFAULT_LAYOUT_POPULATION_LIMIT
end, Schema.countRange)
Util.BasePadding = Schema.field(function()
	return ENV.DEFAULT_LAYOUT_BASE_PADDING
end, Util.Padding.Validate)
Util.TopPadding = Schema.field(function()
	return ENV.DEFAULT_LAYOUT_TOP_PADDING
end, Util.Padding.Validate)

function Util.insetXZ(size: Vector3, padding: UDim): Vector3
	local inset = Vector3.new(
		(size.X - padding.Offset * 2) * (1 - padding.Scale * 2),
		size.Y,
		(size.Z - padding.Offset * 2) * (1 - padding.Scale * 2)
	)
	assert(inset.X > 0 and inset.Z > 0, "layout padding leaves no room in X/Z")
	return inset
end

function Util.taperPadding(parameters: Types.Parameters, alpha: number): UDim
	local base, top = parameters.Attributes.Layout_BasePadding, parameters.Attributes.Layout_TopPadding
	return UDim.new(base.Scale + (top.Scale - base.Scale) * alpha, base.Offset + (top.Offset - base.Offset) * alpha)
end

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
function Util.grid(parameters: Types.Parameters, columns: number, rows: number, naturalSize: Vector3?): { Types.Cell }
	if columns == 0 or rows == 0 then
		return {}
	end
	local size = parameters.Size
	local cellSize = naturalSize or size / Vector3.new(columns, 1, rows)
	-- Keep the outer footprints flush with the area, distributing gaps or overlap inside.
	-- A single cell or an oversized footprint stays centered on that axis.
	local step = Vector3.new(
		if columns > 1 then math.max(size.X - cellSize.X, 0) / (columns - 1) else 0,
		0,
		if rows > 1 then math.max(size.Z - cellSize.Z, 0) / (rows - 1) else 0
	)
	local first = -step * Vector3.new(columns - 1, 0, rows - 1) / 2
	local cells: { Types.Cell } = {}
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			table.insert(cells, {
				Frame = CFrame.new(first + Vector3.new(column, 0, row) * step),
				Size = cellSize,
			})
			Util.pause(parameters, #cells)
		end
	end
	return cells
end

-- Partition all three dimensions; each template is fitted to its own cell.
function Util.volume(parameters: Types.Parameters, columns: number, layers: number, rows: number): { Types.Cell }
	if columns == 0 or layers == 0 or rows == 0 then
		return {}
	end
	local size = parameters.Size
	local cellSize = size / Vector3.new(columns, layers, rows)
	local cells: { Types.Cell } = {}
	for layer = 1, layers do
		for row = 1, rows do
			for column = 1, columns do
				table.insert(cells, {
					Frame = CFrame.new(-size / 2 + cellSize * Vector3.new(column - 0.5, layer - 0.5, row - 0.5)),
					Size = cellSize,
					FitSize = cellSize,
				})
				Util.pause(parameters, #cells)
			end
		end
	end
	return cells
end

return Util
