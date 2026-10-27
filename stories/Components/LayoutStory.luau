--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Types = require(game:GetService("ReplicatedStorage").Packages.ProceduralPackage.Types)
local Story = require(script.Parent.Story)
local Controls = require(script.Parent.Controls)
local Preview = require(script.Parent.Preview)
local Fixtures = require(script.Parent.Fixtures)
local Viewport = require(script.Parent.Viewport)
local LayoutStory = {}

function LayoutStory.create(
	kind: Types.LayoutType,
	layout: Types.Layout,
	drawGuides: ((Viewport.Scene, Types.Parameters) -> ())?
): UILabs.GenericStory
	local controls: { [string]: unknown } = {
		Width = UILabs.Slider(40, 5, 80, 1),
		Depth = UILabs.Slider(30, 5, 60, 1),
		Random_Seed = UILabs.Slider(2026, 0, 10000, 1),
		ShowCells = true,
	}
	if kind == "SurfaceGrid" then
		controls.ColumnMin = UILabs.Slider(1, 1, 12, 1)
		controls.ColumnMax = UILabs.Slider(6, 1, 12, 1)
		controls.RowMin = UILabs.Slider(1, 1, 12, 1)
		controls.RowMax = UILabs.Slider(4, 1, 12, 1)
		controls.TemplateWidth = UILabs.Slider(5, 1, 20, 0.5)
		controls.TemplateDepth = UILabs.Slider(4, 1, 20, 0.5)
		controls.Source_Padding = UILabs.Slider(0.1, 0, 0.4, 0.01)
	elseif kind ~= "Single" then
		controls.Population = UILabs.Slider(12, 0, 60, 1)
	end
	if kind == "SurfaceCurvedLine" then
		controls.Layout_CurveSize0 = UILabs.Slider(12, -40, 40, 1)
		controls.Layout_CurveSize1 = UILabs.Slider(12, -40, 40, 1)
	end
	return Story.create(
		`{kind} · Cell math`,
		"Calls only this layout's GetCells. RGB axes show sampled frames; gold points show cell centers / random offsets.",
		controls,
		function(scene, values)
			local parameters =
				Preview.parameters({ Layout_Type = kind, Random_Seed = Controls.number(values, "Random_Seed") })
			parameters.Size = Vector3.new(Controls.number(values, "Width"), 12, Controls.number(values, "Depth"))
			local templateSize = Vector3.new(5, 8, 4)
			if kind == "SurfaceGrid" then
				local a, b = Controls.number(values, "ColumnMin"), Controls.number(values, "ColumnMax")
				local c, d = Controls.number(values, "RowMin"), Controls.number(values, "RowMax")
				parameters.Attributes.Layout_ColumnLimit = NumberRange.new(math.min(a, b), math.max(a, b))
				parameters.Attributes.Layout_RowLimit = NumberRange.new(math.min(c, d), math.max(c, d))
				parameters.Attributes.Source_Padding = UDim.new(Controls.number(values, "Source_Padding"), 0)
				templateSize =
					Vector3.new(Controls.number(values, "TemplateWidth"), 8, Controls.number(values, "TemplateDepth"))
			elseif kind ~= "Single" then
				parameters.Attributes.Layout_PopulationLimit = NumberRange.new(Controls.number(values, "Population"))
			end
			if kind == "SurfaceCurvedLine" then
				parameters.Attributes.Layout_CurveSize0 = Controls.number(values, "Layout_CurveSize0")
				parameters.Attributes.Layout_CurveSize1 = Controls.number(values, "Layout_CurveSize1")
			end
			local pauses = 0
			parameters.Attributes.Layout_PauseInterval = 8
			parameters.Pause = function(_self: Types.Parameters)
				pauses += 1
			end
			local cells = layout.GetCells(parameters, templateSize, Random.new(parameters.Attributes.Random_Seed))
			scene.Box(CFrame.identity, parameters.Size, Color3.fromRGB(76, 93, 120))
			local previous: Vector3? = nil
			for _, cell in cells do
				if Controls.boolean(values, "ShowCells") then
					scene.Box(cell.Frame, cell.Size, Fixtures.Blue)
				end
				local position = cell.Frame.Position + (cell.Offset or Vector3.zero) * cell.Size
				scene.Marker(CFrame.new(position) * cell.Frame.Rotation, 1.8)
				if previous and kind == "SurfaceCurvedLine" then
					scene.Line(previous, position, Fixtures.Green, 0.16)
				end
				previous = position
			end
			if drawGuides then
				drawGuides(scene, parameters)
			end
			scene.SetStatus(
				`{#cells} cells · template footprint {templateSize.X} × {templateSize.Z} · {pauses} pause calls\n{if kind
						== "SurfaceCurvedLine"
					then "Front-left → back-right. Gold = signed front / right handles; green = backend samples."
					elseif
						kind == "SurfaceRandom"
					then "Offsets use normalized free cell space; the placement pipeline subtracts fitted source dimensions."
					else "Every cell is returned directly by the production layout module."}`
			)
		end
	)
end

return LayoutStory
