-- ClientState: общее состояние клиента для всех LocalScript'ов
-- (снимок данных с сервера, какое меню открыто, идёт ли мини-игра, включён ли сканер).
-- Только отображение — клиент ничего не решает за сервер.

local Players = game:GetService("Players")

local Util = require(script.Parent.Util)

local ClientState = {
	Data = nil :: any,
	DataReceivedAt = 0,
	OpenMenuName = nil :: string?,
	LockpickActive = false,
	ScannerOn = false,
	Speed = 0,
}

ClientState.DataChanged = Instance.new("BindableEvent")
ClientState.MenuChanged = Instance.new("BindableEvent")
ClientState.LockpickChanged = Instance.new("BindableEvent")
ClientState.ScannerChanged = Instance.new("BindableEvent")
ClientState.ToastRequested = Instance.new("BindableEvent")

local menus: { [string]: { Open: (any) -> (), Close: () -> () } } = {}

function ClientState.OnData(callback: (any) -> ())
	ClientState.DataChanged.Event:Connect(callback)
	if ClientState.Data then
		task.spawn(callback, ClientState.Data)
	end
end

function ClientState.RegisterMenu(name: string, handlers: { Open: (any) -> (), Close: () -> () })
	menus[name] = handlers
end

function ClientState.CloseMenu(name: string?)
	local current = ClientState.OpenMenuName
	if not current or (name and name ~= current) then
		return
	end
	ClientState.OpenMenuName = nil
	local menu = menus[current]
	if menu then
		menu.Close()
	end
	ClientState.MenuChanged:Fire(nil)
end

function ClientState.OpenMenu(name: string, arg: any?)
	if ClientState.LockpickActive then
		return
	end
	if ClientState.OpenMenuName and ClientState.OpenMenuName ~= name then
		ClientState.CloseMenu()
	end
	local menu = menus[name]
	if not menu then
		return
	end
	ClientState.OpenMenuName = name
	menu.Open(arg)
	ClientState.MenuChanged:Fire(name)
end

function ClientState.ToggleMenu(name: string, arg: any?)
	if ClientState.OpenMenuName == name then
		ClientState.CloseMenu(name)
	else
		ClientState.OpenMenu(name, arg)
	end
end

-- Мини-игра перекрывает всё: меню закрываются, HUD прячется.
function ClientState.SetLockpick(active: boolean)
	if active then
		ClientState.CloseMenu()
	end
	ClientState.LockpickActive = active
	ClientState.LockpickChanged:Fire(active)
end

function ClientState.SetScanner(on: boolean)
	ClientState.ScannerOn = on
	ClientState.ScannerChanged:Fire(on)
end

function ClientState.Toast(text: string, kind: string?)
	ClientState.ToastRequested:Fire(text, kind or "Info")
end

function ClientState.HasPass(key: string): boolean
	local data = ClientState.Data
	return data ~= nil and data.Passes ~= nil and data.Passes[key] == true
end

function ClientState.GetStolenCarId(): string?
	local id = Players.LocalPlayer:GetAttribute("StolenCarId")
	return if type(id) == "string" then id else nil
end

-- Подписка на данные с сервера и первичный запрос
local dataSync = Util.Remote("DataSync")
dataSync.OnClientEvent:Connect(function(snapshot)
	ClientState.Data = snapshot
	ClientState.DataReceivedAt = os.clock()
	ClientState.DataChanged:Fire(snapshot)
end)
task.defer(function()
	dataSync:FireServer()
end)

return ClientState
