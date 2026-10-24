--!strict
-- Run from the repository root: lune run scripts/build-demo.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance = roblox.Instance
-- Lune's published definitions omit datatype constructors. Give that boundary
-- Roblox's constructor types so the rest of this builder stays typed.
type Datatypes = {
	CFrame: typeof(CFrame),
	Vector3: typeof(Vector3),
	Vector2: typeof(Vector2),
	Color3: typeof(Color3),
	NumberRange: typeof(NumberRange),
	UDim: typeof(UDim),
	UDim2: typeof(UDim2),
	Enum: typeof(Enum),
}
local datatypes = (roblox :: any) :: Datatypes
local CFrame = datatypes.CFrame
local Vector3 = datatypes.Vector3
local Vector2 = datatypes.Vector2
local Color3 = datatypes.Color3
local NumberRange = datatypes.NumberRange
local UDim = datatypes.UDim
local UDim2 = datatypes.UDim2
local Enum = datatypes.Enum
-- Serialized properties such as WorldPivotData and Dirty are intentionally
-- dynamic in Lune; keep that boundary separate from the typed demo settings.
type RInstance = roblox.Instance & { [string]: any }
type Frame = CFrame
type Vector = Vector3
type Color = Color3
type Attribute = string | number | boolean | Frame | Vector | Color | NumberRange | UDim
type Attributes = { [string]: Attribute }
type Settings = {
	SourcePath: string?,
	SourcePathDelimiter: string?,
	SourceMaxYield: number?,
	PauseInterval: number?,
	GeneratedAlignment: string?,
	GeneratedPivotMethod: string?,
	GeneratedScaleMethod: string?,
	GeneratedScaleReference: string?,
	GeneratedPadding: UDim?,
	GeneratedExcludedTags: string?,
	GeneratedCount: NumberRange?,
	RandomSeed: number?,
	RandomScale: NumberRange?,
	RandomRoll: NumberRange?,
	RandomPan: NumberRange?,
	RandomTilt: NumberRange?,
	RandomPlacement: string?,
	Size: Vector3?,
	PivotOffset: CFrame?,
	Tint: Color3?,
	Transparency: number?,
}
type Entry = {
	Id: string,
	Title: string,
	Description: string,
	Section: string,
	InstancePath: string,
	SourcePath: string,
	Position: { number },
	Settings: { [string]: string },
}

local EXAMPLES_PATH = "demo/workspace/examples.rbxm"
local LIBRARY_PATH = "demo/lib.rbxm"
local MANAGED_ATTRIBUTE = "ProceduralPackageDemoGallery"
local examples = roblox.deserializeModel(fs.readFile(EXAMPLES_PATH))[1] :: RInstance
local library = roblox.deserializeModel(fs.readFile(LIBRARY_PATH))[1] :: RInstance
local entries: { Entry } = {}
local pivotMethods = {
	"Pivot",
	"Center",
	"Bottom",
	"Top",
	"PrimaryPartPivot",
	"PrimaryPartCenter",
	"PrimaryPartBottom",
	"PrimaryPartTop",
}

local function make(className: string, name: string, parent: RInstance?): RInstance
	local instance = Instance.new(className) :: RInstance
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function children(instance: RInstance): { RInstance }
	return instance:GetChildren() :: { RInstance }
end

local function descendants(instance: RInstance): { RInstance }
	return instance:GetDescendants() :: { RInstance }
end

local function replaceManaged(parent: RInstance, name: string): RInstance
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(
			existing:GetAttribute(MANAGED_ATTRIBUTE) == true,
			`Refusing to replace unmanaged {existing:GetFullName()}`
		)
		existing:Destroy()
	end
	local folder = make("Folder", name, parent)
	folder:SetAttribute(MANAGED_ATTRIBUTE, true)
	return folder
end

local gallery = replaceManaged(examples, "Gallery")
local fixtures = replaceManaged(library, "DemoSources")
local displays = make("Folder", "Displays", gallery)

