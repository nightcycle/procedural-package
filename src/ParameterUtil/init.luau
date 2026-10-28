--!strict
local ENV = require(script.Parent.ENV)
local Types = require(script.Parent.Types)
local Schema = require(script.Parent.ParameterSchema)
local Layouts = require(script.Parent.Layouts)
local field = Schema.field

local function isString(value: unknown): boolean
	return typeof(value) == "string"
end
local common: Types.ParameterSchema = {
	Solver_Cast_Path = field(function()
		return ENV.DEFAULT_SOLVER_CAST_PATH
	end, isString),
	Source_Path = field(function()
		return ENV.DEFAULT_SOURCE_PATH
	end, isString),
	Source_PathDelimiter = field(function()
		return ENV.DEFAULT_SOURCE_PATH_DELIMITER
	end, function(value)
		return typeof(value) == "string" and value ~= ""
	end),
	Source_MaxYield = field(function()
		return ENV.DEFAULT_SOURCE_MAX_YIELD
	end, Schema.nonNegative),
	Source_PivotMethod = field(function()
		return ENV.DEFAULT_SOURCE_PIVOT_METHOD
	end, Types.PivotMethod, true),
	Source_ScaleMethod = field(function()
		return ENV.DEFAULT_SOURCE_SCALE_METHOD
	end, Types.ScaleMethod, true),
	Source_ScaleReference = field(function()
		return ENV.DEFAULT_SOURCE_SCALE_REFERENCE
	end, Types.ScaleReference, true),
	Source_Alignment = field(function()
		return ENV.DEFAULT_SOURCE_ALIGNMENT
	end, Types.AlignType, true),
	Source_ExcludedTags = field(function()
		return ENV.DEFAULT_SOURCE_EXCLUDED_TAGS
	end, isString),
	Random_Seed = field(function()
		return ENV.DEFAULT_RANDOM_SEED
	end, Schema.finite),
	Random_Scale = field(function()
		return ENV.DEFAULT_RANDOM_SCALE
	end, Schema.scaleRange, true),
	Random_Roll = field(function()
		return ENV.DEFAULT_RANDOM_ROLL
	end, Schema.range, true),
	Random_Pan = field(function()
		return ENV.DEFAULT_RANDOM_PAN
	end, Schema.range, true),
	Random_Tilt = field(function()
		return ENV.DEFAULT_RANDOM_TILT
	end, Schema.range, true),
	Layout_PauseInterval = field(function()
		return ENV.DEFAULT_LAYOUT_PAUSE_INTERVAL
	end, Schema.positiveInteger),
	Layout_Type = field(function()
		return ENV.DEFAULT_LAYOUT_TYPE
	end, Types.LayoutType),
}
local all = table.clone(common)
for _, layout in Layouts do
	for name, definition in layout.Parameters do
		assert(all[name] == nil or all[name] == definition, `conflicting parameter definition: {name}`)
		all[name] = definition
	end
end

local Util = {}

local function assertValid(validator: Types.Validator, value: unknown, message: string)
	local valid, reason = validator(value)
	assert(valid, if reason then `{message}; {reason}` else message)
end

local function validate(schema: Types.ParameterSchema, attributes: Types.ExtraAttributes, context: string)
	for name, definition in schema do
		assertValid(definition.Validate, attributes[name], `{context}: invalid {name} ({attributes[name]})`)
	end
end

function Util.getDefaults(
	extraAttributes: Types.ExtraAttributes?,
	layoutType: Types.LayoutType?
): Types.PackageAttributes & Types.ExtraAttributes
	local defaults: Types.ExtraAttributes = {}
	for name, definition in common do
		defaults[name] = definition.Default()
	end
	local selected: Types.LayoutType = layoutType or ENV.DEFAULT_LAYOUT_TYPE
	assertValid(Types.LayoutType, selected, `invalid Layout_Type: {selected}`)
	defaults.Layout_Type = selected
	for name, definition in Layouts[selected].Parameters do
		defaults[name] = definition.Default()
	end
	if extraAttributes then
		for name, value in extraAttributes do
			assert(all[name] == nil, `custom attribute {name} is reserved by the package`)
			defaults[name] = value
		end
	end
	-- The schema is the single runtime boundary for attribute dictionaries.
	return defaults :: any
