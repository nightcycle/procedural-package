--!strict
local Types = require(script.Parent.Parent.Types)
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local SurfaceGrid = require(script.Parent.SurfaceGrid)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
	Volume = true,
	Parameters = {
		Source_Padding = SurfaceGrid.Parameters.Source_Padding,
		Layout_ColumnLimit = SurfaceGrid.Parameters.Layout_ColumnLimit,
		Layout_RowLimit = SurfaceGrid.Parameters.Layout_RowLimit,
		Layout_LayerLimit = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_LAYER_LIMIT
		end, Schema.dimensionRange),
	},
	GetCells = function(parameters: Types.Parameters, sourceSize: Vector3, random: Random): { Types.Cell }
		local attributes = parameters.Attributes
		local padding = attributes.Source_Padding
		local footprint = Vector3.new(
			sourceSize.X / (1 - 2 * padding.Scale) + 2 * padding.Offset,
			sourceSize.Y,
			sourceSize.Z / (1 - 2 * padding.Scale) + 2 * padding.Offset
		)
		local counts = parameters.Size / footprint
		local cells = Util.volume(
			parameters,
			Util.clampDimension(counts.X, attributes.Layout_ColumnLimit),
			Util.clampDimension(counts.Y, attributes.Layout_LayerLimit),
			Util.clampDimension(counts.Z, attributes.Layout_RowLimit)
		)
		for index, cell in cells do
			-- Jitter across layer boundaries so neighboring copies can overlap vertically.
			cell.Frame += Vector3.yAxis * random:NextNumber(-0.5, 0.5) * cell.Size.Y
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
