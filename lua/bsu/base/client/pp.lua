--- base/client/pp.lua

concommand.Add("bsu_reset_permissions", function()
	-- easiest way is to delete the table and recreate it
	BSU.SQLQuery("DROP TABLE IF EXISTS %s", BSU.EscOrNULL(BSU.SQL_PP, true))
	BSU.SQLCreateTable(BSU.SQL_PP, string.format(
		[[
			steamid TEXT PRIMARY KEY,
			permission INTEGER NOT NULL
		]]
	))
	BSU.SendPermissions() -- tell the server we updated our perms for everyone
	hook.Run("BSU_ResetPermissions")
end)

local function addPropProtectionMenu()
	spawnmenu.AddToolMenuOption("Utilities", "BSU", "Prop Protection", "Prop Protection", "", "", function(pnl)
		pnl:ClearControls()

		pnl:Button("Reset Permissions", "bsu_reset_permissions")

		local list = vgui.Create("DIconLayout")
		pnl:AddItem(list)
		list:SetHeight(2000)
		list:SetSpaceY(4)

		local top = list:Add("DIconLayout")
		top:SetSize(225, 16)
		top:SetSpaceX(9)
		local label = top:Add("DLabel")
		label:SetSize(100, 16)
		label:SetText("[ Players ]")
		label:SetColor(color_black)
		local icons = { "wrench", "wrench_orange", "wand", "ruby", "gun" }
		local tips = { "Physgun", "Gravgun", "Toolgun/Properties", "Use (E)", "Damage" }
		for i = 1, 5 do
			local icon = top:Add("DImageButton")
			icon:SetSize(16, 16)
			icon:SetImage(string.format("icon16/%s.png", icons[i]))
			icon:SetTooltip(tips[i])
		end

		local elems = {}

		local function boxOnChange(self, checked)
			if self.ply:IsValid() then
				if checked then
					BSU.GrantPermission(self.ply, self.perm)
				else
					BSU.RevokePermission(self.ply, self.perm)
				end
			end
		end

		local function update()
			local oldElems = elems
			elems = {}
			for _, v in ipairs(player.GetHumans()) do
				if v == LocalPlayer() then continue end
				local oldElem = oldElems[v]
				if oldElem and oldElem:IsValid() then
					oldElem.name:SetText(v:Nick()) -- incase name changed
					elems[v] = oldElem
					oldElems[v] = nil
				else -- add player element
					local elem = list:Add("DIconLayout")
					elems[v] = elem
					elem.OwnLine = true
					elem:SetSize(225, 15)
					elem:SetSpaceX(10)

					local name = elem:Add("DLabel")
					elem.name = name
					name:SetSize(100, 15)
					name:SetText(v:Nick())
					name:SetColor(color_black)

					elem.boxes = {}
					for i = 1, 5 do
						local box = elem:Add("DCheckBox")
						elem.boxes[i] = box
						box.ply = v
						box.perm = math.pow(2, i - 1)
						box:SetValue(BSU.CheckPermission(v:SteamID64(), box.perm))
						box.OnChange = boxOnChange
					end
				end
			end

			-- remove disconnected players elements
			for _, v in pairs(oldElems) do
				v:Remove()
			end
		end

		timer.Create("BSU_UpdatePropProtectionMenu", 1, 0, update)

		hook.Add("BSU_ResetPermissions", "BSU_UpdatePropProtectionMenu", function()
			for _, v in pairs(elems) do
				v:Remove()
			end
			update()
		end)

		update()

		pnl:CheckBox("Persist permissions across sessions", "bsu_permission_persist")
		pnl:CheckBox("Allow props to take fire damage", "bsu_allow_fire_damage")
	end)
end

hook.Add("PopulateToolMenu", "BSU_AddPropProtectionMenu", addPropProtectionMenu)

local hudColorBG = Color(0, 0, 0, 75)
local hudColorFG = Color(255, 255, 255, 255)
local hudX, hudY = GetConVar("bsu_propinfo_x"):GetInt(), GetConVar("bsu_propinfo_y"):GetInt()

local font = "BSU_PP_HUD"
surface.CreateFont(font, {
	font = "Verdana",
	size = 16,
	weight = 400,
	antialias = true,
	shadow = true
})

cvars.AddChangeCallback("bsu_propinfo_x", function(_, _, new)
	hudX = tonumber(new)
end)

cvars.AddChangeCallback("bsu_propinfo_y", function(_, _, new)
	hudY = tonumber(new)
end)

local function drawPropProtectionHUD()
	local ply = LocalPlayer()

	if not GetConVar("bsu_show_propinfo"):GetBool() then return end

	local trace = util.GetPlayerTrace(ply)
	trace.mask = MASK_SHOT
	local ent = util.TraceLine(trace).Entity
	if ent:IsValid() and not ent:IsPlayer() then
		local name, steamid = BSU.GetOwnerName(ent) or "N/A", BSU.GetOwnerSteamID(ent)
		local text = "Owner: " .. name .. (steamid and "<" .. steamid .. ">" or "") .. "\n" .. ent:GetModel() .. "\n" .. tostring(ent)
		surface.SetFont(font)
		local w, h = surface.GetTextSize(text)
		draw.RoundedBox(4, hudX, hudY, w + 8, h + 8, hudColorBG)
		draw.DrawText(text, font, hudX + 4, hudY + 4, hudColorFG, TEXT_ALIGN_LEFT)
	end
end

hook.Add("HUDPaint", "BSU_DrawPropProtectionHUD", drawPropProtectionHUD)

if not GetConVar("bsu_permission_persist"):GetBool() then
	RunConsoleCommand("bsu_reset_permissions")
end

hook.Add("InitPostEntity", "BSU_SendPermissions", BSU.SendPermissions)
