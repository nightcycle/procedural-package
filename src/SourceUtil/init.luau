--!strict
local IndexUtil = require(script.Parent.Parent.IndexUtil)
local ParameterUtil = require(script.Parent.ParameterUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
local Types = require(script.Parent.Types)
type Template = Types.Template
type Parameters = Types.Parameters
local Util = {}
function Util.getTemplates(source: Instance, parameters: Parameters): { Template }
	if source:IsA("BasePart") or source:IsA("Model") then
		return { source }
	end
	assert(source:IsA("Folder"), `unsupported source type: "{source.ClassName}"`)
	local excludedTags = ParameterUtil.parseTags(parameters.Attributes.Source_ExcludedTags)
	local function isExcluded(candidate: Instance): boolean
		for _, tag in excludedTags do
			if candidate:HasTag(tag) then
				return true
			end
		end
		return false
	end
	local templates: { Template } = {}
	local visited = 0
	local function gatherTemplates(root: Instance)
		for _, v in root:GetChildren() do
			visited += 1
			if visited % parameters.Attributes.Layout_PauseInterval == 0 then
				parameters:Pause()
			end
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
		`source folder "{source:GetFullName()}" contains no eligible BaseParts or Models after applying Source_ExcludedTags`
	)

	return templates
end

function Util.prepareClone(
	template: Template,
	size: Vector3,
	rotation: CFrame,
	scaleMethod: Types.ScaleMethod,
	scaleRef: Types.ScaleReference,
	randomScale: number,
	padding: UDim,
	pivotMethod: Types.PivotMethod,
	paddingAxes: Vector3?
): Template
	assert(template.Archivable, `template "{template:GetFullName()}" must be Archivable`)
	local instance = template:Clone()
	if pivotMethod ~= "Pivot" then
		GeometryUtil.setPivot(instance, GeometryUtil.getGeneratedPivot(instance, pivotMethod))
	end
	-- Measure in the generated orientation, including any native pivot rotation.
	instance:PivotTo(rotation)
	local axes = paddingAxes or Vector3.one
	-- Inset the target dimensions before fitting, so unpadded axes keep their full extent.
	size = (size - axes * padding.Offset * 2) * (Vector3.one - axes * padding.Scale * 2)
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, "Source_Padding.Offset leaves no room inside the layout cell")
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
		uniformScale *= scale
	end
	-- Apply the combined multiplier once so a minimum Model scale clamp does not
	-- distort the result when RandomScale follows the fitting scale.
	if uniformScale ~= 1 then
		GeometryUtil.scaleInstance(instance, uniformScale)
	end
	instance:PivotTo(rotation)
	return instance
end

-- Fit once against the generation area, before layout spacing or orientation.
function Util.prepareForLayout(template: Template, parameters: Parameters, randomScale: number): Template
	local attributes = parameters.Attributes
	return Util.prepareClone(
		template,
		parameters.Size,
		CFrame.identity,
		attributes.Source_ScaleMethod,
		attributes.Source_ScaleReference,
		randomScale,
		if attributes.Layout_Type == "Single" then UDim.new(0) else attributes.Source_Padding,
		attributes.Source_PivotMethod,
		Vector3.new(1, 0, 1)
	)
end

function Util.getLayoutSize(
	templates: { Template },
	parameters: Parameters,
	extraDefaults: Types.ExtraAttributes?
): Vector3
	local size = Vector3.zero
	for index, template in templates do
		local scoped = ParameterUtil.resolveTemplateAttributes(template, parameters, extraDefaults)
		-- Reserve the largest possible random scale without consuming the generation RNG.
		local instance = Util.prepareForLayout(template, scoped, scoped.Attributes.Random_Scale.Max)
		local _, boundsSize = GeometryUtil.getBounds(instance)
		instance:Destroy()
		size = size:Max(boundsSize)
		if index % parameters.Attributes.Layout_PauseInterval == 0 then
			parameters:Pause()
		end
	end
	assert(size.X > 0 and size.Y > 0 and size.Z > 0, "sources must have positive scaled dimensions")
	return size
end

function Util.getCopies(
	templates: { Template },
	count: number,
	parameters: Parameters,
	random: Random,
	extraDefaults: Types.ExtraAttributes?
): { Types.TemplateGroup }
	local byTemplate: { [Instance]: Types.TemplateGroup } = {}
	local copies: { Types.TemplateGroup } = {}
	for index = 1, count do
		local template = if #templates == 1 then templates[1] else templates[random:NextInteger(1, #templates)]
		local group = byTemplate[template]
		if not group then
			group = {
				Template = template,
				Parameters = ParameterUtil.resolveTemplateAttributes(template, parameters, extraDefaults),
			}
			byTemplate[template] = group
		end
		table.insert(copies, group)
		if index % parameters.Attributes.Layout_PauseInterval == 0 then
			parameters:Pause()
		end
	end
	return copies
end

function Util.run(parameters: Parameters): { Template }
	local attributes = parameters.Attributes
	local source =
		IndexUtil.waitForPath(attributes.Source_Path, attributes.Source_MaxYield, attributes.Source_PathDelimiter)
	assert(source, `failed to find template at path: {attributes.Source_Path}`)
	return Util.getTemplates(source, parameters)
end

return Util
