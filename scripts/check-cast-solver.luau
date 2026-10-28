--!strict
-- Production query adapters and solver resolution, using observable WorldRoot stubs.
local roblox = require("@lune/roblox")
local makeLoader = require("./lib/load-package")
local datatypes = (roblox :: any) :: { Vector3: typeof(Vector3), CFrame: typeof(CFrame) }
local Vector3, CFrame = datatypes.Vector3, datatypes.CFrame
local Enum = roblox.Enum
local lastMethod = ""
local lastArgs: { any } = {}
local hit = { Distance = 5, Position = Vector3.new(1, 2, 3) }
local parts = { roblox.Instance.new("Part") }
local world: { [string]: any } = {}
world.HasTag = function(_self: unknown, _tag: string): boolean
	return false
end
for _, name in
	{
		"Raycast",
		"Spherecast",
		"Blockcast",
		"Shapecast",
		"GetPartBoundsInBox",
		"GetPartBoundsInRadius",
		"GetPartsInPart",
	}
do
	world[name] = function(self: unknown, ...: any): any
		assert(self == world)
		lastMethod, lastArgs = name, { ... }
		return if string.sub(name, 1, 3) == "Get" then parts else hit
	end
end
local moduleRef: any = nil
local lookups = 0
local load = makeLoader({ workspace = world }, {
	IndexUtil = {
		waitForPath = function(path: string, timeout: number, delimiter: string): any
			lookups += 1
			assert(path == "custom/casts" and timeout == 0 and delimiter == "/")
			return moduleRef
		end,
	},
	["checks/not-table"] = true,
	["checks/incomplete"] = {},
})
local Solver = load("src/CastSolver")
local Surface = load("src/SurfaceUtil")
local ParameterUtil = load("src/ParameterUtil")
local ENV = load("src/ENV")
ENV.DEFAULT_SOLVER_CAST_PATH = "custom/casts"
assert(ParameterUtil.getDefaults().Solver_Cast_Path == "custom/casts")
ENV.DEFAULT_SOLVER_CAST_PATH = ""
local parameters = ParameterUtil.resolve({
	Attributes = ParameterUtil.getDefaults(nil, "SurfaceGrid"),
	Size = Vector3.new(20, 10, 30),
	Pause = function() end,
})
local model, target = roblox.Instance.new("Model"), roblox.Instance.new("Folder")
local shape = roblox.Instance.new("Part")
local origin, direction = Vector3.new(1, 10, 3), Vector3.new(0, -20, 0)
local cf, size = CFrame.new(origin), Vector3.new(2, 3, 4)
local function excluded(params: any)
	assert(params.FilterType == Enum.RaycastFilterType.Exclude)
	assert(params.FilterDescendantsInstances[1] == model and params.FilterDescendantsInstances[2] == target)
