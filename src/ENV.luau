--!strict
-- Services
-- Packages
-- Modules
-- Types
local Types = require(script.Parent.Types)
type Env = {
	DEFAULT_LAYOUT_PAUSE_INTERVAL: number,
	DEFAULT_MIN_MODEL_SCALE: number,
	DEFAULT_SOURCE_PATH: string,
	DEFAULT_SOURCE_PATH_DELIMITER: string,
	DEFAULT_SOURCE_MAX_YIELD: number,
	DEFAULT_SOURCE_ALIGNMENT: Types.AlignType,
	DEFAULT_LAYOUT_SURFACE_DETECTION_METHOD: Types.SurfaceDetectionMethod,
	DEFAULT_SOLVER_CAST_PATH: string,
	DEFAULT_SOURCE_PIVOT_METHOD: Types.PivotMethod,
	DEFAULT_SOURCE_SCALE_METHOD: Types.ScaleMethod,
	DEFAULT_SOURCE_SCALE_REFERENCE: Types.ScaleReference,
	DEFAULT_SOURCE_PADDING: UDim,
	DEFAULT_SOURCE_EXCLUDED_TAGS: string,
	DEFAULT_LAYOUT_TYPE: Types.LayoutType,
	DEFAULT_LAYOUT_HEIGHT_AXIS: Types.HeightAxis,
	DEFAULT_LAYOUT_BASE_PADDING: UDim,
	DEFAULT_LAYOUT_TOP_PADDING: UDim,
	DEFAULT_LAYOUT_ARCH_SHAPE: number,
	DEFAULT_LAYOUT_LAYER_LIMIT: NumberRange,
	DEFAULT_LAYOUT_SIDES: number,
	DEFAULT_LAYOUT_AVOID_OVERLAP: boolean,
	DEFAULT_LAYOUT_PLACEMENT_ATTEMPTS: number,
	DEFAULT_RANDOM_SEED: number,
	DEFAULT_RANDOM_SCALE: NumberRange,
	DEFAULT_RANDOM_ROLL: NumberRange,
	DEFAULT_RANDOM_PAN: NumberRange,
	DEFAULT_RANDOM_TILT: NumberRange,
	DEFAULT_LAYOUT_COLUMN_LIMIT: NumberRange,
	DEFAULT_LAYOUT_ROW_LIMIT: NumberRange,
	DEFAULT_LAYOUT_POPULATION_LIMIT: NumberRange,
	DEFAULT_LAYOUT_CURVE_SIZE_0: UDim,
	DEFAULT_LAYOUT_CURVE_SIZE_1: UDim,
	SMALL: number,
	DEBUG_PRINT_ENABLED: boolean,
	DEBUG_AREA_ENABLED: boolean,
	DEBUG_OUTER_CELL_ENABLED: boolean,
	DEBUG_INNER_CELL_ENABLED: boolean,
	DEBUG_TEMPLATE_BOUNDS_ENABLED: boolean,
	DEBUG_BOUNDS_ENABLED: boolean,
	[any]: nil,
}
-- Constants
local PREFIX = "__PROCEDURALPACKAGE__"
-- Variables
-- References
-- Private Functions
-- Class
local DEFAULT_ENV: Env = {
	DEFAULT_LAYOUT_PAUSE_INTERVAL = 100,
	DEFAULT_MIN_MODEL_SCALE = 0.001,
	DEFAULT_SOURCE_PATH = "",
	DEFAULT_SOURCE_PATH_DELIMITER = ".",
	DEFAULT_SOURCE_MAX_YIELD = 15,
	DEFAULT_SOURCE_ALIGNMENT = "Floor",
	DEFAULT_LAYOUT_SURFACE_DETECTION_METHOD = "None",
	DEFAULT_SOLVER_CAST_PATH = "",
	DEFAULT_SOURCE_PIVOT_METHOD = "Pivot",
	DEFAULT_SOURCE_PADDING = UDim.new(0.1, 0),
	DEFAULT_SOURCE_SCALE_METHOD = "Stretch",
	DEFAULT_SOURCE_SCALE_REFERENCE = "Min",
	DEFAULT_SOURCE_EXCLUDED_TAGS = "",
	DEFAULT_LAYOUT_TYPE = "Single",
	DEFAULT_LAYOUT_HEIGHT_AXIS = "Y",
	DEFAULT_LAYOUT_BASE_PADDING = UDim.new(0),
	DEFAULT_LAYOUT_TOP_PADDING = UDim.new(0),
	DEFAULT_LAYOUT_ARCH_SHAPE = 0.5,
	DEFAULT_LAYOUT_LAYER_LIMIT = NumberRange.new(1, 100),
	DEFAULT_LAYOUT_SIDES = 6,
	DEFAULT_LAYOUT_AVOID_OVERLAP = false,
	DEFAULT_LAYOUT_PLACEMENT_ATTEMPTS = 32,
	DEFAULT_RANDOM_SEED = 0,
	DEFAULT_RANDOM_SCALE = NumberRange.new(1),
	DEFAULT_RANDOM_ROLL = NumberRange.new(0),
	DEFAULT_RANDOM_PAN = NumberRange.new(0),
	DEFAULT_RANDOM_TILT = NumberRange.new(0),
	DEFAULT_LAYOUT_COLUMN_LIMIT = NumberRange.new(1, 100),
	DEFAULT_LAYOUT_ROW_LIMIT = NumberRange.new(1, 100),
	DEFAULT_LAYOUT_POPULATION_LIMIT = NumberRange.new(10),
	DEFAULT_LAYOUT_CURVE_SIZE_0 = UDim.new(0, 12),
	DEFAULT_LAYOUT_CURVE_SIZE_1 = UDim.new(0, 12),
	SMALL = 0.0001,
	DEBUG_PRINT_ENABLED = workspace:HasTag("PROC_PACKAGE_DEBUG_PRINT_ENABLED"),
	DEBUG_AREA_ENABLED = workspace:HasTag("PROC_PACKAGE_DEBUG_ENABLED")
		or workspace:HasTag("PROC_PACKAGE_DEBUG_AREA_ENABLED"),
	DEBUG_OUTER_CELL_ENABLED = workspace:HasTag("PROC_PACKAGE_DEBUG_ENABLED")
		or workspace:HasTag("PROC_PACKAGE_DEBUG_OUTER_CELL_ENABLED"),
	DEBUG_INNER_CELL_ENABLED = workspace:HasTag("PROC_PACKAGE_DEBUG_ENABLED")
		or workspace:HasTag("PROC_PACKAGE_DEBUG_INNER_CELL_ENABLED"),
	DEBUG_TEMPLATE_BOUNDS_ENABLED = workspace:HasTag("PROC_PACKAGE_DEBUG_ENABLED")
		or workspace:HasTag("PROC_PACKAGE_DEBUG_TEMPLATE_BOUNDS_ENABLED"),
	DEBUG_BOUNDS_ENABLED = workspace:HasTag("PROC_PACKAGE_DEBUG_ENABLED")
		or workspace:HasTag("PROC_PACKAGE_DEBUG_BOUNDS_ENABLED"),
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
