--!strict
-- Production-module smoke checks in Lune. World queries and the engine RNG are adapters.
local roblox = require("@lune/roblox")
local makeLoader = require("./lib/load-package")
type RInstance = roblox.Instance & { [string]: any }
type Datatypes = {
	CFrame: typeof(CFrame),
	Vector3: typeof(Vector3),
	NumberRange: typeof(NumberRange),
	Color3: typeof(Color3),
	UDim: typeof(UDim),
}
local datatypes = (roblox :: any) :: Datatypes
local CFrame, Vector3 = datatypes.CFrame, datatypes.Vector3
local NumberRange, Color3, UDim = datatypes.NumberRange, datatypes.Color3, datatypes.UDim

roblox.implementMethod("BasePart", "GetPivot", function(part: RInstance): CFrame
	return part.CFrame * part.PivotOffset
end)
roblox.implementMethod("BasePart", "PivotTo", function(part: RInstance, frame: CFrame)
	part.CFrame = frame * part.PivotOffset:Inverse()
end)

local function random(seed: number)
	local state = seed % 2147483647
	local function nextUnit(): number
		state = (state * 16807 + 1) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_self: unknown, minimum: number, maximum: number): number
			return minimum + nextUnit() * (maximum - minimum)
		end,
		NextInteger = function(_self: unknown, minimum: number, maximum: number): number
			return minimum + math.floor(nextUnit() * (maximum - minimum + 1))
		end,
		Shuffle = function<T>(_self: unknown, array: { T })
			for index = #array, 2, -1 do
				local other = 1 + math.floor(nextUnit() * index)
				array[index], array[other] = array[other], array[index]
			end
		end,
	}
end

local source = roblox.Instance.new("Folder") :: RInstance
local template = roblox.Instance.new("Part") :: RInstance
template.Name = "Template"
template.Size = Vector3.new(4, 6, 4)
template.Parent = source
local queryHit = true
local world = {
	HasTag = function(_self: unknown, _tag: string): boolean
		return false
	end,
	Raycast = function(_self: unknown, start: Vector3, direction: Vector3, _params: unknown)
		return if queryHit then { Position = start + direction / 2 } else nil
	end,
	Shapecast = function(
		_self: unknown,
		_part: unknown,
		direction: Vector3,
		_params: unknown,
		_frame: CFrame,
		_size: Vector3
	)
		return if queryHit then { Distance = direction.Magnitude / 2 } else nil
	end,
}
local load = makeLoader({ Random = { new = random }, workspace = world }, {
	IndexUtil = {
		waitForPath = function(_path: string, _timeout: number, _delimiter: string)
			return source
		end,
	},
})
local Generator = load("src/Generator")
local ParameterUtil = load("src/ParameterUtil")
local SourceUtil = load("src/SourceUtil")
local Layouts = load("src/Layouts")
local pauses, callbacks = 0, 0
local definition = Generator.append(
	{ Tint = Color3.new(1, 0, 0) },
	function(instance: RInstance, parameters: any, _target: unknown)
		callbacks += 1
		instance.Color = parameters.Attributes.Tint
	end
)
local attributes = table.clone(definition.Attributes)
attributes.Source_Path = "fixture"
attributes.Source_PivotMethod = "Bottom"
attributes.Source_ScaleMethod = "Fit"
attributes.Source_Padding = UDim.new(0)
attributes.Layout_PauseInterval = 1
attributes.Layout_ColumnLimit = NumberRange.new(4)
attributes.Layout_RowLimit = NumberRange.new(3)
attributes.Layout_PopulationLimit = NumberRange.new(12)
attributes.Layout_CurveSize0 = 20
attributes.Layout_CurveSize1 = 20
local parameters = {
	Attributes = attributes,
	Size = Vector3.new(80, 24, 60),
	Pause = function(_self: unknown)
		pauses += 1
	end,
}
local function generate(): { RInstance }
	local target = roblox.Instance.new("Folder")
	definition.OnGenerate(parameters, target)
	return target:GetChildren() :: { RInstance }
end
local function expectFailure(fn: () -> (), message: string)
	local ok, problem = pcall(fn)
	assert(
		not ok and tostring(problem):find(message, 1, true),
		`expected error containing {message}, received {problem}`
	)
end

