# procedural-package

Strictly typed Luau generators for Roblox ProceduralModels. Change `Layout_Type` on a model to switch layouts using the same Generator ModuleScript.

## Usage

Set the ProceduralModel's Generator to a ModuleScript containing:

```luau
--!strict
local Package = require(game.ReplicatedStorage.Packages.ProceduralPackage)
local model = script.Parent
assert(model:IsA("ProceduralModel"))
return Package.Generator.new(model)
```

Set `Source_Path` to the full path of a BasePart, Model, or Folder. Folders select seeded random templates from eligible descendants. Models are treated as whole templates; their children are not independently selected. `Source_ExcludedTags` skips matching descendants and their subtrees. Commas separate tags.

Only the selected layout's attributes appear on the ProceduralModel. Changing `Layout_Type` removes unrelated fields with `SetAttribute(name, nil)` and adds the new layout's fields. Previously edited layout values are cached for that model during the current generator session and restored when you switch back. Source, random, pause, and custom attributes are preserved.

Pass the owning model to `Generator.new(model)` or `Generator.append(defaults, callback, model)` to keep the Properties panel synchronized. The constructor manages attribute changes outside `OnGenerate`; its optional `Destroy()` cleanup disconnects the binding, and destroying the model also disconnects it. Generators constructed without an owner still resolve missing layout fields internally but cannot edit a model's displayed attributes.

When updating an already-open place, save and reopen it once if existing generators retain the old attribute list. Studio can keep previously required package exports cached even after their source changes; newly loaded generators use the new layout schema.

## Layouts

| `Layout_Type` | Placement | Parameters |
| --- | --- | --- |
| `Single` (default) | One copy using the entire generation box as its cell. | None. |
| `SurfaceGrid` | One X/Z layer of evenly spaced cells. | `Layout_ColumnLimit`, `Layout_RowLimit`: NumberRanges clamping the calculated integer dimensions. |
| `SurfaceRandom` | Seeded, shuffled X/Z cells with random offsets inside each cell's free space. | `Layout_PopulationLimit`: NumberRange sampled as an integer count. |
| `SurfaceCurvedLine` | Copies along a cubic Bézier curve from the front-left corner to the back-right corner, rotated along its horizontal tangent. | `Layout_PopulationLimit`, `Layout_CurveSize0`, `Layout_CurveSize1`. |

`SurfaceGrid` calculates natural dimensions from the largest source footprint, including `Source_Padding`, then clamps them to the limits. Limits default to 1–100. Set both ends of a range to the same integer to fix a dimension, for example `NumberRange.new(4)` columns and `NumberRange.new(3)` rows produce 12 copies. Source overrides do not change the layout or its population.

Population limits default to 10 and may contain zero. A range must contain at least one nonnegative integer. Grid dimension ranges must start at 1 or greater.

### Curved line

The curve starts at the exact front-left corner `(-Size.X / 2, 0, -Size.Z / 2)` and ends at the exact back-right corner `(Size.X / 2, 0, Size.Z / 2)`. Front is local -Z and right is local +X. These endpoints follow both area dimensions and are independent of population. Copy origins lie on the corners; their geometry may extend beyond the area.

