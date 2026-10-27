--!strict
local roblox = require("@lune/roblox")
local load = require("./lib/load-package")()("src/ParameterUtil")
local datatypes = (roblox :: any) :: { NumberRange: typeof(NumberRange), UDim: typeof(UDim) }
local NumberRange = datatypes.NumberRange
local UDim = datatypes.UDim

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
	Layout_CurveSize0 = UDim.new(0.5, 23),
	Layout_CurveSize1 = UDim.new(-0.25, -11),
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
assert(values.Layout_CurveSize0 == UDim.new(0.5, 23) and values.Layout_CurveSize1 == UDim.new(-0.25, -11))
assert(values.Layout_PopulationLimit == NumberRange.new(6))
model:SetAttribute("Layout_CurveSize0", UDim.new(0.75, 41))
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
model:SetAttribute("Layout_CurveSize0", UDim.new(-0.5, 99))
assert(values.Layout_CurveSize0 == nil, "an inactive field reappeared")
model:SetAttribute("Layout_Type", "SurfaceCurvedLine")
assert(values.Layout_CurveSize0 == UDim.new(-0.5, 99), "removed values should be retained privately")

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

-- Literal errors include every accepted spelling at each public validation boundary.
local literalCases: { [string]: { string } } = {
	Source_Alignment = { "Center", "Floor" },
	Source_PivotMethod = {
		"Pivot",
		"Center",
		"Bottom",
		"Top",
		"PrimaryPartPivot",
		"PrimaryPartCenter",
		"PrimaryPartBottom",
		"PrimaryPartTop",
	},
	Source_ScaleMethod = { "Stretch", "Fill", "Fit" },
	Source_ScaleReference = { "Height", "Average", "Min", "Max" },
	Layout_SurfaceDetectionMethod = { "Raycast", "Shapecast", "None" },
	Layout_Type = { "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine" },
}
local parameters = load.resolve({
	Attributes = load.getDefaults(nil, "SurfaceGrid"),
	Size = (roblox :: any).Vector3.new(20, 10, 30),
	Pause = function() end,
})
local function expectError(callback: () -> (), message: string)
	local ok, failure = pcall(callback)
	assert(not ok, "expected validation to fail")
	assert(string.find(tostring(failure), message, 1, true), tostring(failure))
end
-- Grid limits accept zero and fractional bounds containing a nonnegative integer.
for _, name in { "Layout_ColumnLimit", "Layout_RowLimit" } do
	local original = parameters.Attributes[name]
	for _, limit in { NumberRange.new(0, 3), NumberRange.new(0), NumberRange.new(1.1, 3.9) } do
		parameters.Attributes[name] = limit
		load.validate(parameters)
	end
	for _, limit in { NumberRange.new(-1, 3), NumberRange.new(0.1, 0.9) } do
		parameters.Attributes[name] = limit
		expectError(function()
			load.validate(parameters)
		end, `invalid {name}`)
	end
	parameters.Attributes[name] = original
end
local template = roblox.Instance.new("Part")
template.Name = "LiteralTemplate"
for name, accepted in literalCases do
	local original = parameters.Attributes[name]
	local expected = `expected one of: "{table.concat(accepted, '", "')}"`
	for _, value in accepted do
		parameters.Attributes[name] = value
		load.validate(parameters)
	end
	for _, value in { "invalid", 42 } do
		parameters.Attributes[name] = value
		expectError(function()
			load.validate(parameters)
		end, `invalid {name} ({value}); {expected}`)
	end
	parameters.Attributes[name] = original
	if string.sub(name, 1, 7) == "Source_" then
		template:SetAttribute(name, "invalid")
		expectError(function()
			load.resolveTemplateAttributes(template, parameters)
		end, `template "LiteralTemplate": invalid {name} (invalid); {expected}`)
		template:SetAttribute(name, nil)
	end
end
expectError(function()
	load.getDefaults(nil, "invalid")
end, 'invalid Layout_Type: invalid; expected one of: "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine"')
parameters.Attributes.Layout_PauseInterval = 0
expectError(function()
	load.validate(parameters)
end, "invalid Layout_PauseInterval (0)")
template:Destroy()
print(
	"Verified active-only defaults, inactive attribute removal, layout switches, restored edits, sparse generation snapshots, listener replacement, cleanup, and literal validation errors."
)
