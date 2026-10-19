--!strict
-- Services
-- Packages
-- Modules
-- Types
local Types = require(script.Parent.Types)
type Env = {
	DEFAULT_PAUSE_INTERVAL: number,
	DEFAULT_MIN_MODEL_SCALE: number,
	DEFAULT_SOURCE_PATH: string,
	DEFAULT_SOURCE_PATH_DELIMITER: string,
	DEFAULT_SOURCE_MAX_YIELD: number,
	DEFAULT_GENERATED_ALIGNMENT: Types.AlignType,
	DEFAULT_GENERATED_SCALE_METHOD: Types.ScaleMethod,
	DEFAULT_GENERATED_SCALE_REFERENCE: Types.ScaleReference,
	DEFAULT_GENERATED_PADDING: UDim,
	DEFAULT_GENERATED_EXCLUDED_TAGS: string,
	DEFAULT_GENERATED_COUNT: NumberRange,
	DEFAULT_RANDOM_SEED: number,
	DEFAULT_RANDOM_SCALE: NumberRange,
	DEFAULT_RANDOM_ROLL: NumberRange,
	DEFAULT_RANDOM_PAN: NumberRange,
	DEFAULT_RANDOM_TILT: NumberRange,
	DEFAULT_RANDOM_PLACEMENT: Types.PlacementType,
	SMALL: number,
	DEBUG_PRINT_ENABLED: boolean,
	DEBUG_AREA_ENABLED: boolean,
	DEBUG_OUTER_CELL_ENABLED: boolean,
	DEBUG_INNER_CELL_ENABLED: boolean,
	[any]: nil,
}
-- Constants
local PREFIX = "__PROCEDURALPACKAGE__"
-- Variables
-- References
-- Private Functions
-- Class
local DEFAULT_ENV: Env = {
	DEFAULT_PAUSE_INTERVAL = 100,
	DEFAULT_MIN_MODEL_SCALE = 0.001,
	DEFAULT_SOURCE_PATH = "",
	DEFAULT_SOURCE_PATH_DELIMITER = ".",
	DEFAULT_SOURCE_MAX_YIELD = 15,
	DEFAULT_GENERATED_ALIGNMENT = "Floor",
	DEFAULT_GENERATED_PADDING = UDim.new(0.1, 0),
	DEFAULT_GENERATED_SCALE_METHOD = "Stretch",
	DEFAULT_GENERATED_SCALE_REFERENCE = "Min",
	DEFAULT_GENERATED_EXCLUDED_TAGS = "",
	DEFAULT_GENERATED_COUNT = NumberRange.new(1),
	DEFAULT_RANDOM_SEED = 0,
	DEFAULT_RANDOM_SCALE = NumberRange.new(1),
	DEFAULT_RANDOM_ROLL = NumberRange.new(0),
	DEFAULT_RANDOM_PAN = NumberRange.new(0),
	DEFAULT_RANDOM_TILT = NumberRange.new(0),
	DEFAULT_RANDOM_PLACEMENT = "Grid",
	SMALL = 0.0001,
	DEBUG_PRINT_ENABLED = workspace:HasTag("IS_PROC_PACKAGE_DEBUG_PRINT"),
	DEBUG_AREA_ENABLED = workspace:HasTag("IS_PROC_PACKAGE_DEBUG_MODE"),
	DEBUG_OUTER_CELL_ENABLED = workspace:HasTag("IS_PROC_PACKAGE_DEBUG_MODE"),
	DEBUG_INNER_CELL_ENABLED = workspace:HasTag("IS_PROC_PACKAGE_DEBUG_MODE"),
}
local out: Env = setmetatable({}, {
	__index = function(_, readableKey: string): any?
		local k = PREFIX .. readableKey
		local v = _G[k]
		local dV = rawget(DEFAULT_ENV, readableKey)
		if dV == nil then
			error(`Attempt to access undefined key "{readableKey}" in ENV`)
		end
		if typeof(v) == "string" then
			if typeof(dV) == "boolean" then
				if v == "true" then
					return true
				elseif v == "false" then
					return false
				else
					return dV
				end
			elseif typeof(dV) == "number" then
				local n = tonumber(v)
				if n ~= nil then
					return n
				else
					return dV
				end
			end
		end
		if v == nil then
			return dV
		else
			return v
		end
	end,
	__newindex = function(_, readableKey, v)
		local k = PREFIX .. readableKey
		assert(rawget(DEFAULT_ENV, readableKey) ~= nil, `Attempt to set undefined key "{readableKey}" in ENV`)
		_G[k] = v
	end,
}) :: any

return out :: Env
