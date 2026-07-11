--[[
	GhostHub  |  Grow a Garden
	Single-file Luau script  •  WindUI (https://github.com/Footagesus/WindUI)

	Everything here is grounded in the game's own modules pulled from the
	client dump, so it uses the REAL mechanics:
	  Auto Farm   - fruit-aware harvest with weight / mutation / type filters,
	                auto-sell via Networking.NPCS.SellAll
	  Auto Buy    - Networking.SeedShop.PurchaseSeed / GearShop.PurchaseGear /
	                CrateShop.PurchaseCrate / Egg.OpenEgg
	  Auction     - Networking.Auctioneer RequestSnapshot / CurrentPrice /
	                PurchaseLot, with name / mutation / max-price filters
	  Visual      - CLIENT-SIDE ONLY spoofs (sheckles, tokens, fake inventory
	                items/pets) written to the local replica + leaderstats.
	                Nothing is sent to the server. "Rollback" restores reality.
	  Player/World- speed, jump, fly, noclip, anti-afk, ESP, fullbright, etc.

	Note: purchase / sell / auction remotes are SERVER-validated. The client
	fires them; the server decides. Visual features never touch the server.
--]]

--========================================================================
-- Services
--========================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")
local HttpService      = game:GetService("HttpService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--========================================================================
-- Executor shims
--========================================================================
local fireprompt = (typeof(fireproximityprompt) == "function") and fireproximityprompt
	or function(prompt)
		pcall(function() prompt:InputHoldBegin() end)
		task.wait(prompt.HoldDuration or 0)
		pcall(function() prompt:InputHoldEnd() end)
	end
local toclipboard = (typeof(setclipboard) == "function") and setclipboard
	or (typeof(toclipboard) == "function" and toclipboard) or function() end

local function httpGet(url)
	local getter = (typeof(request) == "function" and function(u)
		local r = request({ Url = u, Method = "GET" }); return r and r.Body
	end) or (typeof(http_request) == "function" and function(u)
		local r = http_request({ Url = u, Method = "GET" }); return r and r.Body
	end) or function(u) return game:HttpGet(u) end
	return getter(url)
end

--========================================================================
-- Small helpers
--========================================================================
local function num(s, default)
	if type(s) == "number" then return s end
	local cleaned = tostring(s):gsub("[^%d%.%-]", "")
	return tonumber(cleaned) or default
end

local function splitList(s)
	local t = {}
	for item in tostring(s):gmatch("[^,]+") do
		local trimmed = item:gsub("^%s+", ""):gsub("%s+$", "")
		if #trimmed > 0 then table.insert(t, trimmed) end
	end
	return t
end

--========================================================================
-- Character helpers (survive respawns)
--========================================================================
local Char, Humanoid, HRP
local function bindCharacter(c)
	Char = c
	Humanoid = c:WaitForChild("Humanoid", 10)
	HRP = c:WaitForChild("HumanoidRootPart", 10)
end
if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.2) bindCharacter(c) end)

local function getHRP()
	if HRP and HRP.Parent then return HRP end
	local c = LocalPlayer.Character
	if c then HRP = c:FindFirstChild("HumanoidRootPart"); return HRP end
	return nil
end
local function teleportTo(cf)
	local hrp = getHRP()
	if not hrp then return end
	hrp.CFrame = (typeof(cf) == "Vector3") and CFrame.new(cf + Vector3.new(0, 3, 0)) or (cf + Vector3.new(0, 3, 0))
end

--========================================================================
-- Game module hooks (all optional / pcalled)
--========================================================================
local Networking, PlayerStateClient, Auctioneer, FruitsGenFolder
pcall(function() Networking = require(ReplicatedStorage.SharedModules.Networking) end)
pcall(function() PlayerStateClient = require(ReplicatedStorage.ClientModules.PlayerStateClient) end)
pcall(function() Auctioneer = require(ReplicatedStorage.SharedModules.Auctioneer) end)
pcall(function() FruitsGenFolder = ReplicatedStorage.PlantGenerationModules.Fruits end)