-- Swap every layout on the same definition and preserve its callback/custom defaults.
template:SetAttribute("Tint", Color3.new(0, 1, 0))
for _, kind in { "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine" } do
	attributes.Layout_Type = kind
	local before = callbacks
	local first = generate()
	assert(#first == (if kind == "Single" then 1 else 12), `wrong count for {kind}`)
	assert(callbacks - before == #first)
	local second = generate()
	for index, copy in first do
		assert(copy.Color == Color3.new(0, 1, 0), "callback did not receive source-scoped attributes")
		assert(copy.CFrame == second[index].CFrame, `non-deterministic {kind}`)
		assert(math.abs(copy:GetPivot().Y + parameters.Size.Y / 2) < 0.001, "Floor alignment lost")
	end
end
assert(pauses > 0, "generation did not pause cooperatively")
assert(attributes.Tint == Color3.new(1, 0, 0), "template overrides leaked into area attributes")

-- Direct and nested folder sources share overrides while excluding entire tagged subtrees.
assert(SourceUtil.getTemplates(template, parameters)[1] == template)
local hidden = roblox.Instance.new("Folder")
hidden.Name = "Hidden"
hidden:AddTag("Skip")
hidden.Parent = source
local hiddenPart = template:Clone()
hiddenPart.Parent = hidden
attributes.Source_ExcludedTags = "  Skip, , Other  "
local eligible = SourceUtil.getTemplates(source, parameters)
assert(#eligible == 1 and eligible[1] == template, "tagged source subtree was included")
hidden:Destroy()
attributes.Source_ExcludedTags = ""

-- A seed change alters random placement without changing its population.
attributes.Layout_Type = "SurfaceRandom"
local seeded = generate()
attributes.Random_Seed = 2026
local changed = generate()
assert(#seeded == #changed and seeded[1].CFrame ~= changed[1].CFrame)
attributes.Random_Seed = 0

-- Every surface layout uses Center alignment as one layer, not a 3D grid.
attributes.Source_Alignment = "Center"
attributes.Layout_Type = "SurfaceGrid"
for _, copy in generate() do
	assert(math.abs(copy:GetPivot().Y) < 0.001)
end
attributes.Source_Alignment = "Floor"

-- Cubic curve endpoints and midpoint, including Beam's signed handle behavior.
attributes.Layout_Type = "SurfaceCurvedLine"
attributes.Layout_PopulationLimit = NumberRange.new(3)
local cells = Layouts.SurfaceCurvedLine.GetCells(parameters, template.Size, random(1))
assert(math.abs(cells[1].Frame.Z) < 0.001 and math.abs(cells[3].Frame.Z) < 0.001)
assert(math.abs(cells[2].Frame.Z - 15) < 0.001, "cubic midpoint must be 3/8 of each handle")
attributes.Layout_CurveSize0, attributes.Layout_CurveSize1 = -20, -20
cells = Layouts.SurfaceCurvedLine.GetCells(parameters, template.Size, random(1))
assert(math.abs(cells[2].Frame.Z + 15) < 0.001, "negative handles should reverse the curve")
for _, count in { 0, 1 } do
	attributes.Layout_PopulationLimit = NumberRange.new(count)
	assert(#generate() == count)
end
attributes.Layout_Type = "SurfaceRandom"
for _, count in { 0, 1 } do
	attributes.Layout_PopulationLimit = NumberRange.new(count)
	assert(#generate() == count)
end

-- Inactive layout values are ignored until their layout is selected.
attributes.Layout_Type = "Single"
attributes.Layout_PopulationLimit = NumberRange.new(-2)
assert(#generate() == 1)
attributes.Layout_Type = "SurfaceRandom"
expectFailure(function()
	generate()
end, "Layout_PopulationLimit")
attributes.Layout_PopulationLimit = NumberRange.new(12)
attributes.Layout_Type = "invalid"
expectFailure(function()
	generate()
end, "Layout_Type")
attributes.Layout_Type = "Single"
attributes.Layout_PauseInterval = 0
expectFailure(function()
	generate()
end, "Layout_PauseInterval")
attributes.Layout_PauseInterval = 1
template:SetAttribute("Random_Scale", NumberRange.new(0))
expectFailure(function()
	generate()
end, "Random_Scale")
template:SetAttribute("Random_Scale", nil)
template:SetAttribute("Tint", 3)
expectFailure(function()
	generate()
end, "Tint")
template:SetAttribute("Tint", nil)
expectFailure(function()
	Generator.append({ Layout_Type = "Single" }, function() end)
end, "reserved")

-- Source-side layout attributes never alter the area's selected layout/count.
template:SetAttribute("Layout_Type", "Single")
attributes.Layout_Type = "SurfaceGrid"
assert(#generate() == 12)
attributes.Layout_ColumnLimit = NumberRange.new(2, 4)
attributes.Layout_RowLimit = NumberRange.new(2, 3)
assert(#generate() == 12, "natural grid dimensions were not clamped")

-- Both surface modes discard misses before invoking callbacks and still pause.
local owner = {
	GetPivot = function(_self: unknown)
		return CFrame.new(10, 0, 0)
	end,
	GetScale = function(_self: unknown)
		return 2
	end,
}
local surfaceGenerator = Generator.append(
	{ Tint = Color3.new(1, 0, 0) },
	function(_instance: unknown, _parameters: unknown, _target: unknown)
		callbacks += 1
	end,
	owner
)
for _, mode in { "Raycast", "Shapecast" } do
	attributes.Layout_SurfaceDetectionMethod = mode
	queryHit = false
	local before = callbacks
	local target = roblox.Instance.new("Folder")
	surfaceGenerator.OnGenerate(parameters, target)
	assert(#target:GetChildren() == 0, `misses survived {mode}`)
	assert(callbacks == before, `misses invoked callbacks for {mode}`)
	queryHit = true
	surfaceGenerator.OnGenerate(parameters, target)
	assert(#target:GetChildren() == 12, `hits were dropped by {mode}`)
end
ParameterUtil.validate(parameters)
print(
	"Verified all four layouts, swaps, deterministic transforms, Beam handles, callbacks, overrides, validation, zero/one populations, cooperative pauses, and surface hit/miss paths."
)
