--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

local Layout: Types.Layout = {
	Surface = true,
	Parameters = {
		Source_Padding = Util.Padding,
		Layout_SurfaceDetectionMethod = Util.SurfaceDetection,
		Layout_ColumnLimit = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_COLUMN_LIMIT
		end, Schema.dimensionRange),
		Layout_RowLimit = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_ROW_LIMIT
		end, Schema.dimensionRange),
	},
	GetCells = function(parameters: Types.Parameters, sourceSize: Vector3, _random: Random): { Types.Cell }
		local attributes = parameters.Attributes
		local padding = attributes.Source_Padding
		-- Reserve padding on both sides of the source when finding its natural spacing.
		local cellSize = Vector3.new(
			sourceSize.X / (1 - padding.Scale * 2) + padding.Offset * 2,
			parameters.Size.Y,
			sourceSize.Z / (1 - padding.Scale * 2) + padding.Offset * 2
		)
		local columns = Util.clampDimension(parameters.Size.X / cellSize.X, attributes.Layout_ColumnLimit)
		local rows = Util.clampDimension(parameters.Size.Z / cellSize.Z, attributes.Layout_RowLimit)
		return Util.grid(parameters, columns, rows, cellSize)
	end,
}
return Layout