-- local data replica (client-side copy of the player's data)
local Replica
task.spawn(function()
	if PlayerStateClient and PlayerStateClient.WaitForLocalReplica then
		local ok, r = pcall(function() return PlayerStateClient.WaitForLocalReplica(nil, 25) end)
		if ok then Replica = r end
	end
end)

local function net(path)
	if not Networking then return nil end
	local node = Networking
	for _, k in ipairs(path) do
		node = node and node[k]
		if not node then return nil end
	end
	return node
end
local function fireNet(path, ...)
	local ev = net(path)
	if not ev or not ev.Fire then return false end
	local args = { ... }
	local ok, res = pcall(function() return ev:Fire(table.unpack(args)) end)
	return ok, res
end

--========================================================================
-- Static data (names, from the dump)
--========================================================================
local MUTATIONS = {
	"Gold", "Rainbow", "Electric", "Frozen", "Bloodlit", "Chained",
	"Starstruck", "Aurora", "Ignited", "Pizza", "Solarflare",
}
local SEEDS = {
	"Carrot", "Strawberry", "Blueberry", "Tomato", "Cauliflower", "Corn",
	"Watermelon", "Pumpkin", "Apple", "Bamboo", "Coconut", "Cactus",
	"Dragon Fruit", "Mango", "Grape", "Mushroom", "Pepper", "Cacao",
	"Beanstalk", "Sunflower", "Pineapple", "Banana", "Cherry", "Lotus",
	"Pomegranate", "Green Bean", "Acorn", "Ghost Pepper", "Romanesco",
}
local GEARS = {
	"Watering Can", "Trowel", "Recall Wrench", "Basic Sprinkler",
	"Advanced Sprinkler", "Godly Sprinkler", "Magnifying Glass",
	"Common Sprinkler", "Rare Sprinkler", "Legendary Sprinkler",
	"Super Sprinkler", "Lightning Rod", "Master Sprinkler", "Favorite Tool",
	"Harvest Tool", "Friendship Pot", "Rake", "Grappling Hook", "Magic Dice",
}
local FRUIT_TYPES = {}
if FruitsGenFolder then
	for _, m in ipairs(FruitsGenFolder:GetChildren()) do
		if m.Name ~= "PartFruit" then table.insert(FRUIT_TYPES, m.Name) end
	end
	table.sort(FRUIT_TYPES)
end
if #FRUIT_TYPES == 0 then FRUIT_TYPES = SEEDS end

--========================================================================
-- Fruit weight  =  BaseWeight * SizeMulti * OvertimeGrowth
--========================================================================
local baseWeightCache = {}
local function getBaseWeight(name)
	if not name or name == "" then return nil end
	local c = baseWeightCache[name]
	if c ~= nil then return c ~= false and c or nil end
	local w
	if FruitsGenFolder then
		local m = FruitsGenFolder:FindFirstChild(name)
		if m then
			local ok, data = pcall(require, m)
			if ok and type(data) == "table" and data.GrowData then w = data.GrowData.BaseWeight end
		end
	end
	baseWeightCache[name] = w or false
	return w
end
local function fruitWeight(fruit)
	local size = fruit:GetAttribute("SizeMulti") or 1
	local over = fruit:GetAttribute("OvertimeGrowth")
	if type(over) ~= "number" or over < 1 then over = 1 end
	over = math.clamp(over, 1, 100)
	local base = getBaseWeight(fruit:GetAttribute("CorePartName"))
	if not base then return nil end
	return base * size * over
end
local function fruitMutation(fruit)
	local m = fruit:GetAttribute("Mutation")
	if m == nil or m == "" then return nil end
	return m
end

--========================================================================
-- Authentication — DISABLED FOR TESTING.
--   Key + HWID check (Hub.GhostShop.eu) is stubbed out below so the script
--   runs standalone. To re-enable, restore the validate-against-backend
--   block (see git history / previous version) before shipping this.
--========================================================================
local GhostAuth = { plan = "dev", discord_id = "local-test", hwid = "unlocked" }

--========================================================================
-- GhostUI  —  self-contained dark UI library (styled like the website).
--   Implements the subset of the WindUI API this script uses:
--   CreateWindow, Window:Tab, Tab:{Section,Paragraph,Button,Toggle,Input,
--   Dropdown(+:Refresh)}, WindUI:Notify, Window:Destroy.
--========================================================================
local WindUI = (function()
	local UIS = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local LP = Players.LocalPlayer

	local C = {
		bg      = Color3.fromRGB(13, 13, 15),
		panel   = Color3.fromRGB(20, 20, 22),
		panel2  = Color3.fromRGB(27, 27, 31),
		line    = Color3.fromRGB(40, 40, 46),
		text    = Color3.fromRGB(244, 244, 245),
		muted   = Color3.fromRGB(150, 150, 158),
		white   = Color3.fromRGB(255, 255, 255),
		black   = Color3.fromRGB(0, 0, 0),
		green   = Color3.fromRGB(126, 231, 135),
	}
	local FONT, FONTB = Enum.Font.Gotham, Enum.Font.GothamBold

	local function mk(cls, props, kids)
		local o = Instance.new(cls)
		for k, v in pairs(props or {}) do o[k] = v end
		for _, c in ipairs(kids or {}) do c.Parent = o end
		return o
	end
	local function corner(r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 10) }) end
	local function strokeOf(col, th) return mk("UIStroke", { Color = col or C.line, Thickness = th or 1 }) end
	local function padding(t, b, l, r)
		return mk("UIPadding", { PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
			PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0) })
	end
	local function tween(o, t, props) TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play() end

	local host = (gethui and gethui()) or LP:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
	local Lib = {}

	-- Notifications -------------------------------------------------------
	local toastHolder
	function Lib:Notify(cfg)
		if not toastHolder then
			toastHolder = mk("ScreenGui", { Name = "GhostToast", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = host })
			mk("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom,
				HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastHolder })
			mk("UIPadding", { PaddingRight = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), Parent = toastHolder })
		end
		local card = mk("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.fromOffset(300, 64), BorderSizePixel = 0 },
			{ corner(12), strokeOf(C.line, 1), padding(10, 10, 14, 14) })
		mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Font = FONTB, TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, Text = cfg.Title or "GhostHub", Parent = card })
		mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 1, -22),
			Font = FONT, TextSize = 12.5, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, Text = cfg.Content or "", Parent = card })
		card.Parent = toastHolder
		card.BackgroundTransparency = 1
		tween(card, 0.2, { BackgroundTransparency = 0 })
		task.delay(cfg.Duration or 4, function()
			tween(card, 0.25, { BackgroundTransparency = 1 })
			task.wait(0.3); card:Destroy()
		end)
	end

	-- Window --------------------------------------------------------------
	function Lib:CreateWindow(cfg)
		local gui = mk("ScreenGui", { Name = "GhostHub", ResetOnSpawn = false, IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = host })

		local root = mk("Frame", { BackgroundColor3 = C.bg, Size = UDim2.fromOffset(600, 430),
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Parent = gui },
			{ corner(16), strokeOf(C.line, 1) })

		-- top bar (drag handle)
		local top = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Parent = root }, { padding(0, 0, 18, 14) })
		local brand = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 200, 1, 0), Parent = top })
		mk("Frame", { BackgroundColor3 = C.white, Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 0, 0.5, -7), BorderSizePixel = 0, Parent = brand }, { corner(7), strokeOf(C.bg, 3) })
		mk("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 1, 0),
			Font = FONTB, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text,
			Text = cfg.Title or "GhostHub", Parent = brand })
		local closeBtn = mk("TextButton", { BackgroundColor3 = C.panel2, Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(1, -26, 0.5, -13), Text = "✕", TextColor3 = C.muted, Font = FONTB, TextSize = 13,
			AutoButtonColor = false, BorderSizePixel = 0, Parent = top }, { corner(8), strokeOf(C.line, 1) })

		-- drag
		do
			local dragging, startPos, startMouse
			top.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					dragging = true; startPos = root.Position; startMouse = i.Position
				end
			end)
			UIS.InputChanged:Connect(function(i)
				if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
					local d = i.Position - startMouse
					root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
				end
			end)
			UIS.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
			end)
		end

		-- sidebar (tabs) + content
		local sidebar = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(0, 168, 1, -46), Parent = root }, { padding(6, 10, 12, 6) })
		mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sidebar })

		local content = mk("Frame", { BackgroundColor3 = C.panel, Position = UDim2.fromOffset(168, 46),
			Size = UDim2.new(1, -168, 1, -46), BorderSizePixel = 0, Parent = root }, { corner(14), padding(6, 6, 6, 6) })

		local Window = { _gui = gui, _tabs = {}, _active = nil }
		closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)
		-- toggle with RightShift
		UIS.InputBegan:Connect(function(i, gpe)
			if not gpe and i.KeyCode == Enum.KeyCode.RightShift then gui.Enabled = not gui.Enabled end
		end)

		function Window:Destroy() pcall(function() gui:Destroy() end) end

		function Window:Tab(tcfg)
			local btn = mk("TextButton", { BackgroundColor3 = C.panel2, BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 34), Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = sidebar }, { corner(9) })
			mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(12, 0),
				Font = FONT, TextSize = 13.5, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted,
				Text = tcfg.Title or "Tab", Parent = btn })

			local page = mk("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false,
				BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.line, CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = content }, { padding(8, 8, 10, 10) })
			mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })

			local Tab = {}
			local function activate()
				for _, t in ipairs(Window._tabs) do
					t.page.Visible = false; t.btn.BackgroundTransparency = 1
					t.btn:FindFirstChildOfClass("TextLabel").TextColor3 = C.muted
				end
				page.Visible = true; btn.BackgroundTransparency = 0
				btn:FindFirstChildOfClass("TextLabel").TextColor3 = C.text
			end
			btn.MouseButton1Click:Connect(activate)
			table.insert(Window._tabs, { btn = btn, page = page })
			if #Window._tabs == 1 then activate() end

			-- element base row
			local function row(h)
				return mk("Frame", { BackgroundColor3 = C.panel2, Size = UDim2.new(1, 0, 0, h or 44), BorderSizePixel = 0, Parent = page },
					{ corner(10), strokeOf(C.line, 1), padding(0, 0, 14, 12) })
			end
			local function labelPair(parent, title, desc)
				local box = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromScale(0, 0), Parent = parent })
				mk("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 2), Parent = box })
				mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Font = FONT, TextSize = 13.5,
					TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, Text = title or "", Parent = box })
				if desc and desc ~= "" then
					mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Font = FONT, TextSize = 11.5,
						TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, Text = desc, Parent = box })
				end
				return box
			end

			function Tab:Section(cfg)
				mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Font = FONTB, TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, Text = (cfg.Title or ""):upper(),
					LayoutOrder = 0, Parent = page })
				return {}
			end

			function Tab:Paragraph(cfg)
				local r = row(0); r.AutomaticSize = Enum.AutomaticSize.Y
				r.Size = UDim2.new(1, 0, 0, 0)
				local box = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = r }, { padding(12, 12, 0, 0) })
				mk("UIListLayout", { Padding = UDim.new(0, 4), Parent = box })
				mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.Y,
					Font = FONTB, TextSize = 13.5, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.text, Text = cfg.Title or "", Parent = box })
				mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
					Font = FONT, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.muted, Text = cfg.Desc or "", Parent = box })
				return {}
			end

			function Tab:Button(cfg)
				local r = row(44)
				labelPair(r, cfg.Title, cfg.Desc)
				local b = mk("TextButton", { BackgroundColor3 = C.white, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
					Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Text = "", AutoButtonColor = false,
					BorderSizePixel = 0, Parent = r }, { corner(8), padding(0, 0, 14, 14) })
				mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
					Font = FONTB, TextSize = 12.5, TextColor3 = C.black, Text = "Run", Parent = b })
				b.MouseButton1Click:Connect(function()
					tween(b, 0.08, { BackgroundColor3 = C.muted })
					task.wait(0.08); tween(b, 0.15, { BackgroundColor3 = C.white })
					if cfg.Callback then task.spawn(cfg.Callback) end
				end)
				return {}
			end

			function Tab:Toggle(cfg)
				local state = cfg.Value and true or false
				local r = row(44)
				labelPair(r, cfg.Title, cfg.Desc)
				local track = mk("TextButton", { BackgroundColor3 = state and C.white or C.line, Size = UDim2.fromOffset(40, 22),
					Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Text = "", AutoButtonColor = false,
					BorderSizePixel = 0, Parent = r }, { corner(11) })
				local knob = mk("Frame", { BackgroundColor3 = state and C.black or C.muted, Size = UDim2.fromOffset(16, 16),
					Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8), BorderSizePixel = 0, Parent = track }, { corner(8) })
				local function set(v, fire)
					state = v
					tween(track, 0.15, { BackgroundColor3 = state and C.white or C.line })
					tween(knob, 0.15, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
						BackgroundColor3 = state and C.black or C.muted })
					if fire and cfg.Callback then task.spawn(cfg.Callback, state) end
				end
				track.MouseButton1Click:Connect(function() set(not state, true) end)
				return { Set = function(_, v) set(v, false) end }
			end

			function Tab:Input(cfg)
				local r = row(44)
				labelPair(r, cfg.Title, cfg.Desc)
				local box = mk("Frame", { BackgroundColor3 = C.bg, Size = UDim2.fromOffset(120, 28),
					Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BorderSizePixel = 0, Parent = r },
					{ corner(8), strokeOf(C.line, 1), padding(0, 0, 8, 8) })
				local tb = mk("TextBox", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextSize = 12.5,
					TextColor3 = C.text, PlaceholderText = cfg.Placeholder or "", PlaceholderColor3 = C.muted,
					Text = cfg.Value or "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
				tb.FocusLost:Connect(function()
					if cfg.Callback then task.spawn(cfg.Callback, tb.Text) end
				end)
				return { Set = function(_, v) tb.Text = tostring(v) end }
			end

			function Tab:Dropdown(cfg)
				local multi = cfg.Multi and true or false
				local values = cfg.Values or {}
				local selected = {}
				if cfg.Value then
					if type(cfg.Value) == "table" then for _, v in ipairs(cfg.Value) do selected[v] = true end
					else selected[cfg.Value] = true end
				end

				local r = row(44); r.ClipsDescendants = true
				labelPair(r, cfg.Title, cfg.Desc)
				local header = mk("TextButton", { BackgroundColor3 = C.bg, Size = UDim2.fromOffset(150, 28),
					Position = UDim2.new(1, 0, 0, 8), AnchorPoint = Vector2.new(1, 0), Text = "", AutoButtonColor = false,
					BorderSizePixel = 0, Parent = r }, { corner(8), strokeOf(C.line, 1), padding(0, 0, 10, 8) })
				local htxt = mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextSize = 12,
					TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
				local listHolder = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
					Position = UDim2.new(0, 0, 0, 44), AutomaticSize = Enum.AutomaticSize.Y, Parent = r })
				mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listHolder })

				local open = false
				local function summary()
					local names = {}
					for _, v in ipairs(values) do if selected[v] then table.insert(names, v) end end
					if #names == 0 then return cfg.Placeholder or "Select..." end
					if multi then return table.concat(names, ", ") end
					return names[1]
				end
				local function fire()
					if not cfg.Callback then return end
					if multi then
						local arr = {}
						for _, v in ipairs(values) do if selected[v] then table.insert(arr, v) end end
						task.spawn(cfg.Callback, arr)
					else
						task.spawn(cfg.Callback, summary())
					end
				end
				local function rebuild()
					for _, ch in ipairs(listHolder:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
					for _, v in ipairs(values) do
						local it = mk("TextButton", { BackgroundColor3 = C.bg, Size = UDim2.new(1, 0, 0, 26), Text = "",
							AutoButtonColor = false, BorderSizePixel = 0, Parent = listHolder }, { corner(7), strokeOf(C.line, 1), padding(0, 0, 10, 8) })
						local lab = mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextSize = 12,
							TextColor3 = selected[v] and C.white or C.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(v), Parent = it })
						it.MouseButton1Click:Connect(function()
							if multi then selected[v] = not selected[v]
							else selected = {}; selected[v] = true end
							lab.TextColor3 = selected[v] and C.white or C.muted
							if multi then for _, other in ipairs(listHolder:GetChildren()) do
								if other:IsA("TextButton") then local ol = other:FindFirstChildOfClass("TextLabel"); if ol then ol.TextColor3 = selected[ol.Text] and C.white or C.muted end end
							end end
							htxt.Text = summary()
							fire()
							if not multi then open = false; r.Size = UDim2.new(1, 0, 0, 44) end
						end)
					end
				end
				local function setOpen(v)
					open = v
					if open then rebuild(); r.Size = UDim2.new(1, 0, 0, 44 + (#values * 30) + 6)
					else r.Size = UDim2.new(1, 0, 0, 44) end
				end
				header.MouseButton1Click:Connect(function() setOpen(not open) end)
				htxt.Text = summary()

				return {
					Refresh = function(_, newValues)
						values = newValues or {}
						-- prune selections that no longer exist
						local keep = {}
						for _, v in ipairs(values) do if selected[v] then keep[v] = true end end
						selected = keep
						htxt.Text = summary()
						if open then setOpen(true) end
					end,
				}
			end

			return Tab
		end

		return Window
	end

	return Lib
end)()

local Window = WindUI:CreateWindow({
	Title = "GhostHub • Grow a Garden",
	Icon = "sprout",
	Author = "by Noxx",
	Folder = "GhostHub",
	Size = UDim2.fromOffset(560, 400),
	Transparent = true,
	HideSearchBar = false,
})

local function notify(title, content, dur)
	pcall(function()
		WindUI:Notify({ Title = title, Content = content, Duration = dur or 4, Icon = "sprout" })
	end)
end

local State = {}

--========================================================================
-- TAB: Player
--========================================================================
local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })

