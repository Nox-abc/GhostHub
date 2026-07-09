local user = "@ghostdabestt"

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local lp            = Players.LocalPlayer

local function tween(obj, props, t, style)
	TweenService:Create(obj,
		TweenInfo.new(t or 0.3, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		props
	):Play()
end

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function rounded(parent, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, parent)
end

local function stroke(parent, color, thickness)
	make("UIStroke", {
		Color = color or Color3.fromRGB(110, 85, 230),
		Thickness = thickness or 2,
		Parent = parent,
	})
end

local function gradient(parent, colors, rotation)
	make("UIGradient", {
		Color = ColorSequence.new(colors),
		Rotation = rotation or 0,
		Parent = parent,
	})
end

local function runMainScript()
	local backpack = lp:WaitForChild("Backpack")

	local gui = make("ScreenGui", {
		Name            = "PetFinder",
		ResetOnSpawn    = false,
		IgnoreGuiInset  = true,
		ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
		Parent          = lp.PlayerGui,
	})

	local overlay = make("Frame", {
		Size                    = UDim2.new(1, 0, 1, 0),
		BackgroundColor3        = Color3.fromRGB(6, 6, 14),
		BackgroundTransparency  = 0,
		BorderSizePixel         = 0,
		Parent                  = gui,
	})

	gradient(overlay, {
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(12, 8, 30)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 6, 14)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(8, 12, 28)),
	}, 135)

	local card = make("Frame", {
		Size             = UDim2.new(0, 460, 0, 360),
		Position         = UDim2.new(0.5, -230, 0.5, -180),
		BackgroundColor3 = Color3.fromRGB(16, 14, 28),
		BorderSizePixel  = 0,
		Parent           = overlay,
	})
	rounded(card, 20)
	stroke(card, Color3.fromRGB(110, 85, 230), 2)

	local accent = make("Frame", {
		Size             = UDim2.new(0.6, 0, 0, 3),
		Position         = UDim2.new(0.2, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel  = 0,
		Parent           = card,
	})
	rounded(accent, 2)
	gradient(accent, {
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 50, 200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 130, 255)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(80, 50, 200)),
	})

	make("TextLabel", {
		Size                    = UDim2.new(1, 0, 0, 56),
		Position                = UDim2.new(0, 0, 0, 18),
		BackgroundTransparency  = 1,
		Text                    = "🐾",
		TextSize                = 44,
		Font                    = Enum.Font.GothamBold,
		Parent                  = card,
	})

	make("TextLabel", {
		Size                    = UDim2.new(1, 0, 0, 34),
		Position                = UDim2.new(0, 0, 0, 78),
		BackgroundTransparency  = 1,
		Text                    = "Pet Finder",
		TextColor3              = Color3.fromRGB(210, 195, 255),
		TextSize                = 28,
		Font                    = Enum.Font.GothamBold,
		Parent                  = card,
	})

	local subtitle = make("TextLabel", {
		Size                    = UDim2.new(1, 0, 0, 20),
		Position                = UDim2.new(0, 0, 0, 114),
		BackgroundTransparency  = 1,
		Text                    = "Scanning inventory...",
		TextColor3              = Color3.fromRGB(140, 125, 190),
		TextSize                = 13,
		Font                    = Enum.Font.Gotham,
		Parent                  = card,
	})

	local track = make("Frame", {
		Size             = UDim2.new(1, -60, 0, 8),
		Position         = UDim2.new(0, 30, 0, 148),
		BackgroundColor3 = Color3.fromRGB(30, 26, 50),
		BorderSizePixel  = 0,
		Parent           = card,
	})
	rounded(track, 4)

	local bar = make("Frame", {
		Size             = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(120, 90, 255),
		BorderSizePixel  = 0,
		Parent           = track,
	})
	rounded(bar, 4)
	gradient(bar, {
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 70, 230)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 140, 255)),
	})

	local pctLabel = make("TextLabel", {
		Size                    = UDim2.new(1, 0, 0, 18),
		Position                = UDim2.new(0, 0, 0, 160),
		BackgroundTransparency  = 1,
		Text                    = "0%",
		TextColor3              = Color3.fromRGB(110, 95, 170),
		TextSize                = 12,
		Font                    = Enum.Font.Gotham,
		Parent                  = card,
	})

	local resultsFrame = make("Frame", {
		Size                    = UDim2.new(1, -60, 0, 150),
		Position                = UDim2.new(0, 30, 0, 185),
		BackgroundColor3        = Color3.fromRGB(12, 10, 22),
		BackgroundTransparency  = 0.3,
		BorderSizePixel         = 0,
		Visible                 = false,
		Parent                  = card,
	})
	rounded(resultsFrame, 10)

	local resultsLabel = make("TextLabel", {
		Size                    = UDim2.new(1, -20, 1, -16),
		Position                = UDim2.new(0, 10, 0, 8),
		BackgroundTransparency  = 1,
		Text                    = "",
		TextColor3              = Color3.fromRGB(230, 225, 255),
		TextSize                = 14,
		Font                    = Enum.Font.Gotham,
		TextXAlignment          = Enum.TextXAlignment.Left,
		TextYAlignment          = Enum.TextYAlignment.Top,
		TextWrapped             = true,
		Parent                  = resultsFrame,
	})

	local closeBtn = make("TextButton", {
		Size             = UDim2.new(0, 160, 0, 40),
		Position         = UDim2.new(0.5, -80, 0, 306),
		BackgroundColor3 = Color3.fromRGB(100, 75, 220),
		BorderSizePixel  = 0,
		Text             = "Close",
		TextColor3       = Color3.fromRGB(255, 255, 255),
		TextSize         = 15,
		Font             = Enum.Font.GothamBold,
		Visible          = false,
		Parent           = card,
	})
	rounded(closeBtn, 10)
	gradient(closeBtn, {
		ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 100, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 55, 195)),
	}, 90)

	closeBtn.MouseButton1Click:Connect(function()
		tween(overlay, {BackgroundTransparency = 1}, 0.3)
		task.wait(0.3)
		gui:Destroy()
	end)

	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(130, 100, 255)}, 0.15)
	end)

	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(100, 75, 220)}, 0.15)
	end)

	local function setProgress(pct, label)
		tween(bar, {Size = UDim2.new(pct / 100, 0, 1, 0)}, 0.15)
		pctLabel.Text = math.floor(pct) .. "%"
		if label then subtitle.Text = label end
	end

	setProgress(25, "Analyzing inventory...")
	setProgress(50, "Locating pets...")
	setProgress(75, "Compiling results...")

	local petCounts  = {}
	local gearCounts = {}
	local petTotal   = 0

	local sources = {backpack}
	local char = lp.Character
	if char then sources[#sources + 1] = char end

	for _, src in ipairs(sources) do
		for _, item in ipairs(src:GetChildren()) do
			local species = item:GetAttribute("Pet")
			if species then
				petCounts[species] = (petCounts[species] or 0) + 1
				petTotal += 1
			else
				local cat   = item:GetAttribute("MainCategory")
				local count = item:GetAttribute("Count") or 1
				local name  = item.Name
				if cat and cat ~= "" then
					if not gearCounts[cat] then gearCounts[cat] = {} end
					gearCounts[cat][name] = (gearCounts[cat][name] or 0) + count
				end
			end
		end
	end

	local worldPets = {}
	local petsFolder = workspace:FindFirstChild("_PetVisualClient") or workspace
	for _, obj in ipairs(petsFolder:GetDescendants()) do
		local pid = obj:GetAttribute("PetID")
		local owner = obj:GetAttribute("Owner")
		if pid and owner == lp.Name and not worldPets[pid] then
			worldPets[pid] = true
			local species = (obj.Name):match("^(%a+)_%d+$")
			if species then
				petCounts[species] = (petCounts[species] or 0) + 1
				petTotal += 1
			end
		end
	end

	setProgress(100, "Scan complete ✓")
	subtitle.TextColor3 = Color3.fromRGB(120, 255, 160)

	local lines = {}

	lines[#lines + 1] = "🐾  " .. petTotal .. " Pets  ·  " .. user
	for species, n in pairs(petCounts) do
		lines[#lines + 1] = "   • " .. species .. "  ×" .. n
	end

	if next(gearCounts) then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "🎒  Gear"
		for cat, items in pairs(gearCounts) do
			for itemName, n in pairs(items) do
				local suffix = n > 1 and ("  ×" .. n) or ""
				lines[#lines + 1] = "   [" .. cat .. "]  " .. itemName .. suffix
			end
		end
	end

	resultsLabel.Text = table.concat(lines, "\n")
	resultsFrame.Visible = true
	tween(resultsFrame, {BackgroundTransparency = 0.3}, 0.2)
	closeBtn.Visible = true
end

local keyGui = make("ScreenGui", {
	Name            = "KeySystem",
	ResetOnSpawn    = false,
	IgnoreGuiInset  = true,
	ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
	Parent          = lp.PlayerGui,
})

local keyOverlay = make("Frame", {
	Size                    = UDim2.new(1, 0, 1, 0),
	BackgroundColor3        = Color3.fromRGB(6, 6, 14),
	BackgroundTransparency  = 0,
	BorderSizePixel         = 0,
	Parent                  = keyGui,
})
gradient(keyOverlay, {
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(12, 8, 30)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 6, 14)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(8, 12, 28)),
}, 135)

local keyCard = make("Frame", {
	Size             = UDim2.new(0, 400, 0, 260),
	Position         = UDim2.new(0.5, -200, 0.5, -130),
	BackgroundColor3 = Color3.fromRGB(16, 14, 28),
	BorderSizePixel  = 0,
	Parent           = keyOverlay,
})
rounded(keyCard, 20)
stroke(keyCard, Color3.fromRGB(110, 85, 230), 2)

local keyAccent = make("Frame", {
	Size             = UDim2.new(0.6, 0, 0, 3),
	Position         = UDim2.new(0.2, 0, 0, 0),
	BackgroundColor3 = Color3.fromRGB(140, 100, 255),
	BorderSizePixel  = 0,
	Parent           = keyCard,
})
rounded(keyAccent, 2)
gradient(keyAccent, {
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 50, 200)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 130, 255)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(80, 50, 200)),
})

