--!strict
local roblox = require("@lune/roblox")
local makeLoader = require("./lib/load-package")
type RInstance = roblox.Instance & { [string]: any }
local data = (
	roblox :: any
) :: { CFrame: typeof(CFrame), Vector3: typeof(Vector3), NumberRange: typeof(NumberRange), UDim: typeof(UDim) }
local CFrame, Vector3, NumberRange, UDim = data.CFrame, data.Vector3, data.NumberRange, data.UDim

-- Engine transform adapters, including off-center Models with and without PrimaryParts.
local function bounds(instance: RInstance): (CFrame, Vector3)
	if instance:IsA("BasePart") then
		local cf = instance.CFrame
		return cf,
			cf.RightVector:Abs() * instance.Size.X
				+ cf.UpVector:Abs() * instance.Size.Y
				+ cf.ZVector:Abs() * instance.Size.Z
	end
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, child in instance:GetDescendants() :: { RInstance } do
		if child:IsA("BasePart") then
			local cf, size = bounds(child)
			low, high = low:Min(cf.Position - size / 2), high:Max(cf.Position + size / 2)
		end
	end
	return CFrame.new((low + high) / 2), high - low
end
local function pivot(instance: RInstance): CFrame
	if instance:IsA("BasePart") then
		return instance.CFrame * instance.PivotOffset
	end
	if instance.PrimaryPart then
		return pivot(instance.PrimaryPart)
	end
	return instance.WorldPivotData or (bounds(instance))
end
local function pivotTo(instance: RInstance, frame: CFrame)
	if instance:IsA("BasePart") then
		instance.CFrame = frame * instance.PivotOffset:Inverse()
		return
	end
	local delta = frame * pivot(instance):Inverse()
	for _, child in instance:GetDescendants() :: { RInstance } do
		if child:IsA("BasePart") then
			child.CFrame = delta * child.CFrame
		end
	end
	instance.WorldPivotData = frame
end
for _, class in { "Model", "BasePart" } do
	roblox.implementMethod(class, "GetPivot", pivot)
	roblox.implementMethod(class, "PivotTo", pivotTo)
end
roblox.implementProperty("Model", "WorldPivot", pivot, function(instance: RInstance, frame: CFrame)
	instance.WorldPivotData = frame
end)
roblox.implementMethod("Model", "GetBoundingBox", bounds)
roblox.implementMethod("Model", "GetScale", function(instance: RInstance)
	return instance.Scale
end)
roblox.implementMethod("Model", "ScaleTo", function(instance: RInstance, scale: number)
	local factor, cf = scale / instance.Scale, pivot(instance)
	for _, part in instance:GetDescendants() :: { RInstance } do
		if not part:IsA("BasePart") then
			continue
		end
		local relative = cf:ToObjectSpace(part.CFrame)
		part.CFrame = cf * CFrame.new(relative.Position * factor) * relative.Rotation
		part.Size *= factor
		part.PivotOffset = CFrame.new(part.PivotOffset.Position * factor) * part.PivotOffset.Rotation
	end
	instance.Scale = scale
end)
local function random(seed: number)
	local state = seed + 1
	local function unit(): number
		state = (state * 16807 + 1) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_self: unknown, low: number, high: number): number
			return low + unit() * (high - low)
		end,
		NextInteger = function(_self: unknown, low: number, high: number): number
			return low + math.floor(unit() * (high - low + 1))
		end,
	}
end
local template = roblox.Instance.new("Part") :: RInstance
template.Size, template.Name = Vector3.new(2, 3, 5), "SourceA"
local source: RInstance = template
local queryCount, lookups, callbacks, pauses = 0, 0, 0, 0
local behavior = "normal"
local ownerFrame = CFrame.new(15, 8, -9) * CFrame.Angles(0, 0.4, 0)
local ownerScale = 2
local owner = {
	GetAttribute = function()
		return nil
	end,
	GetPivot = function()
		return ownerFrame
	end,
	GetScale = function()
		return ownerScale
	end,
	AttributeChanged = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	},
	Destroying = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	},
}
local function intersects(cf: CFrame, size: Vector3, other: CFrame, otherSize: Vector3): boolean
	local relative = cf:ToObjectSpace(other)
	local extent = (
		relative.RightVector:Abs() * otherSize.X
		+ relative.UpVector:Abs() * otherSize.Y
		+ relative.ZVector:Abs() * otherSize.Z
		+ size
	) / 2
	local delta = relative.Position:Abs()
	return delta.X < extent.X - 0.0001 and delta.Y < extent.Y - 0.0001 and delta.Z < extent.Z - 0.0001
