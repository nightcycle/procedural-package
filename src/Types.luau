--!strict
local Type = require(script.Parent.Parent.Type)
local Types = {}

export type ExtraAttributes = { [string]: any }
export type Template = BasePart | Model
export type Bounds = { Center: Vector3, Size: Vector3 }
export type CallbackFn<V> = (
	inst: Template,
	parameters: GenerationFunctionParams<V & PackageAttributes>,
	targetContainer: GeneratedFolder
) -> ()

export type Parameters = GenerationFunctionParams<PackageAttributes>
export type TemplateGroup = { Template: Template, Parameters: Parameters, Count: number }

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
export type PackageAttributes = {
	SourcePath: string, -- where the original template is found, if a folder it will randomly select one of the basePart / model descendants using the seed
	SourcePathDelimiter: string, -- in case you want to use "/" instead of "." for the path
	SourceMaxYield: number, -- how long to wait for the template to appear (if streaming enabled keep high, if not, do whatever)
	PauseInterval: number, -- positive integer loop iterations between cooperative pauses
	GeneratedAlignment: AlignType, -- Center places the selected pivot at the cell center; Floor places it on the bottom of the generation box
	GeneratedSurfaceDetectionMethod: SurfaceDetectionMethod, -- None preserves placement; casts skip copies without a supporting surface
	GeneratedPivotMethod: PivotMethod, -- PrimaryPart variants use that part when assigned; otherwise use the matching Pivot/Center/Bottom/Top behavior
	GeneratedScaleMethod: ScaleMethod, -- Stretch sizes BaseParts to the cell and fits Models; Fit is uniform but never increases past template size (for scale = 1), Fill is fit with increasing; Height matches cell height
	GeneratedScaleReference: ScaleReference, -- determines what a scale of "1" is for the template
	GeneratedPadding: UDim, -- minimum separation between instances; a single seeded gap is sampled per generation
	GeneratedExcludedTags: string, -- comma-delimited tags; matching candidates and their subtrees are skipped during folder selection
	GeneratedCount: NumberRange, -- inclusive range of non-negative integer copy counts; template overrides set that selected template's total
	RandomSeed: number, -- used to keep regeneration deterministic
	RandomScale: NumberRange, -- finite positive uniform scale multiplier sampled per copy after GeneratedScaleMethod; 1 preserves size
	RandomRoll: NumberRange, -- X axis random rotation in degrees
	RandomPan: NumberRange, -- Y axis random rotation in degrees
	RandomTilt: NumberRange, -- Z axis random rotation in degrees
	RandomPlacement: PlacementType, -- Grid is X/Z on Floor or X/Y/Z in Center; Line follows X; Random shuffles and jitters cells
	PackageVersion: number, --used for backward compatibility
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