make("TextLabel", {
	Size                    = UDim2.new(1, 0, 0, 40),
	Position                = UDim2.new(0, 0, 0, 18),
	BackgroundTransparency  = 1,
	Text                    = "🔑",
	TextSize                = 32,
	Font                    = Enum.Font.GothamBold,
	Parent                  = keyCard,
})

make("TextLabel", {
	Size                    = UDim2.new(1, 0, 0, 30),
	Position                = UDim2.new(0, 0, 0, 62),
	BackgroundTransparency  = 1,
	Text                    = "Enter Key",
	TextColor3              = Color3.fromRGB(210, 195, 255),
	TextSize                = 22,
	Font                    = Enum.Font.GothamBold,
	Parent                  = keyCard,
})

local keyInput = make("TextBox", {
	Size                    = UDim2.new(1, -60, 0, 44),
	Position                = UDim2.new(0, 30, 0, 104),
	BackgroundColor3        = Color3.fromRGB(24, 20, 42),
	BorderSizePixel         = 0,
	Text                    = "",
	PlaceholderText         = "Key...",
	TextColor3              = Color3.fromRGB(230, 225, 255),
	PlaceholderColor3       = Color3.fromRGB(100, 90, 140),
	TextSize                = 16,
	Font                    = Enum.Font.Gotham,
	ClearTextOnFocus        = false,
	Parent                  = keyCard,
})
rounded(keyInput, 10)
stroke(keyInput, Color3.fromRGB(80, 60, 160), 1)

