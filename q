--[[
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                           VEX UI LIBRARY v2.0                                ║
    ║                  Professional Roblox Executor UI Framework                   ║
    ║                                                                              ║
    ║  Features:                                                                   ║
    ║  • Modular Component System                                                  ║
    ║  • Plugin/Addon Architecture                                                 ║
    ║  • JSON-Based Configuration                                                  ║
    ║  • Theme System with Live Reloading                                          ║
    ║  • Animation & Tweening Engine                                               ║
    ║  • Event-Driven Architecture                                                   ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
]]

local Vex = {}
Vex.__index = Vex
Vex.Version = "2.0.0"
Vex.Components = {}
Vex.Addons = {}
Vex.Config = {}
Vex.Themes = {}
Vex.Events = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════════════════════
-- UTILITY MODULE
-- ═══════════════════════════════════════════════════════════════════════════════

local Utility = {}

function Utility.Create(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties or {}) do
        if prop ~= "Parent" then
            instance[prop] = value
        end
    end
    if properties and properties.Parent then
        instance.Parent = properties.Parent
    end
    return instance
end

function Utility.Tween(instance, properties, duration, easingStyle, easingDirection, callback)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(
            duration or 0.3,
            easingStyle or Enum.EasingStyle.Quart,
            easingDirection or Enum.EasingDirection.Out
        ),
        properties
    )
    if callback then
        tween.Completed:Connect(callback)
    end
    tween:Play()
    return tween
end

function Utility.Drag(frame, handle)
    handle = handle or frame
    local dragging = false
    local dragStart, startPos
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                        input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

