--!strict
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
	Parameters = {
		Source_Padding = Util.Padding,
		Layout_SurfaceDetectionMethod = Util.SurfaceDetection,
		Layout_PopulationLimit = Util.Population,
	},
	GetCells = function(parameters: Types.Parameters, _sourceSize: Vector3, random: Random): { Types.Cell }
		local count = Util.sampleCount(parameters.Attributes.Layout_PopulationLimit, random)
		if count == 0 then
			return {}
		end
		local size = parameters.Size
		local columns = math.clamp(math.ceil(math.sqrt(count * size.X / size.Z)), 1, count)
		local rows = math.ceil(count / columns)
		local slots = Util.grid(parameters, columns, rows)
		random:Shuffle(slots)
		local cells: { Types.Cell } = {}
		for index = 1, count do
			local cell = slots[index]
			local offset = Vector3.new(random:NextNumber(-0.5, 0.5), 0, random:NextNumber(-0.5, 0.5))
			table.insert(cells, { Frame = cell.Frame, Size = cell.Size, Offset = offset })
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