local function getExtents(instance: RInstance): (Frame, Vector)
	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	local primary = instance.PrimaryPart
	local worldPivot = instance.WorldPivotData or CFrame.identity
	local basis = if primary then primary.CFrame.Rotation else worldPivot.Rotation
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	for _, part in descendants(instance) do
		if not part:IsA("BasePart") then
			continue
		end
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
					local point = basis:PointToObjectSpace(corner)
					minimum = minimum:Min(point)
					maximum = maximum:Max(point)
				end
			end
		end
	end
	assert(minimum.X < math.huge, "Model must contain parts")
	return basis * CFrame.new((minimum + maximum) / 2), maximum - minimum
end

local function getPivot(instance: RInstance): Frame
	if instance:IsA("BasePart") then
		return instance.CFrame * instance.PivotOffset
	elseif instance.PrimaryPart then
		return getPivot(instance.PrimaryPart)
	end
	return instance.WorldPivotData or (getExtents(instance))
end

local function move(instance: RInstance, target: Frame)
	local delta = target * getPivot(instance):Inverse()
	if instance:IsA("BasePart") then
		instance.CFrame = delta * instance.CFrame
		return
	end
	for _, child in descendants(instance) do
		if child:IsA("BasePart") then
			child.CFrame = delta * child.CFrame
		elseif child:IsA("Model") and child.WorldPivotData then
			child.WorldPivotData = delta * child.WorldPivotData
		end
	end
	instance.WorldPivotData = target
end

-- Lune writes the serialized ScaleFactor but does not implement engine ScaleTo.
-- Scale fixture geometry and pivot offsets by the relative factor before saving it.
local function scaleModel(model: RInstance, targetScale: number)
	local factor = targetScale / model.Scale
	local origin = getPivot(model)
	for _, child in descendants(model) do
		if child:IsA("BasePart") then
			local relative = origin:ToObjectSpace(child.CFrame)
			child.Size *= factor
			child.CFrame = origin * CFrame.new(relative.Position * factor) * relative.Rotation
			local offset = child.PivotOffset
			child.PivotOffset = CFrame.new(offset.Position * factor) * offset.Rotation
		end
	end
	model.Scale = targetScale
end

local function findSource(path: string, delimiter: string?): RInstance
	local keys = string.split(path, delimiter or ".")
	assert(keys[1] == "game" and keys[2] == "ReplicatedStorage" and keys[3] == "lib", `Unexpected source {path}`)
	local current = library
	for index = 4, #keys do
		local child = current:FindFirstChild(keys[index])
		assert(child, `Missing source {path} at {keys[index]}`)
		current = child :: RInstance
	end
	return current
end

local function sourcePath(instance: RInstance): string
	return "game.ReplicatedStorage." .. instance:GetFullName()
end

local pillar = findSource("game.ReplicatedStorage.lib.ruin.pillar.Meshes/PolygonNature_Prop_Pillar_01")
local birch = findSource("game.ReplicatedStorage.lib.vegetation.tree.full.Meshes/Birch_Tree_Birch_04")
local function fixture(original: RInstance, name: string, parent: RInstance?): RInstance
	local clone = original:Clone() :: RInstance
	clone.Name = name
	clone:SetAttribute("DemoOriginalSource", sourcePath(original))
	clone.Parent = parent or fixtures
	for _, child in descendants(clone) do
		if child:IsA("BasePart") then
			child.Anchored = true
		end
	end
	if clone:IsA("BasePart") then
		clone.Anchored = true
	end
	move(clone, CFrame.identity)
	return clone
end

