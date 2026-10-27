--!strict
local Types = {}

export type ExtraAttributes = { [string]: any }
export type Template = BasePart | Model
export type Bounds = { Center: Vector3, Size: Vector3 }
export type AlignType = "Center" | "Floor"
export type SurfaceDetectionMethod = "Raycast" | "Shapecast" | "None"
export type PivotMethod =
	"Pivot"
	| "Center"
	| "Bottom"
	| "Top"
	| "PrimaryPartPivot"
	| "PrimaryPartCenter"
	| "PrimaryPartBottom"
	| "PrimaryPartTop"
export type ScaleReference = "Height" | "Average" | "Min" | "Max"
export type ScaleMethod = "Stretch" | "Fill" | "Fit"
export type LayoutType = "Single" | "SurfaceGrid" | "SurfaceRandom" | "SurfaceCurvedLine"

local function literal(...: string): (unknown) -> boolean
	local values = { ... }
	return function(value: unknown): boolean
		for _, candidate in values do
			if value == candidate then
				return true
			end
		end
		return false
	end
end

Types.AlignType = literal("Center", "Floor")
Types.SurfaceDetectionMethod = literal("Raycast", "Shapecast", "None")
Types.PivotMethod = literal(
	"Pivot",
	"Center",
	"Bottom",
	"Top",
	"PrimaryPartPivot",
	"PrimaryPartCenter",
	"PrimaryPartBottom",
	"PrimaryPartTop"
)
Types.ScaleReference = literal("Height", "Average", "Min", "Max")
Types.ScaleMethod = literal("Stretch", "Fill", "Fit")
Types.LayoutType = literal("Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine")

export type BaseSourceAttributes = {
	Source_Path: string,
	Source_PathDelimiter: string,
	Source_MaxYield: number,
	Source_PivotMethod: PivotMethod,
	Source_ScaleMethod: ScaleMethod,
	Source_ScaleReference: ScaleReference,
	Source_Padding: UDim,
	Source_Alignment: AlignType,
	Source_ExcludedTags: string,
}
export type BaseRandomAttributes = {
	Random_Seed: number,
	Random_Scale: NumberRange,
	Random_Roll: NumberRange,
	Random_Pan: NumberRange,
	Random_Tilt: NumberRange,
}
export type BaseLayoutAttributes = {
	Layout_PauseInterval: number,
	Layout_Type: LayoutType,
}
export type SingleLayoutAttributes = BaseLayoutAttributes
export type BaseSurfaceLayoutAttributes = BaseLayoutAttributes & {
	Layout_SurfaceDetectionMethod: SurfaceDetectionMethod,
}
export type SurfaceGridLayoutAttributes = BaseSurfaceLayoutAttributes & {
	Layout_ColumnLimit: NumberRange,
	Layout_RowLimit: NumberRange,
}
export type SurfaceRandomLayoutAttributes = BaseSurfaceLayoutAttributes & {
	Layout_PopulationLimit: NumberRange,
}
export type SurfaceCurvedLineLayoutAttributes = SurfaceRandomLayoutAttributes & {
	Layout_CurveSize0: number,
	Layout_CurveSize1: number,
}
-- Public model attributes contain only the fields owned by the selected layout.
export type PackageAttributes = BaseSourceAttributes & BaseRandomAttributes & BaseLayoutAttributes & {
	Layout_SurfaceDetectionMethod: SurfaceDetectionMethod?,
	Layout_ColumnLimit: NumberRange?,
	Layout_RowLimit: NumberRange?,
	Layout_PopulationLimit: NumberRange?,
	Layout_CurveSize0: number?,
	Layout_CurveSize1: number?,
}
-- Internal math receives a complete snapshot, without adding hidden fields to the model.
export type ResolvedPackageAttributes =
	BaseSourceAttributes
	& BaseRandomAttributes
	& SurfaceGridLayoutAttributes
	& SurfaceCurvedLineLayoutAttributes
export type GenerationFunctionParams<Attributes> = {
	Attributes: Attributes,
	Size: Vector3,
	Pause: (self: GenerationFunctionParams<Attributes>) -> (),
}
export type Parameters = GenerationFunctionParams<ResolvedPackageAttributes & ExtraAttributes>
export type CallbackFn<Attributes> = (Template, GenerationFunctionParams<Attributes>, GeneratedFolder) -> ()
export type TemplateGroup = { Template: Template, Parameters: Parameters }
export type GeneratorModuleDefinition<Attributes> = {
	Attributes: Attributes,
	OnGenerate: (GenerationFunctionParams<Attributes>, GeneratedFolder) -> (),
	Destroy: (() -> ())?,
}
export type ParameterDefinition = {
	Default: () -> unknown,
	Validate: (unknown) -> boolean,
	TemplateOverride: boolean,
}
export type ParameterSchema = { [string]: ParameterDefinition }
export type Cell = { Frame: CFrame, Size: Vector3, Offset: Vector3? }
export type Layout = {
	Parameters: ParameterSchema,
	GetCells: (Parameters, Vector3, Random) -> { Cell },
}

return Types
