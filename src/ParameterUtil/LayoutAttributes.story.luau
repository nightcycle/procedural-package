--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Components = ReplicatedStorage.DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Types = require(script.Parent.Parent.Types)
local Parameters = require(script.Parent)
local layouts: { Types.LayoutType } =
	{ "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine", "Stack", "Arch", "NGon", "Grid", "Random" }

return Story.create(
	"Parameter attributes · Active layout schema",
	"Only the chosen layout's fields are exported. Grid never exposes CurveSize0 or CurveSize1.",
	{
		Layout_Type = UILabs.Choose(layouts, 2),
	},
	function(scene, values)
		local selected: Types.LayoutType = Controls.choose(values, "Layout_Type", layouts) :: Types.LayoutType
		local attributes = Parameters.getDefaults(nil, selected)
		local fields: { string } = {}
		for name in pairs(attributes :: Types.ExtraAttributes) do
			if
				name:sub(1, 7) == "Layout_"
				and name ~= "Layout_Type"
				and name ~= "Layout_PauseInterval"
				and name ~= "Layout_HeightAxis"
			then
				table.insert(fields, name)
			end
		end
		table.sort(fields)
		for index, name in fields do
			Fixtures.part(
				name,
				Vector3.new(3, 6, 3),
				CFrame.new((index - (#fields + 1) / 2) * 5, 0, 0),
				Fixtures.Green,
				scene.Content
			)
		end
		scene.Marker(CFrame.identity)
		scene.SetStatus(
			`{selected}: {#fields} layout-specific fields\n{if #fields > 0
				then table.concat(fields, " · ")
				else "Only Layout_Type / Layout_PauseInterval / Layout_HeightAxis, plus shared source and random fields."}`
		)
	end
)