function Utility.Round(number, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(number * mult + 0.5) / mult
end

function Utility.CloneTable(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = Utility.CloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function Utility.GenerateId(length)
    length = length or 8
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local id = ""
    for i = 1, length do
        local randomIndex = math.random(1, #chars)
        id = id .. chars:sub(randomIndex, randomIndex)
    end
    return id
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EVENT SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local EventSystem = {}
EventSystem.__index = EventSystem

function EventSystem.new()
    local self = setmetatable({}, EventSystem)
    self._events = {}
    return self
end

function EventSystem:On(eventName, callback)
    if not self._events[eventName] then
        self._events[eventName] = {}
    end
    table.insert(self._events[eventName], callback)
    return {
        Disconnect = function()
            for i, cb in ipairs(self._events[eventName]) do
                if cb == callback then
                    table.remove(self._events[eventName], i)
                    break
                end
            end
        end
    }
end

function EventSystem:Emit(eventName, ...)
    if self._events[eventName] then
        for _, callback in ipairs(self._events[eventName]) do
            task.spawn(callback, ...)
        end
    end
end

function EventSystem:Once(eventName, callback)
    local connection
    connection = self:On(eventName, function(...)
        callback(...)
        connection:Disconnect()
    end)
    return connection
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local ConfigSystem = {}
ConfigSystem.__index = ConfigSystem

function ConfigSystem.new(name, defaultConfig)
    local self = setmetatable({}, ConfigSystem)
    self.Name = name
    self.DefaultConfig = defaultConfig or {}
    self.CurrentConfig = Utility.CloneTable(self.DefaultConfig)
    self.Events = EventSystem.new()
    self:Load()
    return self
end

function ConfigSystem:Get(key)
    local keys = key:split(".")
    local value = self.CurrentConfig
    for _, k in ipairs(keys) do
        value = value[k]
        if value == nil then
            return nil
        end
    end
    return value
end

function ConfigSystem:Set(key, value)
    local keys = key:split(".")
    local config = self.CurrentConfig
    for i = 1, #keys - 1 do
        if not config[keys[i]] then
            config[keys[i]] = {}
        end
        config = config[keys[i]]
    end
    local oldValue = config[keys[#keys]]
    config[keys[#keys]] = value
    self.Events:Emit("Changed", key, value, oldValue)
    self:Save()
end

function ConfigSystem:Reset(key)
    local keys = key:split(".")
    local default = self.DefaultConfig
    local current = self.CurrentConfig
    
    for i = 1, #keys - 1 do
        default = default[keys[i]]
        current = current[keys[i]]
        if not default or not current then
            return
        end
    end
    
    current[keys[#keys]] = Utility.CloneTable(default[keys[#keys]])
    self.Events:Emit("Reset", key, current[keys[#keys]])
    self:Save()
end

function ConfigSystem:Export()
    return HttpService:JSONEncode(self.CurrentConfig)
end

function ConfigSystem:Import(jsonString)
    local success, result = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    if success then
        self.CurrentConfig = result
        self.Events:Emit("Imported", self.CurrentConfig)
        self:Save()
        return true
    end
    return false
end

function ConfigSystem:Save()
    -- In a real executor, you'd write to file system
    -- For Roblox, we use DataStore or just keep in memory
    Vex.Config[self.Name] = self.CurrentConfig
    self.Events:Emit("Saved", self.CurrentConfig)
end

function ConfigSystem:Load()
    if Vex.Config[self.Name] then
        self.CurrentConfig = Utility.CloneTable(Vex.Config[self.Name])
        self.Events:Emit("Loaded", self.CurrentConfig)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- THEME SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local ThemeSystem = {}
ThemeSystem.__index = ThemeSystem

function ThemeSystem.new()
    local self = setmetatable({}, ThemeSystem)
    self.Themes = {}
    self.ActiveTheme = nil
    self.Events = EventSystem.new()
    return self
end

function ThemeSystem:Register(name, theme)
    self.Themes[name] = theme
    if not self.ActiveTheme then
        self:SetTheme(name)
    end
end

function ThemeSystem:SetTheme(name)
    if self.Themes[name] then
        local oldTheme = self.ActiveTheme
        self.ActiveTheme = name
        self.Events:Emit("ThemeChanged", name, self.Themes[name], oldTheme)
    end
end

function ThemeSystem:GetColor(key)
    if not self.ActiveTheme then
        return Color3.fromRGB(255, 255, 255)
    end
    local theme = self.Themes[self.ActiveTheme]
    return theme.Colors[key] or theme.Colors.Primary or Color3.fromRGB(255, 255, 255)
end

function ThemeSystem:GetFont(key)
    if not self.ActiveTheme then
        return Enum.Font.SourceSans
    end
    local theme = self.Themes[self.ActiveTheme]
    return theme.Fonts[key] or Enum.Font.SourceSans
end

-- Default Themes
local DefaultThemes = {
    Dark = {
        Colors = {
            Background = Color3.fromRGB(25, 25, 25),
            Surface = Color3.fromRGB(35, 35, 35),
            Primary = Color3.fromRGB(88, 101, 242),
            Secondary = Color3.fromRGB(57, 60, 67),
            Accent = Color3.fromRGB(88, 101, 242),
            Text = Color3.fromRGB(255, 255, 255),
            TextMuted = Color3.fromRGB(150, 150, 150),
            Border = Color3.fromRGB(50, 50, 50),
            Success = Color3.fromRGB(67, 181, 129),
            Warning = Color3.fromRGB(250, 166, 26),
            Error = Color3.fromRGB(237, 66, 69),
            Hover = Color3.fromRGB(45, 45, 45),
            Pressed = Color3.fromRGB(55, 55, 55)
        },
        Fonts = {
            Regular = Enum.Font.SourceSans,
            Bold = Enum.Font.SourceSansBold,
            Mono = Enum.Font.Code
        },
        CornerRadius = 6,
        AnimationSpeed = 0.2
    },
    Light = {
        Colors = {
            Background = Color3.fromRGB(245, 245, 245),
            Surface = Color3.fromRGB(255, 255, 255),
            Primary = Color3.fromRGB(88, 101, 242),
            Secondary = Color3.fromRGB(220, 220, 220),
            Accent = Color3.fromRGB(88, 101, 242),
            Text = Color3.fromRGB(30, 30, 30),
            TextMuted = Color3.fromRGB(120, 120, 120),
            Border = Color3.fromRGB(200, 200, 200),
            Success = Color3.fromRGB(67, 181, 129),
            Warning = Color3.fromRGB(250, 166, 26),
            Error = Color3.fromRGB(237, 66, 69),
            Hover = Color3.fromRGB(235, 235, 235),
            Pressed = Color3.fromRGB(225, 225, 225)
        },
        Fonts = {
            Regular = Enum.Font.SourceSans,
            Bold = Enum.Font.SourceSansBold,
            Mono = Enum.Font.Code
        },
        CornerRadius = 6,
        AnimationSpeed = 0.2
    },
    Midnight = {
        Colors = {
            Background = Color3.fromRGB(15, 15, 25),
            Surface = Color3.fromRGB(25, 25, 40),
            Primary = Color3.fromRGB(124, 58, 237),
            Secondary = Color3.fromRGB(40, 40, 60),
            Accent = Color3.fromRGB(139, 92, 246),
            Text = Color3.fromRGB(243, 243, 255),
            TextMuted = Color3.fromRGB(150, 150, 170),
            Border = Color3.fromRGB(50, 50, 70),
            Success = Color3.fromRGB(52, 211, 153),
            Warning = Color3.fromRGB(251, 191, 36),
            Error = Color3.fromRGB(248, 113, 113),
            Hover = Color3.fromRGB(35, 35, 55),
            Pressed = Color3.fromRGB(45, 45, 75)
        },
        Fonts = {
            Regular = Enum.Font.Gotham,
            Bold = Enum.Font.GothamBold,
            Mono = Enum.Font.Code
        },
        CornerRadius = 8,
        AnimationSpeed = 0.25
    },
    Cyber = {
        Colors = {
            Background = Color3.fromRGB(10, 10, 15),
            Surface = Color3.fromRGB(20, 20, 30),
            Primary = Color3.fromRGB(0, 255, 136),
            Secondary = Color3.fromRGB(30, 30, 45),
            Accent = Color3.fromRGB(0, 255, 255),
            Text = Color3.fromRGB(0, 255, 136),
            TextMuted = Color3.fromRGB(0, 200, 100),
            Border = Color3.fromRGB(0, 255, 136),
            Success = Color3.fromRGB(0, 255, 136),
            Warning = Color3.fromRGB(255, 200, 0),
            Error = Color3.fromRGB(255, 50, 50),
            Hover = Color3.fromRGB(30, 40, 50),
            Pressed = Color3.fromRGB(40, 50, 70)
        },
        Fonts = {
            Regular = Enum.Font.Code,
            Bold = Enum.Font.Code,
            Mono = Enum.Font.Code
        },
        CornerRadius = 0,
        AnimationSpeed = 0.15
    }
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADDON SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local AddonSystem = {}
AddonSystem.__index = AddonSystem

function AddonSystem.new(ui)
    local self = setmetatable({}, AddonSystem)
    self.UI = ui
    self.Addons = {}
    self.Hooks = {
        PreRender = {},
        PostRender = {},
        PreExecute = {},
        PostExecute = {},
        WindowCreated = {},
        TabChanged = {}
    }
    self.Events = EventSystem.new()
    return self
end

function AddonSystem:Register(name, addon)
    if self.Addons[name] then
        warn("Addon '" .. name .. "' is already registered!")
        return false
    end
    
    addon._name = name
    addon._ui = self.UI
    addon._enabled = false
    
    -- Initialize addon
    if addon.Init then
        local success, err = pcall(addon.Init, addon)
        if not success then
            warn("Failed to initialize addon '" .. name .. "': " .. tostring(err))
            return false
        end
    end
    
    self.Addons[name] = addon
    self.Events:Emit("AddonRegistered", name, addon)
    return true
end

function AddonSystem:Enable(name)
    local addon = self.Addons[name]
    if not addon then
        warn("Addon '" .. name .. "' not found!")
        return false
    end
    
    if addon._enabled then
        return true
    end
    
    if addon.OnEnable then
        local success, err = pcall(addon.OnEnable, addon)
        if not success then
            warn("Failed to enable addon '" .. name .. "': " .. tostring(err))
            return false
        end
    end
    
    addon._enabled = true
    self.Events:Emit("AddonEnabled", name, addon)
    return true
end

function AddonSystem:Disable(name)
    local addon = self.Addons[name]
    if not addon or not addon._enabled then
        return false
    end
    
    if addon.OnDisable then
        pcall(addon.OnDisable, addon)
    end
    
    addon._enabled = false
    self.Events:Emit("AddonDisabled", name, addon)
    return true
end

function AddonSystem:Unregister(name)
    self:Disable(name)
    self.Addons[name] = nil
    self.Events:Emit("AddonUnregistered", name)
end

function AddonSystem:Get(name)
    return self.Addons[name]
end

function AddonSystem:Hook(hookName, callback)
    if not self.Hooks[hookName] then
        self.Hooks[hookName] = {}
    end
    table.insert(self.Hooks[hookName], callback)
end

function AddonSystem:ExecuteHook(hookName, ...)
    if self.Hooks[hookName] then
        for _, callback in ipairs(self.Hooks[hookName]) do
            pcall(callback, ...)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- BASE COMPONENT CLASS
-- ═══════════════════════════════════════════════════════════════════════════════

local Component = {}
Component.__index = Component

function Component.new(ui, type, config)
    local self = setmetatable({}, Component)
    self.UI = ui
    self.Type = type
    self.Config = config or {}
    self.Instance = nil
    self.Children = {}
    self.Events = EventSystem.new()
    self._destroyed = false
    
    return self
end

function Component:Build(parent)
    error("Build method must be implemented by subclass")
end

function Component:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self.Events:Emit("Destroyed")
    for _, child in ipairs(self.Children) do
        if child.Destroy then
            child:Destroy()
        end
    end
    if self.Instance then
        self.Instance:Destroy()
    end
end

function Component:Animate(properties, duration, callback)
    if self.Instance then
        return Utility.Tween(self.Instance, properties, duration, nil, nil, callback)
    end
end

function Component:SetVisible(visible)
    if self.Instance then
        self.Instance.Visible = visible
    end
end

function Component:SetPosition(position)
    if self.Instance then
        self.Instance.Position = position
    end
end

function Component:SetSize(size)
    if self.Instance then
        self.Instance.Size = size
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI COMPONENTS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Button Component
local Button = setmetatable({}, {__index = Component})
Button.__index = Button

function Button.new(ui, config)
    local self = setmetatable(Component.new(ui, "Button", config), Button)
    self.Config = Utility.CloneTable(config)
    self.Config.Text = self.Config.Text or "Button"
    self.Config.Callback = self.Config.Callback or function() end
    return self
end

function Button:Build(parent)
    local theme = self.UI.Theme
    local config = self.Config
    
    local button = Utility.Create("TextButton", {
        Name = config.Name or "Button",
        Parent = parent,
        Size = config.Size or UDim2.new(0, 120, 0, 32),
        Position = config.Position or UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = theme:GetColor("Primary"),
        BorderSizePixel = 0,
        Text = config.Text,
        TextColor3 = theme:GetColor("Text"),
        Font = theme:GetFont("Regular"),
        TextSize = 14,
        AutoButtonColor = false,
        ClipsDescendants = true
    })
    
    local corner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, theme.Themes[theme.ActiveTheme].CornerRadius),
        Parent = button
    })
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        Utility.Tween(button, {BackgroundColor3 = theme:GetColor("Hover")}, 0.2)
    end)
    
    button.MouseLeave:Connect(function()
        Utility.Tween(button, {BackgroundColor3 = theme:GetColor("Primary")}, 0.2)
    end)
    
    button.MouseButton1Down:Connect(function()
        Utility.Tween(button, {BackgroundColor3 = theme:GetColor("Pressed")}, 0.1)
    end)
    
    button.MouseButton1Up:Connect(function()
        Utility.Tween(button, {BackgroundColor3 = theme:GetColor("Hover")}, 0.1)
    end)
    
    button.MouseButton1Click:Connect(function()
        self.Events:Emit("Click")
        config.Callback()
    end)
    
    self.Instance = button
    return self
end

-- Toggle Component
local Toggle = setmetatable({}, {__index = Component})
Toggle.__index = Toggle

function Toggle.new(ui, config)
    local self = setmetatable(Component.new(ui, "Toggle", config), Toggle)
    self.Config = Utility.CloneTable(config)
    self.Config.Text = self.Config.Text or "Toggle"
    self.Config.Default = self.Config.Default or false
    self.Config.Callback = self.Config.Callback or function() end
    self.Value = self.Config.Default
    return self
end

function Toggle:Build(parent)
    local theme = self.UI.Theme
    local config = self.Config
    
    local container = Utility.Create("Frame", {
        Name = config.Name or "Toggle",
        Parent = parent,
        Size = config.Size or UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1
    })
    
    local label = Utility.Create("TextLabel", {
        Name = "Label",
        Parent = container,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = config.Text,
        TextColor3 = theme:GetColor("Text"),
        Font = theme:GetFont("Regular"),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local toggleBg = Utility.Create("Frame", {
        Name = "ToggleBackground",
        Parent = container,
        Size = UDim2.new(0, 44, 0, 24),
        Position = UDim2.new(1, -44, 0.5, -12),
        BackgroundColor3 = self.Value and theme:GetColor("Primary") or theme:GetColor("Secondary"),
        BorderSizePixel = 0
    })
    
    local corner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = toggleBg
    })
    
    local knob = Utility.Create("Frame", {
        Name = "Knob",
        Parent = toggleBg,
        Size = UDim2.new(0, 20, 0, 20),
        Position = self.Value and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10),
        BackgroundColor3 = theme:GetColor("Text"),
        BorderSizePixel = 0
    })
    
    local knobCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = knob
    })
    
    local clickArea = Utility.Create("TextButton", {
        Name = "ClickArea",
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = ""
    })
    
    local function updateState()
        self.Value = not self.Value
        local targetColor = self.Value and theme:GetColor("Primary") or theme:GetColor("Secondary")
        local targetPos = self.Value and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        
        Utility.Tween(toggleBg, {BackgroundColor3 = targetColor}, 0.2)
        Utility.Tween(knob, {Position = targetPos}, 0.2)
        
        self.Events:Emit("Changed", self.Value)
        config.Callback(self.Value)
    end
    
    clickArea.MouseButton1Click:Connect(updateState)
    
    self.Instance = container
    self.SetValue = function(_, value)
        if self.Value ~= value then
            self.Value = value
            local targetColor = self.Value and theme:GetColor("Primary") or theme:GetColor("Secondary")
            local targetPos = self.Value and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            Utility.Tween(toggleBg, {BackgroundColor3 = targetColor}, 0.2)
            Utility.Tween(knob, {Position = targetPos}, 0.2)
            config.Callback(self.Value)
        end
    end
    
    return self
end

-- Slider Component
local Slider = setmetatable({}, {__index = Component})
Slider.__index = Slider

function Slider.new(ui, config)
    local self = setmetatable(Component.new(ui, "Slider", config), Slider)
    self.Config = Utility.CloneTable(config)
    self.Config.Text = self.Config.Text or "Slider"
    self.Config.Min = self.Config.Min or 0
    self.Config.Max = self.Config.Max or 100
    self.Config.Default = self.Config.Default or self.Config.Min
    self.Config.Callback = self.Config.Callback or function() end
    self.Value = self.Config.Default
    self.Dragging = false
    return self
end

function Slider:Build(parent)
    local theme = self.UI.Theme
    local config = self.Config
    
    local container = Utility.Create("Frame", {
        Name = config.Name or "Slider",
        Parent = parent,
        Size = config.Size or UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1
    })
    
    local label = Utility.Create("TextLabel", {
        Name = "Label",
        Parent = container,
        Size = UDim2.new(1, -50, 0, 20),
        BackgroundTransparency = 1,
        Text = config.Text,
        TextColor3 = theme:GetColor("Text"),
        Font = theme:GetFont("Regular"),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local valueLabel = Utility.Create("TextLabel", {
        Name = "Value",
        Parent = container,
        Size = UDim2.new(0, 50, 0, 20),
        Position = UDim2.new(1, -50, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(self.Value),
        TextColor3 = theme:GetColor("TextMuted"),
        Font = theme:GetFont("Mono"),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right
    })
    
    local track = Utility.Create("Frame", {
        Name = "Track",
        Parent = container,
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 32),
        BackgroundColor3 = theme:GetColor("Secondary"),
        BorderSizePixel = 0
    })
    
    local trackCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = track
    })
    
    local fill = Utility.Create("Frame", {
        Name = "Fill",
        Parent = track,
        Size = UDim2.new((self.Value - config.Min) / (config.Max - config.Min), 0, 1, 0),
        BackgroundColor3 = theme:GetColor("Primary"),
        BorderSizePixel = 0
    })
    
    local fillCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = fill
    })
    
    local knob = Utility.Create("Frame", {
        Name = "Knob",
        Parent = track,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new((self.Value - config.Min) / (config.Max - config.Min), -8, 0.5, -8),
        BackgroundColor3 = theme:GetColor("Text"),
        BorderSizePixel = 0
    })
    
    local knobCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = knob
    })
    
    local function updateValue(input)
        local trackPos = track.AbsolutePosition.X
        local trackSize = track.AbsoluteSize.X
        local mouseX = input.Position.X
        
        local percent = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
        local value = config.Min + (percent * (config.Max - config.Min))
        
        if config.Step then
            value = math.floor(value / config.Step + 0.5) * config.Step
        end
        
        self.Value = value
        valueLabel.Text = tostring(Utility.Round(value, 2))
        
        local fillPercent = (value - config.Min) / (config.Max - config.Min)
        fill.Size = UDim2.new(fillPercent, 0, 1, 0)
        knob.Position = UDim2.new(fillPercent, -8, 0.5, -8)
        
        self.Events:Emit("Changed", value)
        config.Callback(value)
    end
    
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Dragging = true
        end
    end)
    
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Dragging = true
            updateValue(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if self.Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateValue(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Dragging = false
        end
    end)
    
    self.Instance = container
    self.SetValue = function(_, value)
        self.Value = math.clamp(value, config.Min, config.Max)
        local fillPercent = (self.Value - config.Min) / (config.Max - config.Min)
        fill.Size = UDim2.new(fillPercent, 0, 1, 0)
        knob.Position = UDim2.new(fillPercent, -8, 0.5, -8)
        valueLabel.Text = tostring(Utility.Round(self.Value, 2))
        config.Callback(self.Value)
    end
    
    return self
end

-- TextBox Component
local TextBox = setmetatable({}, {__index = Component})
TextBox.__index = TextBox

function TextBox.new(ui, config)
    local self = setmetatable(Component.new(ui, "TextBox", config), TextBox)
    self.Config = Utility.CloneTable(config)
    self.Config.Placeholder = self.Config.Placeholder or "Enter text..."
    self.Config.Callback = self.Config.Callback or function() end
    return self
end

function TextBox:Build(parent)
    local theme = self.UI.Theme
    local config = self.Config
    
    local container = Utility.Create("Frame", {
        Name = config.Name or "TextBox",
        Parent = parent,
        Size = config.Size or UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0
    })
    
    local corner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, theme.Themes[theme.ActiveTheme].CornerRadius),
        Parent = container
    })
    
    local stroke = Utility.Create("UIStroke", {
        Parent = container,
        Color = theme:GetColor("Border"),
        Thickness = 1
    })
    
    local textBox = Utility.Create("TextBox", {
        Name = "Input",
        Parent = container,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = config.Default or "",
        PlaceholderText = config.Placeholder,
        TextColor3 = theme:GetColor("Text"),
        PlaceholderColor3 = theme:GetColor("TextMuted"),
        Font = theme:GetFont("Regular"),
        TextSize = 14,
        ClearTextOnFocus = config.ClearOnFocus or false
    })
    
    textBox.Focused:Connect(function()
        Utility.Tween(stroke, {Color = theme:GetColor("Primary")}, 0.2)
    end)
    
    textBox.FocusLost:Connect(function(enterPressed)
        Utility.Tween(stroke, {Color = theme:GetColor("Border")}, 0.2)
        self.Events:Emit("FocusLost", textBox.Text, enterPressed)
        config.Callback(textBox.Text, enterPressed)
    end)
    
    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        self.Events:Emit("Changed", textBox.Text)
    end)
    
    self.Instance = container
    self.GetText = function()
        return textBox.Text
    end
    self.SetText = function(_, text)
        textBox.Text = text
    end
    
    return self
