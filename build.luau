-- Model builder
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local stdio = require("@lune/stdio")

--local DEKNIT_ASSET_ID = "18812793726"
local function SuccessText(Text: string)
	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color("green"))

	print("DeKnit build.luau : " .. Text)
end

local function ErrorText(Error: string)
	stdio.write(stdio.style("bold"))
	stdio.write(stdio.color("red"))

	print("[ERROR] DeKnit build.luau : " .. Error)
end

SuccessText("Loading DeKnit place")

local place = roblox.deserializePlace(fs.readFile("DeKnit.rbxl"))

SuccessText("Destroying packages on ReplicatedStorage")

local Packages = place.ReplicatedStorage.Packages
Packages.DeKnit.Packages:Destroy()

SuccessText("Writing DeKnit module to model file...")

local Success, Error = pcall(function()
	fs.writeFile("DeKnit.rbxm", roblox.serializeModel({ Packages }))
end)

if Success then
	SuccessText("DeKnit model written successfully!")
end

if Error then
	ErrorText(Error)
end
