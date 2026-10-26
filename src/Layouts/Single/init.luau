--!strict
local Types = require(script.Parent.Parent.Types)
local Layout: Types.Layout = {
	Parameters = {},
	GetCells = function(parameters: Types.Parameters, _templateSize: Vector3, _random: Random): { Types.Cell }
		return { { Frame = CFrame.identity, Size = parameters.Size } }
	end,
}
return Layout
