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
export type HeightAxis = "X" | "Y" | "Z"
export type LayoutType =
	"Single"
	| "SurfaceGrid"
	| "SurfaceRandom"
	| "SurfaceCurvedLine"
	| "Stack"
	| "Arch"
	| "NGon"
	| "Grid"
	| "Random"

export type Validator = (unknown) -> (boolean, string?)

local function literal(...: string): Validator
	local values = { ... }
	local expected = `expected one of: "{table.concat(values, '", "')}"`
	return function(value: unknown): (boolean, string?)
		for _, candidate in values do
			if value == candidate then
				return true, nil
			end
		end
		return false, expected
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
Types.HeightAxis = literal("X", "Y", "Z")
Types.LayoutType =
	literal("Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine", "Stack", "Arch", "NGon", "Grid", "Random")

export type BaseSourceAttributes = {
	Source_Path: string,
	Source_PathDelimiter: string,
	Source_MaxYield: number,
	Source_PivotMethod: PivotMethod,
	Source_ScaleMethod: ScaleMethod,
	Source_ScaleReference: ScaleReference,
	Source_Alignment: AlignType,
	Source_ExcludedTags: string,
}
export type SolverAttributes = {
	Solver_Cast_Path: string,
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
	Layout_HeightAxis: HeightAxis,
}
export type SingleLayoutAttributes = BaseLayoutAttributes
export type BaseSurfaceLayoutAttributes = BaseLayoutAttributes & {
	Source_Padding: UDim,
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
	Layout_CurveSize0: UDim,
	Layout_CurveSize1: UDim,
}
export type StackLayoutAttributes = BaseLayoutAttributes & {
	Layout_PopulationLimit: NumberRange,
	Layout_BasePadding: UDim,
	Layout_TopPadding: UDim,
}
export type ArchLayoutAttributes = StackLayoutAttributes & { Layout_ArchShape: number }
export type NGonLayoutAttributes = BaseLayoutAttributes & { Layout_Sides: number }
export type GridLayoutAttributes = BaseLayoutAttributes & {
	Source_Padding: UDim,
	Layout_ColumnLimit: NumberRange,
	Layout_RowLimit: NumberRange,
	Layout_LayerLimit: NumberRange,
}
export type RandomLayoutAttributes = BaseLayoutAttributes & {
	Source_Padding: UDim,
	Layout_PopulationLimit: NumberRange,
}
-- Public model attributes contain only the fields owned by the selected layout.
export type PackageAttributes = BaseSourceAttributes & SolverAttributes & BaseRandomAttributes & BaseLayoutAttributes & {
	Source_Padding: UDim?,
	Layout_SurfaceDetectionMethod: SurfaceDetectionMethod?,
	Layout_ColumnLimit: NumberRange?,
	Layout_RowLimit: NumberRange?,
	Layout_LayerLimit: NumberRange?,
	Layout_PopulationLimit: NumberRange?,
	Layout_CurveSize0: UDim?,
	Layout_CurveSize1: UDim?,
	Layout_BasePadding: UDim?,
	Layout_TopPadding: UDim?,
	Layout_ArchShape: number?,
	Layout_Sides: number?,
}
-- Internal math receives a complete snapshot, without adding hidden fields to the model.
export type ResolvedPackageAttributes =
	BaseSourceAttributes
	& SolverAttributes
	& BaseRandomAttributes
	& SurfaceGridLayoutAttributes
	& SurfaceCurvedLineLayoutAttributes
	& ArchLayoutAttributes
	& NGonLayoutAttributes
	& GridLayoutAttributes
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
	Validate: Validator,
	TemplateOverride: boolean,
}
export type ParameterSchema = { [string]: ParameterDefinition }
export type Cell = { Frame: CFrame, Size: Vector3, Offset: Vector3?, FitSize: Vector3? }
export type Layout = {
	Parameters: ParameterSchema,
	Surface: boolean?,
	Volume: boolean?,
	-- Largest measured source bound; volume layouts use authored bounds before cell fitting.
	GetCells: (Parameters, Vector3, Random) -> { Cell },
}

-- Internal queries check only the target GeneratedFolder; external queries check surrounding geometry.
export type CastSolver = {
	raycast: (
		proceduralModel: ProceduralModel,
		parameters: Parameters,
		targetGeneratedFolder: GeneratedFolder,
		castingInternally: boolean,
		origin: Vector3,
		direction: Vector3
	) -> RaycastResult?,
	spherecast: (
		proceduralModel: ProceduralModel,
		parameters: Parameters,
		targetGeneratedFolder: GeneratedFolder,
		castingInternally: boolean,
		origin: Vector3,
		radius: number,
		direction: Vector3
	) -> RaycastResult?,
	blockcast: (
		proceduralModel: ProceduralModel,
		parameters: Parameters,
		targetGeneratedFolder: GeneratedFolder,
		castingInternally: boolean,
		origin: CFrame,
		size: Vector3,
		direction: Vector3
	) -> RaycastResult?,
	shapecast: (
		proceduralModel: ProceduralModel,
		parameters: Parameters,
		targetGeneratedFolder: GeneratedFolder,
		castingInternally: boolean,
		shape: BasePart,
		direction: Vector3,
		cf: CFrame?,
		size: Vector3?
	) -> RaycastResult?,
	getPartBoundsInBox: (
		proceduralModel: ProceduralModel,
		parameters: Parameters,
		targetGeneratedFolder: GeneratedFolder,
		castingInternally: boolean,
		cf: CFrame,
		size: Vector3
	) -> { BasePart },
	getPartBoundsInRadius: (
		proceduralModel: ProceduralModel,
		parameters: Parameters,
		targetGeneratedFolder: GeneratedFolder,
		castingInternally: boolean,
		position: Vector3,
		radius: number
	) -> { BasePart },
	getPartBoundsInPart: (
		proceduralModel: ProceduralModel,
		parameters: Parameters,
		targetGeneratedFolder: GeneratedFolder,
		castingInternally: boolean,
		shape: BasePart
	) -> { BasePart },
}

return Types
