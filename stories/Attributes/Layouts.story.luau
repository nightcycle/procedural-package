--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Components = ReplicatedStorage.DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local Types = require(ReplicatedStorage.Packages.ProceduralPackage.Types)
local kinds: { Types.LayoutType } = { "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine" }
local alignments: { Types.AlignType } = { "Floor", "Center" }

return Story.create(
	"Layout attributes · Swap layouts",
	"The same source and attribute table flow through the production layout, source, and placement modules.",
	{
		Layout_Type = UILabs.Choose(kinds, 2),
		Source_Alignment = UILabs.Choose(alignments),
		Columns = UILabs.Slider(4, 1, 10, 1),
		Rows = UILabs.Slider(3, 1, 10, 1),
		Population = UILabs.Slider(12, 0, 80, 1),
		Layout_CurveSize0 = UILabs.Slider(12, -40, 40, 1),
		Layout_CurveSize1 = UILabs.Slider(12, -40, 40, 1),
		AsModel = true,
		ShowCells = true,
	},
	function(scene, values)
		local parameters = Preview.parameters({
			Layout_Type = Controls.choose(values, "Layout_Type", kinds),
			Source_Alignment = Controls.choose(values, "Source_Alignment", alignments),
			Layout_ColumnLimit = NumberRange.new(Controls.number(values, "Columns")),
			Layout_RowLimit = NumberRange.new(Controls.number(values, "Rows")),
			Layout_PopulationLimit = NumberRange.new(Controls.number(values, "Population")),
			Layout_CurveSize0 = Controls.number(values, "Layout_CurveSize0"),
			Layout_CurveSize1 = Controls.number(values, "Layout_CurveSize1"),
		})
		local template = Fixtures.template(Controls.boolean(values, "AsModel"))
		scene.Keep(template)
		local count = Preview.generate(scene, parameters, template, Controls.boolean(values, "ShowCells"))
		scene.SetStatus(
			`{parameters.Attributes.Layout_Type}: {count} copies · {parameters.Attributes.Source_Alignment} alignment\nBlue guides = layout cells; source and placement settings are shared when switching layouts.`
		)
	end
)
