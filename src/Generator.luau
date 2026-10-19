--!strict
-- Packages
local IndexUtil = require(script.Parent.Parent.IndexUtil)
-- Modules
local ENV = require(script.Parent.ENV)
local SourceUtil = require(script.Parent.SourceUtil)
local PlacementUtil = require(script.Parent.PlacementUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
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
		OnGenerate = function(parameters: Parameters, targetContainer: GeneratedFolder): ()
			DebugUtil.print("generating")
			targetContainer.Archivable = false
			local attributes = parameters.Attributes
			if attributes.SourcePath == "" then
				warn(`no SourcePath set`)
				return
			end
			local fullSize = parameters.Size
			assert(
				fullSize.X > 0 and fullSize.Y > 0 and fullSize.Z > 0,
				"generation Size must have positive dimensions"
			)
			assert(attributes.SourcePathDelimiter ~= "", "SourcePathDelimiter must not be empty")
			assert(attributes.SourceMaxYield >= 0, "SourceMaxYield must not be negative")
			local random = Random.new(attributes.RandomSeed)
			DebugUtil.print(`searching for source`)
			local source =
				IndexUtil.waitForPath(attributes.SourcePath, attributes.SourceMaxYield, attributes.SourcePathDelimiter)
			DebugUtil.print(`finished waiting for source`)
			assert(source, `failed to find template at path: {attributes.SourcePath}`)
			local extraAttributes = {}
			if extraDefaultAttributes then
				for k, v in extraDefaultAttributes do
					extraAttributes[k] = parameters.Attributes[k]
				end
			end
			do
				local success, msg = Types.PlacementType(attributes.RandomPlacement)
				if not success then
					error(`bad RandomPlacement value: {msg}`)
				end
			end
			do
				local success, msg = Types.AlignType(attributes.GeneratedAlignment)
				if not success then
					error(`bad GeneratedAlignment value: {msg}`)
				end
			end
			do
				local success, msg = Types.ScaleMethod(attributes.GeneratedScaleMethod)
				if not success then
					error(`bad GeneratedScaleMethod value: {msg}`)
				end
			end
			do
				local success, msg = Types.ScaleReference(attributes.GeneratedScaleReference)
				if not success then
					error(`bad GeneratedScaleReference value: {msg}`)
				end
			end
			local copies, layoutParameters = SourceUtil.getCopies(source, parameters, random, extraAttributes)
			local count = #copies
			if count == 0 then
				return
			end
			local pauseInterval = layoutParameters.Attributes.PauseInterval
			local grid = PlacementUtil.getGrid(fullSize, count, layoutParameters)
			local outerCellSize = fullSize / grid
			local paddingDimMag = math.min(outerCellSize.X, outerCellSize.Z)
					* layoutParameters.Attributes.GeneratedPadding.Scale
				+ layoutParameters.Attributes.GeneratedPadding.Offset
			local innerCellSize = (Vector3.one * ENV.SMALL):Max(outerCellSize - (Vector3.one * 2 * paddingDimMag))
			local cells: { number } = {}
			for index = 1, grid.X * grid.Y * grid.Z do
				cells[index] = index - 1
				if index % pauseInterval == 0 then
					parameters:Pause()
				end
			end
			if attributes.RandomPlacement == "Random" then
				random:Shuffle(cells)
			end
			local placed: { Bounds } = {}
			local generatedByTemplate: { [Instance]: number } = {}
			for index, copy in copies do
				local template = copy.Template
				local copyParameters = copy.Parameters
				local copyAttributes = copyParameters.Attributes
				local rotation = CFrame.Angles(
					math.rad(random:NextNumber(copyAttributes.RandomRoll.Min, copyAttributes.RandomRoll.Max)),
					math.rad(random:NextNumber(copyAttributes.RandomPan.Min, copyAttributes.RandomPan.Max)),
					math.rad(random:NextNumber(copyAttributes.RandomTilt.Min, copyAttributes.RandomTilt.Max))
				)
				local scaleRange = copyAttributes.RandomScale
				local randomScale = if scaleRange.Min == scaleRange.Max
					then scaleRange.Min
					else random:NextNumber(scaleRange.Min, scaleRange.Max)
				local instance = SourceUtil.prepareClone(
					template,
					innerCellSize,
					rotation,
					copyAttributes.GeneratedScaleMethod,
					copyAttributes.GeneratedScaleReference,
					randomScale
				)
				local boundsCenter, boundsSize = GeometryUtil.getBounds(instance)
				local cellIndex = cells[index]
				local coordinates = Vector3.new(
					cellIndex % grid.X,
					math.floor(cellIndex / (grid.X * grid.Z)),
					math.floor(cellIndex / grid.X) % grid.Z
				)
				local center = -fullSize / 2 + outerCellSize / 2 + coordinates * outerCellSize

				if attributes.RandomPlacement == "Random" then
					local available = Vector3.new(
						math.max(0, innerCellSize.X - boundsSize.X),
						math.max(0, innerCellSize.Y - boundsSize.Y),
						math.max(0, innerCellSize.Z - boundsSize.Z)
					)
					center += Vector3.new(
						random:NextNumber(-0.5, 0.5) * available.X,
						random:NextNumber(-0.5, 0.5) * available.Y,
						random:NextNumber(-0.5, 0.5) * available.Z
					)
				end
				if copyAttributes.GeneratedAlignment == "Floor" then
					local cellBottom = -fullSize.Y / 2 + coordinates.Y * outerCellSize.Y
					center = Vector3.new(center.X, cellBottom + boundsSize.Y / 2, center.Z)
				end
				table.insert(placed, { Center = center, Size = boundsSize })
				instance:PivotTo(CFrame.new(center - boundsCenter) * instance:GetPivot())
				if fn then
					fn(instance, layoutParameters, targetContainer)
				end
				(instance :: Instance).Parent = targetContainer

				if ENV.DEBUG_OUTER_CELL_ENABLED then
					local part, _box = DebugUtil.debugRegion(CFrame.new(center), outerCellSize, Color3.new(1, 0, 0))
					part.Name = `Outer`
					part.Parent = instance
				end
				if ENV.DEBUG_INNER_CELL_ENABLED then
					do
						local _templateCenter, tempateSize = GeometryUtil.getBounds(template)
						local part, _box = DebugUtil.debugRegion(CFrame.new(center), tempateSize, Color3.new(0, 1, 1))
						part.Name = `Original`
						part.Parent = instance
					end
					do
						local part, _box = DebugUtil.debugRegion(CFrame.new(center), innerCellSize, Color3.new(0, 0, 1))
						part.Name = `Inner`
						part.Parent = instance
					end
				end
				local generated = (generatedByTemplate[template] or 0) + 1
				generatedByTemplate[template] = generated
				if generated % copyAttributes.PauseInterval == 0 then
					copyParameters:Pause()
				end
			end
			if ENV.DEBUG_AREA_ENABLED then
				local part, box = DebugUtil.debugRegion(CFrame.new(0, 0, 0), parameters.Size, Color3.new(1, 1, 0))
				box.LineThickness *= 2
				part.Name = `Area`
				part.Parent = targetContainer
			end
			for i, v in targetContainer:GetDescendants() do
				v.Archivable = false
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