end

-- Dropdown Component
local Dropdown = setmetatable({}, {__index = Component})
Dropdown.__index = Dropdown

function Dropdown.new(ui, config)
    local self = setmetatable(Component.new(ui, "Dropdown", config), Dropdown)
    self.Config = Utility.CloneTable(config)
    self.Config.Options = self.Config.Options or {}
    self.Config.Default = self.Config.Default or self.Config.Options[1]
    self.Config.Callback = self.Config.Callback or function() end
    self.Open = false
    self.Selected = self.Config.Default
    return self
end

function Dropdown:Build(parent)
    local theme = self.UI.Theme
    local config = self.Config
    
    local container = Utility.Create("Frame", {
        Name = config.Name or "Dropdown",
        Parent = parent,
        Size = config.Size or UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0,
        ClipsDescendants = true
    })
    
    local corner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, theme.Themes[theme.ActiveTheme].CornerRadius),
        Parent = container
    })
    
    local stroke = Utility.Create("UIStroke", {
        Parent = container,
        Color = theme:GetColor("Border"),
        Thickness = 1
    })
    
    local selectedText = Utility.Create("TextLabel", {
        Name = "Selected",
        Parent = container,
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Selected or "Select...",
        TextColor3 = self.Selected and theme:GetColor("Text") or theme:GetColor("TextMuted"),
        Font = theme:GetFont("Regular"),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local arrow = Utility.Create("ImageLabel", {
        Name = "Arrow",
        Parent = container,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -26, 0.5, -10),
        BackgroundTransparency = 1,
        Image = "rbxassetid://7072706748",
        ImageColor3 = theme:GetColor("TextMuted"),
        Rotation = 0
    })
    
    local optionsContainer = Utility.Create("Frame", {
        Name = "Options",
        Parent = container,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0,
        Visible = false
    })
    
    local optionsCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, theme.Themes[theme.ActiveTheme].CornerRadius),
        Parent = optionsContainer
    })
    
    local optionsList = Utility.Create("ScrollingFrame", {
        Name = "List",
        Parent = optionsContainer,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme:GetColor("Primary"),
        CanvasSize = UDim2.new(0, 0, 0, 0)
    })
    
    local listLayout = Utility.Create("UIListLayout", {
        Parent = optionsList,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    })
    
    local function createOption(text, index)
        local option = Utility.Create("TextButton", {
            Name = "Option_" .. index,
            Parent = optionsList,
            Size = UDim2.new(1, -8, 0, 32),
            Position = UDim2.new(0, 4, 0, 0),
            BackgroundColor3 = theme:GetColor("Surface"),
            BorderSizePixel = 0,
            Text = text,
            TextColor3 = theme:GetColor("Text"),
            Font = theme:GetFont("Regular"),
            TextSize = 14
        })
        
        local optionCorner = Utility.Create("UICorner", {
            CornerRadius = UDim.new(0, 4),
            Parent = option
        })
        
        option.MouseEnter:Connect(function()
            Utility.Tween(option, {BackgroundColor3 = theme:GetColor("Hover")}, 0.15)
        end)
        
        option.MouseLeave:Connect(function()
            Utility.Tween(option, {BackgroundColor3 = theme:GetColor("Surface")}, 0.15)
        end)
        
        option.MouseButton1Click:Connect(function()
            self.Selected = text
            selectedText.Text = text
            selectedText.TextColor3 = theme:GetColor("Text")
            
            self:Toggle(false)
            self.Events:Emit("Selected", text)
            config.Callback(text)
        end)
        
        return option
    end
    
    for i, option in ipairs(config.Options) do
        createOption(option, i)
    end
    
    optionsList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
    
    local clickArea = Utility.Create("TextButton", {
        Name = "ClickArea",
        Parent = container,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = ""
    })
    
    self.Toggle = function(_, open)
        self.Open = open ~= nil and open or not self.Open
        local targetSize = self.Open and UDim2.new(1, 0, 0, 36 + math.min(#config.Options * 34, 200)) or UDim2.new(1, 0, 0, 36)
        local targetRot = self.Open and 180 or 0
        
        optionsContainer.Visible = true
        Utility.Tween(container, {Size = targetSize}, 0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, function()
            if not self.Open then
                optionsContainer.Visible = false
            end
        end)
        Utility.Tween(arrow, {Rotation = targetRot}, 0.3)
    end
    
    clickArea.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    self.Instance = container
    self.SetOptions = function(_, newOptions)
        for _, child in ipairs(optionsList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        config.Options = newOptions
        for i, option in ipairs(newOptions) do
            createOption(option, i)
        end
        optionsList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
    end
    
    self.SetSelected = function(_, text)
        if table.find(config.Options, text) then
            self.Selected = text
            selectedText.Text = text
            selectedText.TextColor3 = theme:GetColor("Text")
            config.Callback(text)
        end
    end
    
    return self
end

-- Label Component
local Label = setmetatable({}, {__index = Component})
Label.__index = Label

function Label.new(ui, config)
    local self = setmetatable(Component.new(ui, "Label", config), Label)
    self.Config = Utility.CloneTable(config)
    self.Config.Text = self.Config.Text or "Label"
    return self
end

function Label:Build(parent)
    local theme = self.UI.Theme
    
    local label = Utility.Create("TextLabel", {
        Name = self.Config.Name or "Label",
        Parent = parent,
        Size = self.Config.Size or UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = self.Config.Text,
        TextColor3 = self.Config.Color or theme:GetColor("Text"),
        Font = self.Config.Font or theme:GetFont("Regular"),
        TextSize = self.Config.TextSize or 14,
        TextXAlignment = self.Config.Alignment or Enum.TextXAlignment.Left,
        TextWrapped = self.Config.Wrapped or false
    })
    
    self.Instance = label
    self.SetText = function(_, text)
        label.Text = text
    end
    
    return self
end

-- Section Component
local Section = setmetatable({}, {__index = Component})
Section.__index = Section

function Section.new(ui, config)
    local self = setmetatable(Component.new(ui, "Section", config), Section)
    self.Config = Utility.CloneTable(config)
    self.Config.Title = self.Config.Title or "Section"
    return self
end

function Section:Build(parent)
    local theme = self.UI.Theme
    
    local container = Utility.Create("Frame", {
        Name = self.Config.Name or "Section",
        Parent = parent,
        Size = self.Config.Size or UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0
    })
    
    local corner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, theme.Themes[theme.ActiveTheme].CornerRadius),
        Parent = container
    })
    
    local title = Utility.Create("TextLabel", {
        Name = "Title",
        Parent = container,
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, 5),
        BackgroundTransparency = 1,
        Text = self.Config.Title,
        TextColor3 = theme:GetColor("Text"),
        Font = theme:GetFont("Bold"),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local content = Utility.Create("Frame", {
        Name = "Content",
        Parent = container,
        Size = UDim2.new(1, -20, 1, -40),
        Position = UDim2.new(0, 10, 0, 35),
        BackgroundTransparency = 1
    })
    
    local layout = Utility.Create("UIListLayout", {
        Parent = content,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8)
    })
    
    self.Instance = container
    self.Content = content
    
    return self
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN WINDOW CLASS
-- ═══════════════════════════════════════════════════════════════════════════════

