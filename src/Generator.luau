--!strict
-- Packages
-- Modules
local ENV = require(script.Parent.ENV)
local SourceUtil = require(script.Parent.SourceUtil)
local PlacementUtil = require(script.Parent.PlacementUtil)
local DebugUtil = require(script.Parent.DebugUtil)
-- Types
local Types = require(script.Parent.Types)
type ExtraAttributes = Types.ExtraAttributes
type Template = Types.Template
type Bounds = Types.Bounds
type CallbackFn<V> = Types.CallbackFn<V>
type Parameters = Types.Parameters
type TemplateGroup = Types.TemplateGroup
-- Constants
-- Private Functions
-- Convert an oriented bounding box into bounds along the generation box's axes.
function newGenerator(
	extraDefaultAttributes: ExtraAttributes?,
	fn: CallbackFn<ExtraAttributes>?
): Types.GeneratorModuleDefinition<Types.PackageAttributes>
	local defaultAttributes: Types.PackageAttributes = {
		SourcePath = ENV.DEFAULT_SOURCE_PATH,
		SourcePathDelimiter = ENV.DEFAULT_SOURCE_PATH_DELIMITER,
		SourceMaxYield = ENV.DEFAULT_SOURCE_MAX_YIELD,
		PauseInterval = ENV.DEFAULT_PAUSE_INTERVAL,
		GeneratedAlignment = ENV.DEFAULT_GENERATED_ALIGNMENT,
		GeneratedPivotMethod = ENV.DEFAULT_GENERATED_PIVOT_METHOD,
		GeneratedScaleMethod = ENV.DEFAULT_GENERATED_SCALE_METHOD,
		GeneratedScaleReference = ENV.DEFAULT_GENERATED_SCALE_REFERENCE,
		GeneratedPadding = ENV.DEFAULT_GENERATED_PADDING,
		GeneratedExcludedTags = ENV.DEFAULT_GENERATED_EXCLUDED_TAGS,
		GeneratedCount = ENV.DEFAULT_GENERATED_COUNT,
		RandomSeed = ENV.DEFAULT_RANDOM_SEED,
		RandomScale = ENV.DEFAULT_RANDOM_SCALE,
		RandomRoll = ENV.DEFAULT_RANDOM_ROLL,
		RandomPan = ENV.DEFAULT_RANDOM_PAN,
		RandomTilt = ENV.DEFAULT_RANDOM_TILT,
		RandomPlacement = ENV.DEFAULT_RANDOM_PLACEMENT,
		PackageVersion = 2,
	}
	if extraDefaultAttributes then
		for k, v in extraDefaultAttributes do
			if defaultAttributes[k] == nil then
				defaultAttributes[k] = v
			end
		end
	end
	return {
		Attributes = defaultAttributes,
		OnGenerate = function(inputParameters: Parameters, targetContainer: GeneratedFolder): ()
			DebugUtil.print("generating")

			if inputParameters.Attributes.SourcePath == "" then
				warn(`no SourcePath set`)
				return
			end
			local random = Random.new(inputParameters.Attributes.RandomSeed)
			local copies, parameters = SourceUtil.run(random, inputParameters, extraDefaultAttributes)
			local count = #copies
			if count == 0 then
				return
			end
			if
				parameters.Attributes.RandomPlacement == "Grid"
				or parameters.Attributes.RandomPlacement == "Line"
				or parameters.Attributes.RandomPlacement == "Random"
			then
				PlacementUtil.runGrid(parameters, copies, random, targetContainer, fn)
			else
				error(`unknown placement method: {parameters.Attributes.RandomPlacement}`)
			end

			if ENV.DEBUG_AREA_ENABLED then
				local part, box = DebugUtil.debugRegion(CFrame.new(0, 0, 0), parameters.Size, Color3.new(1, 1, 0))
				box.LineThickness *= 2
				part.Name = `Area`
				part.Parent = targetContainer
			end
		end,
	}
end

-- Class
local Module = {}

Module.new = function()
	return newGenerator()
end

Module.append = function<Attributes>(
	defaultAttributes: Attributes,
	fn: CallbackFn<Attributes & Types.PackageAttributes>
): Types.GeneratorModuleDefinition<Attributes & Types.PackageAttributes>
	return newGenerator(defaultAttributes :: any, fn :: any) :: any
end

return Module