end
local function included(params: any)
	assert(params.FilterType == Enum.RaycastFilterType.Include)
	assert(#params.FilterDescendantsInstances == 1 and params.FilterDescendantsInstances[1] == target)
end
assert(Surface.getSolver(parameters) == Solver and lookups == 0)
assert(Solver.raycast(model, parameters, target, false, origin, direction) == hit)
assert(lastMethod == "Raycast" and lastArgs[1] == origin and lastArgs[2] == direction)
excluded(lastArgs[3])
local firstParams = lastArgs[3]
local otherTarget = roblox.Instance.new("Folder")
Solver.raycast(model, parameters, otherTarget, false, origin, direction)
assert(lastArgs[3] ~= firstParams and lastArgs[3].FilterDescendantsInstances[2] == otherTarget)
assert(firstParams.FilterDescendantsInstances[2] == target, "query filters leaked between generations")
assert(Solver.spherecast(model, parameters, target, false, origin, 3, direction) == hit)
assert(lastMethod == "Spherecast" and lastArgs[1] == origin and lastArgs[2] == 3 and lastArgs[3] == direction)
excluded(lastArgs[4])
assert(Solver.blockcast(model, parameters, target, false, cf, size, direction) == hit)
assert(lastMethod == "Blockcast" and lastArgs[1] == cf and lastArgs[2] == size and lastArgs[3] == direction)
excluded(lastArgs[4])
assert(Solver.shapecast(model, parameters, target, false, shape, direction, cf, size) == hit)
assert(lastMethod == "Shapecast" and lastArgs[1] == shape and lastArgs[2] == direction)
assert(lastArgs[4] == cf and lastArgs[5] == size)
excluded(lastArgs[3])
Solver.shapecast(model, parameters, target, false, shape, direction)
assert(lastArgs[4] == nil and lastArgs[5] == nil)
assert(Solver.getPartBoundsInBox(model, parameters, target, false, cf, size) == parts)
assert(lastMethod == "GetPartBoundsInBox" and lastArgs[1] == cf and lastArgs[2] == size)
excluded(lastArgs[3])
assert(Solver.getPartBoundsInRadius(model, parameters, target, false, origin, 3) == parts)
assert(lastMethod == "GetPartBoundsInRadius" and lastArgs[1] == origin and lastArgs[2] == 3)
excluded(lastArgs[3])
assert(Solver.getPartBoundsInPart(model, parameters, target, false, shape) == parts)
assert(lastMethod == "GetPartsInPart" and lastArgs[1] == shape)
excluded(lastArgs[2])

-- Every internal query must target only the current output folder.
Solver.raycast(model, parameters, target, true, origin, direction)
included(lastArgs[3])
Solver.spherecast(model, parameters, target, true, origin, 3, direction)
included(lastArgs[4])
Solver.blockcast(model, parameters, target, true, cf, size, direction)
included(lastArgs[4])
Solver.shapecast(model, parameters, target, true, shape, direction, cf, size)
assert(lastArgs[4] == cf and lastArgs[5] == size)
included(lastArgs[3])
Solver.getPartBoundsInBox(model, parameters, target, true, cf, size)
included(lastArgs[3])
Solver.getPartBoundsInRadius(model, parameters, target, true, origin, 3)
included(lastArgs[3])
Solver.getPartBoundsInPart(model, parameters, target, true, shape)
included(lastArgs[2])
assert(firstParams.FilterType == Enum.RaycastFilterType.Exclude)
assert(firstParams.FilterDescendantsInstances[2] == target, "internal checks mutated external query filters")

-- Explicit filters and a private world belong to the bound solver, without changing defaults.
local raycastParams = {
	FilterType = Enum.RaycastFilterType.Exclude,
	FilterDescendantsInstances = { model },
	BruteForceAllSlow = false,
	CollisionGroup = "Default",
	IgnoreWater = true,
	RespectCanCollide = true,
}
local overlapParams = {
	FilterType = Enum.RaycastFilterType.Exclude,
	FilterDescendantsInstances = { model },
	BruteForceAllSlow = false,
	CollisionGroup = "Default",
	MaxParts = 1,
	RespectCanCollide = true,
	Tolerance = 0.1,
}
local internalBound = false
local privateCalls = 0
local bound = Solver.new({
	Raycast = function(_self: unknown, _origin: Vector3, _direction: Vector3, params: any)
		if internalBound then
			included(params)
			assert(params ~= raycastParams)
			assert(params.IgnoreWater == true and params.RespectCanCollide == true)
			assert(params.CollisionGroup == "Default" and params.BruteForceAllSlow == false)
		else
			assert(params == raycastParams)
		end
		privateCalls += 1
		return nil
	end,
	GetPartsInPart = function(_self: unknown, _shape: unknown, params: any)
		if internalBound then
			included(params)
			assert(params ~= overlapParams)
			assert(params.MaxParts == 1 and params.Tolerance == 0.1 and params.RespectCanCollide == true)
			assert(params.CollisionGroup == "Default" and params.BruteForceAllSlow == false)
		else
			assert(params == overlapParams)
		end
		privateCalls += 1
		return {}
	end,
}, raycastParams, overlapParams)
assert(bound.raycast(model, parameters, target, false, origin, direction) == nil)
assert(#bound.getPartBoundsInPart(model, parameters, target, false, shape) == 0 and privateCalls == 2)
internalBound = true
assert(bound.raycast(model, parameters, target, true, origin, direction) == nil)
assert(#bound.getPartBoundsInPart(model, parameters, target, true, shape) == 0 and privateCalls == 4)
assert(raycastParams.FilterType == Enum.RaycastFilterType.Exclude)
assert(overlapParams.FilterType == Enum.RaycastFilterType.Exclude)
assert(raycastParams.FilterDescendantsInstances[1] == model and overlapParams.FilterDescendantsInstances[1] == model)
Solver.raycast(model, parameters, target, false, origin, direction)
excluded(lastArgs[3])

local function expectError(callback: () -> (), message: string)
	local ok, problem = pcall(callback)
	assert(not ok and tostring(problem):find(message, 1, true), `expected {message}, got {problem}`)
end
parameters.Attributes.Solver_Cast_Path = "custom/casts"
parameters.Attributes.Source_MaxYield = 0
parameters.Attributes.Source_PathDelimiter = "/"
expectError(function()
	Surface.getSolver(parameters)
end, "failed to find cast solver")
moduleRef = roblox.Instance.new("Folder")
expectError(function()
	Surface.getSolver(parameters)
end, "must reference a ModuleScript")
for path, message in { ["checks/not-table"] = "must return a table", ["checks/incomplete"] = "is missing raycast" } do
	moduleRef = {
		ModulePath = path,
		IsA = function(_self: unknown, className: string)
			return className == "ModuleScript"
		end,
	}
	expectError(function()
		Surface.getSolver(parameters)
	end, message)
end
local before = lookups
parameters.Attributes.Layout_SurfaceDetectionMethod = "None"
assert(Surface.detect(shape, cf, parameters, Vector3.zero, size, target, nil) == cf)
assert(lookups == before, "disabled detection resolved a custom solver")

parameters.Attributes.Solver_Cast_Path = 12
expectError(function()
	ParameterUtil.validate(parameters)
end, "invalid Solver_Cast_Path")
parameters.Attributes.Solver_Cast_Path = "custom/casts"
shape:SetAttribute("Solver_Cast_Path", "template-cannot-override")
assert(ParameterUtil.resolveTemplateAttributes(shape, parameters).Attributes.Solver_Cast_Path == "custom/casts")
expectError(function()
	ParameterUtil.getDefaults({ Solver_Cast_Path = "reserved" })
end, "reserved by the package")
print(
	"Verified seven CastSolver queries with internal/external filters, per-generation isolation, shape overrides, bound worlds/settings, default resolution, invalid solver paths/exports, disabled detection, and solver attribute ownership."
)