end
local lastFrame, lastSize = CFrame.identity, Vector3.zero
local world = {
	HasTag = function()
		return false
	end,
	GetPartBoundsInBox = function(_self: unknown, cf: CFrame, size: Vector3, params: any): { RInstance }
		queryCount += 1
		lastFrame, lastSize = cf, size
		assert(
			params.FilterType == roblox.Enum.RaycastFilterType.Include and #params.FilterDescendantsInstances == 1,
			"query must restrict itself to the target"
		)
		if behavior == "blocked" or behavior == "reject-first" and queryCount == 1 then
			return { template }
		end
		local matches = {}
		for _, part in params.FilterDescendantsInstances[1]:GetDescendants() :: { RInstance } do
			if not part:IsA("BasePart") then
				continue
			end
			local other = ownerFrame * CFrame.new(part.CFrame.Position * ownerScale) * part.CFrame.Rotation
			if intersects(cf, size, other, part.Size * ownerScale) then
				table.insert(matches, part)
			end
		end
		return matches
	end,
}
local custom: any = nil
local moduleRef = {
	ModulePath = "checks/random-solver",
	IsA = function(_self: unknown, name: string): boolean
		return name == "ModuleScript"
	end,
}
local load = makeLoader({ Random = { new = random }, workspace = world }, {
	IndexUtil = {
		waitForPath = function(path: string): any
			if path == "solver" then
				lookups += 1
				return moduleRef
			end
			return source
		end,
	},
	["checks/random-solver"] = setmetatable({}, {
		__index = function(_self: unknown, key: string): any
			return custom[key]
		end,
	}),
})
local Parameters, Generator, Geometry = load("src/ParameterUtil"), load("src/Generator"), load("src/GeometryUtil")
custom = table.clone(load("src/CastSolver"))
local definition = Generator.append({ Label = "area" }, function()
	callbacks += 1
end, owner)
local function parameters(count: number): any
	local attributes = Parameters.getDefaults({ Label = "area" }, "Random")
	attributes.Source_Path, attributes.Source_ScaleMethod, attributes.Source_PivotMethod = "source", "Stretch", "Bottom"
	attributes.Source_Padding, attributes.Layout_PopulationLimit = UDim.new(0), NumberRange.new(count)
	return Parameters.resolve({
		Attributes = attributes,
		Size = Vector3.new(40, 24, 30),
		Pause = function()
			pauses += 1
		end,
	})
end
local function generate(p: any): { RInstance }
	local target = roblox.Instance.new("Folder")
	definition.OnGenerate(p, target)
	local output = target:GetChildren() :: { RInstance }
	for _, copy in output do
		copy.Parent = nil
	end
	target:Destroy()
	return output
end
local function cleanup(output: { RInstance })
	for _, copy in output do
		copy:Destroy()
	end
end
local function inside(copy: RInstance, region: Vector3)
	local cf, size = Geometry.getBounds(copy)
	local edge = cf.Position:Abs() + size / 2
	assert(
		edge.X <= region.X / 2 + 0.001 and edge.Y <= region.Y / 2 + 0.001 and edge.Z <= region.Z / 2 + 0.001,
		`escaped volume: {edge}/{region}; center {cf.Position}; bounds {size}`
	)
end

