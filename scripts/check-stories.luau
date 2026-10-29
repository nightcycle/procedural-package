--!strict
-- Mount and update the real UI Labs stories in Lune. Signals, camera sizing,
-- Model methods, world queries, and RNG are adapters, not Studio visual tests.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local makeLoader = require("./lib/load-package")
type RInstance = roblox.Instance & { [string]: any }
type Datatypes = { CFrame: typeof(CFrame), Vector3: typeof(Vector3), Vector2: typeof(Vector2) }
local datatypes = (roblox :: any) :: Datatypes
local CFrame, Vector3, Vector2 = datatypes.CFrame, datatypes.Vector3, datatypes.Vector2
local connections = 0
local function signal()
	return {
		Connect = function(_self: unknown, _callback: (...any) -> ())
			connections += 1
			local active = true
			return {
				Disconnect = function()
					if active then
						connections -= 1
						active = false
					end
				end,
			}
		end,
	}
end
for _, key in { "InputBegan", "InputChanged" } do
	roblox.implementProperty("GuiObject", key, function(_instance: RInstance)
		return signal()
	end)
end
roblox.implementProperty("TextButton", "Activated", function(_instance: RInstance)
	return signal()
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(_instance: RInstance, _name: string)
	return signal()
end)

local function getBounds(model: RInstance): (CFrame, Vector3)
	local minimum, maximum = Vector3.one * math.huge, -Vector3.one * math.huge
	local found = false
	for _, child in model:GetDescendants() :: { RInstance } do
		if not child:IsA("BasePart") then
			continue
		end
		found = true
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local point = child.CFrame:PointToWorldSpace(child.Size * Vector3.new(x, y, z) / 2)
					minimum, maximum = minimum:Min(point), maximum:Max(point)
				end
			end
		end
	end
	return if found then CFrame.new((minimum + maximum) / 2) else CFrame.identity,
		if found then maximum - minimum else Vector3.zero
end
local function getPivot(instance: RInstance): CFrame
	if instance:IsA("BasePart") then
		return instance.CFrame * instance.PivotOffset
	end
	if instance.PrimaryPart then
		return getPivot(instance.PrimaryPart)
	end
	return instance.WorldPivotData or (getBounds(instance))
end
local function pivotTo(instance: RInstance, frame: CFrame)
	if instance:IsA("BasePart") then
		instance.CFrame = frame * instance.PivotOffset:Inverse()
		return
	end
	local delta = frame * getPivot(instance):Inverse()
	for _, child in instance:GetDescendants() :: { RInstance } do
		if child:IsA("BasePart") then
			child.CFrame = delta * child.CFrame
		end
	end
	instance.WorldPivotData = frame
end
roblox.implementProperty("Model", "WorldPivot", function(instance: RInstance)
	return getPivot(instance)
end, function(instance: RInstance, frame: CFrame)
	instance.WorldPivotData = frame
end)
for _, className in { "Model", "BasePart" } do
	roblox.implementMethod(className, "GetPivot", getPivot)
	roblox.implementMethod(className, "PivotTo", pivotTo)
end
roblox.implementMethod("Model", "GetBoundingBox", getBounds)
roblox.implementMethod("Model", "GetScale", function(instance: RInstance)
	return instance.Scale
end)
roblox.implementMethod("Model", "ScaleTo", function(instance: RInstance, scale: number)
	local factor = scale / instance.Scale
	local pivot = getPivot(instance)
	for _, child in instance:GetDescendants() :: { RInstance } do
		if not child:IsA("BasePart") then
			continue
		end
		local relative = pivot:ToObjectSpace(child.CFrame)
		child.CFrame = pivot * CFrame.new(relative.Position * factor) * relative.Rotation
		child.Size *= factor
		child.PivotOffset = CFrame.new(child.PivotOffset.Position * factor) * child.PivotOffset.Rotation
	end
	instance.Scale = scale
end)
for _, method in { "Raycast", "Shapecast" } do
	roblox.implementMethod("WorldRoot", method, function(world: RInstance, ...: any)
		local arguments = { ... }
		local params = arguments[3]
		local support = params.FilterDescendantsInstances[1]
		if not support:IsDescendantOf(world) then
			return nil
		end
		local direction = arguments[2]
		return { Position = support.CFrame.Position, Distance = direction.Magnitude / 2 }
	end)
end
local function node(path: string): any
	return setmetatable({ ModulePath = path }, {
		__index = function(_self: unknown, key: string)
			return node(path .. "/" .. key)
		end,
	})