local Window = {}
Window.__index = Window

function Window.new(ui, config)
    local self = setmetatable({}, Window)
    self.UI = ui
    self.Config = Utility.CloneTable(config)
    self.Config.Title = self.Config.Title or "Vex UI"
    self.Config.Size = self.Config.Size or UDim2.new(0, 600, 0, 400)
    
    self.Tabs = {}
    self.ActiveTab = nil
    self.Minimized = false
    self.Events = EventSystem.new()
    
    return self
end

function Window:Build()
    local theme = self.UI.Theme
    
    -- Main ScreenGui
    self.ScreenGui = Utility.Create("ScreenGui", {
        Name = "VexUI_" .. Utility.GenerateId(6),
        Parent = PlayerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    
    -- Main Container
    self.MainFrame = Utility.Create("Frame", {
        Name = "Main",
        Parent = self.ScreenGui,
        Size = self.Config.Size,
        Position = UDim2.new(0.5, -self.Config.Size.X.Offset/2, 0.5, -self.Config.Size.Y.Offset/2),
        BackgroundColor3 = theme:GetColor("Background"),
        BorderSizePixel = 0,
        ClipsDescendants = true
    })
    
    local mainCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, 12),
        Parent = self.MainFrame
    })
    
    local mainStroke = Utility.Create("UIStroke", {
        Parent = self.MainFrame,
        Color = theme:GetColor("Border"),
        Thickness = 1
    })
    
    -- Shadow
    local shadow = Utility.Create("ImageLabel", {
        Name = "Shadow",
        Parent = self.ScreenGui,
        Size = UDim2.new(0, self.Config.Size.X.Offset + 40, 0, self.Config.Size.Y.Offset + 40),
        Position = UDim2.new(0.5, -(self.Config.Size.X.Offset + 40)/2, 0.5, -(self.Config.Size.Y.Offset + 40)/2),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6015897843",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0
    })
    
    -- Title Bar
    local titleBar = Utility.Create("Frame", {
        Name = "TitleBar",
        Parent = self.MainFrame,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0
    })
    
    local titleCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, 12),
        Parent = titleBar
    })
    
    -- Fix corner for title bar
    local titleFix = Utility.Create("Frame", {
        Name = "Fix",
        Parent = titleBar,
        Size = UDim2.new(1, 0, 0.5, 0),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0
    })
    
    local titleLabel = Utility.Create("TextLabel", {
        Name = "Title",
        Parent = titleBar,
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Config.Title,
        TextColor3 = theme:GetColor("Text"),
        Font = theme:GetFont("Bold"),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    -- Window Controls
    local controls = Utility.Create("Frame", {
        Name = "Controls",
        Parent = titleBar,
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(1, -85, 0, 0),
        BackgroundTransparency = 1
    })
    
    local minimizeBtn = Utility.Create("TextButton", {
        Name = "Minimize",
        Parent = controls,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(0, 5, 0.5, -15),
        BackgroundColor3 = theme:GetColor("Secondary"),
        BorderSizePixel = 0,
        Text = "-",
        TextColor3 = theme:GetColor("Text"),
        Font = theme:GetFont("Bold"),
        TextSize = 18
    })
    
    local minCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = minimizeBtn
    })
    
    local closeBtn = Utility.Create("TextButton", {
        Name = "Close",
        Parent = controls,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(0, 40, 0.5, -15),
        BackgroundColor3 = theme:GetColor("Error"),
        BorderSizePixel = 0,
        Text = "×",
        TextColor3 = Color3.new(1, 1, 1),
        Font = theme:GetFont("Bold"),
        TextSize = 18
    })
    
    local closeCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = closeBtn
    })
    
    -- Tab Container
    local tabContainer = Utility.Create("Frame", {
        Name = "TabContainer",
        Parent = self.MainFrame,
        Size = UDim2.new(0, 120, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0
    })
    
    local tabLayout = Utility.Create("UIListLayout", {
        Parent = tabContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2)
    })
    
    local tabPadding = Utility.Create("UIPadding", {
        Parent = tabContainer,
        PaddingTop = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10)
    })
    
    -- Content Container
    self.ContentFrame = Utility.Create("Frame", {
        Name = "Content",
        Parent = self.MainFrame,
        Size = UDim2.new(1, -120, 1, -40),
        Position = UDim2.new(0, 120, 0, 40),
        BackgroundColor3 = theme:GetColor("Background"),
        BorderSizePixel = 0
    })
    
    -- Dragging
    Utility.Drag(self.MainFrame, titleBar)
    
    -- Controls functionality
    minimizeBtn.MouseButton1Click:Connect(function()
        self:Minimize()
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        self:Close()
    end)
    
    self.TabContainer = tabContainer
    self.Shadow = shadow
    
    -- Theme change listener
    self.UI.Theme.Events:On("ThemeChanged", function()
        self:UpdateTheme()
    end)
    
    return self
