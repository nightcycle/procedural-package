--!strict
-- Packages
-- Modules
-- Types
local Types = require(script.Parent.Types)
type Template = Types.Template
type ExtraAttributes = Types.ExtraAttributes
type Parameters = Types.GenerationFunctionParams<Types.PackageAttributes>
-- Constants
-- Private Functions
-- Class
local Util = {}

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

function Util.getRangeAttribute(template: Template, name: string, fallback: NumberRange): NumberRange
	local value: unknown = template:GetAttribute(name)
	if value == nil then
		return fallback
	end
	assert(typeof(value) == "NumberRange", `template "{template:GetFullName()}" attribute {name} must be a NumberRange`)
	return value
end

function Util.resolveTemplateAttributes(
	template: Template,
	attributes: Types.PackageAttributes,
	extraAttributes: ExtraAttributes
): Types.PackageAttributes
	local resolved = table.clone(attributes)
	local pauseInterval: unknown = template:GetAttribute("PauseInterval")
	if pauseInterval ~= nil then
		assert(
			typeof(pauseInterval) == "number",
			`template "{template:GetFullName()}" attribute PauseInterval must be a number`
		)
		resolved.PauseInterval = pauseInterval
	end
	local alignment: unknown = template:GetAttribute("GeneratedAlignment")
	if alignment ~= nil then
		assert(
			alignment == "Center" or alignment == "Floor",
			`template "{template:GetFullName()}" attribute GeneratedAlignment must be Center or Floor`
		)
		resolved.GeneratedAlignment = alignment
	end
	local pivotMethod: unknown = template:GetAttribute("GeneratedPivotMethod")
	if pivotMethod ~= nil then
		local success, msg = Types.PivotMethod(pivotMethod)
		assert(
			success,
			`template "{template:GetFullName()}" has unknown value for attribute "GeneratedPivotMethod": {msg}`
		)
		resolved.GeneratedPivotMethod = pivotMethod :: Types.PivotMethod
	end
	local scaleType: unknown = template:GetAttribute("GeneratedScaleMethod")
	if scaleType ~= nil then
		local success, msg = Types.ScaleMethod(scaleType)
		assert(
			success,
			`template "{template:GetFullName()}" has unknown value for attribute "GeneratedScaleMethod": {msg}`
		)
		resolved.GeneratedScaleMethod = scaleType :: any
	end
	resolved.GeneratedCount = Util.getRangeAttribute(template, "GeneratedCount", attributes.GeneratedCount)
	resolved.RandomScale = Util.getRangeAttribute(template, "RandomScale", attributes.RandomScale)
	assert(
		resolved.RandomScale.Min > 0 and resolved.RandomScale.Max < math.huge,
		"RandomScale must contain finite positive scale factors"
	)
	resolved.RandomRoll = Util.getRangeAttribute(template, "RandomRoll", attributes.RandomRoll)
	resolved.RandomPan = Util.getRangeAttribute(template, "RandomPan", attributes.RandomPan)
	resolved.RandomTilt = Util.getRangeAttribute(template, "RandomTilt", attributes.RandomTilt)
	for k, v in extraAttributes do
		local tempV = template:GetAttribute(k)
		if type(tempV) == "nil" then
			resolved[k] = v
			continue
		elseif type(tempV) == type(v) then
			resolved[k] = tempV
		end
	end
	resolved.GeneratedScaleMethod = if resolved.RandomPlacement == "Random"
		then "Fit"
		else resolved.GeneratedScaleMethod
	return resolved
end

function Util.withAttributes(parameters: Parameters, attributes: Types.PackageAttributes): Parameters
	return {
		Attributes = attributes,
		Size = parameters.Size,
		Pause = function(_self: Parameters)
			parameters:Pause()
		end,
	}
end

function Util.validatePauseInterval(attributes: Types.PackageAttributes)
	local interval = attributes.PauseInterval
	assert(
		interval >= 1 and interval < math.huge and interval % 1 == 0,
		"PauseInterval must be a finite positive integer"
	)
end
return Util
