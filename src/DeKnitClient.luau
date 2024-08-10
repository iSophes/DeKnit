--!strict

type Middleware = {
	Inbound: ClientMiddleware?,
	Outbound: ClientMiddleware?,
}

type ClientMiddleware = { ClientMiddlewareFn }
type ClientMiddlewareFn = (args: { any }) -> (boolean, ...any)

type Controller = {
	Name: string,
	[any]: any,
}

type Service = {
	[any]: any,
}

type DeKnitControllerOptions = {
	ServicePromises: boolean,
	Middleware: Middleware?,
	PerServiceMiddleware: { [string]: Middleware }?,
	CodePath: Instance?,
}

local Players = game:GetService("Players")

local DefaultOptions: DeKnitControllerOptions = {
	ServicePromises = true,
	Middleware = nil,
	PerServiceMiddleware = {},
	CodePath = Players.LocalPlayer.PlayerScripts,
}

local DeKnitClient = {}

local Packages = script.Parent.Parent
local Promise = require(Packages.Promise)
local Comm = require(Packages.Comm)
local ClientComm = Comm.ClientComm

local Controllers: { [string]: Controller } = {}
local Services: { [string]: Service } = {}
local ServicesFolder = nil

local Started = false
local StartedComplete = false
local StartedCompleteEvent = Instance.new("BindableEvent")

local SelectedOptions: DeKnitControllerOptions = nil

local function GetServicesFolder(): Folder
	if not ServicesFolder then
		ServicesFolder = (script.Parent :: Instance):WaitForChild("Services") :: Folder
	end

	return ServicesFolder
end

local function GetMiddlewareForService(ServiceName: string): Middleware
	local Middleware = if SelectedOptions.Middleware then SelectedOptions.Middleware else {}

	if SelectedOptions.PerServiceMiddleware then
		if SelectedOptions.PerServiceMiddleware[ServiceName] then
			return SelectedOptions.PerServiceMiddleware[ServiceName]
		end
	end

	return Middleware
end

local function BuildService(ServiceName: string): Service
	local folder = GetServicesFolder()
	local middleware = GetMiddlewareForService(ServiceName)
	local clientComm = ClientComm.new(folder, SelectedOptions.ServicePromises, ServiceName)
	local service = clientComm:BuildObject(middleware.Inbound, middleware.Outbound)

	Services[ServiceName] = service

	return service
end

function DeKnitClient.InitControllers()
	local Path = SelectedOptions.CodePath

	if not Path then
		Path = DefaultOptions.CodePath
	end

	if not Path then
		return
	end

	for _, Module in Path:GetDescendants() do
		if not Module:IsA("ModuleScript") then
			continue
		end
		if not string.find(Module.Name, "Controller", string.len(Module.Name) - string.len("Controller")) then
			continue
		end

		Controllers[Module.Name] = { Name = Module.Name }

		for Name, Element in require(Module) :: any do
			Controllers[Module.Name][Name] = Element
		end
	end
end

function DeKnitClient:GetService(ServiceName: string): Service
	assert(Started, "Cannot call GetService before DeKnit has started. ")

	assert(type(ServiceName) == "string", `Service name must be a string!; got {type(ServiceName)}`)

	local Service = Services[ServiceName]

	if Service then
		return Service :: typeof(Service)
	end

	local BuiltService = BuildService(ServiceName)

	return BuiltService :: typeof(BuiltService)
end

function DeKnitClient.Start(Options: DeKnitControllerOptions?)
	if Started then
		return Promise.reject("DeKnit has already been started!")
	end

	if Options then
		assert(typeof(Options) == "table", `DeKnit Options must be a table or nil; got type {typeof(Options)}`)

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

	if type(SelectedOptions.PerServiceMiddleware) ~= "table" then
		SelectedOptions.PerServiceMiddleware = {}
	end

	DeKnitClient.InitControllers()

	Started = true

	table.freeze(Controllers)

	return Promise.new(function(Resolve)
		local PromiseStartControllers = {}

		for _, Controller in Controllers do
			if type(Controller.Init) ~= "function" then
				continue
			end

			table.insert(
				PromiseStartControllers,
				Promise.new(function(ResolveStart)
					debug.setmemorycategory(Controller.Name)
					Controller:Init()
					ResolveStart()
				end)
			)
		end

		Resolve(Promise.all(PromiseStartControllers))
	end):andThen(function()
		for _, Controller in Controllers do
			if type(Controller.Start) ~= "function" then
				continue
			end

			task.spawn(function()
				debug.setmemorycategory(Controller.Name)
				Controller:Start()
			end)
		end

		StartedComplete = true
		StartedCompleteEvent:Fire()

		task.defer(function()
			StartedCompleteEvent:Destroy()
		end)
	end)
end

function DeKnitClient.OnStart()
	if StartedComplete then
		return Promise.resolve()
	end

	return Promise.fromEvent(StartedCompleteEvent.Event)
end

return DeKnitClient
