--!strict
local Type = require(script.Parent.Parent.Type)
local Types = {}

export type ExtraAttributes = { [string]: any }
export type Template = BasePart | Model
export type Bounds = { Center: Vector3, Size: Vector3 }
export type CallbackFn<Attributes> = (
	inst: Template,
	parameters: GenerationFunctionParams<Attributes>,
	targetContainer: GeneratedFolder
) -> ()

export type TemplateGroup<Attributes> = {
	Template: Template,
	Parameters: GenerationFunctionParams<Attributes>,
	Count: number,
}

function betterLiteral(...: any): typeof(Type.literal())
	local params = { ... }
	return function(v: unknown?): boolean
		for i, literal in params do
			if literal == v then
				return true
			end
		end
		return false, `received "{v}", expected one of the following: {table.concat(params, ", ")}`
	end
end

export type AlignType = "Center" | "Floor"
Types.AlignType = betterLiteral("Center", "Floor")
export type SurfaceDetectionMethod = "Raycast" | "Shapecast" | "None"
Types.SurfaceDetectionMethod = betterLiteral("Raycast", "Shapecast", "None")
export type PivotMethod =
	"Pivot"
	| "Center"
	| "Bottom"
	| "Top"
	| "PrimaryPartPivot"
	| "PrimaryPartCenter"
	| "PrimaryPartBottom"
	| "PrimaryPartTop"
Types.PivotMethod = betterLiteral(
	"Pivot",
	"Center",
	"Bottom",
	"Top",
	"PrimaryPartPivot",
	"PrimaryPartCenter",
	"PrimaryPartBottom",
	"PrimaryPartTop"
)
export type ScaleReference = "Height" | "Average" | "Min" | "Max"
Types.ScaleReference = betterLiteral("Height", "Average", "Min", "Max")
export type ScaleMethod = "Stretch" | "Fill" | "Fit"
Types.ScaleMethod = betterLiteral("Stretch", "Fill", "Fit")
export type PlacementType = "Grid" | "Random" | "Line" -- partially constrained by AlignType
Types.PlacementType = betterLiteral("Grid", "Random", "Line")

-- Templates may override PauseInterval, GeneratedAlignment/PivotMethod/SurfaceDetectionMethod/ScaleMethod/Count, and RandomScale/Roll/Pan/Tilt.
-- Source settings, RandomSeed, tag fields, RandomPlacement, and RandomPadding stay package-controlled.

export type BaseSourceAttributes = {
	Source_Path: string, -- where the original template is found, if a folder it will randomly select one of the basePart / model descendants using the seed
	Source_PathDelimiter: string, -- in case you want to use "/" instead of "." for the path
	Source_MaxYield: number, -- how long to wait for the template to appear (if streaming enabled keep high, if not, do whatever)
	Source_PivotMethod: PivotMethod, -- PrimaryPart variants use that part when assigned; otherwise use the matching Pivot/Center/Bottom/Top behavior
	Source_ScaleMethod: ScaleMethod, -- Stretch sizes BaseParts to the cell and fits Models; Fit is uniform but never increases past template size (for scale = 1), Fill is fit with increasing; Height matches cell height
	Source_ScaleReference: ScaleReference, -- determines what a scale of "1" is for the template
	Source_Padding: UDim, -- minimum separation between instances; a single seeded gap is sampled per generation
	Source_Alignment: AlignType, -- Center places the selected pivot at the cell center; Floor places it on the bottom of the generation box
	Source_ExcludedTags: string, -- comma-delimited tags; matching candidates and their subtrees are skipped during folder selection
}
export type BaseRandomAttributes = {
	Random_Seed: number, -- used to keep regeneration deterministic
	Random_Scale: NumberRange, -- finite positive uniform scale multiplier sampled per copy after GeneratedScaleMethod; 1 preserves size
	Random_Roll: NumberRange, -- X axis random rotation in degrees
	Random_Pan: NumberRange, -- Y axis random rotation in degrees
	Random_Tilt: NumberRange, -- Z axis random rotation in degrees
}

export type LayoutType = "Single" | "SurfaceGrid" | "SurfaceRandom" | "SurfaceCurvedLine"
Types.LayoutType = betterLiteral("") -- @TODO

export type BaseLayoutAttributes = {
	Layout_PauseInterval: number, -- positive integer loop iterations between cooperative pauses
	Layout_Type: LayoutType,
}
export type BaseSurfaceLayoutAttributes = BaseLayoutAttributes & {
	Layout_SurfaceDetectionMethod: SurfaceDetectionMethod, -- None preserves placement; casts skip copies without a supporting surface
}
export type SurfaceGridLayoutAttributes = BaseSurfaceLayoutAttributes & {
	Layout_ColumnLimit: NumberRange, -- a min / max range of for number of columns to allow, clamping the math accordingly
	Layout_RowLimit: NumberRange, -- a min / max range of for number of rows to allow, clamping the math accordingly
}
export type SurfaceRandomLayoutAttributes = BaseSurfaceLayoutAttributes & {
	Layout_PopulationLimit: NumberRange, -- a min / max range of for number of copies to allow, clamping the math accordingly
}

export type SurfaceRandomLayoutAttributes = BaseSurfaceLayoutAttributes & {
	Layout_PopulationLimit: NumberRange, -- a min / max range of for number of copies to allow, clamping the math accordingly
}

export type GenerationFunctionParams<Attributes> = {
	Attributes: Attributes,
	Size: Vector3,
	Pause: (self: GenerationFunctionParams<Attributes>) -> (),
}

export type GeneratorModuleDefinition<Attributes> = {
	Attributes: Attributes,
	OnGenerate: (parameters: GenerationFunctionParams<Attributes>, targetContainer: GeneratedFolder) -> (),
}

return Types
