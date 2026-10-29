--!strict
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
	Parameters = {
		Layout_PopulationLimit = Util.Population,
		Layout_BasePadding = Util.BasePadding,
		Layout_TopPadding = Util.TopPadding,
	},
	GetCells = function(parameters: Types.Parameters, sourceSize: Vector3, _random: Random): { Types.Cell }
		local size = parameters.Size
		local count = Util.clampDimension(size.Y / sourceSize.Y, parameters.Attributes.Layout_PopulationLimit)
		local cells: { Types.Cell } = {}
		for index = 1, count do
			local alpha = if count == 1 then 0.5 else (index - 1) / (count - 1)
			local cellSize =
				Util.insetXZ(Vector3.new(size.X, size.Y / count, size.Z), Util.taperPadding(parameters, alpha))
			table.insert(cells, {
				Frame = CFrame.new(0, -size.Y / 2 + (index - 0.5) * size.Y / count, 0),
				Size = cellSize,
				FitSize = cellSize,
			})
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