local pivotSources = make("Folder", "Pivots", fixtures)
local pivotPart = fixture(pillar, "Part", pivotSources)
pivotPart.PivotOffset = CFrame.new(1.5, -pillar.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(25), 0)
local pivotFixtures: { { Name: string, Source: RInstance, Note: string } } = {
	{
		Name = "part",
		Source = pivotPart,
		Note = "BasePart; PrimaryPart options fall back. Native pivot is offset and rotated.",
	},
}
for _, primary in { false, true } do
	for _, scale in { 1, 0.25, 3 } do
		local name = (if primary then "Primary" else "Model")
			.. (if scale == 0.25 then "Quarter" elseif scale == 3 then "Triple" else "Unit")
		local model = fixture(birch, name, pivotSources)
		if primary then
			for _, child in children(model) do
				if child:IsA("BasePart") and string.find(string.lower(child.Name), "trunk", 1, true) then
					model.PrimaryPart = child
					child.PivotOffset = CFrame.new(0.5, -child.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(15), 0)
					break
				end
			end
			assert(model.PrimaryPart, "Birch fixture requires a trunk PrimaryPart")
		end
		move(model, CFrame.identity)
		scaleModel(model, scale)
		table.insert(pivotFixtures, {
			Name = string.lower(name),
			Source = model,
			Note = `Source Model scale = {scale}; {if primary
				then "trunk PrimaryPart assigned"
				else "no PrimaryPart, matching fallback behavior"}.`,
		})
	end
end
local unitModel = pivotSources.ModelUnit

local selection = make("Folder", "Selection", fixtures)
fixture(pillar, "Pillar", selection)
fixture(birch, "Birch", selection)
local nested = make("Folder", "Nested", selection)
fixture(library.vegetation.bush:GetChildren()[1], "Bush", nested)
local excluded = make("Folder", "HiddenSubtree", selection)
excluded:AddTag("DemoHidden")
fixture(library.rock.boulder:GetChildren()[1], "HiddenBoulder", excluded)

local defaults: Attributes = {
	SourcePath = sourcePath(pillar),
	SourcePathDelimiter = ".",
	SourceMaxYield = 15,
	PauseInterval = 100,
	GeneratedAlignment = "Floor",
	GeneratedPivotMethod = "Bottom",
	GeneratedScaleMethod = "Fit",
	GeneratedScaleReference = "Min",
	GeneratedPadding = UDim.new(0.05, 0),
	GeneratedExcludedTags = "",
	GeneratedCount = NumberRange.new(1),
	RandomSeed = 2026,
	RandomScale = NumberRange.new(1),
	RandomRoll = NumberRange.new(0),
	RandomPan = NumberRange.new(0),
	RandomTilt = NumberRange.new(0),
	RandomPlacement = "Grid",
	PackageVersion = 2,
}
local normalGenerator = "--!strict\nreturn require(game.ReplicatedStorage.Packages.ProceduralPackage).Generator.new()\n"
local section: RInstance = gallery
local sectionName = ""
local sectionColor = Color3.fromRGB(65, 145, 210)
local slot = 0
local currentRow = 0
local sectionOffset = 0

local function part(name: string, parent: RInstance, size: Vector, frame: Frame, color: Color): RInstance
	local result = make("Part", name, parent)
	result.Size = size
	result.CFrame = frame
	result.Color = color
	result.Material = Enum.Material.SmoothPlastic
	result.Anchored = true
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	return result
end

local function label(plate: RInstance, text: string, face: EnumItem)
	local isTop = face == Enum.NormalId.Top
	local size: Vector = plate.Size
	-- A top face's canvas axes follow Z/X. Match that aspect ratio, then
	-- rotate the text clockwise so its width follows the plate's long X axis.
	local canvas = (if isTop then Vector2.new(size.Z, size.X) else Vector2.new(size.X, size.Y)) * 12
	local textSize = if isTop then Vector2.new(canvas.Y, canvas.X) else canvas
	local surface = make("SurfaceGui", "Label", plate)
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = canvas
	surface.LightInfluence = 0
	local textLabel = make("TextLabel", "Text", surface)
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.Position = UDim2.fromScale(0.5, 0.5)
	textLabel.Size = UDim2.fromOffset(textSize.X - 24, textSize.Y - 24)
	textLabel.Rotation = if isTop then 90 else 0
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(235, 242, 250)
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.TextSize = 34
	textLabel.Text = text
	local textConstraint = make("UITextSizeConstraint", "TextSize", textLabel)
	textConstraint.MinTextSize = 12
	textConstraint.MaxTextSize = 34
