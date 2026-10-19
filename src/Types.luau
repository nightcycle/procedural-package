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
export type AlignType = "Center" | "Floor"
Types.AlignType = Type.literal("Center", "Floor")
export type ScaleType = "Default" | "Fit" | "Height"
Types.ScaleType = Type.literal("Default", "Fit", "Height")
export type PlacementType = "Grid" | "Random" | "Line" -- partially constrained by AlignType
Types.PlacementType = Type.literal("Grid", "Random", "Line")
-- Templates may override PauseInterval, GeneratedAlignment/Scale/Count, and RandomScale/Roll/Pan/Tilt.
-- Source settings, RandomSeed, tag fields, RandomPlacement, and RandomPadding stay package-controlled.
export type PackageAttributes = {
	SourcePath: string, -- where the original template is found, if a folder it will randomly select one of the basePart / model descendants using the seed
	SourcePathDelimiter: string, -- in case you want to use "/" instead of "." for the path
	SourceMaxYield: number, -- how long to wait for the template to appear (if streaming enabled keep high, if not, do whatever)
	PauseInterval: number, -- positive integer loop iterations between cooperative pauses
	GeneratedAlignment: AlignType, -- Center aligns within a cell; Floor rests on the bottom of the generation box
	GeneratedScaleType: ScaleType, -- Default sizes BaseParts to the cell and fits Models; Fit is uniform; Height matches cell height
	GeneratedTags: string, -- tags it will add to the copies of the template in comma delimited format (aka "tag1,tag2,tag3"), spaces immediately after commas are ignored
	GeneratedPadding: UDim, -- minimum separation between instances; a single seeded gap is sampled per generation
	GeneratedExcludedTags: string, -- comma-delimited tags; matching candidates and their subtrees are skipped during folder selection
	GeneratedCount: NumberRange, -- inclusive range of non-negative integer copy counts; template overrides set that selected template's total
	RandomSeed: number, -- used to keep regeneration deterministic
	RandomScale: NumberRange, -- finite positive uniform scale multiplier sampled per copy after GeneratedScaleType; 1 preserves size
	RandomRoll: NumberRange, -- X axis random rotation in degrees
	RandomPan: NumberRange, -- Y axis random rotation in degrees
	RandomTilt: NumberRange, -- Z axis random rotation in degrees
	RandomPlacement: PlacementType, -- Grid is X/Z on Floor or X/Y/Z in Center; Line follows X; Random shuffles and jitters cells
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