end

function Util.resolve(
	parameters: Types.GenerationFunctionParams<Types.PackageAttributes & Types.ExtraAttributes>
): Types.Parameters
	local resolved = table.clone(parameters.Attributes)
	for name, definition in all do
		if resolved[name] == nil then
			resolved[name] = definition.Default()
		end
	end
	return {
		Attributes = resolved :: any,
		Size = parameters.Size,
		Pause = function(_self: Types.Parameters)
			parameters:Pause()
		end,
	}
end

-- Attribute editing runs from the constructor/listener, never inside OnGenerate.
local bindings: { [ProceduralModel]: () -> () } = setmetatable({}, { __mode = "k" }) :: any

function Util.bindAttributes(
	model: ProceduralModel,
	defaults: Types.PackageAttributes & Types.ExtraAttributes
): () -> ()
	local previous = bindings[model]
	if previous then
		previous()
	end
	local cached: Types.ExtraAttributes = {}
	local connections: { RBXScriptConnection } = {}
	local syncing, alive = false, true
	local function sync()
		if syncing or not alive then
			return
		end
		local selected = model:GetAttribute("Layout_Type") or defaults.Layout_Type
		if not Types.LayoutType(selected) then
			return
		end
		local schema = Layouts[selected :: Types.LayoutType].Parameters
		syncing = true
		for name in all do
			if common[name] then
				continue
			end
			local value = model:GetAttribute(name)
			if value ~= nil then
				cached[name] = value
			end
			if schema[name] == nil then
				defaults[name] = nil
				if value ~= nil then
					model:SetAttribute(name, nil)
				end
			end
		end
		for name, definition in schema do
			defaults[name] = definition.Default()
			if model:GetAttribute(name) == nil then
				model:SetAttribute(name, if cached[name] ~= nil then cached[name] else definition.Default())
			end
		end
		syncing = false
	end
	local function disconnect()
		if not alive then
			return
		end
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		if bindings[model] == disconnect then
			bindings[model] = nil
		end
	end
	bindings[model] = disconnect
	table.insert(
		connections,
		model.AttributeChanged:Connect(function(name: string)
			-- Also remove an inactive field if an older generation/default snapshot re-adds it.
			if name == "Layout_Type" or (all[name] ~= nil and common[name] == nil) then
				sync()
			end
		end)
	)
	table.insert(connections, model.Destroying:Connect(disconnect))
	sync()
	return disconnect
end

function Util.validate(parameters: Types.Parameters): Types.Layout
	validate(common, parameters.Attributes, "generator")
	local size = parameters.Size
	assert(
		Schema.vector(size) and size.X > 0 and size.Y > 0 and size.Z > 0,
		"generation Size must contain finite positive dimensions"
	)
	local layout = Layouts[parameters.Attributes.Layout_Type]
	validate(layout.Parameters, parameters.Attributes, parameters.Attributes.Layout_Type)
	return layout
end

function Util.parseTags(value: string): { string }
	local tags: { string } = {}
	for _, entry in string.split(value, ",") do
		local tag = string.match(entry, "^%s*(.-)%s*$")
		if tag and tag ~= "" then
			table.insert(tags, tag)
		end
	end
	return tags
end

function Util.resolveTemplateAttributes(
	template: Types.Template,
	parameters: Types.Parameters,
	extraDefaults: Types.ExtraAttributes?
): Types.Parameters
	local resolved = table.clone(parameters.Attributes)
	for name, definition in common do
		if not definition.TemplateOverride then
			continue
		end
		local value: unknown = template:GetAttribute(name)
		if value ~= nil then
			assertValid(definition.Validate, value, `template "{template:GetFullName()}": invalid {name} ({value})`)
			resolved[name] = value
		end
	end
	if extraDefaults then
		for name, defaultValue in extraDefaults do
			local value: unknown = template:GetAttribute(name)
			if value ~= nil then
				assert(
					typeof(value) == typeof(defaultValue),
					`template "{template:GetFullName()}": invalid custom attribute {name}`
				)
				resolved[name] = value
			end
		end
	end
	return {
		Attributes = resolved,
		Size = parameters.Size,
		Pause = function(_self: Types.Parameters)
			parameters:Pause()
		end,
	}
end

return Util
