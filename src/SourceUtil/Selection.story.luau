--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local Source = require(script.Parent)

return Story.create(
	"Source attributes · Folder selection and tags",
	"getTemplates and getCopies use local fixtures. Red subtree has a tag; Models remain atomic candidates.",
	{
		ExcludeTagged = true,
		Random_Seed = UILabs.Slider(2026, 0, 10000, 1),
		Count = UILabs.Slider(12, 0, 40, 1),
	},
	function(scene, values)
		local folder = Instance.new("Folder")
		folder.Name = "SourceFixtures"
		scene.Keep(folder)
		Fixtures.part("A_Part", Vector3.new(3, 5, 3), CFrame.identity, Fixtures.Blue, folder)
		local model = Fixtures.template(true)
		local modelInstance: Instance = model
		modelInstance.Name = "B_Model"
		modelInstance.Parent = folder
		local hidden = Instance.new("Folder")
		hidden.Name, hidden.Parent = "Hidden", folder
		hidden:AddTag("StoryHidden")
		Fixtures.part("C_Hidden", Vector3.new(5, 3, 5), CFrame.identity, Fixtures.Red, hidden)
		local parameters = Preview.parameters({
			Source_ExcludedTags = if Controls.boolean(values, "ExcludeTagged") then "StoryHidden" else "",
		})
		local candidates = Source.getTemplates(folder, parameters)
		local counts: { [Instance]: number } = {}
		local copies = Source.getCopies(
			candidates,
			Controls.number(values, "Count"),
			parameters,
			Random.new(Controls.number(values, "Random_Seed")),
			nil
		)
		for index, copy in copies do
			counts[copy.Template] = (counts[copy.Template] or 0) + 1
			local clone = copy.Template:Clone()
			clone:PivotTo(CFrame.new((index - 1) % 8 * 9, 0, math.floor((index - 1) / 8) * 12))
			local displayed: Instance = clone
			displayed.Parent = scene.Content
		end
		local tally: { string } = {}
		for _, candidate in candidates do
			table.insert(tally, `{candidate.Name}: {counts[candidate] or 0}`)
		end
		scene.SetStatus(
			`{#candidates} eligible templates → {#copies} seeded selections\n{table.concat(tally, " · ")}`
		)
	end
)