end
roblox.implementMethod(
	"WorldRoot",
	"GetPartBoundsInBox",
	function(_world: RInstance, frame: CFrame, size: Vector3, params: any)
		local matches = {}
		for _, root in params.FilterDescendantsInstances do
			for _, part in root:GetDescendants() :: { RInstance } do
				if not part:IsA("BasePart") then
					continue
				end
				local relative = frame:ToObjectSpace(part.CFrame)
				local x, y, z = relative.RightVector:Abs(), relative.UpVector:Abs(), relative.ZVector:Abs()
				local extent = (x * part.Size.X + y * part.Size.Y + z * part.Size.Z + size) / 2
				local delta = relative.Position:Abs()
				if delta.X < extent.X and delta.Y < extent.Y and delta.Z < extent.Z then
					table.insert(matches, part)
				end
			end
		end
		return matches
	end
)
local replicatedStorage = {
	Packages = { ProceduralPackage = node("src") },
	DevPackages = { UILabs = node("DevPackages/_Index/pepeeltoro41_ui-labs@2.4.2/ui-labs/src") },
	DebugStories = node("stories"),
}
local services = {
	ReplicatedStorage = replicatedStorage,
	UserInputService = { InputChanged = signal(), InputEnded = signal() },
}
-- Lune does not expose Roblox Random. Repeatable values suffice to exercise the render paths.
local randomState = 1
local randomAdapter = {
	new = function(seed: number)
		randomState = seed
		return {
			NextNumber = function(_self: unknown, low: number, high: number)
				randomState = (randomState * 16807 + 1) % 2147483647
				return low + (high - low) * randomState / 2147483647
			end,
			NextInteger = function(_self: unknown, low: number, _high: number)
				return low
			end,
			Shuffle = function(_self: unknown, _array: { unknown }) end,
		}
	end,
}
local load = makeLoader({
	game = {
		GetService = function(_self: unknown, name: string): any
			return (services :: any)[name]
		end,
	},
	Random = randomAdapter,
	Instance = {
		new = function(className: string)
			local instance = roblox.Instance.new(className) :: RInstance
			if instance:IsA("GuiObject") then
				instance.AbsoluteSize = Vector2.new(960, 680)
			end
			return instance
		end,
	},
}, { IndexUtil = {} })

local paths: { string } = {}
local function gather(directory: string)
	for _, entry in fs.readDir(directory) do
		local path = directory .. "/" .. entry
		if fs.isDir(path) then
			gather(path)
		elseif path:sub(-11) == ".story.luau" then
			table.insert(paths, path:sub(1, -6))
		end
	end
end
gather("src")
gather("stories/Attributes")
table.sort(paths)
local mounted, updated = 0, 0
for _, path in paths do
	local story = load(path)
	local values: { [string]: any } = {}
	for key, control in story.controls do
		values[key] = if typeof(control) == "table" then control.ControlValue else control
	end
	local target = roblox.Instance.new("Frame") :: RInstance
	local listener: (({ [string]: any }, any) -> ())? = nil
	local disconnected = false
	local cleanup = story.render({
		target = target,
		controls = values,
		converted = {},
		subscribe = function(callback: ({ [string]: any }, any) -> ())
			listener = callback
			return function()
				disconnected = true
			end
		end,
	})
	local function inspect()
		local root = target:FindFirstChild("VisualDebug") :: RInstance
		assert(root, `missing viewport in {path}`)
		local status = (root:FindFirstChild("Status") :: RInstance).Text
		assert(not status:find("ERROR:", 1, true), `{path}: {status}`)
		assert(not status:find("FAIL", 1, true), `{path}: {status}`)
		local viewport = root:FindFirstChild("Viewport") :: RInstance
		assert(
			viewport:FindFirstChildOfClass("Camera") and viewport:FindFirstChild("PreviewWorld"),
			`missing camera/world in {path}`
		)
	end
	inspect()
	mounted += 1
	assert(listener, `missing control subscription in {path}`)
	for key, control in story.controls do
		local changed = table.clone(values)
		if typeof(control) == "boolean" then
			changed[key] = not control
		elseif typeof(control) == "table" and control.Type == "Slider" then
			changed[key] = if control.Min ~= values[key] then control.Min else control.Max
		elseif typeof(control) == "table" and control.Type == "Choose" then
			changed[key] = control.List[#control.List]
		else
			continue
		end
		listener(changed, {})
		inspect()
		updated += 1
	end
	if path == "stories/Attributes/Layouts.story" then
		for _, kind in story.controls.Layout_Type.List do
			for _, axis in { "X", "Y", "Z" } do
				for _, asModel in { true, false } do
					local changed = table.clone(values)
					changed.Layout_Type, changed.Layout_HeightAxis, changed.AsModel = kind, axis, asModel
					listener(changed, {})
					inspect()
					updated += 1
				end
			end
		end
	end
	cleanup()
	assert(disconnected and #target:GetChildren() == 0 and connections == 0, `cleanup leak in {path}`)
	listener(values, {})
	assert(#target:GetChildren() == 0, `late subscription remounted {path}`)
	target:Destroy()
	print(`PASS {path}`)
end
assert(mounted > 0, "No stories discovered")
print(
	`Verified {mounted} real UI Labs story mounts, {updated} live control updates, result readouts, and complete cleanup with Lune adapters.`
)
