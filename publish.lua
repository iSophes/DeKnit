-- Remodel Publish script

local DEKNIT_ASSET_ID = "18812793726"

print("Loading DeKnit")
local place = remodel.readPlaceFile("DeKnit.rbxl")
local Packages = place.ReplicatedStorage.Packages
Packages.DeKnit.Packages:Destroy()

print("Writing DeKnit module to model file...")
remodel.writeModelFile("DeKnit.rbxm", Packages)
print("DeKnit model written")

print("Publishing DeKnit module to Roblox...")
remodel.writeExistingModelAsset(Packages, DEKNIT_ASSET_ID)
print("DeKnit asset published")
