--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Types = require(game:GetService("ReplicatedStorage").Packages.ProceduralPackage.Types)
local SourceUtil = require(game:GetService("ReplicatedStorage").Packages.ProceduralPackage.SourceUtil)
local Story = require(script.Parent.Story)
local Controls = require(script.Parent.Controls)
local Preview = require(script.Parent.Preview)
local Fixtures = require(script.Parent.Fixtures)
local Viewport = require(script.Parent.Viewport)
local LayoutStory = {}
local scaleMethods: { Types.ScaleMethod } = { "Fit", "Fill", "Stretch" }
local scaleReferences: { Types.ScaleReference } = { "Min", "Height", "Average", "Max" }

function LayoutStory.create(
	kind: Types.LayoutType,
	layout: Types.Layout,
	drawGuides: ((Viewport.Scene, Types.Parameters) -> ())?
): UILabs.GenericStory
	local controls: { [string]: unknown } = {
		Width = UILabs.Slider(40, 5, 80, 1),
		Height = UILabs.Slider(12, 1, 40, 1),
		Depth = UILabs.Slider(30, 5, 60, 1),
		Source_ScaleMethod = UILabs.Choose(scaleMethods),
		Source_ScaleReference = UILabs.Choose(scaleReferences),
		Random_Seed = UILabs.Slider(2026, 0, 10000, 1),
		ShowCells = true,
	}
	if kind == "SurfaceGrid" then
		controls.ColumnMin = UILabs.Slider(1, 0, 12, 1)
		controls.ColumnMax = UILabs.Slider(6, 0, 12, 1)
		controls.RowMin = UILabs.Slider(1, 0, 12, 1)
		controls.RowMax = UILabs.Slider(4, 0, 12, 1)
		controls.TemplateWidth = UILabs.Slider(5, 1, 20, 0.5)
		controls.TemplateHeight = UILabs.Slider(8, 1, 20, 0.5)
		controls.TemplateDepth = UILabs.Slider(4, 1, 20, 0.5)
		controls.Source_Padding = UILabs.Slider(0.1, 0, 0.4, 0.01)
	elseif kind ~= "Single" then
		controls.Population = UILabs.Slider(12, 0, 60, 1)
	end
	if kind == "SurfaceCurvedLine" then
		controls.CurveSize0Scale = UILabs.Slider(0, -2, 2, 0.05)
		controls.CurveSize0Offset = UILabs.Slider(12, -40, 40, 1)
		controls.CurveSize1Scale = UILabs.Slider(0, -2, 2, 0.05)
		controls.CurveSize1Offset = UILabs.Slider(12, -40, 40, 1)
	end
	return Story.create(
		`{kind} · Cell math`,
		"Fits the source to the area before calling GetCells. RGB axes show sampled frames; gold points show cell centers / random offsets.",
		controls,
		function(scene, values)
			local parameters =
				Preview.parameters({ Layout_Type = kind, Random_Seed = Controls.number(values, "Random_Seed") })
			parameters.Size = Vector3.new(
				Controls.number(values, "Width"),
				Controls.number(values, "Height"),
				Controls.number(values, "Depth")
			)
			parameters.Attributes.Source_ScaleMethod = Controls.choose(values, "Source_ScaleMethod", scaleMethods)
			parameters.Attributes.Source_ScaleReference =
				Controls.choose(values, "Source_ScaleReference", scaleReferences)
			local templateSize = Vector3.new(5, 8, 4)
			if kind == "SurfaceGrid" then
				local a, b = Controls.number(values, "ColumnMin"), Controls.number(values, "ColumnMax")
				local c, d = Controls.number(values, "RowMin"), Controls.number(values, "RowMax")
				parameters.Attributes.Layout_ColumnLimit = NumberRange.new(math.min(a, b), math.max(a, b))
				parameters.Attributes.Layout_RowLimit = NumberRange.new(math.min(c, d), math.max(c, d))
				parameters.Attributes.Source_Padding = UDim.new(Controls.number(values, "Source_Padding"), 0)
				templateSize = Vector3.new(
					Controls.number(values, "TemplateWidth"),
					Controls.number(values, "TemplateHeight"),
					Controls.number(values, "TemplateDepth")
				)
			elseif kind ~= "Single" then
				parameters.Attributes.Layout_PopulationLimit = NumberRange.new(Controls.number(values, "Population"))
			end
			if kind == "SurfaceCurvedLine" then
				parameters.Attributes.Layout_CurveSize0 =
					UDim.new(Controls.number(values, "CurveSize0Scale"), Controls.number(values, "CurveSize0Offset"))
				parameters.Attributes.Layout_CurveSize1 =
					UDim.new(Controls.number(values, "CurveSize1Scale"), Controls.number(values, "CurveSize1Offset"))
			end
			local pauses = 0
			parameters.Attributes.Layout_PauseInterval = 8
			parameters.Pause = function(_self: Types.Parameters)
				pauses += 1
			end
			local template = Fixtures.template(false)
			assert(template:IsA("BasePart"))
			template.Size = templateSize
			local sourceSize = SourceUtil.getLayoutSize({ template }, parameters)
			template:Destroy()
			local cells = layout.GetCells(parameters, sourceSize, Random.new(parameters.Attributes.Random_Seed))
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
				`{#cells} cells · scaled footprint {sourceSize.X} × {sourceSize.Z} · {pauses} pause calls\n{if kind
						== "SurfaceCurvedLine"
					then "Front-left → back-right. Gold = signed front / right handles; green = backend samples."
					elseif
						kind == "SurfaceRandom"
					then "Offsets use normalized free cell space; the placement pipeline subtracts fitted source dimensions."
					elseif
						kind == "SurfaceGrid"
					then "Centers use area / count spacing; fixed footprints have gaps or overlaps."
					else "Every cell is returned directly by the production layout module."}`
			)
		end
	)
end

return LayoutStory
