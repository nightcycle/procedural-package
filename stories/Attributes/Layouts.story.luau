--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Components = ReplicatedStorage.DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local Types = require(ReplicatedStorage.Packages.ProceduralPackage.Types)
local kinds: { Types.LayoutType } =
	{ "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine", "Stack", "Arch", "NGon", "Grid", "Random" }
local alignments: { Types.AlignType } = { "Floor", "Center" }
local heightAxes: { Types.HeightAxis } = { "X", "Y", "Z" }

return Story.create(
	"Layout attributes · Swap layouts",
	"The same source and attribute table flow through the production layout, source, and placement modules.",
	{
		Layout_Type = UILabs.Choose(kinds, 2),
		Source_Alignment = UILabs.Choose(alignments),
		Layout_HeightAxis = UILabs.Choose(heightAxes, 2),
		BasePadding = UILabs.Slider(0, 0, 0.4, 0.01),
		TopPadding = UILabs.Slider(0.2, 0, 0.4, 0.01),
		ArchShape = UILabs.Slider(0.5, 0, 1, 0.05),
		Sides = UILabs.Slider(6, 3, 16, 1),
		Columns = UILabs.Slider(4, 1, 10, 1),
		Rows = UILabs.Slider(3, 1, 10, 1),
		Layers = UILabs.Slider(3, 1, 10, 1),
		Population = UILabs.Slider(12, 0, 80, 1),
		CurveSize0Scale = UILabs.Slider(0, -2, 2, 0.05),
		CurveSize0Offset = UILabs.Slider(12, -40, 40, 1),
		CurveSize1Scale = UILabs.Slider(0, -2, 2, 0.05),
		CurveSize1Offset = UILabs.Slider(12, -40, 40, 1),
		AsModel = true,
		ShowCells = true,
	},
	function(scene, values)
		local parameters = Preview.parameters({
			Layout_Type = Controls.choose(values, "Layout_Type", kinds),
			Source_Alignment = Controls.choose(values, "Source_Alignment", alignments),
			Layout_HeightAxis = Controls.choose(values, "Layout_HeightAxis", heightAxes),
			Layout_BasePadding = UDim.new(Controls.number(values, "BasePadding"), 0),
			Layout_TopPadding = UDim.new(Controls.number(values, "TopPadding"), 0),
			Layout_ArchShape = Controls.number(values, "ArchShape"),
			Layout_Sides = Controls.number(values, "Sides"),
			Layout_ColumnLimit = NumberRange.new(Controls.number(values, "Columns")),
			Layout_RowLimit = NumberRange.new(Controls.number(values, "Rows")),
			Layout_LayerLimit = NumberRange.new(Controls.number(values, "Layers")),
			Layout_PopulationLimit = NumberRange.new(Controls.number(values, "Population")),
			Layout_CurveSize0 = UDim.new(
				Controls.number(values, "CurveSize0Scale"),
				Controls.number(values, "CurveSize0Offset")
			),
			Layout_CurveSize1 = UDim.new(
				Controls.number(values, "CurveSize1Scale"),
				Controls.number(values, "CurveSize1Offset")
			),
		})
		local template = Fixtures.template(Controls.boolean(values, "AsModel"))
		scene.Keep(template)
		local count = Preview.generate(scene, parameters, template, Controls.boolean(values, "ShowCells"))
		scene.SetStatus(
			`{parameters.Attributes.Layout_Type}: {count} copies · {parameters.Attributes.Source_Alignment} alignment\nBlue guides = layout cells; source and placement settings are shared when switching layouts.`
		)
	end
)