end

function Window:AddTab(name, icon)
    local theme = self.UI.Theme
    
    local tabBtn = Utility.Create("TextButton", {
        Name = "Tab_" .. name,
        Parent = self.TabContainer,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = theme:GetColor("Secondary"),
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = theme:GetColor("TextMuted"),
        Font = theme:GetFont("Regular"),
        TextSize = 14
    })
    
    local tabCorner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = tabBtn
    })
    
    local contentFrame = Utility.Create("ScrollingFrame", {
        Name = "Content_" .. name,
        Parent = self.ContentFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme:GetColor("Primary"),
        CanvasSize = UDim2.new(0, 0, 0, 0)
    })
    
    local contentPadding = Utility.Create("UIPadding", {
        Parent = contentFrame,
        PaddingTop = UDim.new(0, 15),
        PaddingLeft = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),
        PaddingBottom = UDim.new(0, 15)
    })
    
    local contentLayout = Utility.Create("UIListLayout", {
        Parent = contentFrame,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10)
    })
    
    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 30)
    end)
    
    local tab = {
        Name = name,
        Button = tabBtn,
        Content = contentFrame,
        Components = {}
    }
    
    tabBtn.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)
    
    table.insert(self.Tabs, tab)
    
    if #self.Tabs == 1 then
        self:SelectTab(name)
    end
    
    return contentFrame, tab
