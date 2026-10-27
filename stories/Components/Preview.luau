--!strict
local Package = game:GetService("ReplicatedStorage").Packages.ProceduralPackage
local Types = require(Package.Types)
local ParameterUtil = require(Package.ParameterUtil)
local SourceUtil = require(Package.SourceUtil)
local PlacementUtil = require(Package.PlacementUtil)
local GeometryUtil = require(Package.GeometryUtil)
local Fixtures = require(script.Parent.Fixtures)
local Viewport = require(script.Parent.Viewport)
local Preview = {}

function Preview.parameters(overrides: Types.ExtraAttributes?): Types.Parameters
	local attributes = ParameterUtil.getDefaults(nil)
	attributes.Source_PivotMethod = "Bottom"
	attributes.Source_ScaleMethod = "Fit"
	attributes.Source_Padding = UDim.new(0.05, 0)
	attributes.Layout_Type = "SurfaceGrid"
	attributes.Layout_ColumnLimit = NumberRange.new(4)
	attributes.Layout_RowLimit = NumberRange.new(3)
	attributes.Layout_PopulationLimit = NumberRange.new(12)
	if overrides then
		for key, value in overrides do
			attributes[key] = value
		end
	end
	return ParameterUtil.resolve({ Attributes = attributes, Size = Vector3.new(40, 16, 30), Pause = function() end })
end

function Preview.showCells(scene: Viewport.Scene, cells: { Types.Cell }, fullSize: Vector3)
	scene.Box(CFrame.identity, fullSize, Color3.fromRGB(76, 93, 120))
	for _, cell in cells do
		scene.Box(
			CFrame.new(cell.Frame.X, -fullSize.Y / 2, cell.Frame.Z) * cell.Frame.Rotation,
			Vector3.new(cell.Size.X, 0.06, cell.Size.Z),
			Fixtures.Blue
		)
		scene.Marker(cell.Frame, 0.9)
	end
end

function Preview.generate(
	scene: Viewport.Scene,
	parameters: Types.Parameters,
	template: Types.Template,
	showCells: boolean
): number
	local layout = ParameterUtil.validate(parameters)
	local random = Random.new(parameters.Attributes.Random_Seed)
	local _, templateSize = GeometryUtil.getBounds(template)
	local cells = layout.GetCells(parameters, templateSize, random)
	local copies = SourceUtil.getCopies({ template }, #cells, parameters, random, nil)
	local output = Instance.new("Folder")
	output.Name = "Generated"
	output.Parent = scene.Content
	local generated = 0
	-- Placement uses ordinary instance parenting; the engine owns GeneratedFolder creation.
	PlacementUtil.run(parameters, copies, cells, random, output :: any, function(_instance, _parameters, _target)
		generated += 1
	end, nil)
	if showCells then
		Preview.showCells(scene, cells, parameters.Size)
	end
	return generated
end

return Preview
