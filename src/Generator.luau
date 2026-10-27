--!strict
local ENV = require(script.Parent.ENV)
local Types = require(script.Parent.Types)
local ParameterUtil = require(script.Parent.ParameterUtil)
local SourceUtil = require(script.Parent.SourceUtil)
local PlacementUtil = require(script.Parent.PlacementUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
local DebugUtil = require(script.Parent.DebugUtil)

local function newGenerator(
	extraDefaults: Types.ExtraAttributes?,
	callback: Types.CallbackFn<Types.PackageAttributes & Types.ExtraAttributes>?,
	model: ProceduralModel?
): Types.GeneratorModuleDefinition<Types.PackageAttributes & Types.ExtraAttributes>
	local selected: Types.LayoutType? = nil
	if model then
		local value = model:GetAttribute("Layout_Type")
		if Types.LayoutType(value) then
			selected = value :: Types.LayoutType
		end
	end
	local defaults = ParameterUtil.getDefaults(extraDefaults, selected)
	local disconnect = if model then ParameterUtil.bindAttributes(model, defaults) else nil
	return {
		Attributes = defaults,
		Destroy = disconnect,
		OnGenerate = function(
			input: Types.GenerationFunctionParams<Types.PackageAttributes & Types.ExtraAttributes>,
			target: GeneratedFolder
		)
			local parameters = ParameterUtil.resolve(input)
			local layout = ParameterUtil.validate(parameters)
			if parameters.Attributes.Source_Path == "" then
				warn("no Source_Path set")
				return
			end
			local random = Random.new(parameters.Attributes.Random_Seed)
			local templates = SourceUtil.run(parameters)
			-- Use the largest source footprint so mixed folders have stable, conservative grid spacing.
			local templateSize = Vector3.zero
			for index, template in templates do
				local _, size = GeometryUtil.getBounds(template)
				templateSize = templateSize:Max(size)
				if index % parameters.Attributes.Layout_PauseInterval == 0 then
					parameters:Pause()
				end
			end
			assert(
				templateSize.X > 0 and templateSize.Y > 0 and templateSize.Z > 0,
				"sources must have positive dimensions"
			)
			local cells = layout.GetCells(parameters, templateSize, random)
			local copies = SourceUtil.getCopies(templates, #cells, parameters, random, extraDefaults)
			PlacementUtil.run(parameters, copies, cells, random, target, callback, model)
			if ENV.DEBUG_AREA_ENABLED then
				local part, box = DebugUtil.debugRegion(CFrame.identity, parameters.Size, Color3.new(1, 1, 0))
				box.LineThickness *= 2
				part.Name = "Area"
				part.Parent = target
			end
		end,
	}
end

local Generator = {}

function Generator.new(model: ProceduralModel?): Types.GeneratorModuleDefinition<Types.PackageAttributes>
	return newGenerator(nil, nil, model)
end

function Generator.append<Attributes>(
	defaults: Attributes,
	callback: Types.CallbackFn<Attributes & Types.PackageAttributes>,
	model: ProceduralModel?
): Types.GeneratorModuleDefinition<Attributes & Types.PackageAttributes>
	-- Generic custom attributes are checked by ParameterUtil at the engine attribute boundary.
	return newGenerator(defaults :: any, callback :: any, model) :: any
end

return Generator