end

function Window:SelectTab(name)
    local theme = self.UI.Theme
    
    for _, tab in ipairs(self.Tabs) do
        if tab.Name == name then
            tab.Content.Visible = true
            Utility.Tween(tab.Button, {BackgroundColor3 = theme:GetColor("Primary")}, 0.2)
            tab.Button.TextColor3 = theme:GetColor("Text")
            self.ActiveTab = tab
        else
            tab.Content.Visible = false
            Utility.Tween(tab.Button, {BackgroundColor3 = theme:GetColor("Secondary")}, 0.2)
            tab.Button.TextColor3 = theme:GetColor("TextMuted")
        end
    end
    
    self.Events:Emit("TabChanged", name)
    self.UI.Addons:ExecuteHook("TabChanged", name)
end

function Window:Minimize()
    self.Minimized = not self.Minimized
    local targetSize = self.Minimized and UDim2.new(0, self.Config.Size.X.Offset, 0, 40) or self.Config.Size
    local targetShadowSize = self.Minimized and 
        UDim2.new(0, self.Config.Size.X.Offset + 40, 0, 80) or 
        UDim2.new(0, self.Config.Size.X.Offset + 40, 0, self.Config.Size.Y.Offset + 40)
    
    Utility.Tween(self.MainFrame, {Size = targetSize}, 0.3)
    Utility.Tween(self.Shadow, {Size = targetShadowSize}, 0.3)
    
    self.ContentFrame.Visible = not self.Minimized
    self.TabContainer.Visible = not self.Minimized
