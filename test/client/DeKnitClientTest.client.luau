local DeKnit = require(game:GetService("ReplicatedStorage").Test.DeKnit)

local MyController = {}

function MyController:Init()
	local MyService = DeKnit:GetService("MyService")
	MyService.TestEvent:Connect(function(msg)
		print("Got event from server:", msg)
	end)
	MyService.TestEvent:Fire("Hello")
	MyService:TestMethod("Hello world from client"):andThen(function(result)
		print("Result from server:", result)
	end)
	MyService.TestProperty:Observe(function(value)
		print("TestProperty value:", value)
	end)
end

DeKnit.Start({ ServicePromises = true })
	:andThen(function()
		print("KnitClient started")
	end)
	:catch(warn)