-- Population affects count, never source size, and no disabled overlap path resolves a solver.
for _, count in { 0, 1, 12, 120 } do
	local p = parameters(count)
	p.Attributes.Solver_Cast_Path = "unused-solver"
	local output = generate(p)
	assert(#output == count and queryCount == 0 and lookups == 0)
	for _, copy in output do
		assert((copy.Size - template.Size).Magnitude < 0.001)
		inside(copy, p.Size)
	end
	cleanup(output)
end

-- Uniform independent centers fill all axes without boundary clamping spikes or a hidden grid.
local p = parameters(4000)
p.Attributes.Random_Seed = 2026
local output = generate(p)
local bins = { table.create(10, 0), table.create(10, 0), table.create(10, 0) }
local octants = table.create(8, 0)
local mean, squares = Vector3.zero, Vector3.zero
local available = p.Size - template.Size
for _, copy in output do
	inside(copy, p.Size)
	local sample = copy.CFrame.Position / available
	mean += sample
	squares += sample * sample
	for axis, value in { sample.X, sample.Y, sample.Z } do
		assert(math.abs(value) < 0.5, "clamping piled copies against a volume boundary")
		local bin = math.clamp(math.floor((value + 0.5) * 10) + 1, 1, 10)
		bins[axis][bin] += 1
	end
	local octant = 1
		+ (if sample.X >= 0 then 1 else 0)
		+ (if sample.Y >= 0 then 2 else 0)
		+ (if sample.Z >= 0 then 4 else 0)
	octants[octant] += 1
end
assert((mean / #output).Magnitude < 0.025, "distribution has a directional bias")
assert((squares / #output - Vector3.one / 12).Magnitude < 0.015, "distribution has the wrong variance")
for _, axis in bins do
	for _, count in axis do
		assert(count > 300 and count < 500, "uneven decile occupancy")
	end
end
for _, count in octants do
	assert(count > 400 and count < 600, "uneven octant occupancy")
end
cleanup(output)

-- Native pivots, axis overrides, random rotations/scales, and final PivotOffset remain contained.
template.PivotOffset = CFrame.new(3, -2, 7) * CFrame.Angles(0.2, 0.6, -0.3)
template:SetAttribute("PivotOffset", CFrame.new(12, -8, 6) * CFrame.Angles(0.5, -0.8, 0.4))
for _, axis in { "X", "Y", "Z" } do
	p = parameters(30)
	p.Size = Vector3.new(9, 6, 11)
	p.Attributes.Layout_HeightAxis, p.Attributes.Source_PivotMethod = axis, "Pivot"
	p.Attributes.Random_Roll, p.Attributes.Random_Pan, p.Attributes.Random_Tilt =
		NumberRange.new(-180, 180), NumberRange.new(-180, 180), NumberRange.new(-180, 180)
	p.Attributes.Random_Scale, p.Attributes.Source_Padding = NumberRange.new(0.3, 5), UDim.new(0.1, 1)
	local a, b = generate(p), generate(p)
	assert(#a == 30 and #b == 30)
	local region = (p.Size - Vector3.one * 2) * 0.8
	for index, copy in a do
		inside(copy, region)
		assert(copy.CFrame == b[index].CFrame and copy.Size == b[index].Size, "seed was not repeatable")
	end
	cleanup(a)
	cleanup(b)
end
template.PivotOffset = CFrame.identity
template:SetAttribute("PivotOffset", nil)

-- World-space internal overlap queries respect the owner transform and scale, retrying before acceptance.
p = parameters(1)
p.Attributes.Layout_AvoidOverlap, p.Attributes.Layout_PlacementAttempts = true, 5
queryCount, behavior = 0, "reject-first"
local before = callbacks
output = generate(p)
assert(#output == 1 and queryCount == 2 and callbacks == before + 1, "rejected candidate was not retried")
local expected = ownerFrame * CFrame.new(output[1].CFrame.Position * ownerScale) * output[1].CFrame.Rotation
assert(
	(expected.Position - lastFrame.Position).Magnitude < 0.001
		and (lastSize - output[1].Size * ownerScale).Magnitude < 0.001,
	"overlap geometry was not converted to world space"
)
cleanup(output)

-- A packed volume skips exhausted copies without callbacks, and cooperatively pauses during retries.
p = parameters(3)
p.Attributes.Layout_AvoidOverlap, p.Attributes.Layout_PlacementAttempts, p.Attributes.Layout_PauseInterval = true, 5, 2
queryCount, behavior = 0, "blocked"
before = callbacks
local previousPauses = pauses
output = generate(p)
assert(
	#output == 0 and queryCount == 15 and callbacks == before and pauses > previousPauses,
	"attempt limit or rejected-copy cleanup failed"
)

-- Accepted copies become visible to subsequent queries; overlap-enabled generations are deterministic.
p = parameters(50)
p.Size = Vector3.new(20, 15, 20)
p.Attributes.Layout_AvoidOverlap = true
queryCount, behavior = 0, "normal"
local a, b = generate(p), generate(p)
assert(#a > 10 and #a == #b and queryCount > #a)
for index, copy in a do
	assert(copy.CFrame == b[index].CFrame, "collision retries are not deterministic")
	for other = 1, index - 1 do
		assert(not intersects(copy.CFrame, copy.Size, a[other].CFrame, a[other].Size), "overlapping copy survived")
	end
end
cleanup(a)
cleanup(b)

-- Custom solvers use the same internal query contract and resolve once per generation.
local customCalls = 0
custom.getPartBoundsInBox = function(
	model: unknown,
	scoped: any,
	target: RInstance,
	internal: boolean,
	cf: CFrame,
	size: Vector3
)
	assert(model == owner and internal and target:IsA("Folder") and scoped.Attributes.Layout_Type == "Random")
	assert(typeof(cf) == "CFrame" and size == template.Size * ownerScale)
	customCalls += 1
	return {}
end
p = parameters(3)
p.Attributes.Layout_AvoidOverlap, p.Attributes.Solver_Cast_Path = true, "solver"
local previousLookups = lookups
output = generate(p)
assert(#output == 3 and customCalls == 3 and lookups == previousLookups + 1)
cleanup(output)

-- Multi-part sources keep their authored proportions and query per part, including PrimaryPart pivots.
local model = roblox.Instance.new("Model") :: RInstance
local first, second = template:Clone() :: RInstance, template:Clone() :: RInstance
first.Size, first.CFrame, first.Parent = Vector3.new(2, 6, 2), CFrame.new(-3, 0, 0), model
second.Size, second.CFrame, second.Parent = Vector3.new(2, 2, 2), CFrame.new(3, 3, 0), model
model.WorldPivotData = CFrame.new(12, -9, 3)
source = model
custom.getPartBoundsInBox = function(_owner: unknown, _scoped: any, _target: unknown, internal: boolean)
	assert(internal)
	customCalls += 1
	return {}
end
for _, primary in { false, true } do
	if primary then
		model.PrimaryPart = first
	end
	p = parameters(7)
	p.Attributes.Layout_AvoidOverlap, p.Attributes.Solver_Cast_Path, p.Attributes.Source_PivotMethod =
		true, "solver", "Pivot"
	local previousCalls = customCalls
	output = generate(p)
	assert(#output == 7 and customCalls == previousCalls + 14, "model was queried as a single enclosing box")
	for _, copy in output do
		inside(copy, p.Size)
	end
	cleanup(output)
end
source = template
model:Destroy()

-- Mixed-source overrides do not leak or size small copies according to the largest source.
local folder = roblox.Instance.new("Folder") :: RInstance
template.Parent = folder
local larger = template:Clone() :: RInstance
larger.Name, larger.Size, larger.Parent = "SourceB", Vector3.new(4, 6, 8), folder
larger:SetAttribute("Layout_HeightAxis", "X")
larger:SetAttribute("Random_Scale", NumberRange.new(0.5))
source = folder
p = parameters(60)
output = generate(p)
local selected: { [string]: boolean } = {}
for _, copy in output do
	selected[copy.Name] = true
	assert(
		(copy.Size - (if copy.Name == "SourceA" then Vector3.new(2, 3, 5) else Vector3.new(2, 3, 4))).Magnitude < 0.001,
		"mixed sources changed each other's size"
	)
	inside(copy, p.Size)
end
assert(selected.SourceA and selected.SourceB)
cleanup(output)
folder:Destroy()
print(
	"Verified uniform 3D distribution, authored proportions, count-independent sizes, padding, pivots, axes, random transforms, model parts, mixed sources, deterministic overlap retries, query transforms/filters, custom solvers, bounded exhaustion, and cleanup."
)
