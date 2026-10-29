--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
	Volume = true,
	Parameters = {
		Source_Padding = Util.Padding,
		Layout_PopulationLimit = Util.Population,
		Layout_AvoidOverlap = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_AVOID_OVERLAP
		end, function(value)
			return typeof(value) == "boolean"
		end),
		Layout_PlacementAttempts = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_PLACEMENT_ATTEMPTS
		end, Schema.positiveInteger),
	},
	GetCells = function(parameters: Types.Parameters, _sourceSize: Vector3, random: Random): { Types.Cell }
		local padding = parameters.Attributes.Source_Padding
		local region = (parameters.Size - Vector3.one * padding.Offset * 2) * (1 - padding.Scale * 2)
		assert(region.X > 0 and region.Y > 0 and region.Z > 0, "Source_Padding leaves no room inside the Random volume")
		local count = Util.sampleCount(parameters.Attributes.Layout_PopulationLimit, random)
		local cells: { Types.Cell } = {}
		for index = 1, count do
			-- Each copy samples the whole volume independently. Placement subtracts its actual bounds.
			table.insert(cells, {
				Frame = CFrame.identity,
				Size = region,
				Offset = Vector3.new(
					random:NextNumber(-0.5, 0.5),
					random:NextNumber(-0.5, 0.5),
					random:NextNumber(-0.5, 0.5)
				),
			})
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