`Layout_CurveSize0` and `Layout_CurveSize1` remain signed handle lengths in studs, following [Beam's control point convention](https://create.roblox.com/docs/reference/engine/classes/Beam). The start tangent points inward from the front along +Z, and the end tangent points out through the right along +X. Internally, `P1 = P0 + Z * CurveSize0` and `P2 = P3 - X * CurveSize1`. Negative lengths reverse the corresponding handle, and zero lengths make a straight diagonal. Both lengths default to 12. Large lengths can extend the curve outside the area. No Vector3 control points or Attachments need to be positioned.

Copies sample the curve at equal parameter intervals, including both endpoints. A population of one samples its midpoint. The curve follows the area's rotation and uses the shared alignment/surface rules for height.

## Shared attributes

| Attribute | Default | Purpose |
| --- | --- | --- |
| `Source_Path` | `""` | Source instance path. |
| `Source_PathDelimiter` | `"."` | Separator used to resolve the path. |
| `Source_MaxYield` | `15` | Maximum wait for the source, in seconds. |
| `Source_PivotMethod` | `"Pivot"` | Origin used for scaling, rotation, and placement. |
| `Source_ScaleMethod` | `"Stretch"` | Stretch BaseParts to their cell, uniformly Fill, or Fit without increasing source size. Models always scale uniformly. |
| `Source_ScaleReference` | `"Min"` | Uniform fitting reference: `Height`, `Average`, `Min`, or `Max`. |
| `Source_Padding` | `UDim.new(0.1, 0)` | Padding on each side of a cell; Scale must be in [0, 0.5), Offset nonnegative. |
| `Source_Alignment` | `"Floor"` | Place the selected origin on the area's floor, or use `"Center"` for the cell center. |
| `Source_ExcludedTags` | `""` | Comma-separated tags excluded during folder selection. |
| `Random_Seed` | `0` | Reproducible generation seed. |
| `Random_Scale` | `NumberRange.new(1)` | Finite positive uniform scale multiplier. |
| `Random_Roll`, `Random_Pan`, `Random_Tilt` | `NumberRange.new(0)` | Random X/Y/Z rotation ranges in degrees. |
| `Layout_PauseInterval` | `100` | Positive integer iterations between cooperative pauses. |
| `Layout_SurfaceDetectionMethod` | `"None"` | Surface layouts accept `None`, `Raycast`, or `Shapecast`. Ignored by `Single`. |

Source templates may override `Source_PivotMethod`, `Source_ScaleMethod`, `Source_ScaleReference`, `Source_Alignment`, and `Random_Scale/Roll/Pan/Tilt`. Path, padding, excluded tags, seed, and layout settings stay controlled by the generation area. Validation happens before those overrides are used; overrides never mutate the area's attributes.

A Vector3 `Size` attribute on a source overrides dimensions used for uniform fitting. Model dimensions are authored at model scale 1. A CFrame `PivotOffset` **attribute** is applied last as `solvedOrigin * PivotOffset`; its translation is in studs and is not rescaled. This is separate from a BasePart's native `PivotOffset` property, which is respected by `Source_PivotMethod = "Pivot"` and scales with geometry.

### Pivots

| `Source_PivotMethod` | Origin |
| --- | --- |
| `Pivot` | Model or BasePart native pivot. |
| `Center` | Model bounding box center or BasePart CFrame. |
| `Bottom` / `Top` | Extents center minus/plus half its height along local Y. |
| `PrimaryPartPivot` / `PrimaryPartCenter` / `PrimaryPartBottom` / `PrimaryPartTop` | Corresponding origin of the Model's PrimaryPart. |

PrimaryPart variants fall back to the matching non-PrimaryPart behavior for Models without a PrimaryPart and for BaseParts. They transform the entire copy. Use `Bottom` with `Floor` to stand copies on the floor without changing native pivots.

### Surface detection

Pass the owning ProceduralModel to `Generator.new(model)` or `Generator.append(defaults, callback, model)` so queries account for its position, rotation, and scale.

`Raycast` places the selected pivot at the hit. `Shapecast` sweeps the scaled, rotated geometry and checks every BasePart in a Model, stopping the whole copy at first contact. A miss discards the copy before invoking the callback.

Casts follow the area's local downward axis. `Floor` searches from the area ceiling to its floor; `Center` searches through the assigned cell. The source's `PivotOffset` attribute is applied afterward.

Both modes use `Package.ENV.RAYCAST_PARAMS`, initially `RaycastParams.new()`:

```luau
local params = RaycastParams.new()
params.IncludeInstances = { workspace.Map }
params.IgnoreWater = true
Package.ENV.RAYCAST_PARAMS = params
```

Exclude generated output from the query filters. Regenerate after surrounding surfaces change; those changes do not automatically regenerate ProceduralModels.

## Custom callbacks

```luau
--!strict
local Root = game.ReplicatedStorage.Packages.ProceduralPackage
local Package = require(Root)
local Types = require(Root.Types)
local model = script.Parent
assert(model:IsA("ProceduralModel"))

return Package.Generator.append({ Tint = Color3.new(1, 0, 0) }, function(
	instance: Types.Template,
	parameters: Types.GenerationFunctionParams<Types.PackageAttributes & { Tint: Color3 }>,
	_target: GeneratedFolder
)
	if instance:IsA("BasePart") then
		instance.Color = parameters.Attributes.Tint
	end
end, model)
```

Custom defaults must use names outside the package's reserved attributes. Templates can override custom values with the same Roblox datatype. The callback receives the selected template's resolved attributes, including custom overrides, after placement and before parenting.

## Configuration and migration

Defaults are configurable through `Package.ENV` and `_G` keys prefixed with `__PROCEDURALPACKAGE__`. Source defaults use `DEFAULT_SOURCE_*`, layout defaults `DEFAULT_LAYOUT_*`, and random defaults `DEFAULT_RANDOM_*`. For example, set `Package.ENV.DEFAULT_LAYOUT_TYPE = "SurfaceGrid"` before constructing generators.

This refactor adopts the renamed attributes; existing models and source overrides need their names updated:

| Old | New |
| --- | --- |
| `SourcePath`, `SourcePathDelimiter`, `SourceMaxYield` | `Source_Path`, `Source_PathDelimiter`, `Source_MaxYield` |
| `GeneratedAlignment/PivotMethod/ScaleMethod/ScaleReference/Padding/ExcludedTags` | Corresponding `Source_Alignment/PivotMethod/ScaleMethod/ScaleReference/Padding/ExcludedTags` |
| `RandomSeed/Scale/Roll/Pan/Tilt` | Corresponding `Random_Seed/Scale/Roll/Pan/Tilt` |
| `PauseInterval` | `Layout_PauseInterval` |
| `GeneratedSurfaceDetectionMethod` | `Layout_SurfaceDetectionMethod` |
| `RandomPlacement` | `Layout_Type` (`Single`, `SurfaceGrid`, `SurfaceRandom`, `SurfaceCurvedLine`) |
| `GeneratedCount` | Grid row/column limits, or population limits for Random/CurvedLine. `Single` always generates one copy. |

The old `Line` mode is replaced by `SurfaceCurvedLine`; setting both curve sizes to zero produces a straight corner-to-corner diagonal. Surface layouts always use one X/Z layer, including with Center alignment.

## Modules and checks

Each module under `src/Layouts` owns its parameter schema and cell calculations. `Layouts/Util` shares cell construction, counts, and pauses; `Layouts/init` is the dispatch registry. `ParameterSchema` contains validation helpers, while `ParameterUtil` supplies active defaults, binds visible model attributes, resolves complete internal snapshots, validates settings, and resolves source overrides. Public `PackageAttributes` marks layout-specific fields optional; `ResolvedPackageAttributes` and `Parameters` describe the complete internal snapshot. `PlacementUtil` handles transforms, surface detection, callbacks, and output for all layouts.

To add a layout, define its typed attributes and a module with `Parameters` and `GetCells`, then register it in `Layouts/init` and `Types.LayoutType`. Layout defaults and validation flow through the registry without changes to Generator.

The demo contains exactly four ProceduralModels under `Workspace.examples`, one per layout type. They share a pillar source and can each switch layout by editing `Layout_Type`. Rebuild with:

```sh
lune run scripts/check-layouts.luau
lune run scripts/check-parameters.luau
lune run scripts/build-demo.luau
rojo build demo.project.json --output demo.rbxl
```

The checks load production modules in Lune and exercise layout swaps, deterministic placement, signed Beam handles, counts, callback overrides, validation, and cooperative pauses. Engine world queries and RNG are adapters in these checks; Studio remains the environment for engine-specific visual verification.

## UI Labs visual debug stories

The demo maps the UI Labs dev dependency into `ReplicatedStorage.DevPackages` and the story support directory into `ReplicatedStorage.DebugStories`. Install dependencies, regenerate their type exports, then build or serve the demo:

```sh
wally install
rojo sourcemap demo.project.json --output sourcemap.json
wally-package-types Packages DevPackages --sourcemap sourcemap.json
rojo build demo.project.json --output demo.rbxl
# or: rojo serve demo.project.json
```

Open the built demo in Studio and use the UI Labs plugin to select the **Procedural Package · Visual Debug** storybook. The utility dev package supplies the story/control API; the UI Labs Studio plugin supplies the story browser. These are [generic stories with live controls](https://ui-labs.luau.page/docs/stories/advanced/generic), so no UI framework is needed.

Each story renders isolated geometry in a `ViewportFrame` with a camera and `WorldModel`. Drag to orbit, scroll to zoom, and use **Reset view** to restore the camera. The footer explains colors and reports calculated results, validation decisions, or numeric comparisons. Geometry guides use actual parts so they render inside the viewport.

| Story location | Visual checks |
| --- | --- |
| `GeometryUtil/Bounds.story` | Rotated bounds versus an independent eight-corner calculation. |
| `GeometryUtil/Pivots.story` | All eight pivot methods, PrimaryPart fallbacks, and rotated geometry. |
| `GeometryUtil/Scale.story` | BasePart pivot-offset scaling and Model scaling around its pivot. |
| `SourceUtil/Fitting.story` | Stretch/Fit/Fill, four scale references, padding, source scale, and random scale. |
| `SourceUtil/Selection.story` | Folder candidates, excluded tag subtrees, and seeded source selection. |
| `ParameterUtil/Overrides.story` | Template overrides, custom attributes, and area-owned layout settings. |
| `ParameterUtil/LayoutAttributes.story` | The exact visible attribute schema for each selected layout. |
| `ParameterSchema/Ranges.story` | General/scale/population/grid range boundaries. |
| `Layouts/Single/Layout.story` | The full-area cell. |
| `Layouts/SurfaceGrid/Layout.story` | Natural grid dimensions, limits, padding, and source footprints. |
| `Layouts/SurfaceRandom/Layout.story` | Cell shuffling, populations, and normalized offsets. |
| `Layouts/SurfaceCurvedLine/Curve.story` | Signed Beam handles, sampled frames, tangents, and zero/one populations. |
| `Layouts/Util/GridMath.story` | Dimension clamping, cell partitioning, and pause intervals. |
| `SurfaceUtil/Detection.story` | Raycast/Shapecast hits and misses against a sloped support with owner scale/rotation. |
| `DebugStories/Attributes/Layouts.story` | Layout switching through the shared source/placement pipeline. |
| `DebugStories/Attributes/Random.story` | Seeded placement plus random scale and X/Y/Z rotation groups. |

Stories testing a single module live under that module beside its `init.luau`; the ModuleScript name and existing require paths remain the same. Stories covering several modules live in `stories/Attributes`. All custom UI components and shared story helpers are together in **`stories/Components`**. Story files and support components are excluded from the published Wally package.

The surface story passes its private `WorldModel` and `RaycastParams` through the optional final arguments to `SurfaceUtil.detect`. Normal generation continues using `workspace` and `ENV.RAYCAST_PARAMS`; mounting a story does not change shared query settings or add support fixtures to Workspace.

Run `lune run scripts/check-stories.luau` to mount the actual UI Labs story definitions, update controls, inspect readouts, and verify unmount cleanup. The harness adapts engine signals, Model methods, queries, and RNG for Lune; verify final appearance and cast contacts in Studio.
