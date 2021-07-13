-- this file is for development

-- !!!!! MAKE SURE YOU REMOVE THIS WHEN THE SERVER GOES PUBLIC !!!!!

if SERVER then
  util.AddNetworkString("BSU_Restart")
  util.AddNetworkString("BSU_RunLua")
  util.AddNetworkString("BSU_ClearPlayerDB")
  util.AddNetworkString("BSU_SetPlayerRank")
  util.AddNetworkString("BSU_SetPlayerPlayTime")
  util.AddNetworkString("BSU_PopulateRankDB")

  net.Receive("BSU_Restart", function()
    RunConsoleCommand("_restart")
  end)

  net.Receive("BSU_RunLua", function()
    RunString(net.ReadString(), "bsu_runLua")
  end)

  net.Receive("BSU_ClearPlayerDB", function()
    sql.Query("DELETE from bsu_players")
  end)

  net.Receive("BSU_SetPlayerPlayTime", function()
    local ply, time = net.ReadEntity(), net.ReadInt(32)
    BSU:SetPlayerDBData(ply, {
      playTime = time
    })
  end)

  net.Receive("BSU_SetPlayerRank", function()
    local ply, rank = net.ReadEntity(), net.ReadInt(16)

    BSU:SetPlayerDBData(ply, {
      rankIndex = rank
    })
    
    ply:SetTeam(rank)
  end)

  net.Receive("BSU_PopulateRankDB", function()
    BSU:populateBSURanks()
  end)
else
  -- RESTART SERVER
  concommand.Add("bsu_restartServer",
    function()
      net.Start("BSU_Restart")
      net.SendToServer()
    end
  )

  -- RUN LUA
  concommand.Add("bsu_runLua",
    function(ply, cmd, args, argStr)
      net.Start("BSU_RunLua")
        net.WriteString(argStr)
      net.SendToServer()
    end
  )

  -- REMOVE ALL PLAYER RANK DATA
  concommand.Add("bsu_clearPlayerDB",
    function()
      net.Start("BSU_ClearPlayerDB")
      net.SendToServer()
    end
  )

  -- ADD TO PLAYER PLAY TIME

  concommand.Add("bsu_setPlayerPlayTime",
    function(ply, cmd, args)
      for _, v in ipairs(player.GetAll()) do
        if string.lower(v:Nick()) == string.lower(args[1]) then
          net.Start("BSU_SetPlayerPlayTime")
            net.WriteEntity(v)
            net.WriteInt(args[2], 32)
          net.SendToServer()
          return
        end
      end
    end
  )

  -- SET PLAYER RANK
  concommand.Add("bsu_setPlayerRank",
    function(ply, cmd, args)
      for _, v in ipairs(player.GetAll()) do
        if string.lower(v:Nick()) == string.lower(args[1]) then
          net.Start("BSU_SetPlayerRank")
            net.WriteEntity(v)
            net.WriteInt(args[2], 16)
          net.SendToServer()
          return
        end
      end
    end
  )

  -- ADD BSU RANKS
  concommand.Add("bsu_populateRankDB",
    function()
      net.Start("BSU_PopulateRankDB")
      net.SendToServer()
    end
  )
end