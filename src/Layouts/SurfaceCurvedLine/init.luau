--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

local function getControlPoints(
	size: Vector3,
	curveSize0: number,
	curveSize1: number
): (Vector3, Vector3, Vector3, Vector3)
	-- Front is local -Z; right is local +X. Anchor origins at the exact corners.
	local start = Vector3.new(-size.X / 2, 0, -size.Z / 2)
	local finish = Vector3.new(size.X / 2, 0, size.Z / 2)
	-- Enter from the front along +Z, and leave through the right along +X.
	return start, start + Vector3.zAxis * curveSize0, finish - Vector3.xAxis * curveSize1, finish
end

local Layout: Types.Layout & { GetControlPoints: typeof(getControlPoints) } = {
	GetControlPoints = getControlPoints,
	Parameters = {
		Layout_SurfaceDetectionMethod = Util.SurfaceDetection,
		Layout_PopulationLimit = Util.Population,
		Layout_CurveSize0 = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_CURVE_SIZE_0
		end, Schema.finite),
		Layout_CurveSize1 = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_CURVE_SIZE_1
		end, Schema.finite),
	},
	GetCells = function(parameters: Types.Parameters, _templateSize: Vector3, random: Random): { Types.Cell }
		local count = Util.sampleCount(parameters.Attributes.Layout_PopulationLimit, random)
		local size = parameters.Size
		local cellSize = Vector3.new(size.X / math.max(count, 1), size.Y, size.Z)
		local start, control0, control1, finish =
			getControlPoints(size, parameters.Attributes.Layout_CurveSize0, parameters.Attributes.Layout_CurveSize1)
		local cells: { Types.Cell } = {}
		for index = 1, count do
			local t = if count == 1 then 0.5 else (index - 1) / (count - 1)
			local position = (1 - t) ^ 3 * start
				+ 3 * (1 - t) ^ 2 * t * control0
				+ 3 * (1 - t) * t ^ 2 * control1
				+ t ^ 3 * finish
			local tangent = 3 * (1 - t) ^ 2 * (control0 - start)
				+ 6 * (1 - t) * t * (control1 - control0)
				+ 3 * t ^ 2 * (finish - control1)
			-- Zero-length handles still face along the diagonal at the endpoints.
			local horizontal = if tangent.Magnitude > ENV.SMALL then tangent else finish - start
			local rotation = if horizontal.Magnitude > ENV.SMALL
				then CFrame.Angles(0, -math.atan2(horizontal.Z, horizontal.X), 0)
				else CFrame.identity
			table.insert(cells, { Frame = CFrame.new(position) * rotation, Size = cellSize })
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