end

function Window:Close()
    Utility.Tween(self.MainFrame, {Size = UDim2.new(0, 0, 0, 0)}, 0.3, nil, nil, function()
        self.ScreenGui:Destroy()
        self.Events:Emit("Closed")
    end)
    Utility.Tween(self.Shadow, {ImageTransparency = 1}, 0.3)
end

function Window:UpdateTheme()
    local theme = self.UI.Theme
    -- Update all colors based on new theme
    -- This would recursively update all child elements
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN VEX UI CLASS
-- ═══════════════════════════════════════════════════════════════════════════════

function Vex.new(config)
    local self = setmetatable({}, Vex)
    config = config or {}
    
    -- Initialize systems
    self.Theme = ThemeSystem.new()
    for name, theme in pairs(DefaultThemes) do
        self.Theme:Register(name, theme)
    end
    
    self.Config = ConfigSystem.new("VexMain", {
        Theme = "Dark",
        AnimationSpeed = 0.2,
        ShowShadows = true,
        AutoSave = true
    })
    
    self.Addons = AddonSystem.new(self)
    self.Events = EventSystem.new()
    self.Windows = {}
    
    -- Set initial theme from config
    self.Theme:SetTheme(self.Config:Get("Theme"))
    
    -- Watch for theme changes in config
    self.Config.Events:On("Changed", function(key, value)
        if key == "Theme" then
            self.Theme:SetTheme(value)
        end
    end)
    
    return self