end

local function beginSection(name: string, color: Color)
	if slot > 0 then
		currentRow += math.ceil(slot / 12)
	end
	slot = 0
	sectionOffset += 14
	sectionName = name
	sectionColor = color
	section = make("Folder", name, gallery)
	local z = -930 + currentRow * 112 + sectionOffset
	local board = part(name, displays, Vector3.new(116, 1, 10), CFrame.new(840, 1.5, z), color)
	label(board, string.gsub(name, "%-", " "), Enum.NormalId.Top)
end

local function add(
	title: string,
	description: string,
	source: RInstance,
	settings: Settings?,
	size: Vector?,
	generatorSource: string?
)
	local x: number
	local z: number
	repeat
		x = -704 + (slot % 12) * 128
		z = -930 + (currentRow + math.floor(slot / 12)) * 112 + sectionOffset
		slot += 1
	until not (x > -450 and x < 50 and z > 100 and z < 350)
	assert(z < 970, "Gallery exceeds the existing baseplate")
	local id = string.format("%03d", #entries + 1)
	local name = id .. "-" .. title
	local instance = make("ProceduralModel", name, section)
	local dimensions = size or Vector3.new(72, 36, 56)
	local attributes = table.clone(defaults)
	attributes.SourcePath = sourcePath(source)
	if settings then
		local settingsByName = (settings :: any) :: { [string]: Attribute? }
		for key, value in settingsByName do
			if value ~= nil then
				attributes[key] = value
			end
		end
	end
	for key, value in attributes do
		instance:SetAttribute(key, value)
	end
	instance:SetAttribute("DemoDescription", description)
	instance:SetAttribute("DemoSection", sectionName)
	local raised = string.find(sectionName, "pivots", 1, true) ~= nil
	local height = if raised then 40 else dimensions.Y / 2 + 2
	instance.Size = dimensions
	instance.WorldPivotData = CFrame.new(x, height, z)
	instance.NeedsPivotMigration = false
	local module = make("ModuleScript", "Generator", instance)
	module.Source = generatorSource or normalGenerator
	instance.Generator = module
	instance.Dirty = true
	local display = make("Folder", name, displays)
	part("Platform", display, Vector3.new(116, 1, 86), CFrame.new(x, 0.5, z), Color3.fromRGB(35, 43, 54))
	local caption = part("Caption", display, Vector3.new(116, 0.3, 15), CFrame.new(x, 1.2, z + 35), sectionColor)
	label(caption, id .. "  " .. string.gsub(title, "%-", " ") .. "\n" .. description, Enum.NormalId.Top)
	if raised then
		local line = part("OriginHeight", display, Vector3.new(100, 0.15, 0.15), CFrame.new(x, height, z), sectionColor)
		line.CanCollide = false
		local marker =
			part("Origin", display, Vector3.one * 0.8, CFrame.new(x, height, z), Color3.fromRGB(255, 215, 90))
		marker.Shape = Enum.PartType.Ball
		marker.CanCollide = false
	end
	local settingsText: { [string]: string } = {}
	for key, value in attributes do
		settingsText[key] = tostring(value)
	end
	table.insert(entries, {
		Id = id,
		Title = title,
		Description = description,
		Section = sectionName,
		InstancePath = "game.Workspace." .. instance:GetFullName(),
		SourcePath = attributes.SourcePath :: string,
		Position = { x, height, z },
		Settings = settingsText,
	})
end

beginSection("01-source-collections", Color3.fromRGB(42, 126, 98))
for _, path in
	{
		"rock.boulder",
		"rock.stone",
		"vegetation.tree.full",
		"vegetation.tree.partial",
		"vegetation.bush",
		"vegetation.grass",
		"vegetation.lilypad",
		"vegetation.mushroom",
		"vegetation.plant",
		"ruin.pillar",
	}
do
	add(
		string.gsub(path, "[.]", "-"),
		"Folder selection from the original source collection.",
		findSource("game.ReplicatedStorage.lib." .. path),
		{
			GeneratedCount = NumberRange.new(16),
			RandomPan = NumberRange.new(-180, 180),
			GeneratedExcludedTags = if path == "vegetation.tree.full" then "HD" else "",
		}
	)
end
add("direct-part", "One MeshPart, addressed directly.", pillar)
add("direct-model", "One multi-part birch Model, addressed directly.", birch)

beginSection("02-placement-and-alignment", Color3.fromRGB(58, 112, 172))
for _, placement in { "Grid", "Line", "Random" } do
	for _, alignment in { "Floor", "Center" } do
		add(
			string.lower(placement .. "-" .. alignment),
			if alignment == "Center"
				then "Center pivot; 3D cells for Grid and Random."
				else "Bottom pivot; X/Z cells or an X-axis line.",
			library.ruin.pillar,
			{
				RandomPlacement = placement,
				GeneratedAlignment = alignment,
				GeneratedCount = NumberRange.new(12),
				GeneratedPivotMethod = if alignment == "Center" then "Center" else "Bottom",
			},
			Vector3.new(84, 42, 56)
		)
	end
end

beginSection("03-pivots-and-source-scales", Color3.fromRGB(128, 88, 164))
for _, entry in pivotFixtures do
	for _, method in pivotMethods do
		add(entry.Name .. "-" .. method, entry.Note .. " Gold marker = solved origin.", entry.Source, {
			GeneratedAlignment = "Center",
			GeneratedPivotMethod = method,
			GeneratedScaleMethod = "Fill",
			GeneratedPadding = UDim.new(0, 0),
		}, Vector3.new(32, 24, 32))
	end
end

beginSection("04-scale-methods-and-references", Color3.fromRGB(168, 109, 48))
for _, template in { { Name = "part", Source = pillar }, { Name = "model", Source = unitModel } } do
	for _, method in { "Stretch", "Fit", "Fill" } do
		for _, reference in { "Height", "Min", "Max", "Average" } do
			add(
				template.Name .. "-" .. method .. "-" .. reference,
				if method == "Stretch" and template.Name == "part"
					then "Stretch uses part-local dimensions; scale reference is ignored."
					else "Compare uniform scaling against the same target dimensions.",
				template.Source,
				{ GeneratedScaleMethod = method, GeneratedScaleReference = reference },
				Vector3.new(30, 40, 24)
			)
		end
	end
end

beginSection("05-seeds-ranges-and-rotations", Color3.fromRGB(162, 73, 102))
for index, seed in { 42, 42, 99 } do
	add(
		`seed-{seed}-{index}`,
		"The first two panels share all inputs; the third changes only RandomSeed.",
		library.vegetation.mushroom,
		{
			RandomSeed = seed,
			GeneratedCount = NumberRange.new(16),
			RandomPlacement = "Random",
			RandomPan = NumberRange.new(-180, 180),
			RandomScale = NumberRange.new(0.6, 1.4),
		}
	)
end
for _, multiplier in { 0.5, 1, 1.5 } do
	add("uniform-scale-" .. tostring(multiplier), "RandomScale is applied after fitting.", unitModel, {
		GeneratedScaleMethod = "Fill",
		RandomScale = NumberRange.new(multiplier),
	}, Vector3.new(28, 24, 28))
end
for _, axis in { "Roll", "Pan", "Tilt", "All" } do
	add("random-" .. string.lower(axis), "Roll = X, Pan = Y, Tilt = Z; angles are degrees.", pillar, {
		GeneratedAlignment = "Center",
		GeneratedPivotMethod = "Center",
		GeneratedCount = NumberRange.new(12),
		RandomRoll = if axis == "Roll" or axis == "All" then NumberRange.new(-35, 35) else NumberRange.new(0),
		RandomPan = if axis == "Pan" or axis == "All" then NumberRange.new(-180, 180) else NumberRange.new(0),
		RandomTilt = if axis == "Tilt" or axis == "All" then NumberRange.new(-35, 35) else NumberRange.new(0),
	})
end
add("random-scale-range", "Each copy samples a multiplier from 0.5 to 1.5.", library.vegetation.bush, {
	GeneratedCount = NumberRange.new(20),
	RandomScale = NumberRange.new(0.5, 1.5),
})
add(
	"count-range",
	"Inclusive seeded integer count from 8 to 20.",
	library.vegetation.mushroom,
	{ GeneratedCount = NumberRange.new(8, 20) }
)
add("zero-count", "Intentionally empty: GeneratedCount = 0.", pillar, { GeneratedCount = NumberRange.new(0) })
add(
	"cooperative-pauses",
	"144 grass copies; PauseInterval = 8.",
	library.vegetation.grass,
	{ GeneratedCount = NumberRange.new(144), PauseInterval = 8 }
)

beginSection("06-padding-filtering-and-paths", Color3.fromRGB(45, 136, 151))
for _, gap in
	{
		{ Name = "none", Value = UDim.new(0, 0) },
		{ Name = "proportional", Value = UDim.new(0.2, 0) },
		{ Name = "studs", Value = UDim.new(0, 2) },
		{ Name = "combined", Value = UDim.new(0.1, 1) },
	}
do
	add("padding-" .. gap.Name, "Same 12-copy Fill grid; compare the gaps between copies.", library.vegetation.bush, {
		GeneratedCount = NumberRange.new(12),
		GeneratedScaleMethod = "Fill",
		GeneratedPadding = gap.Value,
	})
end
add(
	"include-HD",
	"Original folder includes HD birch Models and MeshParts.",
	library.vegetation.tree.full,
	{ GeneratedCount = NumberRange.new(12) }
)
add("exclude-HD", "Same seed and source; HD candidates are skipped.", library.vegetation.tree.full, {
	GeneratedCount = NumberRange.new(12),
	GeneratedExcludedTags = "HD",
})
add(
	"nested-selection",
	"Includes templates inside nested folders and the tagged subtree.",
	selection,
	{ GeneratedCount = NumberRange.new(16) }
)
add("exclude-subtree", "Comma-delimited tags; excluded folders also exclude their descendants.", selection, {
	GeneratedCount = NumberRange.new(16),
	GeneratedExcludedTags = " DemoHidden, HD ",
})
add("slash-delimiter", "SourcePath uses / between names, without mesh-name ambiguity.", pivotPart, {
	SourcePath = string.gsub(sourcePath(pivotPart), "[.]", "/"),
	SourcePathDelimiter = "/",
})
add("pipe-delimiter", "SourcePath uses | between names.", unitModel, {
	SourcePath = string.gsub(sourcePath(unitModel), "[.]", "|"),
	SourcePathDelimiter = "|",
})
add("immediate-source", "Existing local source with SourceMaxYield = 0.", pillar, { SourceMaxYield = 0 })
add(
	"random-forces-fit",
	"Random placement selects Fit even when GeneratedScaleMethod requests Fill.",
	library.vegetation.mushroom,
	{
		RandomPlacement = "Random",
		GeneratedCount = NumberRange.new(12),
		GeneratedScaleMethod = "Fill",
	}
)

beginSection("07-source-attribute-overrides", Color3.fromRGB(120, 125, 55))
local overrides = make("Folder", "Overrides", fixtures)
local function overrideExample(
	name: string,
	description: string,
	original: RInstance,
	sourceAttributes: Settings,
	settings: Settings?
)
	local source = fixture(original, name, overrides)
	for key, value in sourceAttributes do
		source:SetAttribute(key, value)
	end
	add(name, description, source, settings)
end
overrideExample(
	"template-count",
	"Source GeneratedCount = 4 overrides the requested count of 12.",
	pillar,
	{ GeneratedCount = NumberRange.new(4) },
	{ GeneratedCount = NumberRange.new(12) }
)
local countFolder = make("Folder", "CountFolder", overrides)
local countSource = fixture(pillar, "Pillar", countFolder)
countSource:SetAttribute("GeneratedCount", NumberRange.new(3))
add(
	"folder-template-count",
	"A selected template's override sets its total to 3, despite 12 draws.",
	countFolder,
	{ GeneratedCount = NumberRange.new(12) }
)
overrideExample(
	"template-pivot",
	"Source PrimaryPartCenter overrides the requested Bottom pivot.",
	pivotSources.PrimaryUnit,
	{ GeneratedPivotMethod = "PrimaryPartCenter" },
	{ GeneratedAlignment = "Center", GeneratedPivotMethod = "Bottom" }
)
overrideExample(
	"template-alignment",
	"Direct source Center alignment overrides requested Floor.",
	pillar,
	{ GeneratedAlignment = "Center" },
	{ GeneratedAlignment = "Floor", GeneratedCount = NumberRange.new(9), GeneratedPivotMethod = "Center" }
)
overrideExample(
	"template-fit",
	"Source Fit overrides requested Fill; this small pillar stays small.",
	pillar,
	{ GeneratedScaleMethod = "Fit" },
	{ GeneratedScaleMethod = "Fill" }
)
overrideExample(
	"template-random-scale",
	"Source RandomScale = 0.5 overrides the requested 1.5.",
	unitModel,
	{ RandomScale = NumberRange.new(0.5) },
	{ RandomScale = NumberRange.new(1.5), GeneratedScaleMethod = "Fill" }
)
overrideExample(
	"template-rotations",
	"Source overrides roll, pan, and tilt ranges.",
	pillar,
	{ RandomRoll = NumberRange.new(-15, 15), RandomPan = NumberRange.new(90), RandomTilt = NumberRange.new(-15, 15) },
	{ GeneratedCount = NumberRange.new(9) }
)
overrideExample(
	"template-pause",
	"Source PauseInterval = 1; 64 copies pause cooperatively.",
	library.vegetation.grass:GetChildren()[1],
	{ PauseInterval = 1 },
	{ GeneratedCount = NumberRange.new(64) }
)
local _, partSize = getExtents(pillar)
overrideExample(
	"part-size-override",
	"Source Size attribute is twice its geometry, so fitting leaves more space.",
	pillar,
	{ Size = partSize * 2 },
	{ GeneratedScaleMethod = "Fill" }
)
local _, modelSize = getExtents(pivotSources.ModelTriple)
overrideExample(
	"scaled-model-size-override",
	"Source scale = 3. Size override is authored at scale 1.",
	pivotSources.ModelTriple,
	{ Size = modelSize * 2 / 3 },
	{ GeneratedScaleMethod = "Fill" }
)
for _, source in { pivotSources.ModelQuarter, pivotSources.PrimaryTriple } do
	overrideExample(
		"final-offset-" .. source.Name,
		"Offset = 6 studs, then 30-degree Y rotation; translation is not rescaled.",
		source,
		{ PivotOffset = CFrame.new(6, 0, 0) * CFrame.Angles(0, math.rad(30), 0) },
		{ GeneratedScaleMethod = "Fill", GeneratedCount = NumberRange.new(3), RandomScale = NumberRange.new(0.7, 1.3) }
	)
end

beginSection("08-custom-callbacks", Color3.fromRGB(165, 91, 51))
local function callbackSource(defaultFields: string, attributeType: string, body: string): string
	return string.format(
		[[--!strict
local Package = game.ReplicatedStorage.Packages.ProceduralPackage
local Generator = require(Package.Generator)
local Types = require(Package.Types)
return Generator.append({ %s }, function(
	instance: Types.Template,
	parameters: Types.GenerationFunctionParams<Types.PackageAttributes & { %s }>,
	_targetContainer: GeneratedFolder
)
	local function apply(part: BasePart)
		%s
	end
	if instance:IsA("BasePart") then apply(instance) end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then apply(descendant) end
	end
end)
]],
		defaultFields,
		attributeType,
		body
	)
end
local tintGenerator =
	callbackSource("Tint = Color3.fromRGB(70, 165, 230)", "Tint: Color3", "part.Color = parameters.Attributes.Tint")
add(
	"append-color",
	"Generator.append exposes a Tint attribute and recolors generated MeshParts.",
	pillar,
	{ GeneratedCount = NumberRange.new(9), Tint = Color3.fromRGB(70, 165, 230) },
	nil,
	tintGenerator
)
add(
	"append-model-descendants",
	"The callback recolors every BasePart inside a multi-part Model.",
	unitModel,
	{ Tint = Color3.fromRGB(210, 125, 70) },
	nil,
	tintGenerator
)
add(
	"append-transparency",
	"Custom Transparency attribute is applied after scale and placement.",
	pillar,
	{ GeneratedCount = NumberRange.new(9), Transparency = 0.45 },
	nil,
	callbackSource(
		"Transparency = 0.45",
		"Transparency: number",
		"part.Transparency = parameters.Attributes.Transparency"
	)
)
local tintedSource = fixture(pillar, "TintOverride", overrides)
tintedSource:SetAttribute("Tint", Color3.fromRGB(175, 90, 220))
add(
	"append-source-override",
	"Source Tint overrides the blue package default for a direct source.",
	tintedSource,
	{ GeneratedCount = NumberRange.new(9), Tint = Color3.fromRGB(70, 165, 230) },
	nil,
	tintGenerator
)

local welcome = part(
	"GalleryGuide",
	displays,
	Vector3.new(76, 24, 1),
	CFrame.lookAt(Vector3.new(840, 15, -60), Vector3.new(0, 15, 0)),
	Color3.fromRGB(30, 43, 62)
)
label(
	welcome,
	`PROCEDURAL PACKAGE\n{#entries} LIVE EXAMPLES\n8 color-coded sections\nSelect a numbered ProceduralModel and edit its attributes.\nGold markers show the shared origin in pivot comparisons.\nThe original four examples remain in place.`,
	Enum.NormalId.Front
)

-- Validate the serialized artifacts before replacing either file.
local libraryBytes = roblox.serializeModel({ library })
local examplesBytes = roblox.serializeModel({ examples })
local savedLibrary = roblox.deserializeModel(libraryBytes)[1] :: RInstance
local savedExamples = roblox.deserializeModel(examplesBytes)[1] :: RInstance
assert(#savedExamples:GetChildren() == 5, "Expected the four original examples plus Gallery")
local validated = 0
for _, instance in descendants(savedExamples.Gallery) do
	if not instance:IsA("ProceduralModel") then
		continue
	end
	assert(instance.Dirty == true and instance.Generator and instance.Generator.Parent == instance)
	assert(instance.Generator.Source:sub(1, 9) == "--!strict")
	assert(instance.Size.X > 0 and instance.Size.Y > 0 and instance.Size.Z > 0)
	local source = findSource(instance:GetAttribute("SourcePath"), instance:GetAttribute("SourcePathDelimiter"))
	assert(source:IsA("Model") or source:IsA("BasePart") or source:IsA("Folder"))
	assert(table.find(pivotMethods, instance:GetAttribute("GeneratedPivotMethod")))
	validated += 1
end
assert(validated == #entries, "Serialized example count changed")
for _, entry in pivotFixtures do
	if entry.Source:IsA("Model") then
		local saved = savedLibrary.DemoSources.Pivots:FindFirstChild(entry.Source.Name)
		assert(saved and saved.Scale == entry.Source.Scale)
		assert((saved.PrimaryPart ~= nil) == (entry.Source.PrimaryPart ~= nil))
	end
end
local manifest = serde.encode("json", {
	ExampleCount = #entries,
	OriginalExampleCount = 4,
	Sections = 8,
	Regeneration = "New ProceduralModels have Dirty=true and their native Generator property assigned; Studio generates the results.",
	Examples = entries,
}, true)
fs.writeFile(LIBRARY_PATH, libraryBytes)
fs.writeFile(EXAMPLES_PATH, examplesBytes)
fs.writeFile("demo/gallery.json", manifest .. "\n")
print(`Saved {#entries} new live examples in 8 sections; preserved the original four examples.`)
print("Verified serialized generator references, source paths, pivot methods, PrimaryParts, and Model scales.")
