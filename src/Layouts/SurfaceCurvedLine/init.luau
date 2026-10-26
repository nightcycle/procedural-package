--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
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
		-- Beam's signed handle lengths: P1 = P0 + axis0 * size0; P2 = P3 - axis1 * size1.
		-- Implicit endpoint axes are +Z and -Z, giving an arch for two positive sizes.
		local start = Vector3.new(-(size.X - cellSize.X) / 2, 0, 0)
		local finish = -start
		local control0 = start + Vector3.zAxis * parameters.Attributes.Layout_CurveSize0
		local control1 = finish + Vector3.zAxis * parameters.Attributes.Layout_CurveSize1
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
			-- Face along the horizontal tangent; degenerate curves preserve the source orientation.
			local horizontal = tangent * Vector3.new(1, 0, 1)
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
