--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
	Parameters = {
		Layout_Sides = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_SIDES
		end, function(value)
			return Schema.positiveInteger(value) and (value :: number) >= 3
		end),
	},
	GetCells = function(parameters: Types.Parameters, sourceSize: Vector3, _random: Random): { Types.Cell }
		local size = parameters.Size
		local sides = parameters.Attributes.Layout_Sides
		local thickness = math.min(sourceSize.Z, math.min(size.X, size.Z) / (2 * sides))
		local halfSide = math.sin(math.pi / sides)
		local radius = math.huge
		local cells: { Types.Cell } = {}
		for index = 1, sides do
			local front = -math.pi / 2 - math.pi / sides
			local angle0, angle1 = front + (index - 1) * math.pi * 2 / sides, front + index * math.pi * 2 / sides
			local start = Vector3.new(math.cos(angle0), 0, math.sin(angle0))
			local finish = Vector3.new(math.cos(angle1), 0, math.sin(angle1))
			local center, right = (start + finish) / 2, (finish - start).Unit
			local back = right:Cross(Vector3.yAxis)
			local extentX = math.abs(center.X) + math.abs(right.X) * halfSide
			local extentZ = math.abs(center.Z) + math.abs(right.Z) * halfSide
			if extentX > ENV.SMALL then
				radius = math.min(radius, (size.X - math.abs(back.X) * thickness) / (2 * extentX))
			end
			if extentZ > ENV.SMALL then
				radius = math.min(radius, (size.Z - math.abs(back.Z) * thickness) / (2 * extentZ))
			end
			table.insert(cells, { Frame = CFrame.fromMatrix(center, right, Vector3.yAxis, back), Size = Vector3.one })
			Util.pause(parameters, index)
		end
		local cellSize = Vector3.new(halfSide * 2 * radius, size.Y, thickness)
		-- The first face is parallel to the front plane; translate the whole regular polygon flush.
		local frontOffset = -size.Z / 2 + math.cos(math.pi / sides) * radius + thickness / 2
		for index, cell in cells do
			cell.Frame = CFrame.new(cell.Frame.Position * radius + Vector3.zAxis * frontOffset) * cell.Frame.Rotation
			cell.Size = cellSize
			cell.FitSize = cellSize
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
