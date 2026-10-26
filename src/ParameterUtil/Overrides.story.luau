--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local Parameters = require(script.Parent)

return Story.create(
	"Parameter attributes · Scoped source overrides",
	"resolveTemplateAttributes accepts source/random/custom overrides and keeps area-owned fields unchanged.",
	{
		EnableOverrides = true,
		BaseScale = UILabs.Slider(1, 0.2, 2, 0.1),
		OverrideScale = UILabs.Slider(1.5, 0.2, 2, 0.1),
		AttemptLayoutOverride = true,
	},
	function(scene, values)
		local template = Fixtures.template(false)
		scene.Keep(template)
		local base = Controls.number(values, "BaseScale")
		local parameters = Preview.parameters({ Random_Scale = NumberRange.new(base), Tint = Fixtures.Blue })
		if Controls.boolean(values, "EnableOverrides") then
			template:SetAttribute("Random_Scale", NumberRange.new(Controls.number(values, "OverrideScale")))
			template:SetAttribute("Tint", Fixtures.Gold)
		end
		if Controls.boolean(values, "AttemptLayoutOverride") then
			template:SetAttribute("Layout_Type", "Single")
		end
		local scoped = Parameters.resolveTemplateAttributes(template, parameters, { Tint = Fixtures.Blue })
		local resolvedScale = scoped.Attributes.Random_Scale.Min
		local resolvedTint = scoped.Attributes.Tint
		assert(typeof(resolvedTint) == "Color3")
		Fixtures.part("AreaAttributes", Vector3.new(4, 8, 4) * base, CFrame.new(-7, 0, 0), Fixtures.Blue, scene.Content)
		Fixtures.part(
			"ResolvedTemplateAttributes",
			Vector3.new(4, 8, 4) * resolvedScale,
			CFrame.new(7, 0, 0),
			resolvedTint,
			scene.Content
		)
		scene.Marker(CFrame.new(-7, 0, 0))
		scene.Marker(CFrame.new(7, 0, 0))
		local unchanged = math.abs(parameters.Attributes.Random_Scale.Min - base) < 0.00001
			and scoped.Attributes.Layout_Type == parameters.Attributes.Layout_Type
		scene.SetStatus(
			`Left: area scale {base} · Right: resolved scale {resolvedScale}\nArea attributes unchanged / template Layout_Type ignored: {if unchanged
				then "PASS"
				else "FAIL"}`
		)
	end
)
