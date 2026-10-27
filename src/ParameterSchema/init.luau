--!strict
local Types = require(script.Parent.Types)
local Schema = {}

function Schema.field(
	default: () -> unknown,
	validate: Types.Validator,
	templateOverride: boolean?
): Types.ParameterDefinition
	return { Default = default, Validate = validate, TemplateOverride = templateOverride == true }
end

function Schema.finite(value: unknown): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

function Schema.udim(value: unknown): boolean
	return typeof(value) == "UDim" and Schema.finite(value.Scale) and Schema.finite(value.Offset)
end

function Schema.nonNegative(value: unknown): boolean
	return Schema.finite(value) and (value :: number) >= 0
end

function Schema.positiveInteger(value: unknown): boolean
	return Schema.finite(value) and (value :: number) >= 1 and (value :: number) % 1 == 0
end

function Schema.range(value: unknown): boolean
	return typeof(value) == "NumberRange" and Schema.finite(value.Min) and Schema.finite(value.Max)
end

function Schema.scaleRange(value: unknown): boolean
	return Schema.range(value) and (value :: NumberRange).Min > 0
end

function Schema.countRange(value: unknown): boolean
	return Schema.range(value)
		and (value :: NumberRange).Min >= 0
		and math.ceil((value :: NumberRange).Min) <= math.floor((value :: NumberRange).Max)
end

function Schema.dimensionRange(value: unknown): boolean
	return Schema.countRange(value)
end

function Schema.vector(value: unknown): boolean
	return typeof(value) == "Vector3" and Schema.finite(value.X) and Schema.finite(value.Y) and Schema.finite(value.Z)
end

return Schema
