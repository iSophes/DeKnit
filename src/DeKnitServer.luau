local ServerScriptService = game:GetService("ServerScriptService")

local DeKnitServer = {}

type DeKnitServerOptions = {
	Middleware: {
		Inbound: ServerMiddlewareFn?,
		Outbound: ServerMiddlewareFn?,
	}?,

	CodePath: Instance?,
}

type ServiceClient = {
	Server: Service,
	[any]: any,
}

type Service = {
	Name: string,
	Client: ServiceClient,
	NetworkComm: any,
	[any]: any,
}

type ServerMiddlewareFn = (player: Player, args: { any }) -> (boolean, ...any)
type ServerMiddleware = { ServerMiddlewareFn }

local Packages = script.Parent.Packages
local Comm = require(Packages.Comm)
local ServerComm = Comm.ServerComm
local Promise = require(Packages.Promise)

local ServiceComms = Instance.new("Folder")
ServiceComms.Name = "Services"

local SIGNAL_MARKER = newproxy(true)
getmetatable(SIGNAL_MARKER).__tostring = function()
	return "SIGNAL_MARKER"
end

local UNRELIABLE_SIGNAL_MARKER = newproxy(true)
getmetatable(UNRELIABLE_SIGNAL_MARKER).__tostring = function()
	return "UNRELIABLE_SIGNAL_MARKER"
end

local PROPERTY_MARKER = newproxy(true)
getmetatable(PROPERTY_MARKER).__tostring = function()
	return "PROPERTY_MARKER"
end

local SelectedOptions = nil
local DefaultOptions: DeKnitServerOptions = {
	Middleware = nil,
	CodePath = ServerScriptService,
}

local Started: boolean = false
local StartedComplete = false
local StartedCompleteEvent = Instance.new("BindableEvent")

local Services = {} :: { Service }

function DeKnitServer.CreateSignal()
	return SIGNAL_MARKER
end

function DeKnitServer.CreateUnreliableSignal()
	return UNRELIABLE_SIGNAL_MARKER
end

function DeKnitServer.CreateProperty(InitialValue: any)
	return { PROPERTY_MARKER, InitialValue }
end

function DeKnitServer.StartServiceNetworking()
	for _, Object: any in SelectedOptions.CodePath:GetDescendants() do
		if not Object:IsA("ModuleScript") then
			continue
		end
		if not string.find(Object.Name, "Service", string.len(Object.Name) - 7) then
			continue
		end

		local Service = require(Object) :: any
		Service.NetworkComm = ServerComm.new(ServiceComms, Object.Name)

		if type(Service.Client) ~= "table" then
			Service.Client = { Server = Service }
		else
			if Service.Client.Server ~= Service then
				Service.Client.Server = Service
			end
		end

		Services[Object.Name] = {
			Name = Object.Name,
		}

		for Name, Thing in Service do
			Services[Object.Name][Name] = Thing
		end
	end
end

function DeKnitServer.Start(Options: DeKnitServerOptions?)
	if Started then
		return Promise.reject("Hey, the DeKnit has already started NOOOOB.")
	end

	Started = true

	if Options then
		assert(typeof(Options) == "table", `DeKnit Options should be a table or nil; got {typeof(Options)}`)

		SelectedOptions = Options

		for Key, Value in Options do
			if SelectedOptions[Key] then
				continue
			end
			SelectedOptions[Key] = Value
		end
	end

	if not Options then
		SelectedOptions = DefaultOptions
	end

	DeKnitServer.StartServiceNetworking()

	table.freeze(Services)

	return Promise.new(function(Resolve)
		local PromiseInitServices = {}
		local DeKnitMiddleware = if SelectedOptions.Middleware then SelectedOptions.Middleware else {}

		for _, Service in Services do
			local Middleware = if Service.Middleware then Service.Middleware else {}
			local InboundMiddleware = if Middleware.Inbound then Middleware.Inbound else DeKnitMiddleware.Inbound
			local OutboundMiddleware = if Middleware.Outbound then Middleware.Outbound else DeKnitMiddleware.Outbound

			Service.Middleware = nil

			for Index, Value in Service.Client do
				if type(Value) == "function" then
					Service.NetworkComm:WrapMethod(Service.Client, Index, InboundMiddleware, OutboundMiddleware)
					continue
				end

				if Value == SIGNAL_MARKER then
					Service.Client[Index] =
						Service.NetworkComm:CreateSignal(Index, false, InboundMiddleware, OutboundMiddleware)
					continue
				end

				if Value == UNRELIABLE_SIGNAL_MARKER then
					Service.Client[Index] =
						Service.NetworkComm:CreateSignal(Index, true, InboundMiddleware, OutboundMiddleware)
					continue
				end

				if type(Value) == "table" and Value[1] == PROPERTY_MARKER then
					Service.Client[Index] =
						Service.NetworkComm:CreateProperty(Index, Value[2], InboundMiddleware, OutboundMiddleware)
					continue
				end
			end

			if type(Service.Init) ~= "function" then
				continue
			end

			table.insert(
				PromiseInitServices,
				Promise.new(function(ResolveInit)
					debug.setmemorycategory(Service.Name)
					Service:Init()
					ResolveInit()
				end)
			)
		end

		Resolve(Promise.all(PromiseInitServices))
	end):andThen(function()
		for _, Service in Services do
			if type(Service.Start) ~= "function" then
				continue
			end

			task.spawn(function()
				debug.setmemorycategory(Service.Name)
				Service:Start()
			end)
		end

		StartedComplete = true
		StartedCompleteEvent:Fire()

		task.defer(function()
			StartedCompleteEvent:Destroy()
		end)

		ServiceComms.Parent = script.Parent
	end)
end

function DeKnitServer.OnStart()
	if StartedComplete then
		return Promise.resolve()
	end

	return Promise.fromEvent(StartedCompleteEvent.Event)
end

return DeKnitServer
