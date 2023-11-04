-- lib/server/privileges.lua
-- functions for managing group and player privileges

function BSU.RegisterGroupPrivilege(groupid, type, value, granted)
	-- incase this privilege is already registered, remove the old one
	BSU.RemoveGroupPrivilege(groupid, type, value) -- sqlite's REPLACE INTO could've been implemented but removing and inserting is practically the same

	BSU.SQLInsert(BSU.SQL_GROUP_PRIVS, {
		groupid = groupid,
		type = type,
		value = value,
		granted = granted and 1 or 0
	})
end

function BSU.RemoveGroupPrivilege(groupid, type, value)
	BSU.SQLDeleteByValues(BSU.SQL_GROUP_PRIVS, {
		groupid = groupid,
		type = type,
		value = value
	})
end

function BSU.GetAllGroupPrivileges()
	return BSU.SQLSelectAll(BSU.SQL_GROUP_PRIVS)
end

function BSU.GetGroupWildcardPrivileges(groupid, type)
	local query = BSU.SQLQuery("SELECT * FROM '%s' WHERE groupid = %s AND type = %s AND value LIKE '%s'",
		BSU.EscOrNULL(BSU.SQL_GROUP_PRIVS, true),
		BSU.EscOrNULL(groupid),
		BSU.EscOrNULL(type),
		"%*%"
	)
	return query and BSU.SQLParse(query, BSU.SQL_GROUP_PRIVS) or {}
end

function BSU.GetGroupInherit(groupid)
	local query = BSU.SQLSelectByValues(BSU.SQL_GROUPS, { id = groupid })[1]
	return query and query.inherit or nil
end

-- returns bool if the group is granted the privilege (or nothing if the privilege is not registered)
function BSU.CheckGroupPrivilege(groupid, type, value, checkwildcards)
	-- check for group privilege
	local priv = BSU.SQLSelectByValues(BSU.SQL_GROUP_PRIVS, { groupid = groupid, type = type, value = value })[1]

	if priv then
		return priv.granted ~= 0
	else
		-- check wildcard privileges
		if checkwildcards then
			local wildcards = BSU.GetGroupWildcardPrivileges(groupid, type)
			table.sort(wildcards, function(a, b) return #a.value > #b.value end)

			for _, v in ipairs(wildcards) do
				if string.find(value, string.Replace(v.value, "*", "(.-)")) ~= nil then
					return v.granted ~= 0
				end
			end
		end

		-- check for privilege in inherited group
		local inherit = BSU.GetGroupInherit(groupid)
		if inherit then
			return BSU.CheckGroupPrivilege(inherit, type, value, checkwildcards)
		end
	end
end

-- returns bool if the player is granted the privilege (or nothing if the privilege is not registered in the player's group)
function BSU.CheckPlayerPrivilege(steamid, type, value, checkwildcards)
	steamid = BSU.ID64(steamid)

	-- check for privilege in player's group
	local data = BSU.SQLSelectByValues(BSU.SQL_PLAYERS, { steamid = steamid })[1]
	if data then
		return BSU.CheckGroupPrivilege(data.groupid, type, value, checkwildcards)
	end
end