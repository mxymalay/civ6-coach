-- Fixed read-only queries. No game commands, setters, UI automation or arbitrary input.
local function quote(s)
  return '"' .. tostring(s):gsub('[%z\1-\31\\"]', function(c)
    return string.format('\\u%04x', string.byte(c))
  end) .. '"'
end
local function json(v)
  local t = type(v)
  if t == 'nil' then return 'null' end
  if t == 'boolean' then return v and 'true' or 'false' end
  if t == 'number' then
    if v ~= v or v == math.huge or v == -math.huge then return 'null' end
    return tostring(v)
  end
  if t ~= 'table' then return quote(v) end
  local parts = {}
  for k,val in pairs(v) do parts[#parts+1] = quote(k)..':'..json(val) end
  return '{'..table.concat(parts, ',')..'}'
end
local function emit(kind, row) row.kind=kind; print(json(row)) end
local function section(name, fn)
  local ok,err=pcall(fn)
  if not ok then emit('error',{section=name,message=tostring(err)}) end
end
local function field(row, key, fn)
  local ok,value=pcall(fn)
  if ok then row[key]=value else
    row.errors=row.errors or {}; row.errors[key]=tostring(value)
  end
end
local function name(row) return row and Locale.Lookup(row.Name) or nil end
local function context()
  local id=Game.GetLocalPlayer()
  if id == nil or id < 0 or not Players[id] then error('没有本地玩家，请进入单人地图') end
  emit('meta',{turn=Game.GetCurrentGameTurn(),player=id,
    civilization=Locale.Lookup(PlayerConfigurations[id]:GetCivilizationShortDescription()),
    leader=Locale.Lookup(PlayerConfigurations[id]:GetLeaderName())})
  return id,Players[id]
end
function collect_snapshot()
  local me,p=context()
  section('economy',function()
    local r={}
    field(r,'gold',function() return p:GetTreasury():GetGoldBalance() end)
    field(r,'gold_net_per_turn',function() local t=p:GetTreasury(); return t:GetGoldYield()-t:GetTotalMaintenance() end)
    field(r,'science_per_turn',function() return p:GetTechs():GetScienceYield() end)
    field(r,'culture_per_turn',function() return p:GetCulture():GetCultureYield() end)
    field(r,'faith',function() return p:GetReligion():GetFaithBalance() end)
    field(r,'government',function() return name(GameInfo.Governments[p:GetCulture():GetCurrentGovernment()]) end)
    emit('economy',r)
  end)
  section('cities',function()
    local productionNames={}
    for _,tbl in ipairs({GameInfo.Units,GameInfo.Buildings,GameInfo.Districts,GameInfo.Projects}) do
      for row in tbl() do productionNames[row.Hash]=name(row) end
    end
    for _,c in p:GetCities():Members() do
      local r={id=c:GetID(),name=Locale.Lookup(c:GetName()),x=c:GetX(),y=c:GetY(),population=c:GetPopulation()}
      local g=c:GetGrowth()
      field(r,'housing',function() return g:GetHousing() end)
      field(r,'amenities_balance',function() return g:GetAmenities() end)
      field(r,'food_surplus',function() return g:GetFoodSurplus() end)
      field(r,'growth_turns',function() return g:GetTurnsUntilGrowth() end)
      for _,y in ipairs({'FOOD','PRODUCTION','GOLD','SCIENCE','CULTURE','FAITH'}) do
        field(r,y:lower()..'_per_turn',function() return c:GetYield(GameInfo.Yields['YIELD_'..y].Index) end)
      end
      field(r,'production',function() local q=c:GetBuildQueue(); if q:GetSize()==0 then return '空闲' end; return productionNames[q:GetCurrentProductionTypeHash()] or '未知生产项目' end)
      field(r,'production_turns',function() return c:GetBuildQueue():GetTurnsLeft() end)
      field(r,'loyalty',function() return c:GetCulturalIdentity():GetLoyalty() end)
      field(r,'loyalty_per_turn',function() return c:GetCulturalIdentity():GetLoyaltyPerTurn() end)
      emit('city',r)
      section('production_options:'..c:GetID(),function()
        local q=c:GetBuildQueue()
        for _,spec in ipairs({{GameInfo.Units,'UnitType'},{GameInfo.Buildings,'BuildingType'},{GameInfo.Districts,'DistrictType'}}) do
          for item in spec[1]() do
            local params=item.Hash
            if spec[2]=='UnitType' then params={UnitType=item.Hash,MilitaryFormationType=MilitaryFormationTypes.STANDARD_MILITARY_FORMATION} end
            if not item.MustPurchase and q:CanProduce(params,true) and q:CanProduce(params,false) then
              local choice={city=c:GetID(),name=name(item),type=item[spec[2]]}
              field(choice,'turns',function() return q:GetTurnsLeft(item.Hash) end)
              emit('production_option',choice)
            end
          end
        end
      end)
      section('buildings:'..c:GetID(),function()
        for b in GameInfo.Buildings() do
          if c:GetBuildings():HasBuilding(b.Index) then emit('building',{city=c:GetID(),name=name(b),type=b.BuildingType}) end
        end
      end)
    end
  end)
  section('units',function()
    for _,u in p:GetUnits():Members() do
      local info=GameInfo.Units[u:GetType()]
      local r={id=u:GetID(),name=name(info),type=info and info.UnitType,x=u:GetX(),y=u:GetY()}
      field(r,'hp',function() return u:GetMaxDamage()-u:GetDamage() end)
      field(r,'max_hp',function() return u:GetMaxDamage() end)
      field(r,'moves',function() return u:GetMovesRemaining() end)
      field(r,'build_charges',function() return u:GetBuildCharges() end)
      emit('unit',r)
    end
  end)
  section('technology',function()
    local te=p:GetTechs()
    local boosts={}
    for b in GameInfo.Boosts() do if b.TechnologyType then boosts[b.TechnologyType]=b end end
    for t in GameInfo.Technologies() do
      if te:CanResearch(t.Index) and not te:HasTech(t.Index) then
        local r={name=name(t),type=t.TechnologyType,current=te:GetResearchingTech()==t.Index,
          turns=te:GetTurnsToResearch(t.Index),boosted=te:HasBoostBeenTriggered(t.Index)}
        local b=boosts[t.TechnologyType]
        if b and b.TriggerDescription then r.boost_condition=Locale.Lookup(b.TriggerDescription) end
        emit('technology_option',r)
      end
    end
  end)
  section('civic',function()
    local cu=p:GetCulture(); local idx=cu:GetProgressingCivic()
    local r={name=name(GameInfo.Civics[idx]),index=idx}
    field(r,'progress',function() return cu:GetCulturalProgress(idx) end)
    field(r,'cost',function() return cu:GetCultureCost(idx) end)
    field(r,'estimated_turns',function()
      local rate=cu:GetCultureYield()
      if idx>=0 and rate>0 then return math.ceil(math.max(0,cu:GetCultureCost(idx)-cu:GetCulturalProgress(idx))/rate) end
    end)
    emit('current_civic',r)
  end)
  section('diplomacy',function()
    local d=p:GetDiplomacy()
    for i=0,63 do
      if i~=me and Players[i] and (Players[i]:IsMajor() or Players[i]:IsMinor()) and d:HasMet(i) then
        local r={player=i,civilization=Locale.Lookup(PlayerConfigurations[i]:GetCivilizationShortDescription())}
        field(r,'at_war',function() return d:IsAtWarWith(i) end)
        emit('known_player',r)
      end
    end
  end)
end
function collect_map(cx,cy,radius)
  local me,p=context(); local vis=PlayersVisibility[me]
  local w,h=Map.GetGridSize()
  if cx>=w or cy>=h then error('坐标超出地图') end
  for dy=-radius,radius do for dx=-radius,radius do
    local plot=Map.GetPlot(cx+dx,cy+dy)
    if plot and Map.GetPlotDistance(cx,cy,plot:GetX(),plot:GetY())<=radius and vis:IsVisible(plot:GetIndex()) then
      local r={x=plot:GetX(),y=plot:GetY(),owner=plot:GetOwner(),terrain=name(GameInfo.Terrains[plot:GetTerrainType()]),
        feature=name(GameInfo.Features[plot:GetFeatureType()]),hills=plot:IsHills(),river=plot:IsRiver(),water=plot:IsWater()}
      field(r,'resource',function()
        local idx=plot:GetResourceType()
        if idx>=0 and p:GetResources():IsResourceVisible(idx) then return name(GameInfo.Resources[idx]) end
      end)
      field(r,'improvement',function() return name(GameInfo.Improvements[plot:GetImprovementType()]) end)
      emit('tile',r)
      section('visible_units',function()
        local units=Map.GetUnitsAt(plot:GetX(),plot:GetY())
        if units then for u in units:Units() do
          if u:GetOwner()==me or vis:IsUnitVisible(u) then
            emit('visible_unit',{id=u:GetID(),owner=u:GetOwner(),name=name(GameInfo.Units[u:GetType()]),
              x=u:GetX(),y=u:GetY(),hp=u:GetMaxDamage()-u:GetDamage(),
              at_war=p:GetDiplomacy():IsAtWarWith(u:GetOwner())})
          end
        end end
      end)
    end
  end end
end