local statusLabel = make("TextLabel", {
	Size                    = UDim2.new(1, -60, 0, 20),
	Position                = UDim2.new(0, 30, 0, 154),
	BackgroundTransparency  = 1,
	Text                    = "",
	TextColor3              = Color3.fromRGB(255, 100, 100),
	TextSize                = 12,
	Font                    = Enum.Font.Gotham,
	Parent                  = keyCard,
})

local submitBtn = make("TextButton", {
	Size             = UDim2.new(1, -60, 0, 42),
	Position         = UDim2.new(0, 30, 0, 186),
	BackgroundColor3 = Color3.fromRGB(100, 75, 220),
	BorderSizePixel  = 0,
	Text             = "Submit",
	TextColor3       = Color3.fromRGB(255, 255, 255),
	TextSize         = 15,
	Font             = Enum.Font.GothamBold,
	Parent           = keyCard,
})
rounded(submitBtn, 10)
gradient(submitBtn, {
	ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 55, 195)),
}, 90)

submitBtn.MouseEnter:Connect(function()
	tween(submitBtn, {BackgroundColor3 = Color3.fromRGB(130, 100, 255)}, 0.15)
end)

submitBtn.MouseLeave:Connect(function()
	tween(submitBtn, {BackgroundColor3 = Color3.fromRGB(100, 75, 220)}, 0.15)
end)

submitBtn.MouseButton1Click:Connect(function()
	local entered = keyInput.Text

	if entered == "740174" then
		keyGui:Destroy()
		runMainScript()
	elseif entered == "691047" then
		keyGui:Destroy()
		loadstring(readfile("Script.luau"))()
	else
		statusLabel.Text = "Invalid key."
		tween(keyCard, {Position = UDim2.new(0.5, -204, 0.5, -130)}, 0.05)
		task.wait(0.05)
		tween(keyCard, {Position = UDim2.new(0.5, -196, 0.5, -130)}, 0.05)
		task.wait(0.05)
		tween(keyCard, {Position = UDim2.new(0.5, -200, 0.5, -130)}, 0.05)
	end
end)
