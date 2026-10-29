--!strict
-- Run from the repository root: lune run scripts/build-demo.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local loadPackage = require("./lib/load-package")()
local ParameterUtil = loadPackage("src/ParameterUtil")
type Datatypes = {
	CFrame: typeof(CFrame),
	Vector3: typeof(Vector3),
	Color3: typeof(Color3),
	NumberRange: typeof(NumberRange),
	UDim: typeof(UDim),
}
local datatypes = (roblox :: any) :: Datatypes
local CFrame, Vector3, Color3 = datatypes.CFrame, datatypes.Vector3, datatypes.Color3
local NumberRange, UDim = datatypes.NumberRange, datatypes.UDim
type RInstance = roblox.Instance & { [string]: any }

local examples = roblox.Instance.new("Folder") :: RInstance
examples.Name = "examples"
local library = roblox.deserializeModel(fs.readFile("demo/lib.rbxm"))[1] :: RInstance
-- Remove the old gallery's comparison fixtures; retain the original source library.
local oldFixtures = library:FindFirstChild("DemoSources")
if oldFixtures and oldFixtures:GetAttribute("ProceduralPackageDemoGallery") == true then
	oldFixtures:Destroy()
end

local sourcePath = "game.ReplicatedStorage.lib.ruin.pillar.Meshes/PolygonNature_Prop_Pillar_01"
local source = library.ruin.pillar:FindFirstChild("Meshes/PolygonNature_Prop_Pillar_01")
assert(source and source:IsA("BasePart"), "Missing demo pillar source")
local entries = {}
local layouts =
	{ "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine", "Stack", "Arch", "NGon", "Grid", "Random" }
for index, layout in layouts do
	local instance = roblox.Instance.new("ProceduralModel") :: RInstance
	instance.Name = layout
	instance.Size = Vector3.new(72, 36, 56)
	instance.WorldPivotData = CFrame.new(((index - 1) % 3 - 1) * 100, 20, math.floor((index - 1) / 3) * 100)
	instance.NeedsPivotMigration = false
	local attributes = ParameterUtil.getDefaults(nil, layout)
	attributes.Source_Path = sourcePath
	attributes.Source_PivotMethod = "Bottom"
	attributes.Source_ScaleMethod = "Fit"
	if layout == "Grid" or layout == "Random" then
		attributes.Source_ScaleMethod = "Stretch"
	end
	if attributes.Source_Padding ~= nil then
		attributes.Source_Padding = UDim.new(0.05, 0)
	end
	attributes.Layout_Type = layout
	if layout == "SurfaceGrid" or layout == "Grid" then
		attributes.Layout_ColumnLimit = NumberRange.new(4)
		attributes.Layout_RowLimit = NumberRange.new(3)
		if layout == "Grid" then
			attributes.Layout_LayerLimit = NumberRange.new(4)
		end
	elseif attributes.Layout_PopulationLimit ~= nil then
		attributes.Layout_PopulationLimit = NumberRange.new(12)
	end
	if layout == "SurfaceCurvedLine" then
		attributes.Layout_CurveSize0 = UDim.new(0, 30)
		attributes.Layout_CurveSize1 = UDim.new(0, 30)
	end
	if layout == "Stack" or layout == "Arch" or layout == "NGon" then
		attributes.Source_ScaleMethod = "Stretch"
		if layout ~= "NGon" then
			attributes.Layout_TopPadding = UDim.new(0.15, 0)
		end
	end
	attributes.Random_Seed = 2026
	local settings: { [string]: string } = {}
	for key, value in attributes do
		instance:SetAttribute(key, value)
		settings[key] = tostring(value)
	end
	local generator = roblox.Instance.new("ModuleScript") :: RInstance
	generator.Name = "Generator"
	generator.Source = [[--!strict
local Package = require(game.ReplicatedStorage.Packages.ProceduralPackage)
local model = script.Parent
assert(model:IsA("ProceduralModel"))
return Package.Generator.new(model)
]]
	generator.Parent = instance
	instance.Generator = generator
	instance.Dirty = true
	instance.Parent = examples
	table.insert(
		entries,
		{ LayoutType = layout, InstancePath = "game.Workspace.examples." .. layout, Settings = settings }
	)
end

local bytes = roblox.serializeModel({ examples })
local saved = roblox.deserializeModel(bytes)[1] :: RInstance
assert(#saved:GetChildren() == #layouts, "Expected exactly one example per layout")
for _, child in saved:GetChildren() do
	local instance = child :: RInstance
	assert(instance:IsA("ProceduralModel") and instance.Dirty == true)
	assert(instance.Generator and instance.Generator.Parent == instance)
	assert(instance.Name == instance:GetAttribute("Layout_Type"))
	assert(instance:GetAttribute("Source_Path") == sourcePath)
	local expected = ParameterUtil.getDefaults(nil, instance.Name)
	for name in instance:GetAttributes() do
		assert(expected[name] ~= nil, `{instance.Name} exposes inactive {name}`)
	end
	for name in expected do
		assert(instance:GetAttribute(name) ~= nil, `{instance.Name} lacks {name}`)
	end
end
fs.writeFile("demo/workspace/examples.rbxm", bytes)
fs.writeFile("demo/lib.rbxm", roblox.serializeModel({ library }))
fs.writeFile("demo/gallery.json", serde.encode("json", { ExampleCount = #entries, Examples = entries }, true) .. "\n")
print(`Saved and verified {#entries} examples, one per layout type.`)