end

function Vex:CreateWindow(windowConfig)
    local window = Window.new(self, windowConfig)
    window:Build()
    table.insert(self.Windows, window)
    self.Addons:ExecuteHook("WindowCreated", window)
    return window
end

function Vex:CreateComponent(type, config, parent)
    local component
    
    if type == "Button" then
        component = Button.new(self, config)
    elseif type == "Toggle" then
        component = Toggle.new(self, config)
    elseif type == "Slider" then
        component = Slider.new(self, config)
    elseif type == "TextBox" then
        component = TextBox.new(self, config)
    elseif type == "Dropdown" then
        component = Dropdown.new(self, config)
    elseif type == "Label" then
        component = Label.new(self, config)
    elseif type == "Section" then
        component = Section.new(self, config)
    else
        error("Unknown component type: " .. tostring(type))
    end
    
    component:Build(parent)
    return component
end

function Vex:Notify(config)
    config = config or {}
    local title = config.Title or "Notification"
    local message = config.Message or ""
    local duration = config.Duration or 3
    local type = config.Type or "Info" -- Info, Success, Warning, Error
    
    local theme = self.Theme
    
    local notification = Utility.Create("Frame", {
        Name = "Notification",
        Parent = PlayerGui,
        Size = UDim2.new(0, 300, 0, 80),
        Position = UDim2.new(1, 20, 1, -100),
        BackgroundColor3 = theme:GetColor("Surface"),
        BorderSizePixel = 0
    })
    
    local corner = Utility.Create("UICorner", {
        CornerRadius = UDim.new(0, 8),
        Parent = notification
    })
    
    local stroke = Utility.Create("UIStroke", {
        Parent = notification,
        Color = type == "Error" and theme:GetColor("Error") or 
                type == "Success" and theme:GetColor("Success") or
                type == "Warning" and theme:GetColor("Warning") or theme:GetColor("Primary"),
        Thickness = 2
    })
    
    local titleLabel = Utility.Create("TextLabel", {
        Name = "Title",
        Parent = notification,
        Size = UDim2.new(1, -20, 0, 25),
        Position = UDim2.new(0, 10, 0, 5),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme:GetColor("Text"),
        Font = theme:GetFont("Bold"),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local messageLabel = Utility.Create("TextLabel", {
        Name = "Message",
        Parent = notification,
        Size = UDim2.new(1, -20, 0, 45),
        Position = UDim2.new(0, 10, 0, 30),
        BackgroundTransparency = 1,
        Text = message,
        TextColor3 = theme:GetColor("TextMuted"),
        Font = theme:GetFont("Regular"),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true
    })
    
    -- Animate in
    Utility.Tween(notification, {Position = UDim2.new(1, -320, 1, -100)}, 0.5, Enum.EasingStyle.Back)
    
    task.delay(duration, function()
        Utility.Tween(notification, {Position = UDim2.new(1, 20, 1, -100)}, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In, function()
            notification:Destroy()
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════════════════════

return Vex
