--!strict
-- Packages
local IndexUtil = require(script.Parent.Parent.IndexUtil)
-- Modules
local ParameterUtil = require(script.Parent.ParameterUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
local DebugUtil = require(script.Parent.DebugUtil)
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type Template = Types.Template
type TemplateGroup = Types.TemplateGroup
type ExtraAttributes = Types.ExtraAttributes
-- Constants
-- Private Functions
local function sampleCount(range: NumberRange, random: Random): number
	local minimum, maximum = math.ceil(range.Min), math.floor(range.Max)
	assert(minimum >= 0 and minimum <= maximum, "GeneratedCount must contain a non-negative integer")
	return random:NextInteger(minimum, maximum)
end

-- Class
local Util = {}

function Util.getTemplates(source: Instance, parameters: Parameters): { Template }
	if source:IsA("BasePart") or source:IsA("Model") then
		return { source }
	end
	assert(source:IsA("Folder"), `unsupported source type: "{source.ClassName}"`)
	local excludedTags = ParameterUtil.parseTags(parameters.Attributes.GeneratedExcludedTags)
	local function isExcluded(candidate: Instance): boolean
		for _, tag in excludedTags do
			if candidate:HasTag(tag) then
				return true
			end
		end
		return false
	end
	local templates: { Template } = {}
	local function gatherTemplates(root: Instance)
		for _, v in root:GetChildren() do
			if isExcluded(v) then
				continue
			end
			if v:IsA("Model") or v:IsA("BasePart") then
				table.insert(templates, v)
			else
				gatherTemplates(v)
			end
		end
	end
	gatherTemplates(source)

	-- Uniquely named templates retain their selection order when insertion order changes.
	table.sort(templates, function(a, b)
		local aPath, bPath = a:GetFullName(), b:GetFullName()
		return if aPath == bPath then a.ClassName < b.ClassName else aPath < bPath
	end)

	assert(
		#templates > 0,
		`source folder "{source:GetFullName()}" contains no eligible BaseParts or Models after applying GeneratedExcludedTags`
	)

	return templates
end

function Util.getCopies(
	source: Instance,
	parameters: Parameters,
	random: Random,
	extraAttributes: ExtraAttributes
): ({ TemplateGroup }, Parameters)
	local templates = Util.getTemplates(source, parameters)
	local groups: { TemplateGroup } = {}
	local selected: { TemplateGroup } = {}
	local layoutParameters = parameters
	if not source:IsA("Folder") then
		local template = templates[1]
		layoutParameters = ParameterUtil.withAttributes(
			parameters,
			ParameterUtil.resolveTemplateAttributes(template, parameters.Attributes, extraAttributes)
		)
		ParameterUtil.validatePauseInterval(layoutParameters.Attributes)
		table.insert(groups, {
			Template = template,
			Parameters = layoutParameters,
			Count = sampleCount(layoutParameters.Attributes.GeneratedCount, random),
		})
	else
		ParameterUtil.validatePauseInterval(parameters.Attributes)
		local count = sampleCount(parameters.Attributes.GeneratedCount, random)
		local byTemplate: { [Instance]: TemplateGroup } = {}
		local function getGroup(template: Template): TemplateGroup
			local existing = byTemplate[template]
			if existing then
				return existing
			end
			local scoped = ParameterUtil.withAttributes(
				parameters,
				ParameterUtil.resolveTemplateAttributes(template, parameters.Attributes, extraAttributes)
			)
			ParameterUtil.validatePauseInterval(scoped.Attributes)
			local group: TemplateGroup = { Template = template, Parameters = scoped, Count = 0 }
			byTemplate[template] = group
			table.insert(groups, group)
			return group
		end
		for index = 1, count do
			local template = templates[random:NextInteger(1, #templates)]
			local group = getGroup(template)
			group.Count += 1
			table.insert(selected, group)
			if index % parameters.Attributes.PauseInterval == 0 then
				parameters:Pause()
			end
		end
		for _, group in groups do
			if group.Template:GetAttribute("GeneratedCount") ~= nil then
				group.Count = sampleCount(group.Parameters.Attributes.GeneratedCount, random)
			end
		end
	end

	local copies: { TemplateGroup } = {}
	-- Preserve selection order where possible, then append extra copies requested by a template.
	for index, group in selected do
		if group.Count > 0 then
			table.insert(copies, group)
			group.Count -= 1
		end
		if index % parameters.Attributes.PauseInterval == 0 then
			parameters:Pause()
		end
	end
	for _, group in groups do
		for index = 1, group.Count do
			table.insert(copies, group)
			if index % group.Parameters.Attributes.PauseInterval == 0 then
				group.Parameters:Pause()
			end
		end
	end
	return copies, layoutParameters
end

function Util.prepareClone(
	template: Template,
	size: Vector3,
	rotation: CFrame,
	scaleMethod: Types.ScaleMethod,
	scaleRef: Types.ScaleReference,
	randomScale: number,
	padding: UDim,
	pivotMethod: Types.PivotMethod
): Template
	assert(template.Archivable, `template "{template:GetFullName()}" must be Archivable`)
	local instance = template:Clone()
	if pivotMethod ~= "Pivot" then
		GeometryUtil.setPivot(instance, GeometryUtil.getGeneratedPivot(instance, pivotMethod))
	end
	-- Measure in the generated orientation, including any native pivot rotation.
	instance:PivotTo(rotation)
	size -= padding.Offset * Vector3.one * 2
	local uniformScale = randomScale
	if instance:IsA("BasePart") and scaleMethod == "Stretch" then
		local rescale = size / instance.Size
		local baseOffset = instance.PivotOffset
		instance.Size *= rescale
		instance.PivotOffset =
			CFrame.fromMatrix(baseOffset.Position * rescale, baseOffset.XVector, baseOffset.YVector, baseOffset.ZVector)
	else
		local sourceFrame, sourceSize = GeometryUtil.getBounds(instance)
		local sizeOverride = template:GetAttribute("Size")
		if typeof(sizeOverride) == "Vector3" then
			-- Model overrides describe dimensions at scale 1, as in the original generator.
			local templateScale = if instance:IsA("Model") then instance:GetScale() else 1
			sourceSize = GeometryUtil.axisAlignedSize(sourceFrame, sizeOverride * templateScale)
		end
		assert(
			sourceSize.X > 0 and sourceSize.Y > 0 and sourceSize.Z > 0,
			`template "{template:GetFullName()}" must have positive dimensions`
		)

		local scale = 1
		if scaleRef == "Height" then
			scale = size.Y / sourceSize.Y
		elseif scaleRef == "Min" then
			scale = math.min(size.X / sourceSize.X, size.Y / sourceSize.Y, size.Z / sourceSize.Z)
		elseif scaleRef == "Max" then
			scale = math.max(size.X / sourceSize.X, size.Y / sourceSize.Y, size.Z / sourceSize.Z)
		elseif scaleRef == "Average" then
			scale = ((size.X / sourceSize.X) + (size.Y / sourceSize.Y) + (size.Z / sourceSize.Z)) / 3
		else -- stretch for models
			scale = math.min(size.X / sourceSize.X, size.Y / sourceSize.Y, size.Z / sourceSize.Z)
		end
		if scaleMethod == "Fit" then
			scale = math.min(scale, 1)
		end
		uniformScale *= scale * (1 - padding.Scale * 2)
	end
	-- Apply the combined multiplier once so a minimum Model scale clamp does not
	-- distort the result when RandomScale follows the fitting scale.
	if uniformScale ~= 1 then
		GeometryUtil.scaleInstance(instance, uniformScale)
	end
	instance:PivotTo(rotation)
	return instance
end

function Util.run(
	random: Random,
	parameters: Types.Parameters,
	extraDefaultAttributes: Types.ExtraAttributes?
): ({ TemplateGroup }, Parameters)
	local attributes = parameters.Attributes
	local fullSize = parameters.Size
	assert(fullSize.X > 0 and fullSize.Y > 0 and fullSize.Z > 0, "generation Size must have positive dimensions")
	assert(attributes.SourcePathDelimiter ~= "", "SourcePathDelimiter must not be empty")
	assert(attributes.SourceMaxYield >= 0, "SourceMaxYield must not be negative")
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
		local success, msg = Types.PivotMethod(attributes.GeneratedPivotMethod)
		if not success then
			error(`bad GeneratedPivotMethod value: {msg}`)
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
	return Util.getCopies(source, parameters, random, extraAttributes)
end

return Util
