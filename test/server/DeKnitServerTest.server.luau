local Knit = require(game:GetService("ReplicatedStorage").Test.Knit)

local MyService = {
	Client = {
		TestEvent = Knit.CreateSignal(),
		TestProperty = Knit.CreateProperty("Hello"),
	},
	Middleware = {
		Inbound = {
			function(player, args)
				print("MyService Inbound", player, args)
				return true
			end,
		},
		Outbound = {
			function(player, args)
				print("MyService Outbound", player, args)
				return true
			end,
		},
	},
}

function MyService:Init()
	self.Client.TestEvent:Connect(function(player, msg)
		print("Got message from client event:", player, msg)
		self.Client.TestEvent:Fire(player, msg:lower())
	end)
end

function MyService.Client:TestMethod(player, msg)
	print("TestMethod from client:", player, msg)
	return msg:upper()
end

Knit.Start({
	Middleware = {
		Inbound = {
			function(player, ...)
				print("INBOUND", player, ...)
				return true
			end,
		},
		Outbound = {
			function(player, ...)
				print("OUTBOUND", player, ...)
				return true
			end,
		},
	},
})
	:andThen(function()
		print("KnitServer started")
	end)
	:catch(warn)
