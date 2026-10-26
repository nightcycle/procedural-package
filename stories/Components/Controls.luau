--!strict
export type Values = { [string]: unknown }
local Controls = {}

function Controls.number(values: Values, name: string): number
	local value = values[name]
	assert(
		typeof(value) == "number" and value == value and math.abs(value) < math.huge,
		`invalid number control {name}`
	)
	return value
end

function Controls.boolean(values: Values, name: string): boolean
	local value = values[name]
	assert(typeof(value) == "boolean", `invalid boolean control {name}`)
	return value
end

function Controls.string(values: Values, name: string): string
	local value = values[name]
	assert(typeof(value) == "string", `invalid string control {name}`)
	return value
end

function Controls.choose<T>(values: Values, name: string, options: { T }): T
	for _, option in options do
		if values[name] == option then
			return option
		end
	end
	error(`invalid choice control {name}`)
end

return Controls
