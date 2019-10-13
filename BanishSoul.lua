local _G = _G
local _, BS = ...
local DataBroker = LibStub("LibDataBroker-1.1");
local MiniMapIcon = LibStub("LibDBIcon-1.0");
local TextArea = LibStub("LibTextDump-1.0")
_G.BanishSoul = BS;

BS.DataBroker = DataBroker:NewDataObject("BanishSoul", {
  type = "data source",
  text = "BanishSoul",
  icon = "Interface\\Addons\\BanishSoul\\icons\\BanishSoulIcon.blp"
})
MiniMapIcon:Register("BanishSoul", BS.DataBroker, {["hide"] = false});
BS.ExportTextArea = TextArea:New("Export to banishsoul.com");

BS.MapIDRemap = {
	[968] = 566,
	[998] = 1035,
	[1681] = 2107
}

function BS:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("PVP_MATCH_COMPLETE")
  self:RegisterForDrag("LeftButton")  
end

function BS:Round(num, idp)
	local mult = 10^(idp or 0)
	return mfloor(num * mult + 0.5) / mult
end

function BS:GetUTCTimestamp(timezone)
	local d1 = date("*t")
	local d2 = date("!*t")
	d2.isdst = d1.isdst
	local utc = time(d2)
	if timezone then
		local player = time(d1)
		return utc, BS:Round((player - utc) / 3600, 0)
	else
		return utc
	end
end

function BS:onPVPEnd()
  if _G.IsArenaSkirmish() then
    BS.MatchData = {}

    local StatsNum = _G.C_PvP.GetMatchPVPStatColumns()
    BS.MatchData.map = select(8, _G.GetInstanceInfo())
    BS.MatchData.winner = _G.GetBattlefieldWinner()
    BS.MatchData.playerSide = _G.GetBattlefieldArenaFaction()
    BS.MatchData.isArena = _G.IsActiveBattlefieldArena()
    BS.MatchData.season = _G.GetCurrentArenaSeason()
    BS.MatchData.playersNum = _G.GetNumBattlefieldScores()
    BS.MatchData.statsNum = #StatsNum
    BS.MatchData.duration = _G.C_PvP.GetActiveMatchDuration()
    BS.MatchData.time = BS:GetUTCTimestamp()
    BS.MatchData.isBrawl = _G.C_PvP.IsInBrawl()

    if BS.MapIDRemap[BS.MatchData.map] then
      BS.MatchData.map = BS.MapIDRemap[BS.MatchData.map]
    end

    -- if IsRatedBattleground() or IsRatedArena() and not IsArenaSkirmish() then
    if _G.IsArenaSkirmish() then    
      BS.MatchData.isRated = true
    end

    BS.MatchData.players = {}
    for i=1, BS.MatchData.playersNum do
      local data = {_G.GetBattlefieldScore(i)}
      if data[1] == BS.playerName then
        BS.MatchData.playerNum = i
      end
      table.insert(BS.MatchData.players, data)
    end

    if BS.MatchData.isRated then
      BS.MatchData.teamData = {}
      BS.MatchData.teamData[1] = {_G.GetBattlefieldTeamInfo(0)}
      BS.MatchData.teamData[2] = {_G.GetBattlefieldTeamInfo(1)}
    end

    if BS.MatchData.statsNum > 0 then
      BS.MatchData.playersStats = {}
      for i=1, BS.MatchData.playersNum do
        BS.MatchData.playersStats[i] = {}
        for j=1, BS.MatchData.statsNum do
          table.insert(BS.MatchData.playersStats[i], {_G.GetBattlefieldStatData(i, j)})
        end
      end
    end

    if not BS.MatchData.playerNum or BS.MatchData.map == 1170 or BS.matchData.Map == 2177 or (BS.MatchData.isArena and BS.MatchData.isRated and BS.MatchData.isBrawl) then
      BS.MatchData.Hidden = true
    else
      BS.MatchData.Hidden = false
    end
    table.insert(BS.Database, BS.MatchData)
    if not BS.MatchData.Hidden then
      if BS.MatchData.isArena then
        BS:UpdateArenaData(false)
      else
        BS:UpdateBGData(false)
      end
    end
  end
	_G.PVPMatchResults.buttonContainer.leaveButton:Enable()
end

function BS:CreateExportString()
  local str = ''
  BS.ExportTextArea:Clear()
  str = str..'{ "data": ['
  for i=1, #BS.Database do
    str = str..'{'
    for k, v in pairs(BS.Database[i]) do  
      if(k == 'players') then
        str = str..'"'.._G.tostring(k)..'"'..': ['
        for kPlayers, vPlayers in pairs(v) do
          str = str..'{'
          for kPlayer, vPlayer in pairs(vPlayers) do
            str = str..'"'.._G.tostring(kPlayer)..'"'..': '..'"'.._G.tostring(vPlayer)..'"'..','
          end
          str = str:sub(1, -2);
          str = str..'},'
        end
        str = str:sub(1, -2);
        str = str..'],'
      elseif(k == 'teamData') then
        str = str..'"'.._G.tostring(k)..'"'..': ['
        for kTeams, vTeams in pairs(v) do
          str = str..'{'
          for kTeam, vTeam in pairs(vTeams) do
            str = str..'"'.._G.tostring(kTeam)..'"'..': '..'"'.._G.tostring(vTeam)..'"'..','
          end
          str = str:sub(1, -2);
          str = str..'},'
        end
        str = str:sub(1, -2);
        str = str..'],'
      else
        str = str..'"'.._G.tostring(k)..'"'..': '..'"'.._G.tostring(v)..'"'..','
      end
    end
    str = str:sub(1, -2);
    str = str..'},'
  end
  str = str:sub(1, -2);
  str = str..']}'
  BS.ExportTextArea:AddLine(str)
  BS.ExportTextArea:Display()
end

function BS:OnEvent(_, event, ...)
  if event == "PVP_MATCH_COMPLETE" then -- and not BS.DataSaved then
    -- BS.DataSaved = true
    _G.PVPMatchResults.buttonContainer.leaveButton:Disable()
    _G.C_Timer.After(1, BS.onPVPEnd)
  elseif event == "ADDON_LOADED" and ... == "BanishSoul" then
    if not _G.BanishSoulDB then
      _G.BanishSoulDB = {}
    end
    BS.Database = _G.BanishSoulDB
  end
  function BS.DataBroker:OnClick(button)
    if MiniMapIcon:GetMinimapButton("BanishSoul") == GetMouseFocus() then
      if button == "LeftButton" then
        BS:CreateExportString()
      end
    end
  end
end