--!strict
local Types = require(script.Parent.Parent.Types)
local SurfaceRandom = require(script.Parent.SurfaceRandom)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
	Volume = true,
	Parameters = {
		Source_Padding = SurfaceRandom.Parameters.Source_Padding,
		Layout_PopulationLimit = SurfaceRandom.Parameters.Layout_PopulationLimit,
	},
	GetCells = function(parameters: Types.Parameters, sourceSize: Vector3, random: Random): { Types.Cell }
		local count = Util.sampleCount(parameters.Attributes.Layout_PopulationLimit, random)
		if count == 0 then
			return {}
		end
		local capacity = parameters.Size / sourceSize
		local density = (count / (capacity.X * capacity.Y * capacity.Z)) ^ (1 / 3)
		local columns = math.clamp(math.ceil(capacity.X * density), 1, count)
		local layers = math.clamp(math.ceil(capacity.Y * density), 1, math.ceil(count / columns))
		local rows = math.ceil(count / (columns * layers))
		local slots = Util.volume(parameters, columns, layers, rows)
		random:Shuffle(slots)
		local cells: { Types.Cell } = {}
		for index = 1, count do
			local cell = slots[index]
			cell.Frame += cell.Size * Vector3.new(
				random:NextNumber(-0.5, 0.5),
				random:NextNumber(-0.5, 0.5),
				random:NextNumber(-0.5, 0.5)
			)
			table.insert(cells, cell)
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
