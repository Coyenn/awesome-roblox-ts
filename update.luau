local process = require("@lune/process")
local fs = require("@lune/fs")
local task = require("@lune/task")
local serde = require("@lune/serde")

local README_PATH = "README.md"

-- Header for the README.md file
local README_HEADER = [[
# Awesome Roblox-TS

A list of all packages for [roblox-ts](https://roblox-ts.com/).

## Packages

]]

-- Function to strip markdown and HTML from descriptions
local function stripMarkdownHtml(s)
	-- Remove HTML tags
	s = s:gsub("<[^>]*>", "")
	-- Remove images and links: ![alt](url) and [text](url)
	s = s:gsub("!%b[]%b()", "")
	s = s:gsub("%b[]%b()", "")
	-- Remove emphasis markers: **bold**, *italic*, __underline__, _italic_
	s = s:gsub("%*%*([^*]-)%*%*", "%1")
	s = s:gsub("%*([^*]-)%*", "%1")
	s = s:gsub("__([^_]-)__", "%1")
	s = s:gsub("_([^_]-)_", "%1")
	-- Remove inline code: `code`
	s = s:gsub("`([^`]-)`", "%1")
	-- Remove code fences: ```...```
	s = s:gsub("```.-```", "")
	-- Remove headers (# H1, ## H2, etc.) anywhere in the string
	s = s:gsub("#+%s*[^\n]*", "")
	-- Remove blockquotes >
	s = s:gsub(">%s?[^\n]*", "")
	-- Remove lists markers (-, *, +) at line-start
	s = s:gsub("^[%-%*%+]%s+", "")
	s = s:gsub("\n[%-%*%+]%s+", " ")
	-- Remove newlines and normalize spaces
	s = s:gsub("[\r\n]+", " ")
	s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

-- Function to run a command and get its output, ignoring errors
local function runCommandSilent(command, args)
	local result = process.exec(command, args)
	-- Always return stdout, even if there was an error (like the original || true)
	return result.stdout or "", nil
end

-- Function to fetch all @rbxts package names from npm
local function getPackageNames()
	print("Fetching package list from npm...")
	local result = process.exec("npm", { "access", "list", "packages", "@rbxts" })
	if not result.ok then
		print(string.format("Error fetching package list: %s", result.stderr))
		process.exit(1)
	end

	local names = {}
	for line in result.stdout:gmatch("[^\r\n]+") do
		local name = line:match("^(%S+):")
		if name then
			table.insert(names, name)
		end
	end
	print(`Found {#names} packages.`)
	return names
end

-- Function to get details for a single package (equivalent to the xargs part)
local function getPackageDetails(name)
	-- Equivalent to: npm view 'package' name description --json 2>/dev/null || true
	local stdout, _ = runCommandSilent("npm", { "view", name, "name", "description", "--json" })

	if not stdout or stdout == "" then
		return nil
	end

	local ok, result = pcall(function()
		return serde.decode("json", stdout)
	end)

	-- Equivalent to jq's: select(type == "object" and .name)
	if ok and type(result) == "table" and result.name then
		return result
	end

	return nil
end

-- Function to process a chunk of packages
local function processPackageChunk(packageNames, startIndex, endIndex)
	local results = {}
	for i = startIndex, endIndex do
		if packageNames[i] then
			local pkg = getPackageDetails(packageNames[i])
			if pkg then
				table.insert(results, pkg)
			end
		end
	end
	return results
end

-- Main function to orchestrate the update
local function main()
	local packageNames = getPackageNames()
	local allPackageDetails = {}

	print("Fetching package details with 10 parallel processes...")

	-- Shared state for parallel processing
	local completedWorkers = 0
	local workerResults = {}

	-- Process packages in parallel chunks
	local chunkSize = math.ceil(#packageNames / 10) -- Divide into 10 roughly equal chunks

	-- Create 10 parallel tasks
	for i = 1, 10 do
		local startIndex = (i - 1) * chunkSize + 1
		local endIndex = math.min(i * chunkSize, #packageNames)

		if startIndex <= #packageNames then
			print(`Starting worker {i}: processing packages {startIndex} to {endIndex}`)
			task.spawn(function()
				local results = processPackageChunk(packageNames, startIndex, endIndex)
				workerResults[i] = results
				completedWorkers = completedWorkers + 1
				print(`Worker {i} completed with {#results} packages`)
			end)
		else
			completedWorkers = completedWorkers + 1
		end
	end

	-- Wait for all workers to complete
	print("Waiting for all workers to complete...")
	while completedWorkers < 10 do
		task.wait(0.1) -- Small delay to avoid busy waiting
	end

	-- Collect all results
	for i = 1, 10 do
		if workerResults[i] then
			for _, pkg in ipairs(workerResults[i]) do
				table.insert(allPackageDetails, pkg)
			end
		end
	end

	-- Sort packages by name (equivalent to jq's sort_by(.name))
	table.sort(allPackageDetails, function(a, b)
		return a.name < b.name
	end)

	print(`Successfully fetched details for {#allPackageDetails} packages.`)
	print("Generating README.md...")
	local readmeContent = { README_HEADER }

	for _, pkg in ipairs(allPackageDetails) do
		local desc = pkg.description or ""

		-- Clean up the description using the comprehensive function
		desc = stripMarkdownHtml(desc)

		if #desc > 0 then
			table.insert(
				readmeContent,
				string.format("- [%s](https://www.npmjs.com/package/%s) - %s", pkg.name, pkg.name, desc)
			)
		else
			table.insert(readmeContent, string.format("- [%s](https://www.npmjs.com/package/%s)", pkg.name, pkg.name))
		end
	end

	local readmeFinal = table.concat(readmeContent, "\n")
	fs.writeFile(README_PATH, readmeFinal)

	print("README.md has been updated successfully.")
end

main()