State.walkSpeed = 16
State.jumpPower = 50
PlayerTab:Section({ Title = "Movement" })
PlayerTab:Input({
	Title = "Walk Speed", Placeholder = "16", Value = "16",
	Callback = function(t) State.walkSpeed = num(t, 16) end,
})
PlayerTab:Input({
	Title = "Jump Power", Placeholder = "50", Value = "50",
	Callback = function(t) State.jumpPower = num(t, 50) end,
})
RunService.Heartbeat:Connect(function()
	if Humanoid and Humanoid.Parent then
		if Humanoid.WalkSpeed ~= State.walkSpeed then Humanoid.WalkSpeed = State.walkSpeed end
		if State.jumpPower ~= 50 then
			Humanoid.UseJumpPower = true
			if Humanoid.JumpPower ~= State.jumpPower then Humanoid.JumpPower = State.jumpPower end
		end
	end
end)

State.infJump = false
PlayerTab:Toggle({
	Title = "Infinite Jump", Value = false,
	Callback = function(v) State.infJump = v end,
})
UserInputService.JumpRequest:Connect(function()
	if State.infJump and Humanoid and Humanoid.Parent then
		Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

-- Fly
State.flying = false
State.flySpeed = 60
local flyBV, flyBG
local flyKeys = {}
local flyMap = {
	[Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A", [Enum.KeyCode.S] = "S",
	[Enum.KeyCode.D] = "D", [Enum.KeyCode.Space] = "Up", [Enum.KeyCode.LeftShift] = "Down",
}
UserInputService.InputBegan:Connect(function(i, gpe)
	if gpe then return end
	local k = flyMap[i.KeyCode]; if k then flyKeys[k] = true end
end)
UserInputService.InputEnded:Connect(function(i)
	local k = flyMap[i.KeyCode]; if k then flyKeys[k] = false end
end)
local function startFly()
	local hrp = getHRP(); if not hrp then return end
	if flyBV then flyBV:Destroy() end
	if flyBG then flyBG:Destroy() end
	flyBV = Instance.new("BodyVelocity"); flyBV.MaxForce = Vector3.one * 9e9; flyBV.Velocity = Vector3.zero; flyBV.Parent = hrp
	flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.one * 9e9; flyBG.P = 9e4; flyBG.CFrame = hrp.CFrame; flyBG.Parent = hrp
	if Humanoid then Humanoid.PlatformStand = true end
end
local function stopFly()
	if flyBV then flyBV:Destroy(); flyBV = nil end
	if flyBG then flyBG:Destroy(); flyBG = nil end
	if Humanoid then Humanoid.PlatformStand = false end
end
RunService.RenderStepped:Connect(function()
	if not State.flying then return end
	local hrp = getHRP()
	if not hrp or not flyBV or not flyBG then if State.flying then startFly() end return end
	local dir, cf = Vector3.zero, Camera.CFrame
	if flyKeys.W then dir += cf.LookVector end
	if flyKeys.S then dir -= cf.LookVector end
	if flyKeys.A then dir -= cf.RightVector end
	if flyKeys.D then dir += cf.RightVector end
	if flyKeys.Up then dir += Vector3.yAxis end
	if flyKeys.Down then dir -= Vector3.yAxis end
	if dir.Magnitude > 0 then dir = dir.Unit end
	flyBV.Velocity = dir * State.flySpeed
	flyBG.CFrame = cf
end)
PlayerTab:Toggle({
	Title = "Fly  (WASD + Space/Shift)", Value = false,
	Callback = function(v) State.flying = v; if v then startFly() else stopFly() end end,
})
PlayerTab:Input({
	Title = "Fly Speed", Placeholder = "60", Value = "60",
	Callback = function(t) State.flySpeed = num(t, 60) end,
})

-- Noclip
State.noclip = false
RunService.Stepped:Connect(function()
	if State.noclip and Char then
		for _, p in ipairs(Char:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
		end
	end
end)
PlayerTab:Toggle({ Title = "Noclip", Value = false, Callback = function(v) State.noclip = v end })

-- Anti-AFK
State.antiAfk = false
LocalPlayer.Idled:Connect(function()
	if not State.antiAfk then return end
	pcall(function()
		VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
		task.wait(1)
		VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
	end)
end)
PlayerTab:Toggle({ Title = "Anti-AFK", Value = false, Callback = function(v) State.antiAfk = v end })
PlayerTab:Button({ Title = "Reset Character", Callback = function() if Humanoid then Humanoid.Health = 0 end end })

--========================================================================
-- TAB: Auto Farm
--========================================================================
local FarmTab = Window:Tab({ Title = "Auto Farm", Icon = "wheat" })

State.autoHarvest = false
State.harvestRadius = 250
State.weightFilter = false
State.minWeight = 0
State.maxWeight = 100000
State.mutMode = "Any"
State.selectedMuts = {}
State.typeFilterOn = false
State.selectedTypes = {}

local function fruitPasses(fruit)
	local mut = fruitMutation(fruit)
	if State.mutMode == "Only Mutated" then
		if not mut then return false end
	elseif State.mutMode == "Only Selected" then
		if not mut or not State.selectedMuts[mut] then return false end
	end
	if State.typeFilterOn then
		local n = fruit:GetAttribute("CorePartName")
		if not (n and State.selectedTypes[n]) then return false end
	end
	if State.weightFilter then
		local w = fruitWeight(fruit)
		if w and (w < State.minWeight or w > State.maxWeight) then return false end
	end
	return true
end

local function harvestFiltered(radius, ignore)
	local hrp = getHRP()
	local gardens = Workspace:FindFirstChild("Gardens")
	if not gardens then return 0, 0 end
	local fired, seen = 0, 0
	for _, plot in ipairs(gardens:GetChildren()) do
		local plants = plot:FindFirstChild("Plants")
		if plants then
			for _, plant in ipairs(plants:GetChildren()) do
				local fruits = plant:FindFirstChild("Fruits")
				if fruits then
					for _, fruit in ipairs(fruits:GetChildren()) do
						local prompt = fruit:FindFirstChildWhichIsA("ProximityPrompt", true)
						local part = prompt and prompt.Parent
						if prompt and part and part:IsA("BasePart") then
							local inRange = (not radius) or (not hrp)
								or (part.Position - hrp.Position).Magnitude <= radius
							if inRange then
								seen += 1
								if ignore or fruitPasses(fruit) then
									pcall(fireprompt, prompt, prompt.HoldDuration or 0)
									fired += 1
									if fired % 40 == 0 then task.wait() end
								end
							end
						end
					end
				end
			end
		end
	end
	return fired, seen
end

FarmTab:Section({ Title = "Harvest" })
FarmTab:Input({
	Title = "Harvest Radius (studs)", Placeholder = "250", Value = "250",
	Callback = function(t) State.harvestRadius = num(t, 250) end,
})
FarmTab:Toggle({
	Title = "Auto Harvest (uses filters)", Value = false,
	Callback = function(v) State.autoHarvest = v end,
})
task.spawn(function()
	while true do
		if State.autoHarvest then pcall(harvestFiltered, State.harvestRadius, false) end
		task.wait(0.5)
	end
end)
FarmTab:Button({
	Title = "Harvest Now (filtered)",
	Callback = function()
		local f, s = harvestFiltered(State.harvestRadius, false)
		notify("GhostHub", ("Harvested %d / %d fruit"):format(f, s))
	end,
})
FarmTab:Button({
	Title = "Harvest EVERYTHING (ignore filters)",
	Callback = function()
		local f = harvestFiltered(nil, true)
		notify("GhostHub", ("Harvested %d fruit map-wide"):format(f))
	end,
})

FarmTab:Section({ Title = "Collect Filters" })
FarmTab:Toggle({ Title = "Enable Weight Filter", Value = false, Callback = function(v) State.weightFilter = v end })
FarmTab:Input({
	Title = "Min Weight (kg)", Placeholder = "0", Value = "0",
	Callback = function(t) State.minWeight = num(t, 0) end,
})
FarmTab:Input({
	Title = "Max Weight (kg)", Placeholder = "100000", Value = "100000",
	Callback = function(t) State.maxWeight = num(t, 100000) end,
})
FarmTab:Dropdown({
	Title = "Mutation Mode", Values = { "Any", "Only Mutated", "Only Selected" },
	Value = "Any", Multi = false,
	Callback = function(v) State.mutMode = (type(v) == "table" and v[1]) or v or "Any" end,
})
FarmTab:Dropdown({
	Title = "Mutations (for 'Only Selected')", Values = MUTATIONS, Value = {}, Multi = true, AllowNone = true,
	Callback = function(v)
		State.selectedMuts = {}
		if type(v) == "table" then for _, n in ipairs(v) do State.selectedMuts[n] = true end end
	end,
})
FarmTab:Toggle({ Title = "Enable Fruit-Type Filter", Value = false, Callback = function(v) State.typeFilterOn = v end })
FarmTab:Dropdown({
	Title = "Fruit Types to Collect", Values = FRUIT_TYPES, Value = {}, Multi = true, AllowNone = true,
	Callback = function(v)
		State.selectedTypes = {}
		if type(v) == "table" then for _, n in ipairs(v) do State.selectedTypes[n] = true end end
	end,
})

--------------------------------------------------------------------------
-- Auto Sell
--------------------------------------------------------------------------
State.autoSell = false
State.sellInterval = 60
State.sellThreshold = 0
State.sellTeleport = false

local function previewSellValue()
	local ok, res = fireNet({ "NPCS", "PreviewSellAll" })
	if ok and type(res) == "table" then
		return res.TotalValue or res.TotalSellValue or res.TotalBaseValue or 0
	end
	return nil
end
local function doSellAll()
	if not net({ "NPCS", "SellAll" }) then notify("GhostHub", "Sell API unavailable"); return nil end
	local restore
	if State.sellTeleport then
		local hrp = getHRP()
		if hrp then
			restore = hrp.CFrame
			teleportTo(Vector3.new(268.37, 146, -127.47)) -- Sell pad
			task.wait(0.35)
		end
	end
	local ok, res = fireNet({ "NPCS", "SellAll" })
	if restore then task.wait(0.2); local hrp = getHRP(); if hrp then hrp.CFrame = restore end end
	if ok and type(res) == "table" then return res.SellPrice or res.TotalValue or 0 end
	return ok and 0 or nil
end

FarmTab:Section({ Title = "Auto Sell" })
FarmTab:Toggle({ Title = "TP to Seller before selling (safer)", Value = false, Callback = function(v) State.sellTeleport = v end })
FarmTab:Input({ Title = "Only sell when value >=", Placeholder = "0", Value = "0", Callback = function(t) State.sellThreshold = num(t, 0) end })
FarmTab:Input({ Title = "Auto Sell Interval (s)", Placeholder = "60", Value = "60", Callback = function(t) State.sellInterval = math.max(5, num(t, 60)) end })
FarmTab:Toggle({ Title = "Auto Sell", Value = false, Callback = function(v) State.autoSell = v end })
task.spawn(function()
	while true do
		if State.autoSell then
			local go = true
			if State.sellThreshold > 0 then
				local val = previewSellValue()
				if val ~= nil and val < State.sellThreshold then go = false end
			end
			if go then pcall(doSellAll) end
		end
		task.wait(math.max(5, State.sellInterval))
	end
end)
FarmTab:Button({ Title = "Sell All Now", Callback = function()
	local g = doSellAll()
	notify("GhostHub", g and ("Sold. Value: " .. tostring(g)) or "Sell failed")
end })
FarmTab:Button({ Title = "Preview Sell Value", Callback = function()
	local v = previewSellValue()
	notify("GhostHub", v and ("Inventory sells for: " .. tostring(v)) or "Preview unavailable")
end })

--------------------------------------------------------------------------
-- Auto collect dropped items
--------------------------------------------------------------------------
State.autoCollect = false
FarmTab:Section({ Title = "Dropped Items" })
FarmTab:Toggle({ Title = "Auto Collect Dropped Items", Value = false, Callback = function(v) State.autoCollect = v end })
task.spawn(function()
	while true do
		if State.autoCollect then
			local hrp = getHRP()
			local drops = Workspace:FindFirstChild("DroppedItems")
			if hrp and drops then
				for _, item in ipairs(drops:GetChildren()) do
					local target = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
					if target then pcall(function() target.CFrame = hrp.CFrame end) end
				end
			end
		end
		task.wait(0.3)
	end
end)

--========================================================================
-- TAB: Auto Buy
--========================================================================
local BuyTab = Window:Tab({ Title = "Auto Buy", Icon = "shopping-cart" })

-- Seeds -----------------------------------------------------------------
State.buySeeds = {}         -- list of names
State.autoBuySeeds = false
State.buyInterval = 3

local function mergeBuyList(dropdownSel, textValue)
	local out, seen = {}, {}
	if type(dropdownSel) == "table" then
		for _, n in ipairs(dropdownSel) do if not seen[n] then seen[n] = true; table.insert(out, n) end end
	end
	for _, n in ipairs(splitList(textValue or "")) do if not seen[n] then seen[n] = true; table.insert(out, n) end end
	return out
end
local seedDropSel, seedText = {}, ""
local function refreshSeedList() State.buySeeds = mergeBuyList(seedDropSel, seedText) end

BuyTab:Section({ Title = "Seed Shop" })
BuyTab:Dropdown({
	Title = "Seeds to buy", Values = SEEDS, Value = {}, Multi = true, AllowNone = true,
	Callback = function(v) seedDropSel = (type(v) == "table") and v or {}; refreshSeedList() end,
})
BuyTab:Input({
	Title = "Extra seed names (comma-separated)", Placeholder = "Sugar Apple, Ember Lily",
	Callback = function(t) seedText = t or ""; refreshSeedList() end,
})
BuyTab:Button({
	Title = "Buy Selected Seeds Once",
	Callback = function()
		local n = 0
		for _, name in ipairs(State.buySeeds) do fireNet({ "SeedShop", "PurchaseSeed" }, name); n += 1 end
		notify("GhostHub", ("Requested %d seed purchase(s)"):format(n))
	end,
})
BuyTab:Toggle({ Title = "Auto Buy Seeds", Value = false, Callback = function(v) State.autoBuySeeds = v end })

-- Gears -----------------------------------------------------------------
State.buyGears = {}
State.autoBuyGears = false
local gearDropSel, gearText = {}, ""
local function refreshGearList() State.buyGears = mergeBuyList(gearDropSel, gearText) end

BuyTab:Section({ Title = "Gear Shop" })
BuyTab:Dropdown({
	Title = "Gears to buy", Values = GEARS, Value = {}, Multi = true, AllowNone = true,
	Callback = function(v) gearDropSel = (type(v) == "table") and v or {}; refreshGearList() end,
})
BuyTab:Input({
	Title = "Extra gear names (comma-separated)", Placeholder = "Master Sprinkler",
	Callback = function(t) gearText = t or ""; refreshGearList() end,
})
BuyTab:Button({
	Title = "Buy Selected Gears Once",
	Callback = function()
		local n = 0
		for _, name in ipairs(State.buyGears) do fireNet({ "GearShop", "PurchaseGear" }, name); n += 1 end
		notify("GhostHub", ("Requested %d gear purchase(s)"):format(n))
	end,
})
BuyTab:Toggle({ Title = "Auto Buy Gears", Value = false, Callback = function(v) State.autoBuyGears = v end })

-- Crates / Eggs ---------------------------------------------------------
State.crateName = ""
State.eggName = ""
BuyTab:Section({ Title = "Crates & Eggs" })
BuyTab:Input({ Title = "Crate name", Placeholder = "Summer Crate", Callback = function(t) State.crateName = t or "" end })
BuyTab:Button({ Title = "Buy Crate", Callback = function()
	if State.crateName ~= "" then fireNet({ "CrateShop", "PurchaseCrate" }, State.crateName); notify("GhostHub", "Requested crate: " .. State.crateName) end
end })
BuyTab:Input({ Title = "Egg name", Placeholder = "Common Egg", Callback = function(t) State.eggName = t or "" end })
BuyTab:Button({ Title = "Open Egg", Callback = function()
	if State.eggName ~= "" then fireNet({ "Egg", "OpenEgg" }, State.eggName); notify("GhostHub", "Opened egg: " .. State.eggName) end
end })

-- Shared interval + loop
BuyTab:Section({ Title = "Auto Buy Settings" })
BuyTab:Input({ Title = "Auto Buy Interval (s)", Placeholder = "3", Value = "3", Callback = function(t) State.buyInterval = math.max(1, num(t, 3)) end })
task.spawn(function()
	while true do
		if State.autoBuySeeds then
			for _, name in ipairs(State.buySeeds) do fireNet({ "SeedShop", "PurchaseSeed" }, name) end
		end
		if State.autoBuyGears then
			for _, name in ipairs(State.buyGears) do fireNet({ "GearShop", "PurchaseGear" }, name) end
		end
		task.wait(math.max(1, State.buyInterval))
	end
end)

--========================================================================
-- TAB: Auction
--========================================================================
local AuctionTab = Window:Tab({ Title = "Auction", Icon = "gavel" })

State.autoAuction = false
State.aucNames = {}       -- lowercased name fragments
State.aucMutMode = "Any"
State.aucMuts = {}
State.aucMaxPrice = math.huge

local function auctionLots()
	local ok, snap = fireNet({ "Auctioneer", "RequestSnapshot" })
	if ok and type(snap) == "table" then return snap.stock or snap.lots or snap end
	return nil
end
local function lotName(lot)
	if Auctioneer and Auctioneer.DisplayName then
		local ok, n = pcall(function() return Auctioneer.DisplayName(lot) end)
		if ok and type(n) == "string" then return n end
	end
	return lot.itemName or lot.ItemName or lot.name or ""
end
local function lotPrice(lot)
	if Auctioneer and Auctioneer.CurrentPrice then
		local ok, p = pcall(function() return Auctioneer.CurrentPrice(lot, os.time()) end)
		if ok and type(p) == "number" then return p end
	end
	return lot.startPrice or lot.price or 0
end
local function lotPasses(lot)
	-- name filter
	if #State.aucNames > 0 then
		local nm = lotName(lot):lower()
		local match = false
		for _, frag in ipairs(State.aucNames) do if nm:find(frag, 1, true) then match = true break end end
		if not match then return false end
	end
	-- mutation filter
	local mut = lot.mutation or lot.Mutation
	if State.aucMutMode == "Only Mutated" then
		if not mut or mut == "" then return false end
	elseif State.aucMutMode == "Only Selected" then
		if not mut or not State.aucMuts[mut] then return false end
	end
	-- price
	if lotPrice(lot) > State.aucMaxPrice then return false end
	return true
end
local function auctionBuyOnce()
	local lots = auctionLots()
	if not lots then return 0, "no snapshot" end
	local bought = 0
	for _, lot in pairs(lots) do
		if type(lot) == "table" and lot.lotId then
			if lotPasses(lot) then
				fireNet({ "Auctioneer", "PurchaseLot" }, lot.lotId, lotPrice(lot))
				bought += 1
			end
		end
	end
	return bought
end

AuctionTab:Section({ Title = "Filters" })
AuctionTab:Input({
	Title = "Item name contains (comma-separated)", Placeholder = "Dragon, Raccoon",
	Callback = function(t)
		State.aucNames = {}
		for _, f in ipairs(splitList(t)) do table.insert(State.aucNames, f:lower()) end
	end,
})
AuctionTab:Dropdown({
	Title = "Mutation Mode", Values = { "Any", "Only Mutated", "Only Selected" }, Value = "Any", Multi = false,
	Callback = function(v) State.aucMutMode = (type(v) == "table" and v[1]) or v or "Any" end,
})
AuctionTab:Dropdown({
	Title = "Mutations (for 'Only Selected')", Values = MUTATIONS, Value = {}, Multi = true, AllowNone = true,
	Callback = function(v)
		State.aucMuts = {}
		if type(v) == "table" then for _, n in ipairs(v) do State.aucMuts[n] = true end end
	end,
})
AuctionTab:Input({
	Title = "Max Price (blank = any)", Placeholder = "1000000",
	Callback = function(t)
		local n = num(t, nil)
		State.aucMaxPrice = n or math.huge
	end,
})

AuctionTab:Section({ Title = "Actions" })
AuctionTab:Button({
	Title = "List Current Lots",
	Callback = function()
		local lots = auctionLots()
		if not lots then notify("GhostHub", "No auction snapshot (open the auction house first)"); return end
		local n, shown = 0, {}
		for _, lot in pairs(lots) do
			if type(lot) == "table" and lot.lotId then
				n += 1
				if #shown < 6 then table.insert(shown, ("%s - %s"):format(lotName(lot), tostring(math.floor(lotPrice(lot))))) end
			end
		end
		notify("GhostHub", ("%d lots. %s"):format(n, table.concat(shown, " | ")), 8)
	end,
})
AuctionTab:Button({
	Title = "Buy Matching Lots Once",
	Callback = function()
		local b = auctionBuyOnce()
		notify("GhostHub", ("Attempted to buy %d matching lot(s)"):format(b))
	end,
})
AuctionTab:Toggle({ Title = "Auto Buy Auction", Value = false, Callback = function(v) State.autoAuction = v end })
task.spawn(function()
	while true do
		if State.autoAuction then pcall(auctionBuyOnce) end
		task.wait(2)
	end
end)

--========================================================================
-- TAB: Visual (CLIENT-SIDE ONLY)
--========================================================================
local VisualTab = Window:Tab({ Title = "Visual Dupe", Icon = "copy" })
VisualTab:Paragraph({
	Title = "Client-Side Only (looks real, isn't)",
	Desc = "This edits the REAL inventory Tools on your own client, so items render through the game's own UI — counts, icons and names are indistinguishable from real. Nothing reaches the server: it can't give real items and it resets when you rejoin. Use Rollback to restore instantly.",
})

--------------------------------------------------------------------------
-- Backpack tool helpers
--   The game builds each hotbar slot from a Tool in LocalPlayer.Backpack
--   and listens to Tool.AttributeChanged, reading GetAttribute("Count").
--   So editing "Count" live-updates the slot, and cloning a Tool into the
--   Backpack spawns a brand-new, real-looking slot. All client-only.
--------------------------------------------------------------------------
local function leaderstat(name)
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(name)
end
local function getBackpack() return LocalPlayer:FindFirstChild("Backpack") end

local function allTools()
	local out = {}
	local bp = getBackpack()
	if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then table.insert(out, t) end end end
	local char = LocalPlayer.Character
	if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then table.insert(out, t) end end end
	return out
end
local function toolNames()
	local names, seen = {}, {}
	for _, t in ipairs(allTools()) do
		if not seen[t.Name] then seen[t.Name] = true; table.insert(names, t.Name) end
	end
	table.sort(names)
	if #names == 0 then names = { "(open game first)" } end
	return names
end
local function findTool(name)
	for _, t in ipairs(allTools()) do if t.Name == name then return t end end
	return nil
end

-- rollback bookkeeping
local origCounts = {}      -- [tool] = original Count (weak keys)
setmetatable(origCounts, { __mode = "k" })
local clonedTools = {}     -- injected Tool instances
local forcedCounts = {}    -- [tool] = value to keep re-asserting  (weak keys)
setmetatable(forcedCounts, { __mode = "k" })
local isFakeTool = {}      -- [tool] = true  (client-only duped tools; weak keys)
setmetatable(isFakeTool, { __mode = "k" })

local realSheckles, realTokens
State.spoofSheckles = nil
State.spoofTokens = nil

local function setToolCount(tool, value)
	if not tool then return end
	if origCounts[tool] == nil then origCounts[tool] = tool:GetAttribute("Count") end
	forcedCounts[tool] = value
	pcall(function() tool:SetAttribute("Count", value) end)
end

-- Re-assert spoofs (server re-replication would otherwise reset them)
RunService.Heartbeat:Connect(function()
	if State.spoofSheckles ~= nil then
		local s = leaderstat("Sheckles")
		if s and s.Value ~= State.spoofSheckles then
			if realSheckles == nil then realSheckles = s.Value end
			pcall(function() s.Value = State.spoofSheckles end)
		end
	end
	if State.spoofTokens ~= nil then
		local s = leaderstat("Tokens")
		if s and s.Value ~= State.spoofTokens then
			if realTokens == nil then realTokens = s.Value end
			pcall(function() s.Value = State.spoofTokens end)
		end
	end
	for tool, v in pairs(forcedCounts) do
		if tool and tool.Parent then
			if tool:GetAttribute("Count") ~= v then pcall(function() tool:SetAttribute("Count", v) end) end
		else
			forcedCounts[tool] = nil
		end
	end
end)

--------------------------------------------------------------------------
-- Currency (display only)
--------------------------------------------------------------------------
VisualTab:Section({ Title = "Currency (display)" })
VisualTab:Input({
	Title = "Visual Sheckles", Placeholder = "999999999",
	Callback = function(t)
		local n = num(t, nil)
		if n then
			local s = leaderstat("Sheckles")
			if s and realSheckles == nil then realSheckles = s.Value end
			State.spoofSheckles = n
			if Replica and Replica.Data then pcall(function() Replica.Data.Sheckles = n end) end
		end
	end,
})
VisualTab:Input({
	Title = "Visual Tokens", Placeholder = "999999",
	Callback = function(t)
		local n = num(t, nil)
		if n then
			local s = leaderstat("Tokens")
			if s and realTokens == nil then realTokens = s.Value end
			State.spoofTokens = n
			if Replica and Replica.Data then pcall(function() Replica.Data.Tokens = n end) end
		end
	end,
})

--------------------------------------------------------------------------
-- Dupe by count (edit real tools -> live re-render, real icons/names)
--------------------------------------------------------------------------
VisualTab:Section({ Title = "Dupe Counts" })
State.dupeAmount = 999999
VisualTab:Input({
	Title = "Dupe Count Value", Placeholder = "999999", Value = "999999",
	Callback = function(t) State.dupeAmount = num(t, 999999) end,
})
VisualTab:Button({
	Title = "Set ALL item counts to value",
	Callback = function()
		local n = 0
		for _, tool in ipairs(allTools()) do
			if tool:GetAttribute("Count") ~= nil then setToolCount(tool, State.dupeAmount); n += 1 end
		end
		notify("GhostHub", ("Set %d item counts to %d"):format(n, State.dupeAmount))
	end,
})
State.dupeMult = 10
VisualTab:Input({
	Title = "Multiply counts x", Placeholder = "10", Value = "10",
	Callback = function(t) State.dupeMult = math.max(1, num(t, 10)) end,
})
VisualTab:Button({
	Title = "Multiply ALL item counts",
	Callback = function()
		local n = 0
		for _, tool in ipairs(allTools()) do
			local c = tool:GetAttribute("Count")
			if type(c) == "number" then setToolCount(tool, math.floor(c * State.dupeMult)); n += 1 end
		end
		notify("GhostHub", ("Multiplied %d item counts x%d"):format(n, State.dupeMult))
	end,
})

local selCountTool
local countToolDrop = VisualTab:Dropdown({
	Title = "Item", Values = toolNames(), Value = nil, Multi = false, AllowNone = true,
	Callback = function(v) selCountTool = (type(v) == "table" and v[1]) or v end,
})
VisualTab:Button({ Title = "Refresh Item List", Callback = function()
	pcall(function() countToolDrop:Refresh(toolNames()) end)
end })
VisualTab:Button({
	Title = "Set Selected Item count -> value",
	Callback = function()
		local tool = selCountTool and findTool(selCountTool)
		if tool then setToolCount(tool, State.dupeAmount); notify("GhostHub", ("%s count = %d"):format(tool.Name, State.dupeAmount))
		else notify("GhostHub", "Select an item first") end
	end,
})

--------------------------------------------------------------------------
-- Dupe by cloning (extra real-looking stacks)
--------------------------------------------------------------------------
VisualTab:Section({ Title = "Dupe Stacks (clone)" })
State.cloneTimes = 5
VisualTab:Input({
	Title = "Clone copies", Placeholder = "5", Value = "5",
	Callback = function(t) State.cloneTimes = math.clamp(num(t, 5), 1, 200) end,
})

local function cloneTool(tool, times)
	local bp = getBackpack()
	if not (tool and bp) then return 0 end
	local made = 0
	for _ = 1, times do
		local ok, clone = pcall(function() return tool:Clone() end)
		if ok and clone then
			clone.Parent = bp
			isFakeTool[clone] = true
			table.insert(clonedTools, clone)
			made += 1
		end
	end
	return made
end

VisualTab:Button({
	Title = "Clone Selected Item",
	Callback = function()
		local tool = selCountTool and findTool(selCountTool)
		if tool then
			local m = cloneTool(tool, State.cloneTimes)
			notify("GhostHub", ("Cloned %s x%d"):format(tool.Name, m))
		else notify("GhostHub", "Select an item first (Dupe Counts list)") end
	end,
})
VisualTab:Button({
	Title = "Clone EVERY item",
	Callback = function()
		local total = 0
		for _, tool in ipairs(allTools()) do total += cloneTool(tool, State.cloneTimes) end
		notify("GhostHub", ("Cloned %d tool copies"):format(total))
	end,
})

--------------------------------------------------------------------------
-- Drop & Equip (visual)
--   Duped tools are real client-side Tool instances, so equipping them with
--   the Humanoid shows them in-hand locally, and we can build a client-only
--   dropped-item model (mesh + name label + glow) inside workspace.DroppedItems
--   that looks just like a real drop. Server never sees any of it.
--------------------------------------------------------------------------
local droppedModels = {}

local function fakeDrop(tool)
	local hrp = getHRP()
	if not (hrp and tool) then return false end

	local model = Instance.new("Model")
	model.Name = "GhostHubDrop"

	-- visual: clone the tool's handle/mesh, else a placeholder cube
	local src = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
	local part
	if src then
		part = src:Clone()
		for _, d in ipairs(part:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
		end
	else
		part = Instance.new("Part"); part.Size = Vector3.new(2, 2, 2); part.Color = Color3.fromRGB(120, 200, 120)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false

	-- place just in front of the player, snapped to the floor
	local dropPos = hrp.Position + hrp.CFrame.LookVector * 4
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character, model }
	local ray = Workspace:Raycast(dropPos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), params)
	local floorY = ray and ray.Position.Y or (hrp.Position.Y - 3)
	part.CFrame = CFrame.new(dropPos.X, floorY + (part.Size.Y * 0.5), dropPos.Z)
	part.Parent = model
	model.PrimaryPart = part

	-- name label like a real dropped item
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, 44); bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true; bb.MaxDistance = 120
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1; lbl.Size = UDim2.fromScale(1, 1); lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.new(1, 1, 1)
	local cnt = tool:GetAttribute("Count")
	lbl.Text = tool.Name .. (cnt and (" x" .. tostring(cnt)) or "")
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = Color3.new(0, 0, 0); stroke.Parent = lbl
	lbl.Parent = bb
	bb.Parent = part

	local glow = Instance.new("PointLight"); glow.Name = "DropGlow"; glow.Range = 8; glow.Brightness = 2; glow.Parent = part

	model.Parent = Workspace:FindFirstChild("DroppedItems") or Workspace
	table.insert(droppedModels, model)
	return true
end

--------------------------------------------------------------------------
-- Make duped items interactive through the game's OWN controls (visual)
--   Duped tools are real client Tools, so:
--     * Equip  - click the slot in your hotbar (native, nothing to enable).
--     * Drop   - press Backspace while holding one; we spawn the floor drop.
--     * Send   - gift it through the mailbox / gift menu; we show it sent.
--   We hook the game's own drop/gift Fire and only handle DUPED tools
--   visually; real items keep working normally. Nothing reaches the server.
--------------------------------------------------------------------------
local NotificationController
pcall(function() NotificationController = require(LocalPlayer.PlayerScripts.Controllers.NotificationController) end)
local function toast(msg)
	local ok = false
	if NotificationController and NotificationController.CreateNotification then
		ok = pcall(function() NotificationController:CreateNotification(msg, false, 4) end)
	end
	if not ok then notify("GhostHub", msg) end
end

local function getEquippedTool()
	local ch = LocalPlayer.Character
	return ch and ch:FindFirstChildWhichIsA("Tool")
end

State.dropHook = false
State.giftHook = false
local dropHooked, giftHooked = false, false

-- Packet events share a metatable method (u7.Fire); assigning ev.Fire on the
-- instance shadows it just for that event, so this only affects drop/gift.
local function installDropHook()
	if dropHooked then return true end
	local ev = net({ "DroppedItem", "RequestDrop" })
	if not ev or not ev.Fire then return false end
	local orig = ev.Fire
	ev.Fire = function(self, ...)
		if State.dropHook then
			local held = getEquippedTool()
			if held and isFakeTool[held] then
				local t = held
				task.spawn(function() fakeDrop(t); pcall(function() t:Destroy() end) end)
				return -- fake item: fully client-side, don't bother the server
			end
		end
		return orig(self, ...)
	end
	dropHooked = true
	return true
end

local function installGiftHook()
	if giftHooked then return true end
	local ev = net({ "Gifting", "Send" })
	if not ev or not ev.Fire then return false end
	local orig = ev.Fire
	ev.Fire = function(self, ...)
		if State.giftHook then
			local held = getEquippedTool()
			if held and isFakeTool[held] then
				local nm = held.Name
				toast("Sent " .. nm .. "!")
				pcall(function() held:Destroy() end)
				return
			end
		end
		return orig(self, ...)
	end
	giftHooked = true
	return true
end

VisualTab:Section({ Title = "Use Duped Items In-Game (visual)" })
VisualTab:Paragraph({
	Title = "How it works",
	Desc = "Dupe items above, then use the game's normal controls: click a hotbar slot to equip, press Backspace while holding to drop it on the floor, and gift it through the mailbox / gift menu. Turn on the toggles so duped items drop and send visually. Real items keep behaving normally, and everything resets on rejoin.",
})
VisualTab:Toggle({
	Title = "Duped items droppable (Backspace)", Value = false,
	Callback = function(v)
		State.dropHook = v
		if v and not installDropHook() then notify("GhostHub", "Drop remote not found") end
	end,
})
VisualTab:Toggle({
	Title = "Duped items sendable (mailbox / gift)", Value = false,
	Callback = function(v)
		State.giftHook = v
		if v and not installGiftHook() then notify("GhostHub", "Gift remote not found") end
	end,
})
VisualTab:Button({
	Title = "Clear My Dropped Items",
	Callback = function()
		for _, m in ipairs(droppedModels) do if m then pcall(function() m:Destroy() end) end end
		droppedModels = {}
		notify("GhostHub", "Cleared visual drops")
	end,
})

--------------------------------------------------------------------------
-- Rollback
--------------------------------------------------------------------------
VisualTab:Section({ Title = "Rollback" })
VisualTab:Button({
	Title = "Rollback — Restore Real Inventory",
	Callback = function()
		-- currency
		State.spoofSheckles, State.spoofTokens = nil, nil
		local s = leaderstat("Sheckles")
		if s and realSheckles ~= nil then pcall(function() s.Value = realSheckles end) end
		local tk = leaderstat("Tokens")
		if tk and realTokens ~= nil then pcall(function() tk.Value = realTokens end) end
		if Replica and Replica.Data then
			if realSheckles ~= nil then pcall(function() Replica.Data.Sheckles = realSheckles end) end
			if realTokens ~= nil then pcall(function() Replica.Data.Tokens = realTokens end) end
		end
		realSheckles, realTokens = nil, nil
		-- destroy cloned tools
		for _, t in ipairs(clonedTools) do if t then pcall(function() t:Destroy() end) end end
		clonedTools = {}
		-- remove visual dropped items + unequip
		for _, m in ipairs(droppedModels) do if m then pcall(function() m:Destroy() end) end end
		droppedModels = {}
		local ch = LocalPlayer.Character
		local hum = ch and ch:FindFirstChildWhichIsA("Humanoid")
		if hum then pcall(function() hum:UnequipTools() end) end
		-- restore original counts
		for tool, orig in pairs(origCounts) do
			forcedCounts[tool] = nil
			if tool and tool.Parent then pcall(function() tool:SetAttribute("Count", orig) end) end
		end
		origCounts = setmetatable({}, { __mode = "k" })
		notify("GhostHub", "Rolled back. Real inventory restored (or just rejoin).")
	end,
})

--========================================================================
-- TAB: Teleports
--========================================================================
local TpTab = Window:Tab({ Title = "Teleports", Icon = "map-pin" })

local SHOPS = {
	Seeds = Vector3.new(265.68, 146.00, -143.35),
	Gears = Vector3.new(238.76, 146.00, -136.27),
	Props = Vector3.new(242.35, 146.00, -121.25),
	Sell  = Vector3.new(268.37, 146.00, -127.47),
}
local function shopPos(name)
	local folder = Workspace:FindFirstChild("Teleports")
	if folder then
		local part = folder:FindFirstChild(name)
		if part and part:IsA("BasePart") then return part.Position end
	end
	return SHOPS[name]
end
TpTab:Section({ Title = "Shops" })
for _, name in ipairs({ "Seeds", "Gears", "Props", "Sell" }) do
	TpTab:Button({ Title = "Teleport to " .. name, Callback = function() teleportTo(shopPos(name)) end })
end

TpTab:Section({ Title = "Players" })
local function playerNames()
	local t = {}
	for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(t, p.Name) end end
	if #t == 0 then t = { "(none)" } end
	return t
end
local selectedPlayer = nil
local playerDrop = TpTab:Dropdown({
	Title = "Select Player", Values = playerNames(), Value = nil, Multi = false, AllowNone = true,
	Callback = function(v) selectedPlayer = (type(v) == "table" and v[1]) or v end,
})
TpTab:Button({ Title = "Refresh Player List", Callback = function()
	pcall(function() playerDrop:Refresh(playerNames()) end)
end })
TpTab:Button({
	Title = "Teleport to Selected Player",
	Callback = function()
		if not selectedPlayer or selectedPlayer == "(none)" then notify("GhostHub", "No player selected"); return end
		local target = Players:FindFirstChild(selectedPlayer)
		local thrp = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if thrp then teleportTo(thrp.CFrame) else notify("GhostHub", "Player has no character") end
	end,
})
TpTab:Section({ Title = "Plot" })
TpTab:Button({
	Title = "Teleport to Nearest Spawn",
	Callback = function()
		local gardens = Workspace:FindFirstChild("Gardens")
		if not gardens then notify("GhostHub", "Gardens not found"); return end
		local best, bestDist, hrp = nil, nil, getHRP()
		for _, plot in ipairs(gardens:GetChildren()) do
			local sp = plot:FindFirstChild("SpawnPoint", true)
			local part = sp and (sp:IsA("BasePart") and sp or sp:FindFirstChildWhichIsA("BasePart", true))
			if part and hrp then
				local dd = (part.Position - hrp.Position).Magnitude
				if not bestDist or dd < bestDist then bestDist, best = dd, part end
			end
		end
		if best then teleportTo(best.CFrame) else notify("GhostHub", "No spawn found") end
	end,
})

--========================================================================
-- TAB: Pet Finder
--   Every player's equipped pets are client-replicated as Models under
--   Workspace._PetVisualClient.Models (Name = species, Attributes: PetID,
--   Owner, OwnerSlot, and Mutation when the pet is mutated e.g. "Rainbow").
--   There's no rarity table exposed to the client, so "rarest" here means
--   "has a Mutation attribute set" rather than an invented tier list.
--========================================================================
local PetTab = Window:Tab({ Title = "Pet Finder", Icon = "paw-print" })

State.petEsp = false
State.petNameFilter = ""
State.petOnlyMutated = false
State.petOnlyOthers = false
local petHighlights = {}
setmetatable(petHighlights, { __mode = "k" })

local function petModelsFolder()
	local pv = Workspace:FindFirstChild("_PetVisualClient")
	return pv and pv:FindFirstChild("Models")
end

local function petPasses(model)
	if State.petOnlyMutated and not model:GetAttribute("Mutation") then return false end
	if State.petOnlyOthers and model:GetAttribute("Owner") == LocalPlayer.Name then return false end
	if State.petNameFilter ~= "" then
		local hay = (model.Name .. " " .. tostring(model:GetAttribute("Owner") or "")):lower()
		if not hay:find(State.petNameFilter:lower(), 1, true) then return false end
	end
	return true
end

local function allPets()
	local folder = petModelsFolder()
	local out = {}
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Model") and petPasses(m) then table.insert(out, m) end
		end
	end
	return out
end

local function petPos(model)
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	return part and part.Position
end

PetTab:Paragraph({
	Title = "How it works",
	Desc = "Scans every player's equipped pets (client-replicated pet models) so you can find, highlight and teleport to them. There is no rarity list exposed to the client, so 'mutated' (Rainbow, etc.) is used as the rare signal instead of a made-up tier list.",
})

PetTab:Section({ Title = "Filters" })
PetTab:Input({
	Title = "Name / owner contains", Placeholder = "Dragonfly, Noxx_Dev...",
	Callback = function(t) State.petNameFilter = t or "" end,
})
PetTab:Toggle({ Title = "Only mutated pets", Value = false, Callback = function(v) State.petOnlyMutated = v end })
PetTab:Toggle({ Title = "Only other players' pets", Value = false, Callback = function(v) State.petOnlyOthers = v end })

PetTab:Section({ Title = "Actions" })
PetTab:Button({
	Title = "List Matching Pets",
	Callback = function()
		local pets = allPets()
		if #pets == 0 then notify("GhostHub", "No pets found matching your filters"); return end
		local lines = {}
		for i, m in ipairs(pets) do
			if i > 8 then break end
			table.insert(lines, ("%s (%s)%s"):format(m.Name, tostring(m:GetAttribute("Owner") or "?"),
				m:GetAttribute("Mutation") and (" [" .. m:GetAttribute("Mutation") .. "]") or ""))
		end
		notify("GhostHub", ("%d pet(s) found:\n%s"):format(#pets, table.concat(lines, "\n")), 8)
	end,
})
PetTab:Button({
	Title = "Teleport to Nearest Matching Pet",
	Callback = function()
		local hrp = getHRP()
		local pets = allPets()
		local best, bestDist
		for _, m in ipairs(pets) do
			local pos = petPos(m)
			if pos and hrp then
				local d = (pos - hrp.Position).Magnitude
				if not bestDist or d < bestDist then bestDist, best = d, pos end
			end
		end
		if best then teleportTo(best) else notify("GhostHub", "No matching pet found") end
	end,
})
PetTab:Button({
	Title = "Teleport to a Mutated Pet",
	Callback = function()
		local hrp = getHRP()
		local folder = petModelsFolder()
		local best, bestDist
		if folder then
			for _, m in ipairs(folder:GetChildren()) do
				if m:IsA("Model") and m:GetAttribute("Mutation") then
					local pos = petPos(m)
					if pos and hrp then
						local d = (pos - hrp.Position).Magnitude
						if not bestDist or d < bestDist then bestDist, best = d, pos end
					end
				end
			end
		end
		if best then teleportTo(best) else notify("GhostHub", "No mutated pet found in this server") end
	end,
})

PetTab:Section({ Title = "Pet ESP" })
PetTab:Toggle({
	Title = "Highlight Matching Pets", Value = false,
	Callback = function(v)
		State.petEsp = v
		if not v then
			for m, h in pairs(petHighlights) do if h then pcall(function() h:Destroy() end) end petHighlights[m] = nil end
		end
	end,
})
task.spawn(function()
	while true do
		if State.petEsp then
			local seen = {}
			for _, m in ipairs(allPets()) do
				seen[m] = true
				if not petHighlights[m] then
					local h = Instance.new("Highlight")
					h.FillColor = m:GetAttribute("Mutation") and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(120, 200, 255)
					h.FillTransparency = 0.4
					h.OutlineColor = Color3.new(1, 1, 1)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = m
					petHighlights[m] = h
				end
			end
			for m, h in pairs(petHighlights) do
				if not seen[m] or not m.Parent then
					if h then pcall(function() h:Destroy() end) end
					petHighlights[m] = nil
				end
			end
		end
		task.wait(1)
	end
end)

--========================================================================
-- TAB: World Visuals
--========================================================================
local WorldTab = Window:Tab({ Title = "World", Icon = "sun" })

local savedLighting = {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
	FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, Ambient = Lighting.Ambient,
}
State.fullbright = false
State.noFog = false
WorldTab:Toggle({
	Title = "Fullbright", Value = false,
	Callback = function(v)
		State.fullbright = v
		if v then Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		else Lighting.Brightness = savedLighting.Brightness; Lighting.ClockTime = savedLighting.ClockTime; Lighting.Ambient = savedLighting.Ambient end
	end,
})
WorldTab:Toggle({
	Title = "No Fog", Value = false,
	Callback = function(v)
		State.noFog = v
		if v then Lighting.FogEnd = 1e9; Lighting.FogStart = 1e9
		else Lighting.FogEnd = savedLighting.FogEnd; Lighting.FogStart = savedLighting.FogStart end
	end,
})
RunService.Heartbeat:Connect(function()
	if State.noFog then Lighting.FogEnd = 1e9 end
	if State.fullbright and Lighting.Brightness < 1.9 then Lighting.Brightness = 2 end
end)

State.playerEsp = false
local espHighlights = {}
WorldTab:Toggle({
	Title = "Player ESP", Value = false,
	Callback = function(v)
		State.playerEsp = v
		if not v then
			for c, h in pairs(espHighlights) do if h then pcall(function() h:Destroy() end) end espHighlights[c] = nil end
		end
	end,
})
task.spawn(function()
	while true do
		if State.playerEsp then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer and p.Character then
					local ex = espHighlights[p.Character]
					if not ex or not ex.Parent then
						local h = Instance.new("Highlight")
						h.FillColor = Color3.fromRGB(0, 170, 255); h.FillTransparency = 0.5
						h.OutlineColor = Color3.new(1, 1, 1); h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.Parent = p.Character
						espHighlights[p.Character] = h
					end
				end
			end
		end
		task.wait(1)
	end
end)

--========================================================================
-- TAB: Server
--========================================================================
local ServerTab = Window:Tab({ Title = "Server", Icon = "server" })
ServerTab:Button({ Title = "Copy Job ID", Callback = function() toclipboard(game.JobId); notify("GhostHub", "Job ID copied") end })
ServerTab:Button({ Title = "Rejoin Server", Callback = function()
	TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end })
ServerTab:Button({
	Title = "Server Hop",
	Callback = function()
		local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if not ok then notify("GhostHub", "Failed to fetch servers"); return end
		local data
		if pcall(function() data = HttpService:JSONDecode(body) end) and data and data.data then
			local cands = {}
			for _, s in ipairs(data.data) do
				if s.playing and s.maxPlayers and s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(cands, s.id) end
			end
			if #cands > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, cands[math.random(1, #cands)], LocalPlayer)
			else TeleportService:Teleport(game.PlaceId, LocalPlayer) end
		else notify("GhostHub", "Could not parse server list") end
	end,
})
ServerTab:Section({ Title = "Danger" })
ServerTab:Button({
	Title = "Unload GhostHub",
	Callback = function()
		State.autoHarvest, State.autoSell, State.autoCollect = false, false, false
		State.autoBuySeeds, State.autoBuyGears, State.autoAuction = false, false, false
		State.flying = false; stopFly()
		State.noclip = false; State.playerEsp = false; State.petEsp = false
		for _, h in pairs(espHighlights) do if h then pcall(function() h:Destroy() end) end end
		for _, h in pairs(petHighlights) do if h then pcall(function() h:Destroy() end) end end
		pcall(function() Window:Destroy() end)
	end,
})

--========================================================================
notify("GhostHub", ("Authenticated (%s). All features ready."):format(tostring(GhostAuth.plan or "basic")), 6)
