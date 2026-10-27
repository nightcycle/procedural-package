--!strict
local roblox = require("@lune/roblox")
local load = require("./lib/load-package")()("src/ParameterUtil")
local datatypes = (roblox :: any) :: { NumberRange: typeof(NumberRange) }
local NumberRange = datatypes.NumberRange

-- The adapter models attribute events synchronously so re-entrant writes and cleanup are exercised.
local activeConnections = 0
local function signal()
	local callbacks: { [number]: (...any) -> () } = {}
	local nextId = 0
	return {
		Connect = function(_self: unknown, callback: (...any) -> ())
			nextId += 1
			local id = nextId
			callbacks[id] = callback
			activeConnections += 1
			return {
				Disconnect = function()
					if callbacks[id] then
						callbacks[id] = nil
						activeConnections -= 1
					end
				end,
			}
		end,
		Fire = function(...: any)
			for _, callback in table.clone(callbacks) do
				callback(...)
			end
		end,
	}
end
local changed, destroying = signal(), signal()
local values: { [string]: any } = {
	Layout_Type = "SurfaceGrid",
	Layout_ColumnLimit = NumberRange.new(3, 7),
	Layout_RowLimit = NumberRange.new(2, 5),
	Layout_CurveSize0 = 23,
	Layout_CurveSize1 = -11,
	Layout_PopulationLimit = NumberRange.new(6),
	Custom = "keep",
	Source_Path = "keep.path",
}
local model = {
	GetAttribute = function(_self: unknown, name: string): any
		return values[name]
	end,
	SetAttribute = function(_self: unknown, name: string, value: any)
		if values[name] == value then
			return
		end
		values[name] = value
		changed.Fire(name)
	end,
	AttributeChanged = changed,
	Destroying = destroying,
}
local defaults = load.getDefaults({ Custom = "keep" }, "SurfaceGrid")
assert(defaults.Layout_CurveSize0 == nil and defaults.Layout_PopulationLimit == nil)
local disconnect = load.bindAttributes(model, defaults)
assert(values.Layout_ColumnLimit == NumberRange.new(3, 7) and values.Layout_RowLimit == NumberRange.new(2, 5))
assert(values.Layout_CurveSize0 == nil and values.Layout_CurveSize1 == nil and values.Layout_PopulationLimit == nil)
assert(defaults.Layout_CurveSize0 == nil and defaults.Layout_PopulationLimit == nil)
assert(values.Source_Path == "keep.path" and values.Custom == "keep")

model:SetAttribute("Layout_Type", "SurfaceCurvedLine")
assert(values.Layout_ColumnLimit == nil and values.Layout_RowLimit == nil)
assert(values.Layout_CurveSize0 == 23 and values.Layout_CurveSize1 == -11)
assert(values.Layout_PopulationLimit == NumberRange.new(6))
model:SetAttribute("Layout_CurveSize0", 41)
model:SetAttribute("Layout_Type", "SurfaceRandom")
assert(values.Layout_CurveSize0 == nil and values.Layout_CurveSize1 == nil)
assert(values.Layout_PopulationLimit == NumberRange.new(6))
model:SetAttribute("Layout_Type", "Single")
for _, name in
	{
		"Layout_CurveSize0",
		"Layout_CurveSize1",
		"Layout_ColumnLimit",
		"Layout_RowLimit",
		"Layout_PopulationLimit",
		"Layout_SurfaceDetectionMethod",
	}
do
	assert(values[name] == nil and defaults[name] == nil, `Single retained {name}`)
end
model:SetAttribute("Layout_Type", "SurfaceGrid")
assert(values.Layout_ColumnLimit == NumberRange.new(3, 7))
assert(values.Layout_RowLimit == NumberRange.new(2, 5))
model:SetAttribute("Layout_CurveSize0", 99)
assert(values.Layout_CurveSize0 == nil, "an inactive field reappeared")
model:SetAttribute("Layout_Type", "SurfaceCurvedLine")
assert(values.Layout_CurveSize0 == 99, "removed values should be retained privately")

-- Starting a replacement binding disconnects the old listeners; destroy is idempotent.
assert(activeConnections == 2)
local stop = load.bindAttributes(model, defaults)
assert(activeConnections == 2)
disconnect()
assert(activeConnections == 2)
destroying.Fire()
assert(activeConnections == 0)
stop()
assert(activeConnections == 0)

-- A sparse public snapshot gains only internal defaults, preserving source parameters and input identity.
for _, kind in { "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine" } do
	local attributes = load.getDefaults(nil, kind)
	local before = table.clone(attributes)
	local pauses = 0
	local parameters = {
		Attributes = attributes,
		Size = (roblox :: any).Vector3.new(20, 10, 30),
		Pause = function()
			pauses += 1
		end,
	}
	local resolved = load.resolve(parameters)
	load.validate(resolved)
	assert(resolved.Attributes.Layout_ColumnLimit ~= nil and resolved.Attributes.Layout_CurveSize0 ~= nil)
	for name, value in attributes do
		assert(before[name] == value)
	end
	for name, value in before do
		assert(attributes[name] == value)
	end
	resolved:Pause()
	assert(pauses == 1)
end
print(
	"Verified active-only defaults, inactive attribute removal, layout switches, restored edits, sparse generation snapshots, listener replacement, and cleanup."
)
