-- FROSTZN DEX • Derivado do arquivo enviado pelo usuario.
--[[
MIT License

Copyright (c) 2021 LorekeeperZinnia

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]
-- Runtime da personalizacao Frostzn. Nao modifica servicos/remotes do jogo.
local FrostznScope=(type(getgenv)=="function" and getgenv()) or _G
local previous=FrostznScope.FrostznDex
if previous and previous.Alive then
    if previous.Open then previous.Open("Explorer") end
    return
end
local FrostznLife={Alive=true,Ready=false,Connections={},Threads={},Guis={},Budget=.003,
    Started=os.clock(),Scanned=0,SearchCount=0,SearchId=0,Phase="Inicializando",Cache={}}
FrostznScope.FrostznDex=FrostznLife
function FrostznLife.Connect(signal,callback)
    local connection=signal:Connect(function(...)
        if FrostznLife.Alive then return callback(...) end
    end)
    if not FrostznLife.Alive then connection:Disconnect();return connection end
    FrostznLife.Connections[#FrostznLife.Connections+1]=connection
    return connection
end
function FrostznLife.Wrap(callback)
    return coroutine.wrap(function(...)
        if not FrostznLife.Alive then return end
        local thread=coroutine.running();FrostznLife.Threads[thread]=true
        local results=table.pack(callback(...))
        FrostznLife.Threads[thread]=nil
        return table.unpack(results,1,results.n)
    end)
end
function FrostznLife.Spawn(callback,...)
    return task.spawn(FrostznLife.Wrap(callback),...)
end
function FrostznLife.TrackGui(gui)
    if typeof(gui)=="Instance" and gui:IsA("LayerCollector") then
        if not FrostznLife.Alive then gui:Destroy();return end
        if FrostznLife.Guis[gui] then return end
        FrostznLife.Guis[gui]=true
        gui:SetAttribute("FrostznDexOwned",true)
        gui.ResetOnSpawn=false
        if FrostznLife.Skin then
            FrostznLife.Skin(gui)
            FrostznLife.Connect(gui.DescendantAdded,function(object)FrostznLife.Skin(object)end)
            for _,object in ipairs(gui:GetDescendants()) do FrostznLife.Skin(object);FrostznLife.Yield() end
        end
    end
end
function FrostznLife.Skin(object)
    if not object:IsA("GuiObject") then return end
    local color=object.BackgroundColor3
    if math.abs(color.R-color.G)<.003 and math.abs(color.G-color.B)<.003 and color.R<.45 then
        local value=color.R*255
        object.BackgroundColor3=value<=25 and Color3.fromRGB(10,12,23) or
            value<=40 and Color3.fromRGB(17,19,30) or value<=55 and Color3.fromRGB(25,28,42) or
            value<=75 and Color3.fromRGB(35,38,56) or Color3.fromRGB(52,55,78)
    end
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        if object.Font~=Enum.Font.Code and object.Font~=Enum.Font.RobotoMono then object.Font=Enum.Font.SourceSans end
        local value=object.TextColor3
        if math.abs(value.R-value.G)<.003 and math.abs(value.G-value.B)<.003 then
            object.TextColor3=value.R>.55 and Color3.fromRGB(231,235,248) or Color3.fromRGB(151,160,188)
        end
    end
end
function FrostznLife.Owned(object)
    local ancestor=object
    for _=1,65 do
        if not ancestor then break end
        if FrostznLife.Guis[ancestor] then return true end
        ancestor=ancestor.Parent
    end
    return false
end
local deadline=os.clock()+FrostznLife.Budget
function FrostznLife.Yield()
    if not FrostznLife.Alive then error("[Frostzn Dex] Sessao encerrada",0) end
    if os.clock()>=deadline then task.wait();deadline=os.clock()+FrostznLife.Budget end
end
function FrostznLife.Status(text)
    FrostznLife.Phase=text
    if FrostznLife.StatusLabel and FrostznLife.StatusLabel.Parent then FrostznLife.StatusLabel.Text=text end
end
function FrostznLife.Descendants(root)
    local found,stack={}, {root}
    while #stack>0 and FrostznLife.Alive do
        local object=table.remove(stack)
        local list=object:GetChildren()
        for i=1,#list do
            local child=list[i]
            if not FrostznLife.Owned(child) then
                found[#found+1]=child;stack[#stack+1]=child
            end
            if i%128==0 then FrostznLife.Yield() end
        end
        FrostznLife.Yield()
    end
    return found
end
function FrostznLife.Shutdown()
    if not FrostznLife.Alive then return end
    if FrostznLife.RestoreCamera then FrostznLife.RestoreCamera() end
    FrostznLife.Alive=false;FrostznLife.SearchId+=1
    for _,connection in ipairs(FrostznLife.Connections) do pcall(function()connection:Disconnect()end) end
    table.clear(FrostznLife.Connections)
    local current=coroutine.running()
    for thread in pairs(FrostznLife.Threads) do
        if thread~=current and coroutine.status(thread)~="dead" then pcall(task.cancel,thread) end
    end
    table.clear(FrostznLife.Threads)
    for gui in pairs(FrostznLife.Guis) do pcall(function()gui:Destroy()end) end
    table.clear(FrostznLife.Guis);table.clear(FrostznLife.Cache)
    if FrostznLife.Nodes then table.clear(FrostznLife.Nodes) end
    if FrostznScope.FrostznDex==FrostznLife then FrostznScope.FrostznDex=nil end
end
-- Remove referencias a conexoes temporarias ja desconectadas.
FrostznLife.Spawn(function()
    while FrostznLife.Alive do
        task.wait(8)
        local compact={}
        for _,connection in ipairs(FrostznLife.Connections) do
            local ok,connected=pcall(function()return connection.Connected end)
            if not ok or connected~=false then compact[#compact+1]=connection end
        end
        FrostznLife.Connections=compact
    end
end)

-- Controle reversivel de observacao; nao muda o personagem observado.
do
    local links={}
    local saved
    local function disconnect()
        for _,c in ipairs(links) do c:Disconnect() end
        table.clear(links)
    end
    function FrostznLife.RestoreCamera()
        disconnect()
        local camera=workspace.CurrentCamera
        local snapshot=saved;saved=nil;FrostznLife.ViewTarget=nil
        if camera and snapshot then
            local character=game:GetService("Players").LocalPlayer.Character
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            local subject=snapshot.Subject
            if not subject or not subject.Parent then subject=humanoid end
            pcall(function()
                camera.CameraSubject=subject or humanoid
                camera.CameraType=snapshot.Type
                if snapshot.Type==Enum.CameraType.Scriptable then camera.CFrame=snapshot.CFrame;camera.Focus=snapshot.Focus end
            end)
        end
        if FrostznLife.CameraExit then FrostznLife.CameraExit.Visible=false end
    end
    function FrostznLife.View(target)
        local camera=workspace.CurrentCamera
        if not camera or not target then return false end
        local player=target:IsA("Player") and target or nil
        local object=player and player.Character or target
        local subject=object and (object:IsA("Model") and (object:FindFirstChildOfClass("Humanoid") or object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart",true)) or object)
        if not subject or not (subject:IsA("Humanoid") or subject:IsA("BasePart")) then
            FrostznLife.Status("Alvo sem personagem ou peça de câmera");return false
        end
        if not saved then saved={Subject=camera.CameraSubject,Type=camera.CameraType,CFrame=camera.CFrame,Focus=camera.Focus} end
        disconnect();FrostznLife.ViewTarget=target
        camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=subject
        local function watch(signal,fn) links[#links+1]=FrostznLife.Connect(signal,fn) end
        watch(object.AncestryChanged,function()if not object:IsDescendantOf(game) then FrostznLife.RestoreCamera() end end)
        watch(game:GetService("Players").LocalPlayer.CharacterAdded,FrostznLife.RestoreCamera)
        watch(workspace:GetPropertyChangedSignal("CurrentCamera"),FrostznLife.RestoreCamera)
        if subject:IsA("Humanoid") then watch(subject.Died,FrostznLife.RestoreCamera) end
        if player then watch(game:GetService("Players").PlayerRemoving,function(p)if p==player then FrostznLife.RestoreCamera() end end) end
        if FrostznLife.CameraExit then FrostznLife.CameraExit.Visible=true end
        FrostznLife.Status("Observando "..target.Name.." • F7 para voltar")
        return true
    end
end

-- Exportacao XML de objetos presentes no cliente, em lotes e com relatorio.
do
    local busy=false
    local function xml(v)
        return tostring(v):gsub("[%z\1-\8\11\12\14-\31]",""):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&apos;")
    end
    local function number(v)
        if v~=v then return "NAN" elseif v==math.huge then return "INF" elseif v==-math.huge then return "-INF" end
        return string.format("%.9g",v)
    end
    local function field(tag,value)return "<"..tag..">"..number(value).."</"..tag..">" end
    local function property(name,v,kind,ids)
        local t=typeof(v);local tag,body
        if t=="string" then
            tag=name=="Source" and "ProtectedString" or "string"
            if kind=="Content" or kind=="ContentId" then tag="Content";body=v=="" and "<null></null>" or "<url>"..xml(v).."</url>" else body=xml(v) end
        elseif t=="boolean" then tag="bool";body=tostring(v)
        elseif t=="number" then tag=(kind=="int" or kind=="int64") and kind or "double";body=number(v)
        elseif t=="EnumItem" then tag="token";body=tostring(v.Value)
        elseif t=="Instance" then tag="Ref";body=ids[v] or "null"
        elseif t=="nil" then
            if kind=="PhysicalProperties" then tag="PhysicalProperties";body="<CustomPhysics>false</CustomPhysics>" else return nil end
        elseif t=="Vector3" then tag=t;body=field("X",v.X)..field("Y",v.Y)..field("Z",v.Z)
        elseif t=="Vector2" then tag=t;body=field("X",v.X)..field("Y",v.Y)
        elseif t=="Color3" then tag=t;body=field("R",v.R)..field("G",v.G)..field("B",v.B)
        elseif t=="BrickColor" then tag="int";body=tostring(v.Number)
        elseif t=="CFrame" then
            tag="CoordinateFrame";local c={v:GetComponents()};local names={"X","Y","Z","R00","R01","R02","R10","R11","R12","R20","R21","R22"};local a={}
            for i,k in ipairs(names) do a[i]=field(k,c[i]) end;body=table.concat(a)
        elseif t=="UDim" then tag=t;body=field("S",v.Scale)..field("O",v.Offset)
        elseif t=="UDim2" then tag=t;body=field("XS",v.X.Scale)..field("XO",v.X.Offset)..field("YS",v.Y.Scale)..field("YO",v.Y.Offset)
        elseif t=="Rect" then tag="Rect2D";body="<min>"..field("X",v.Min.X)..field("Y",v.Min.Y).."</min><max>"..field("X",v.Max.X)..field("Y",v.Max.Y).."</max>"
        elseif t=="NumberRange" then tag=t;body=number(v.Min).." "..number(v.Max)
        elseif t=="NumberSequence" or t=="ColorSequence" then
            tag=t;local a={}
            for _,k in ipairs(v.Keypoints) do
                a[#a+1]=t=="NumberSequence" and (number(k.Time).." "..number(k.Value).." "..number(k.Envelope)) or
                    (number(k.Time).." "..number(k.Value.R).." "..number(k.Value.G).." "..number(k.Value.B).." 0")
            end
            body=table.concat(a," ").." "
        elseif t=="PhysicalProperties" then tag=t;body="<CustomPhysics>true</CustomPhysics>"..field("Density",v.Density)..field("Friction",v.Friction)..field("Elasticity",v.Elasticity)..field("FrictionWeight",v.FrictionWeight)..field("ElasticityWeight",v.ElasticityWeight)
        else return nil end
        return "<"..tag..' name="'..xml(name)..'">'..body.."</"..tag..">"
    end
    function FrostznLife.Export(root,format)
        if busy then return nil,"Uma exportação já está em andamento" end
        if typeof(root)~="Instance" then return nil,"Selecione um objeto" end
        if root==game then return nil,"Selecione um modelo ou serviço, em vez do DataModel inteiro" end
        local p=FrostznLife.Public
        local deps=p.Main.GetInitDeps();local env,API=deps.env,deps.API
        if not env.writefile then return nil,"Executor sem writefile" end
        busy=true
        local result,detail
        local ok,err=xpcall(function()
            local stamp=tostring(os.time()).."_"..tostring(math.random(1000,9999))
            local name=root.Name:gsub('[^%w_.%-]','_'):sub(1,72)
            if name=="" then name="Item" end
            local base="FrostznDex/saved/"..stamp.."_"..name
            if root:IsA("LuaSourceContainer") and format~="rbxmx" then
                local readable,source=pcall(function()return root.Source end)
                if readable and type(source)=="string" and source~="" then
                    env.writefile(base..".lua",source)
                    if env.readfile then assert(env.readfile(base..".lua")==source,"Arquivo .lua não foi confirmado no destino") end
                    result=base..".lua";detail={instances=1,source=true};return
                end
            end
            local list,children,ids={root},{},{}
            local cursor=1;local MAX_INSTANCES=12000
            while cursor<=#list do
                local object=list[cursor];ids[object]="RBX"..cursor
                local good,items=pcall(object.GetChildren,object);items=good and items or {}
                children[object]={}
                for _,child in ipairs(items) do
                    if not FrostznLife.Owned(child) then
                        if #list>=MAX_INSTANCES then error("Limite de 12 mil objetos: selecione uma subpasta menor") end
                        list[#list+1]=child;children[object][#children[object]+1]=child
                    end
                    FrostznLife.Yield()
                end
                cursor+=1;FrostznLife.Yield()
            end
            local report={format="Roblox XML model",path=root:GetFullName(),clientOnly=true,instances=#list,properties=0,unreadable=0,unsupported={},scriptsUnavailable={},attributes={},tags={},externalReferences=0,
                notes={"Somente conteúdo acessível no cliente.","Scripts são exportados desativados por segurança de importação.","IDs de meshes, texturas e sons preservados como referências; arquivos privados/servidor e dados binários internos não são recuperados.","Atributos e tags constam neste relatório; não são aplicados automaticamente ao XML."}}
            local chunks={'<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4"><External>null</External><External>nil</External>'}
            local collection=game:GetService("CollectionService")
            local function encode(object)
                chunks[#chunks+1]='<Item class="'..xml(object.ClassName)..'" referent="'..ids[object]..'"><Properties>'
                local properties=API.GetMember(object.ClassName,"Properties") or {}
                local seen={}
                for _,prop in ipairs(properties) do
                    local key=prop.Name
                    if not seen[key] and key~="Parent" and key~="ClassName" and key~="Attributes" and key~="AttributesSerialize" and key~="Tags" and key~="UniqueId" and key~="HistoryId" and key~="ScriptGuid" then
                        seen[key]=true
                        local serial=prop.Serialization
                        if serial==nil or serial.CanLoad~=false or key=="Source" then
                            local good,value=pcall(function()return object[key] end)
                            if object:IsA("BaseScript") and key=="Disabled" then good=true;value=true end
                            if object:IsA("BaseScript") and key=="Enabled" then good=true;value=false end
                            if key=="Source" and (not good or value=="") then report.scriptsUnavailable[#report.scriptsUnavailable+1]=object:GetFullName() end
                            if good then
                                if typeof(value)=="Instance" and not ids[value] then report.externalReferences+=1 end
                                local encoded=property(key,value,prop.ValueType and prop.ValueType.Name,ids)
                                if encoded then chunks[#chunks+1]=encoded;report.properties+=1 else report.unsupported[typeof(value)]=(report.unsupported[typeof(value)] or 0)+1 end
                            else report.unreadable+=1 end
                        end
                    end
                    FrostznLife.Yield()
                end
                if not seen.Name then chunks[#chunks+1]=property("Name",object.Name,"string",ids) end
                local attributes=object:GetAttributes();local attr={}
                for k,v in pairs(attributes) do attr[k]={type=typeof(v),value=tostring(v)} end
                if next(attr) then report.attributes[ids[object]]=attr end
                local tags=collection:GetTags(object);if #tags>0 then report.tags[ids[object]]=tags end
                chunks[#chunks+1]="</Properties>"
                for _,child in ipairs(children[object]) do encode(child) end
                chunks[#chunks+1]="</Item>";FrostznLife.Yield()
            end
            -- encode utiliza apenas os filhos da fotografia; profundidade limitada abaixo.
            local depth,maxDepth={[root]=1},1
            for _,obj in ipairs(list) do for _,child in ipairs(children[obj]) do depth[child]=depth[obj]+1;maxDepth=math.max(maxDepth,depth[child]) end end
            if maxDepth>180 then error("Hierarquia muito profunda: selecione uma subpasta") end
            encode(root);chunks[#chunks+1]="</roblox>"
            local payload=table.concat(chunks)
            env.writefile(base..".rbxmx",payload)
            if env.readfile then assert(env.readfile(base..".rbxmx")==payload,"Arquivo .rbxmx não foi confirmado no destino") end
            env.writefile(base..".report.json",deps.service.HttpService:JSONEncode(report))
            result=base..".rbxmx";detail=report
        end,debug.traceback)
        busy=false
        if not ok then FrostznLife.Status("Exportação falhou • "..tostring(err):sub(1,110));return nil,tostring(err) end
        FrostznLife.LastExport={path=result,report=detail}
        FrostznLife.Status("Salvo • "..result)
        return result,detail
    end
end

-- https://github.com/LorekeeperZinnia/Dex

--[[
	Dex
	Created by Moon
	Modified for Infinite Yield

	Dex is a debugging suite designed to help the user debug games and find any potential vulnerabilities.
]]

local nodes = {}
FrostznLife.Nodes=nodes
local selection

local function missing(t, f, fallback)
	if type(f) == t then return f end
	return fallback
end

local cloneref = missing("function", cloneref, function(...) return ... end)
local service = setmetatable({}, {
	__index = function(self, name)
		self[name] = cloneref(game:GetService(name))
		return self[name]
	end
})

-- prevent environment implosion from references
-- mainly from the executor not having some game properties in their game variable
-- so we gotta use vanilla game
local oldgame = game
local game = workspace.Parent

local EmbeddedModules = {
	Explorer = function()
--[[
	Explorer App Module
	
	The main explorer interface
]]

		-- Common Locals
		local Main,Lib,Apps,Settings -- Main Containers
		local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
		local API,RMD,env,service,plr,create,createSimple -- Main Locals

		local function initDeps(data)
			Main = data.Main
			Lib = data.Lib
			Apps = data.Apps
			Settings = data.Settings

			API = data.API
			RMD = data.RMD
			env = data.env
			service = data.service
			plr = data.plr
			create = data.create
			createSimple = data.createSimple
		end

		local function initAfterMain()
			Explorer = Apps.Explorer
			Properties = Apps.Properties
			ScriptViewer = Apps.ScriptViewer
			Notebook = Apps.Notebook
		end

		local function main()
			local Explorer = {}
			local tree,listEntries,explorerOrders,searchResults,specResults = {},{},{},{},{}
			local expanded
			local entryTemplate,treeFrame,toolBar,descendantAddedCon,descendantRemovingCon,itemChangedCon
			local ffa = game.FindFirstAncestorWhichIsA
			local getDescendants = game.GetDescendants
			local getTextSize = service.TextService.GetTextSize
			local dirtyParents={}
			local updateDebounce,refreshDebounce = false,false
			local nilNode = {Obj = Instance.new("Folder")}
			local idCounter = 0
			local scrollV,scrollH,clipboard
			local renameBox,renamingNode,searchFunc
			local sortingEnabled,autoUpdateSearch
			local table,math = table,math
			local nilMap,nilCons = {},{}
			local connectSignal = FrostznLife.Connect
			local addObject,removeObject,moveObject = nil,nil,nil

			addObject = function(root)
				if nodes[root] or FrostznLife.Owned(root) then return end

				local isNil = false
				local rootParObj = ffa(root,"Instance")
				local par = nodes[rootParObj]

				-- Nil Handling
				if not par then
					if nilMap[root] then
						nilCons[root] = nilCons[root] or {
							connectSignal(root.ChildAdded,addObject),
							connectSignal(root.AncestryChanged,moveObject),
						}
						par = nilNode
						isNil = true
					else
						return
					end
				elseif nilMap[rootParObj] or par == nilNode then
					nilMap[root] = true
					nilCons[root] = nilCons[root] or {
						connectSignal(root.ChildAdded,addObject),
						connectSignal(root.AncestryChanged,moveObject),
					}
					isNil = true
				end

				local newNode = {Obj = root, Parent = par}
				nodes[root] = newNode

				-- Automatic sorting if expanded
				if sortingEnabled and expanded[par] and par.Sorted then
					local left,right = 1,#par
					local floor = math.floor
					local sorter = Explorer.NodeSorter
					local pos = (right == 0 and 1)

					if not pos then
						while FrostznLife.Alive do
							if left >= right then
								if sorter(newNode,par[left]) then
									pos = left
								else
									pos = left+1
								end
								break
							end

							local mid = floor((left+right)/2)
							if sorter(newNode,par[mid]) then
								right = mid-1
							else
								left = mid+1
							end
						end
					end

					table.insert(par,pos,newNode)
				else
					par[#par+1] = newNode
					par.Sorted = nil
				end

				local insts = FrostznLife.Descendants(root)
				for i = 1,#insts do
					local obj = insts[i]
					if nodes[obj] then continue end -- Deferred

					local par = nodes[ffa(obj,"Instance")]
					if not par then continue end
					local newNode = {Obj = obj, Parent = par}
					nodes[obj] = newNode
					par[#par+1] = newNode

					-- Nil Handling
					if isNil then
						nilMap[obj] = true
						nilCons[obj] = nilCons[obj] or {
							connectSignal(obj.ChildAdded,addObject),
							connectSignal(obj.AncestryChanged,moveObject),
						}
					end
				end

				if searchFunc and autoUpdateSearch then
					searchFunc({newNode})
				end

				if not updateDebounce and Explorer.IsNodeVisible(par) then
					if expanded[par] then
						Explorer.PerformUpdate()
					elseif not refreshDebounce then
						Explorer.PerformRefresh()
					end
				end
			end

			removeObject = function(root)
				local node = nodes[root]
				if not node then return end

				-- Nil Handling
				if nilMap[node.Obj] then
					moveObject(node.Obj)
					return
				end

				local par = node.Parent
				if par then
					par.HasDel = true;dirtyParents[par]=true
				end

				local function recur(root)
					for i = 1,#root do
						local node = root[i]
						if not node.Del then
							nodes[node.Obj] = nil
							if #node > 0 then recur(node) end
						end
					end
				end
				recur(node)
				node.Del = true
				nodes[root] = nil

				if par and not updateDebounce and Explorer.IsNodeVisible(par) then
					if expanded[par] then
						Explorer.PerformUpdate()
					elseif not refreshDebounce then
						Explorer.PerformRefresh()
					end
				end
			end

			moveObject = function(obj)
				local node = nodes[obj]
				if not node then return end

				local oldPar = node.Parent
				local newPar = nodes[ffa(obj,"Instance")]
				if oldPar == newPar then return end

				-- Nil Handling
				if not newPar then
					if nilMap[obj] then
						newPar = nilNode
					else
						return
					end
				elseif nilMap[newPar.Obj] or newPar == nilNode then
					nilMap[obj] = true
					nilCons[obj] = nilCons[obj] or {
						connectSignal(obj.ChildAdded,addObject),
						connectSignal(obj.AncestryChanged,moveObject),
					}
				end

				if oldPar then
					local parPos = table.find(oldPar,node)
					if parPos then table.remove(oldPar,parPos) end
				end

				node.Id = nil
				node.Parent = newPar

				if sortingEnabled and expanded[newPar] and newPar.Sorted then
					local left,right = 1,#newPar
					local floor = math.floor
					local sorter = Explorer.NodeSorter
					local pos = (right == 0 and 1)

					if not pos then
						while FrostznLife.Alive do
							if left >= right then
								if sorter(node,newPar[left]) then
									pos = left
								else
									pos = left+1
								end
								break
							end

							local mid = floor((left+right)/2)
							if sorter(node,newPar[mid]) then
								right = mid-1
							else
								left = mid+1
							end
						end
					end

					table.insert(newPar,pos,node)
				else
					newPar[#newPar+1] = node
					newPar.Sorted = nil
				end

				if searchFunc and searchResults[node] then
					local currentNode = node.Parent
					while currentNode and (not searchResults[currentNode] or expanded[currentNode] == 0) do
						expanded[currentNode] = true
						searchResults[currentNode] = true
						currentNode = currentNode.Parent
					end
				end

				if not updateDebounce and (Explorer.IsNodeVisible(newPar) or Explorer.IsNodeVisible(oldPar)) then
					if expanded[newPar] or expanded[oldPar] then
						Explorer.PerformUpdate()
					elseif not refreshDebounce then
						Explorer.PerformRefresh()
					end
				end
			end

			Explorer.ViewWidth = 0
			Explorer.Index = 0
			Explorer.EntryIndent = 20
			Explorer.FreeWidth = 32
			Explorer.GuiElems = {}

			Explorer.InitRenameBox = function()
				renameBox = create({{1,"TextBox",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderColor3=Color3.new(0.062745101749897,0.51764708757401,1),BorderMode=2,ClearTextOnFocus=false,Font=3,Name="RenameBox",PlaceholderColor3=Color3.new(0.69803923368454,0.69803923368454,0.69803923368454),Position=UDim2.new(0,26,0,2),Size=UDim2.new(0,200,0,16),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,Visible=false,ZIndex=2}}})

				renameBox.Parent = Explorer.Window.GuiElems.Content.List

				FrostznLife.Connect(renameBox.FocusLost,function()
					if not renamingNode then return end

					pcall(function() renamingNode.Obj.Name = renameBox.Text end)
					renamingNode = nil
					Explorer.Refresh()
				end)

				FrostznLife.Connect(renameBox.Focused,function()
					renameBox.SelectionStart = 1
					renameBox.CursorPosition = #renameBox.Text + 1
				end)
			end

			Explorer.SetRenamingNode = function(node)
				renamingNode = node
				renameBox.Text = tostring(node.Obj)
				renameBox:CaptureFocus()
				Explorer.Refresh()
			end

			Explorer.SetSortingEnabled = function(val)
				sortingEnabled = val
				Settings.Explorer.Sorting = val
			end

			Explorer.UpdateView = function()
				local maxNodes = math.ceil(treeFrame.AbsoluteSize.Y / 20)
				local maxX = treeFrame.AbsoluteSize.X
				local totalWidth = Explorer.ViewWidth + Explorer.FreeWidth

				scrollV.VisibleSpace = maxNodes
				scrollV.TotalSpace = #tree + 1
				scrollH.VisibleSpace = maxX
				scrollH.TotalSpace = totalWidth

				scrollV.Gui.Visible = #tree + 1 > maxNodes
				scrollH.Gui.Visible = totalWidth > maxX

				local oldSize = treeFrame.Size
				treeFrame.Size = UDim2.new(1,(scrollV.Gui.Visible and -16 or 0),1,(scrollH.Gui.Visible and -39 or -23))
				if oldSize ~= treeFrame.Size then
					Explorer.UpdateView()
				else
					scrollV:Update()
					scrollH:Update()

					renameBox.Size = UDim2.new(0,maxX-100,0,16)

					if scrollV.Gui.Visible and scrollH.Gui.Visible then
						scrollV.Gui.Size = UDim2.new(0,16,1,-39)
						scrollH.Gui.Size = UDim2.new(1,-16,0,16)
						Explorer.Window.GuiElems.Content.ScrollCorner.Visible = true
					else
						scrollV.Gui.Size = UDim2.new(0,16,1,-23)
						scrollH.Gui.Size = UDim2.new(1,0,0,16)
						Explorer.Window.GuiElems.Content.ScrollCorner.Visible = false
					end

					Explorer.Index = scrollV.Index
				end
			end

			Explorer.NodeSorter = function(a,b)
				if a.Del or b.Del then return false end -- Ghost node

				local aClass = a.Class
				local bClass = b.Class
				if not aClass then aClass = a.Obj.ClassName a.Class = aClass end
				if not bClass then bClass = b.Obj.ClassName b.Class = bClass end

				local aOrder = explorerOrders[aClass]
				local bOrder = explorerOrders[bClass]
				if not aOrder then aOrder = RMD.Classes[aClass] and tonumber(RMD.Classes[aClass].ExplorerOrder) or 9999 explorerOrders[aClass] = aOrder end
				if not bOrder then bOrder = RMD.Classes[bClass] and tonumber(RMD.Classes[bClass].ExplorerOrder) or 9999 explorerOrders[bClass] = bOrder end

				if aOrder ~= bOrder then
					return aOrder < bOrder
				else
					local aName,bName = tostring(a.Obj),tostring(b.Obj)
					if aName ~= bName then
						return aName < bName
					elseif aClass ~= bClass then
						return aClass < bClass
					else
						local aId = a.Id if not aId then aId = idCounter idCounter = (idCounter+0.001)%999999999 a.Id = aId end
						local bId = b.Id if not bId then bId = idCounter idCounter = (idCounter+0.001)%999999999 b.Id = bId end
						return aId < bId
					end
				end
			end

			Explorer.Update = function()
				table.clear(tree)
				local maxNameWidth,maxDepth,count = 0,1,1
				local nameCache = {}
				local font = Enum.Font.SourceSans
				local size = Vector2.new(math.huge,20)
				local useNameWidth = Settings.Explorer.UseNameWidth
				local tSort = table.sort
				local sortFunc = Explorer.NodeSorter
				local isSearching = (expanded == Explorer.SearchExpanded)
				local textServ = service.TextService

				local function recur(root,depth)
					if depth > maxDepth then maxDepth = depth end
					depth = depth + 1
					if sortingEnabled and not root.Sorted then
						tSort(root,sortFunc)
						root.Sorted = true
					end
					for i = 1,#root do
						local n = root[i]

						if (isSearching and not searchResults[n]) or n.Del then continue end

						if useNameWidth then
							local nameWidth = n.NameWidth
							if not nameWidth then
								local objName = tostring(n.Obj)
								nameWidth = nameCache[objName]
								if not nameWidth then
									nameWidth = getTextSize(textServ,objName,14,font,size).X
									nameCache[objName] = nameWidth
								end
								n.NameWidth = nameWidth
							end
							if nameWidth > maxNameWidth then
								maxNameWidth = nameWidth
							end
						end

						tree[count] = n
						count = count + 1
						if expanded[n] and #n > 0 then
							recur(n,depth)
						end
					end
				end

				recur(nodes[game],1)

				-- Nil Instances
				if env.getnilinstances then
					if not (isSearching and not searchResults[nilNode]) then
						tree[count] = nilNode
						count = count + 1
						if expanded[nilNode] then
							recur(nilNode,2)
						end
					end
				end

				Explorer.MaxNameWidth = maxNameWidth
				Explorer.MaxDepth = maxDepth
				Explorer.ViewWidth = useNameWidth and Explorer.EntryIndent*maxDepth + maxNameWidth + 26 or Explorer.EntryIndent*maxDepth + 226
				Explorer.UpdateView()
			end

			Explorer.StartDrag = function(offX,offY)
				if Explorer.Dragging then return end
				for i,v in next, selection.List do
					local Obj = v.Obj
					if Obj.Parent == game or Obj:IsA("Player") then
						return
					end
				end
				Explorer.Dragging = true

				local dragTree = treeFrame:Clone()
				dragTree:ClearAllChildren()

				for i,v in pairs(listEntries) do
					local node = tree[i + Explorer.Index]
					if node and selection.Map[node] then
						local clone = v:Clone()
						clone.Active = false
						clone.Indent.Expand.Visible = false
						clone.Parent = dragTree
					end
				end

				local newGui = Instance.new("ScreenGui")
				newGui.DisplayOrder = Main.DisplayOrders.Menu
				dragTree.Parent = newGui
				Lib.ShowGui(newGui)

				local dragOutline = create({
					{1,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="DragSelect",Size=UDim2.new(1,0,1,0),}},
					{2,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Size=UDim2.new(1,0,0,1),ZIndex=2,}},
					{3,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),ZIndex=2,}},
					{4,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Size=UDim2.new(0,1,1,0),ZIndex=2,}},
					{5,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0),ZIndex=2,}},
				})
				dragOutline.Parent = treeFrame

				local mouse = Main.Mouse or service.Players.LocalPlayer:GetMouse()
				local function move()
					local posX = mouse.X - offX
					local posY = mouse.Y - offY
					dragTree.Position = UDim2.new(0,posX,0,posY)

					for i = 1,#listEntries do
						local entry = listEntries[i]
						if Lib.CheckMouseInGui(entry) then
							dragOutline.Position = UDim2.new(0,entry.Indent.Position.X.Offset-scrollH.Index,0,entry.Position.Y.Offset)
							dragOutline.Size = UDim2.new(0,entry.Size.X.Offset-entry.Indent.Position.X.Offset,0,20)
							dragOutline.Visible = true
							return
						end
					end
					dragOutline.Visible = false
				end
				move()

				local input = service.UserInputService
				local mouseEvent,releaseEvent

				mouseEvent = FrostznLife.Connect(input.InputChanged,function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						move()
					end
				end)

				releaseEvent = FrostznLife.Connect(input.InputEnded,function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						releaseEvent:Disconnect()
						mouseEvent:Disconnect()
						newGui:Destroy()
						dragOutline:Destroy()
						Explorer.Dragging = false

						for i = 1,#listEntries do
							if Lib.CheckMouseInGui(listEntries[i]) then
								local node = tree[i + Explorer.Index]
								if node then
									if selection.Map[node] then return end
									local newPar = node.Obj
									local sList = selection.List
									for i = 1,#sList do
										local n = sList[i]
										pcall(function() n.Obj.Parent = newPar end)
									end
									Explorer.ViewNode(sList[1])
								end
								break
							end
						end
					end
				end)
			end

			Explorer.NewListEntry = function(index)
				local newEntry = entryTemplate:Clone()
				newEntry.Position = UDim2.new(0,0,0,20*(index-1))

				local isRenaming = false

				FrostznLife.Connect(newEntry.InputBegan,function(input)
					local node = tree[index + Explorer.Index]
					if not node or selection.Map[node] or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end

					newEntry.Indent.BackgroundColor3 = Settings.Theme.Button
					newEntry.Indent.BorderSizePixel = 0
					newEntry.Indent.BackgroundTransparency = 0
				end)

				FrostznLife.Connect(newEntry.InputEnded,function(input)
					local node = tree[index + Explorer.Index]
					if not node or selection.Map[node] or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end

					newEntry.Indent.BackgroundTransparency = 1
				end)

				FrostznLife.Connect(newEntry.MouseButton1Down,function()

				end)

				FrostznLife.Connect(newEntry.MouseButton1Up,function()

				end)

				FrostznLife.Connect(newEntry.InputBegan,function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						local releaseEvent, mouseEvent

						local mouse = Main.Mouse or plr:GetMouse()
						local startX, startY

						if input.UserInputType == Enum.UserInputType.Touch then
							startX = input.Position.X
							startY = input.Position.Y
						else
							startX = mouse.X
							startY = mouse.Y
						end

						local listOffsetX = startX - treeFrame.AbsolutePosition.X
						local listOffsetY = startY - treeFrame.AbsolutePosition.Y

						releaseEvent = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								releaseEvent:Disconnect()
								mouseEvent:Disconnect()
							end
						end)

						mouseEvent = FrostznLife.Connect(service.UserInputService.InputChanged,function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								local currentX, currentY

								if input.UserInputType == Enum.UserInputType.Touch then
									currentX = input.Position.X
									currentY = input.Position.Y
								else
									currentX = mouse.X
									currentY = mouse.Y
								end

								local deltaX = currentX - startX
								local deltaY = currentY - startY
								local dist = math.sqrt(deltaX^2 + deltaY^2)

								if dist > 5 then
									releaseEvent:Disconnect()
									mouseEvent:Disconnect()
									isRenaming = false
									Explorer.StartDrag(listOffsetX, listOffsetY)
								end
							end
						end)
					end
				end)

				FrostznLife.Connect(newEntry.MouseButton2Down,function()

				end)

				FrostznLife.Connect(newEntry.Indent.Expand.InputBegan,function(input)
					local node = tree[index + Explorer.Index]
					if not node or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end

					if input.UserInputType == Enum.UserInputType.Touch then
						Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse_Over" or "Expand_Over")
					elseif input.UserInputType == Enum.UserInputType.MouseMovement then
						Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse_Over" or "Expand_Over")
					end
				end)

				FrostznLife.Connect(newEntry.Indent.Expand.InputEnded,function(input)
					local node = tree[index + Explorer.Index]
					if not node or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end

					if input.UserInputType == Enum.UserInputType.Touch then
						Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse" or "Expand")
					elseif input.UserInputType == Enum.UserInputType.MouseMovement then
						Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse" or "Expand")
					end
				end)

				FrostznLife.Connect(newEntry.Indent.Expand.MouseButton1Down,function()
					local node = tree[index + Explorer.Index]
					if not node or #node == 0 then return end

					expanded[node] = not expanded[node]
					Explorer.Update()
					Explorer.Refresh()
				end)

				newEntry.Parent = treeFrame
				return newEntry
			end

			Explorer.Refresh = function()
				local maxNodes = math.max(math.ceil((treeFrame.AbsoluteSize.Y) / 20), 0)	
				local renameNodeVisible = false
				local isa = game.IsA

				for i = 1,maxNodes do
					local entry = listEntries[i]
					if not listEntries[i] then entry = Explorer.NewListEntry(i) listEntries[i] = entry Explorer.ClickSystem:Add(entry) end

					local node = tree[i + Explorer.Index]
					if node then
						local obj = node.Obj
						local depth = Explorer.EntryIndent*Explorer.NodeDepth(node)

						entry.Visible = true
						entry.Position = UDim2.new(0,-scrollH.Index,0,entry.Position.Y.Offset)
						entry.Size = UDim2.new(0,Explorer.ViewWidth,0,20)
						entry.Indent.EntryName.Text = tostring(node.Obj)
						entry.Indent.Position = UDim2.new(0,depth,0,0)
						entry.Indent.Size = UDim2.new(1,-depth,1,0)

						entry.Indent.EntryName.TextTruncate = (Settings.Explorer.UseNameWidth and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd)

						Explorer.MiscIcons:DisplayExplorerIcons(entry.Indent.Icon, obj.ClassName)

						if selection.Map[node] then
							entry.Indent.BackgroundColor3 = Settings.Theme.ListSelection
							entry.Indent.BorderSizePixel = 0
							entry.Indent.BackgroundTransparency = 0
						else
							if Lib.CheckMouseInGui(entry) then
								entry.Indent.BackgroundColor3 = Settings.Theme.Button
							else
								entry.Indent.BackgroundTransparency = 1
							end
						end

						if node == renamingNode then
							renameNodeVisible = true
							renameBox.Position = UDim2.new(0,depth+25-scrollH.Index,0,entry.Position.Y.Offset+2)
							renameBox.Visible = true
						end

						if #node > 0 and expanded[node] ~= 0 then
							if Lib.CheckMouseInGui(entry.Indent.Expand) then
								Explorer.MiscIcons:DisplayByKey(entry.Indent.Expand.Icon, expanded[node] and "Collapse_Over" or "Expand_Over")
							else
								Explorer.MiscIcons:DisplayByKey(entry.Indent.Expand.Icon, expanded[node] and "Collapse" or "Expand")
							end
							entry.Indent.Expand.Visible = true
						else
							entry.Indent.Expand.Visible = false
						end
					else
						entry.Visible = false
					end
				end

				if not renameNodeVisible then
					renameBox.Visible = false
				end

				for i = maxNodes+1, #listEntries do
					Explorer.ClickSystem:Remove(listEntries[i])
					listEntries[i]:Destroy()
					listEntries[i] = nil
				end
			end

			Explorer.PerformUpdate = function(instant)
				updateDebounce = true
				Lib.FastWait(not instant and 0.1)
				if not updateDebounce then return end
				updateDebounce = false
				if not Explorer.Window:IsVisible() then return end
				Explorer.Update()
				Explorer.Refresh()
			end

			Explorer.ForceUpdate = function(norefresh)
				updateDebounce = false
				Explorer.Update()
				if not norefresh then Explorer.Refresh() end
			end

			Explorer.PerformRefresh = function()
				refreshDebounce = true
				Lib.FastWait(0.1)
				refreshDebounce = false
				if updateDebounce or not Explorer.Window:IsVisible() then return end
				Explorer.Refresh()
			end

			Explorer.IsNodeVisible = function(node)
				if not node then return end

				local curNode = node.Parent
				while curNode do
					if not expanded[curNode] then return false end
					curNode = curNode.Parent
				end
				return true
			end

			Explorer.NodeDepth = function(node)
				local depth = 0

				if node == nilNode then
					return 1
				end

				local curNode = node.Parent
				while curNode do
					if curNode == nilNode then depth = depth + 1 end
					curNode = curNode.Parent
					depth = depth + 1
				end
				return depth
			end

			Explorer.SetupConnections = function()
				if descendantAddedCon then descendantAddedCon:Disconnect() end
				if descendantRemovingCon then descendantRemovingCon:Disconnect() end
				if itemChangedCon then itemChangedCon:Disconnect() end

				if Main.Elevated then
					descendantAddedCon = FrostznLife.Connect(game.DescendantAdded,addObject)
					descendantRemovingCon = FrostznLife.Connect(game.DescendantRemoving,removeObject)
				else
					descendantAddedCon = FrostznLife.Connect(game.DescendantAdded,function(obj) pcall(addObject,obj) end)
					descendantRemovingCon = FrostznLife.Connect(game.DescendantRemoving,function(obj) pcall(removeObject,obj) end)
				end

				if Settings.Explorer.UseNameWidth then
					itemChangedCon = FrostznLife.Connect(game.ItemChanged,function(obj,prop)
						if prop == "Parent" and nodes[obj] then
							moveObject(obj)
						elseif prop == "Name" and nodes[obj] then
							nodes[obj].NameWidth = nil
						end
					end)
				else
					itemChangedCon = FrostznLife.Connect(game.ItemChanged,function(obj,prop)
						if prop == "Parent" and nodes[obj] then
							moveObject(obj)
						end
					end)
				end
			end

			Explorer.ViewNode = function(node)
				if not node then return end

				Explorer.MakeNodeVisible(node)
				Explorer.ForceUpdate(true)
				local visibleSpace = scrollV.VisibleSpace

				for i,v in next,tree do
					if v == node then
						local relative = i - 1
						if Explorer.Index > relative then
							scrollV.Index = relative
						elseif Explorer.Index + visibleSpace - 1 <= relative then
							scrollV.Index = relative - visibleSpace + 2
						end
					end
				end

				scrollV:Update() Explorer.Index = scrollV.Index
				Explorer.Refresh()
			end

			Explorer.ViewObj = function(obj)
				Explorer.ViewNode(nodes[obj])
			end

			Explorer.MakeNodeVisible = function(node,expandRoot)
				if not node then return end

				local hasExpanded = false

				if expandRoot and not expanded[node] then
					expanded[node] = true
					hasExpanded = true
				end

				local currentNode = node.Parent
				while currentNode do
					hasExpanded = true
					expanded[currentNode] = true
					currentNode = currentNode.Parent
				end

				if hasExpanded and not updateDebounce then
					FrostznLife.Wrap(Explorer.PerformUpdate)(true)
				end
			end

			Explorer.ShowRightClick = function(MousePos)
				local Mouse = MousePos or Main.Mouse
				local context = Explorer.RightClickContext
				local absoluteSize = context.Gui.AbsoluteSize
				context.MaxHeight = (absoluteSize.Y <= 600 and (absoluteSize.Y - 40)) or nil
				context:Clear()

				local sList = selection.List
				local sMap = selection.Map
				local emptyClipboard = #clipboard == 0
				local presentClasses = {}
				local apiClasses = API.Classes

				for i = 1, #sList do
					local node = sList[i]
					local class = node.Class
					local obj = node.Obj

					if not presentClasses.isViableDecompileScript then
						presentClasses.isViableDecompileScript = env.isViableDecompileScript(obj)
					end
					if not class then
						class = obj.ClassName
						node.Class = class
					end

					local curClass = apiClasses[class]
					while curClass and not presentClasses[curClass.Name] do
						presentClasses[curClass.Name] = true
						curClass = curClass.Superclass
					end
				end

				context:AddRegistered("CUT")
				context:AddRegistered("COPY")
				context:AddRegistered("PASTE", emptyClipboard)
				context:AddRegistered("DUPLICATE")
				context:AddRegistered("DELETE")
				context:AddRegistered("RENAME", #sList ~= 1)

				context:AddDivider()
				context:AddRegistered("GROUP")
				context:AddRegistered("UNGROUP")
				context:AddRegistered("SELECT_CHILDREN")
				context:AddRegistered("JUMP_TO_PARENT")
				context:AddRegistered("EXPAND_ALL")
				context:AddRegistered("COLLAPSE_ALL")

				context:AddDivider()

				if expanded == Explorer.SearchExpanded then context:AddRegistered("CLEAR_SEARCH_AND_JUMP_TO") end
				if env.setclipboard then context:AddRegistered("COPY_PATH") end
				context:AddRegistered("INSERT_OBJECT")
                context:AddRegistered("FROSTZN_DOWNLOAD",env.writefile==nil)
                if FrostznLife.ViewTarget then context:AddRegistered("FROSTZN_STOP_VIEW") end
				-- context:AddRegistered("SAVE_INST")
				-- context:AddRegistered("CALL_FUNCTION")
				-- context:AddRegistered("VIEW_CONNECTIONS")
				-- context:AddRegistered("GET_REFERENCES")
				-- context:AddRegistered("VIEW_API")

				context:QueueDivider()

				if presentClasses["BasePart"] or presentClasses["Model"] then
					context:AddRegistered("TELEPORT_TO")
					context:AddRegistered("VIEW_OBJECT")
				end
				if presentClasses["Tween"] then context:AddRegistered("PLAY_TWEEN") end
				if presentClasses["Animation"] then
					context:AddRegistered("LOAD_ANIMATION")
					context:AddRegistered("STOP_ANIMATION")
				end

				if presentClasses["TouchTransmitter"] then context:AddRegistered("FIRE_TOUCHTRANSMITTER", firetouchinterest == nil) end
				if presentClasses["ClickDetector"] then context:AddRegistered("FIRE_CLICKDETECTOR", fireclickdetector == nil) end
				if presentClasses["ProximityPrompt"] then context:AddRegistered("FIRE_PROXIMITYPROMPT", fireproximityprompt == nil) end

				if presentClasses["Player"] then context:AddRegistered("SELECT_CHARACTER")context:AddRegistered("VIEW_PLAYER") end
				if presentClasses["Players"] then
					context:AddRegistered("SELECT_LOCAL_PLAYER")
					context:AddRegistered("SELECT_ALL_CHARACTERS")
				end

				if presentClasses["LuaSourceContainer"] then
					context:AddRegistered("VIEW_SCRIPT")
					context:AddRegistered("SAVE_SCRIPT", not presentClasses.isViableDecompileScript or env.decompile == nil or env.writefile == nil)
					context:AddRegistered("SAVE_BYTECODE", not presentClasses.isViableDecompileScript or env.getscriptbytecode == nil or env.writefile == nil)
				end

				if sMap[nilNode] then
					context:AddRegistered("REFRESH_NIL")
					context:AddRegistered("HIDE_NIL")
				end

				Explorer.LastRightClickX, Explorer.LastRightClickY = Mouse.X, Mouse.Y
				context:Show(Mouse.X, Mouse.Y)
			end

			Explorer.InitRightClick = function()
				local context = Lib.ContextMenu.new()

				context:Register("CUT",{Name = "Cut", IconMap = Explorer.MiscIcons, Icon = "Cut", DisabledIcon = "Cut_Disabled", Shortcut = "Ctrl+Z", OnClick = function()
					local destroy,clone = game.Destroy,game.Clone
					local sList,newClipboard = selection.List,{}
					local count = 1
					for i = 1,#sList do
						local inst = sList[i].Obj
						local s,cloned = pcall(clone,inst)
						if s and cloned then
							newClipboard[count] = cloned
							count = count + 1
						end
						pcall(destroy,inst)
					end
					clipboard = newClipboard
					selection:Clear()
				end})

				context:Register("COPY",{Name = "Copy", IconMap = Explorer.MiscIcons, Icon = "Copy", DisabledIcon = "Copy_Disabled", Shortcut = "Ctrl+C", OnClick = function()
					local clone = game.Clone
					local sList,newClipboard = selection.List,{}
					local count = 1
					for i = 1,#sList do
						local inst = sList[i].Obj
						local s,cloned = pcall(clone,inst)
						if s and cloned then
							newClipboard[count] = cloned
							count = count + 1
						end
					end
					clipboard = newClipboard
				end})

				context:Register("PASTE",{Name = "Paste Into", IconMap = Explorer.MiscIcons, Icon = "Paste", DisabledIcon = "Paste_Disabled", Shortcut = "Ctrl+Shift+V", OnClick = function()
					local sList = selection.List
					local newSelection = {}
					local count = 1
					for i = 1,#sList do
						local node = sList[i]
						local inst = node.Obj
						Explorer.MakeNodeVisible(node,true)
						for c = 1,#clipboard do
							local cloned = clipboard[c]:Clone()
							if cloned then
								cloned.Parent = inst
								local clonedNode = nodes[cloned]
								if clonedNode then newSelection[count] = clonedNode count = count + 1 end
							end
						end
					end
					selection:SetTable(newSelection)

					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					end
				end})

				context:Register("DUPLICATE",{Name = "Duplicate", IconMap = Explorer.MiscIcons, Icon = "Copy", DisabledIcon = "Copy_Disabled", Shortcut = "Ctrl+D", OnClick = function()
					local clone = game.Clone
					local sList = selection.List
					local newSelection = {}
					local count = 1
					for i = 1,#sList do
						local node = sList[i]
						local inst = node.Obj
						local instPar = node.Parent and node.Parent.Obj
						Explorer.MakeNodeVisible(node)
						local s,cloned = pcall(clone,inst)
						if s and cloned then
							cloned.Parent = instPar
							local clonedNode = nodes[cloned]
							if clonedNode then newSelection[count] = clonedNode count = count + 1 end
						end
					end

					selection:SetTable(newSelection)
					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					end
				end})

				context:Register("DELETE",{Name = "Delete", IconMap = Explorer.MiscIcons, Icon = "Delete", DisabledIcon = "Delete_Disabled", Shortcut = "Del", OnClick = function()
					local destroy = game.Destroy
					local sList = selection.List
					for i = 1,#sList do
						pcall(destroy,sList[i].Obj)
					end
					selection:Clear()
				end})

				context:Register("RENAME",{Name = "Rename", IconMap = Explorer.MiscIcons, Icon = "Rename", DisabledIcon = "Rename_Disabled", Shortcut = "F2", OnClick = function()
					local sList = selection.List
					if sList[1] then
						Explorer.SetRenamingNode(sList[1])
					end
				end})

				context:Register("GROUP",{Name = "Group", IconMap = Explorer.MiscIcons, Icon = "Group", DisabledIcon = "Group_Disabled", Shortcut = "Ctrl+G", OnClick = function()
					local sList = selection.List
					if #sList == 0 then return end

					local model = Instance.new("Model",sList[#sList].Obj.Parent)
					for i = 1,#sList do
						pcall(function() sList[i].Obj.Parent = model end)
					end

					if nodes[model] then
						selection:Set(nodes[model])
						Explorer.ViewNode(nodes[model])
					end
				end})

				context:Register("UNGROUP",{Name = "Ungroup", IconMap = Explorer.MiscIcons, Icon = "Ungroup", DisabledIcon = "Ungroup_Disabled", Shortcut = "Ctrl+U", OnClick = function()
					local newSelection = {}
					local count = 1
					local isa = game.IsA

					local function ungroup(node)
						local par = node.Parent.Obj
						local ch = {}
						local chCount = 1

						for i = 1,#node do
							local n = node[i]
							newSelection[count] = n
							ch[chCount] = n
							count = count + 1
							chCount = chCount + 1
						end

						for i = 1,#ch do
							pcall(function() ch[i].Obj.Parent = par end)
						end

						node.Obj:Destroy()
					end

					for i,v in next,selection.List do
						if isa(v.Obj,"Model") then
							ungroup(v)
						end
					end

					selection:SetTable(newSelection)
					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					end
				end})

				context:Register("SELECT_CHILDREN",{Name = "Select Children", IconMap = Explorer.MiscIcons, Icon = "SelectChildren", DisabledIcon = "SelectChildren_Disabled", OnClick = function()
					local newSelection = {}
					local count = 1
					local sList = selection.List

					for i = 1,#sList do
						local node = sList[i]
						for ind = 1,#node do
							local cNode = node[ind]
							if ind == 1 then Explorer.MakeNodeVisible(cNode) end

							newSelection[count] = cNode
							count = count + 1
						end
					end

					selection:SetTable(newSelection)
					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					else
						Explorer.Refresh()
					end
				end})

				context:Register("JUMP_TO_PARENT",{Name = "Jump to Parent", IconMap = Explorer.MiscIcons, Icon = "JumpToParent", OnClick = function()
					local newSelection = {}
					local count = 1
					local sList = selection.List

					for i = 1,#sList do
						local node = sList[i]
						if node.Parent then
							newSelection[count] = node.Parent
							count = count + 1
						end
					end

					selection:SetTable(newSelection)
					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					else
						Explorer.Refresh()
					end
				end})

				context:Register("TELEPORT_TO",{Name = "Teleport To", IconMap = Explorer.MiscIcons, Icon = "TeleportTo", OnClick = function()
					local sList = selection.List
					local plrRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")

					if not plrRP then return end

					for _,node in next, sList do
						local Obj = node.Obj

						if Obj:IsA("BasePart") then
							if Obj.CanCollide then
								plr.Character:MoveTo(Obj.Position)
							else
								plrRP.CFrame = CFrame.new(Obj.Position + Settings.Explorer.TeleportToOffset)
							end
							break
						elseif Obj:IsA("Model") then
							if Obj.PrimaryPart then
								if Obj.PrimaryPart.CanCollide then
									plr.Character:MoveTo(Obj.PrimaryPart.Position)
								else
									plrRP.CFrame = CFrame.new(Obj.PrimaryPart.Position + Settings.Explorer.TeleportToOffset)
								end
								break
							else
								local part = Obj:FindFirstChildWhichIsA("BasePart", true)
								if part and nodes[part] then
									if part.CanCollide then
										plr.Character:MoveTo(part.Position)
									else
										plrRP.CFrame = CFrame.new(part.Position + Settings.Explorer.TeleportToOffset)
									end
									break
								elseif Obj.WorldPivot then
									plrRP.CFrame = Obj.WorldPivot
								end
							end
						end
					end
				end})

				local OldAnimation
				context:Register("PLAY_TWEEN",{Name = "Play Tween", IconMap = Explorer.MiscIcons, Icon = "Play", OnClick = function()
					local sList = selection.List

					for i = 1, #sList do
						local node = sList[i]
						local Obj = node.Obj

						if Obj:IsA("Tween") then Obj:Play() end
					end
				end})

				local OldAnimation
				context:Register("LOAD_ANIMATION",{Name = "Load Animation", IconMap = Explorer.MiscIcons, Icon = "Play", OnClick = function()
					local sList = selection.List

					local Humanoid = plr.Character and plr.Character:FindFirstChild("Humanoid")
					if not Humanoid then return end

					for i = 1, #sList do
						local node = sList[i]
						local Obj = node.Obj

						if Obj:IsA("Animation") then
							if OldAnimation then OldAnimation:Stop() end
							OldAnimation = Humanoid:LoadAnimation(Obj)
							OldAnimation:Play()
							break
						end
					end
				end})

				context:Register("STOP_ANIMATION",{Name = "Stop Animation", IconMap = Explorer.MiscIcons, Icon = "Pause", OnClick = function()
					local sList = selection.List

					local Humanoid = plr.Character and plr.Character:FindFirstChild("Humanoid")
					if not Humanoid then return end

					for i = 1, #sList do
						local node = sList[i]
						local Obj = node.Obj

						if Obj:IsA("Animation") then
							if OldAnimation then OldAnimation:Stop() end
							Humanoid:LoadAnimation(Obj):Stop()
							break
						end
					end
				end})

				context:Register("EXPAND_ALL",{Name = "Expand All", OnClick = function()
					local sList = selection.List

					local function expand(node)
						expanded[node] = true
						for i = 1,#node do
							if #node[i] > 0 then
								expand(node[i])
							end
						end
					end

					for i = 1,#sList do
						expand(sList[i])
					end

					Explorer.ForceUpdate()
				end})

				context:Register("COLLAPSE_ALL",{Name = "Collapse All", OnClick = function()
					local sList = selection.List

					local function expand(node)
						expanded[node] = nil
						for i = 1,#node do
							if #node[i] > 0 then
								expand(node[i])
							end
						end
					end

					for i = 1,#sList do
						expand(sList[i])
					end

					Explorer.ForceUpdate()
				end})

				context:Register("CLEAR_SEARCH_AND_JUMP_TO",{Name = "Clear Search and Jump to", OnClick = function()
					local newSelection = {}
					local count = 1
					local sList = selection.List

					for i = 1,#sList do
						newSelection[count] = sList[i]
						count = count + 1
					end

					selection:SetTable(newSelection)
					Explorer.ClearSearch()
					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					end
				end})

				-- this code is very bad but im lazy and it works so cope
				local clth = function(str)
					if str:sub(1, 28) == "game:GetService(\"Workspace\")" then str = str:gsub("game:GetService%(\"Workspace\"%)", "workspace", 1) end
					if str:sub(1, 27 + #plr.Name) == "game:GetService(\"Players\")." .. plr.Name then str = str:gsub("game:GetService%(\"Players\"%)." .. plr.Name, "game:GetService(\"Players\").LocalPlayer", 1) end
					return str
				end

				context:Register("COPY_PATH",{Name = "Copy Path", IconMap = Explorer.ClassIcons, Icon = 50, OnClick = function()
					local sList = selection.List
					if #sList == 1 then
						env.setclipboard(clth(Explorer.GetInstancePath(sList[1].Obj)))
					elseif #sList > 1 then
						local resList = {"{"}
						local count = 2
						for i = 1,#sList do
							local path = "\t"..clth(Explorer.GetInstancePath(sList[i].Obj))..","
							if #path > 0 then
								resList[count] = path
								count = count+1
							end
						end
						resList[count] = "}"
						env.setclipboard(table.concat(resList,"\n"))
					end
				end})

				context:Register("INSERT_OBJECT",{Name = "Insert Object", IconMap = Explorer.MiscIcons, Icon = "InsertObject", OnClick = function()
					local mouse = Main.Mouse
					local x,y = Explorer.LastRightClickX or mouse.X, Explorer.LastRightClickY or mouse.Y
					Explorer.InsertObjectContext:Show(x,y)
				end})

				--[[context:Register("CALL_FUNCTION",{Name = "Call Function", IconMap = Explorer.ClassIcons, Icon = 66, OnClick = function()

				end})

				context:Register("GET_REFERENCES",{Name = "Get Lua References", IconMap = Explorer.ClassIcons, Icon = 34, OnClick = function()

				end})

				context:Register("SAVE_INST",{Name = "Save to File", IconMap = Explorer.MiscIcons, Icon = "Save", OnClick = function()

				end})

                context:Register("VIEW_CONNECTIONS",{Name = "View Connections", OnClick = function()
                    
                end})

				context:Register("VIEW_API",{Name = "View API Page", IconMap = Explorer.MiscIcons, Icon = "Reference", OnClick = function()

				end})]]

                context:Register("FROSTZN_DOWNLOAD",{Name="Baixar item...",IconMap=Explorer.MiscIcons,Icon="Save",OnClick=function()
                    FrostznLife.OpenExport()
                end})
                context:Register("FROSTZN_STOP_VIEW",{Name="Sair da observação",Shortcut="F7",OnClick=function()FrostznLife.RestoreCamera()end})
                context:Register("VIEW_OBJECT",{Name="Observar objeto",IconMap=Explorer.ClassIcons,Icon=5,OnClick=function()
                    for _,node in ipairs(selection.List) do if node.Obj:IsA("BasePart") or node.Obj:IsA("Model") then FrostznLife.View(node.Obj);break end end
                end,OnRightClick=function()FrostznLife.RestoreCamera()end})

				context:Register("FIRE_TOUCHTRANSMITTER",{Name = "Fire TouchTransmitter", IconMap = Explorer.ClassIcons, Icon = 37, OnClick = function()
					local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if not hrp then return end
					for _, v in ipairs(selection.List) do if v.Obj and v.Obj:IsA("TouchTransmitter") then firetouchinterest(hrp, v.Obj.Parent, 0) end end
				end})

				context:Register("FIRE_CLICKDETECTOR",{Name = "Fire ClickDetector", IconMap = Explorer.ClassIcons, Icon = 41, OnClick = function()
					local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if not hrp then return end
					for _, v in ipairs(selection.List) do if v.Obj and v.Obj:IsA("ClickDetector") then fireclickdetector(v.Obj) end end
				end})

				context:Register("FIRE_PROXIMITYPROMPT",{Name = "Fire ProximityPrompt", IconMap = Explorer.ClassIcons, Icon = 124, OnClick = function()
					local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if not hrp then return end
					for _, v in ipairs(selection.List) do if v.Obj and v.Obj:IsA("ProximityPrompt") then fireproximityprompt(v.Obj) end end
				end})

				context:Register("VIEW_SCRIPT",{Name = "View Script", IconMap = Explorer.MiscIcons, Icon = "ViewScript", OnClick = function()
					local scr = selection.List[1] and selection.List[1].Obj
					if scr then ScriptViewer.ViewScript(scr) end
				end})

				context:Register("SAVE_SCRIPT",{Name = "Save Script", IconMap = Explorer.MiscIcons, Icon = "Save", OnClick = function()
					for _, v in next, selection.List do
						if v.Obj:IsA("LuaSourceContainer") and env.isViableDecompileScript(v.Obj) then
							local success, source = pcall(env.decompile, v.Obj)
							if not success or not source then source = ("-- DEX - %s failed to decompile %s"):format(env.executor, v.Obj.ClassName) end
							local fileName = ("%i.%s.%s.Source.txt"):format(game.PlaceId, v.Obj.ClassName, env.parsefile(v.Obj.Name))
							env.writefile(fileName, source)
							task.wait(0.2)
						end
					end
				end})

				context:Register("SAVE_BYTECODE",{Name = "Save Script Bytecode", IconMap = Explorer.MiscIcons, Icon = "Save", OnClick = function()
					for _, v in next, selection.List do
						if v.Obj:IsA("LuaSourceContainer") and env.isViableDecompileScript(v.Obj) then
							local success, bytecode = pcall(getscriptbytecode, v.Obj)
							if success and type(bytecode) == "string" then
								local fileName = ("%i.%s.%s.Bytecode.txt"):format(game.PlaceId, v.Obj.ClassName, env.parsefile(v.Obj.Name))
								env.writefile(fileName, bytecode)
								task.wait(0.2)
							end
						end
					end
				end})

				context:Register("SELECT_CHARACTER",{Name = "Select Character", IconMap = Explorer.ClassIcons, Icon = 9, OnClick = function()
					local newSelection = {}
					local count = 1
					local sList = selection.List
					local isa = game.IsA

					for i = 1,#sList do
						local node = sList[i]
						if isa(node.Obj,"Player") and nodes[node.Obj.Character] then
							newSelection[count] = nodes[node.Obj.Character]
							count = count + 1
						end
					end

					selection:SetTable(newSelection)
					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					else
						Explorer.Refresh()
					end
				end})

                context:Register("VIEW_PLAYER",{Name="Observar jogador",IconMap=Explorer.ClassIcons,Icon=5,OnClick=function()
                    for _,node in ipairs(selection.List) do if node.Obj:IsA("Player") then FrostznLife.View(node.Obj);break end end
                end})

				context:Register("SELECT_LOCAL_PLAYER",{Name = "Select Local Player", IconMap = Explorer.ClassIcons, Icon = 9, OnClick = function()
					pcall(function() if nodes[plr] then selection:Set(nodes[plr]) Explorer.ViewNode(nodes[plr]) end end)
				end})

				context:Register("SELECT_ALL_CHARACTERS",{Name = "Select All Characters", IconMap = Explorer.ClassIcons, Icon = 2, OnClick = function()
					local newSelection = {}
					local sList = selection.List

					for i,v in next, service.Players:GetPlayers() do
						if v.Character and nodes[v.Character] then
							if i == 1 then Explorer.MakeNodeVisible(v.Character) end
							table.insert(newSelection, nodes[v.Character])
						end
					end

					selection:SetTable(newSelection)
					if #newSelection > 0 then
						Explorer.ViewNode(newSelection[1])
					else
						Explorer.Refresh()
					end
				end})

				context:Register("REFRESH_NIL",{Name = "Refresh Nil Instances", OnClick = function()
					Explorer.RefreshNilInstances()
				end})

				context:Register("HIDE_NIL",{Name = "Hide Nil Instances", OnClick = function()
					Explorer.HideNilInstances()
				end})

				Explorer.RightClickContext = context
			end

			Explorer.HideNilInstances = function()
				table.clear(nilMap)

				local disconnectCon = FrostznLife.Connect(Instance.new("Folder").ChildAdded,function() end).Disconnect
				for i,v in next,nilCons do
					disconnectCon(v[1])
					disconnectCon(v[2])
				end
				table.clear(nilCons)

				for i = 1,#nilNode do
					FrostznLife.Wrap(removeObject)(nilNode[i].Obj)
				end

				Explorer.Update()
				Explorer.Refresh()
			end

			Explorer.RefreshNilInstances = function()
				if not env.getnilinstances then return end

				local nilInsts = env.getnilinstances()
				local game = game
				local getDescs = game.GetDescendants
				--local newNilMap = {}
				--local newNilRoots = {}
				--local nilRoots = Explorer.NilRoots
				--local connect = game.DescendantAdded.Connect
				--local disconnect
				--if not nilRoots then nilRoots = {} Explorer.NilRoots = nilRoots end

				for i = 1,#nilInsts do
					local obj = nilInsts[i]
					if obj ~= game then
						nilMap[obj] = true
						--newNilRoots[obj] = true

						local descs = getDescs(obj)
						for j = 1,#descs do
							nilMap[descs[j]] = true
						end
					end
				end

				-- Remove unmapped nil nodes
		--[[for i = 1,#nilNode do
			local node = nilNode[i]
			if not newNilMap[node.Obj] then
				nilMap[node.Obj] = nil
				FrostznLife.Wrap(removeObject)(node)
			end
		end]]

				--nilMap = newNilMap

				for i = 1,#nilInsts do
					local obj = nilInsts[i]
					local node = nodes[obj]
					if not node then FrostznLife.Wrap(addObject)(obj) end
				end

		--[[
		-- Remove old root connections
		for obj in next,nilRoots do
			if not newNilRoots[obj] then
				if not disconnect then disconnect = obj[1].Disconnect end
				disconnect(obj[1])
				disconnect(obj[2])
			end
		end
		
		for obj in next,newNilRoots do
			if not nilRoots[obj] then
				nilRoots[obj] = {
					connect(obj.DescendantAdded,addObject),
					connect(obj.DescendantRemoving,removeObject)
				}
			end
		end]]

				--nilMap = newNilMap
				--Explorer.NilRoots = newNilRoots

				Explorer.Update()
				Explorer.Refresh()
			end

			Explorer.GetInstancePath = function(obj)
				local ffc = game.FindFirstChild
				local getCh = game.GetChildren
				local path = ""
				local curObj = obj
				local ts = tostring
				local match = string.match
				local gsub = string.gsub
				local tableFind = table.find
				local useGetCh = Settings.Explorer.CopyPathUseGetChildren
				local formatLuaString = Lib.FormatLuaString

				while curObj do
					if curObj == game then
						path = "game"..path
						break
					end

					local className = curObj.ClassName
					local curName = ts(curObj)
					local indexName
					if match(curName,"^[%a_][%w_]*$") then
						indexName = "."..curName
					else
						local cleanName = formatLuaString(curName)
						indexName = '["'..cleanName..'"]'
					end

					local parObj = curObj.Parent
					if parObj then
						local fc = ffc(parObj,curName)
						if useGetCh and fc and fc ~= curObj then
							local parCh = getCh(parObj)
							local fcInd = tableFind(parCh,curObj)
							indexName = ":GetChildren()["..fcInd.."]"
						elseif parObj == game and API.Classes[className] and API.Classes[className].Tags.Service then
							indexName = ':GetService("'..className..'")'
						end
					elseif parObj == nil then
						local getnil = "local getNil = function(name, class) for _, v in next, getnilinstances() do if v.ClassName == class and v.Name == name then return v end end end"
						local gotnil = "\n\ngetNil(\"%s\", \"%s\")"
						indexName = getnil .. gotnil:format(curObj.Name, className)
					end

					path = indexName..path
					curObj = parObj
				end

				return path
			end

			Explorer.DefaultProps = {
				["BasePart"] = {
					Position = function(Obj)
						local Player = service.Players.LocalPlayer
						if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
							Obj.Position = (Player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10)).p
						end
						return Obj.Position
					end,
					Anchored = true
				},
				["GuiObject"] = {
					Position = function(Obj) return (Obj.Parent:IsA("ScreenGui") and UDim2.new(0.5, 0, 0.5, 0)) or Obj.Position end,
					Active = true
				}
			}

			Explorer.InitInsertObject = function()
				local context = Lib.ContextMenu.new()
				context.SearchEnabled = true
				context.MaxHeight = 400
				context:ApplyTheme({
					ContentColor = Settings.Theme.Main2,
					OutlineColor = Settings.Theme.Outline1,
					DividerColor = Settings.Theme.Outline1,
					TextColor = Settings.Theme.Text,
					HighlightColor = Settings.Theme.ButtonHover
				})

				local classes = {}
				for i,class in next,API.Classes do
					local tags = class.Tags
					if not tags.NotCreatable and not tags.Service then
						local rmdEntry = RMD.Classes[class.Name]
						classes[#classes+1] = {class,rmdEntry and rmdEntry.ClassCategory or "Uncategorized"}
					end
				end
				table.sort(classes,function(a,b)
					if a[2] ~= b[2] then
						return a[2] < b[2]
					else
						return a[1].Name < b[1].Name
					end
				end)

				local function defaultProps(obj)
					for class, props in pairs(Explorer.DefaultProps) do
						if obj:IsA(class) then
							for prop, value in pairs(props) do
								obj[prop] = (type(value) == "function" and value(obj)) or value
							end
						end
					end
				end

				local function onClick(className)
					local sList = selection.List
					local instNew = Instance.new
					for i = 1,#sList do
						local node = sList[i]
						local obj = node.Obj
						Explorer.MakeNodeVisible(node, true)
						local success, obj = pcall(instNew, className, obj)
						if success and obj then defaultProps(obj) end
					end
				end

				local lastCategory = ""
				for i = 1,#classes do
					local class = classes[i][1]
					local rmdEntry = RMD.Classes[class.Name]
					local iconInd = rmdEntry and tonumber(rmdEntry.ExplorerImageIndex) or 0
					local category = classes[i][2]

					if lastCategory ~= category then
						context:AddDivider(category)
						lastCategory = category
					end
					context:Add({Name = class.Name, IconMap = Explorer.ClassIcons, Icon = iconInd, OnClick = onClick})
				end

				Explorer.InsertObjectContext = context
			end

			Explorer._SearchFilters = {} do
				local Filters = Explorer._SearchFilters

				local function NewFilter(list, func)
					for _,v in next, list do
						Filters[v:lower() .. ":"] = func
					end
				end

				local Only = {
					remotes = {"RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction"},
					scripts = {"Script", "LocalScript", "ModuleScript"},
					players = {"Player"}
				}

				NewFilter({"parent", "p"}, function(Obj, str) return Obj.Parent and (Obj.Parent.Name:lower()):find(str) end)
				NewFilter({"class", "c"}, function(Obj, str) return (Obj.ClassName:lower()):find(str) end)
				NewFilter({"isa", "i"}, function(Obj, str) return Obj:IsA(str) end)

				NewFilter({"only", "o"}, function(Obj, str)
					local Special = Only[str]
					return Special and table.find(Special, Obj.ClassName)
				end)
			end

            Explorer.DoSearch=function(query)
                FrostznLife.SearchId+=1
                local token=FrostznLife.SearchId
                Explorer.SearchBusy=false
                FrostznLife.SearchCount=0
                table.clear(Explorer.SearchExpanded);table.clear(searchResults)
                searchFunc=nil
                query=tostring(query or ""):match("^%s*(.-)%s*$")
                if query=="" then
                    expanded=Explorer.Expanded;Explorer.ForceUpdate();FrostznLife.Status("Pronto • objetos do cliente")
                    return
                end
                expanded=Explorer.SearchExpanded;Explorer.SearchBusy=true
                local clauses={}
                local classNames={}
                for name in pairs(API.Classes) do classNames[name:lower()]=name end
                local terms,word,quoted={},"",false
                local function flush()
                    if word=="" then return end
                    local excluded=word:sub(1,1)=="-"
                    if excluded then word=word:sub(2) end
                    local kind,value=word:match("^([%a]+):(.*)$")
                    if word~="" then terms[#terms+1]={kind=kind or "name",value=value or word,excluded=excluded} end
                    word=""
                end
                local lowered=query:lower()
                for i=1,#lowered do
                    local c=lowered:sub(i,i)
                    if c=='"' then quoted=not quoted
                    elseif not quoted and c=="," then flush();if #terms>0 then clauses[#clauses+1]=terms;terms={} end
                    elseif not quoted and c:match("%s") then flush()
                    else word..=c end
                end
                flush();if #terms>0 then clauses[#clauses+1]=terms end
                local function matches(object)
                    local name,class,parent
                    for _,terms in ipairs(clauses) do
                        local pass=true
                        for _,term in ipairs(terms) do
                            local k,v=term.kind,term.value
                            local match=false
                            if k=="class" or k=="c" then
                                class=class or object.ClassName:lower();match=class:find(v,1,true)~=nil
                            elseif k=="isa" or k=="i" then
                                local canonical=classNames[v];match=canonical and object:IsA(canonical) or false
                            elseif k=="parent" or k=="p" then
                                parent=object.Parent;match=parent and parent.Name:lower():find(v,1,true)~=nil
                            elseif k=="path" then match=object:GetFullName():lower():find(v,1,true)~=nil
                            elseif k=="only" or k=="o" then
                                match=(v=="scripts" and object:IsA("LuaSourceContainer")) or
                                    (v=="players" and object:IsA("Player")) or
                                    (v=="remotes" and (object:IsA("RemoteEvent") or object:IsA("RemoteFunction") or object:IsA("BindableEvent") or object:IsA("BindableFunction")))
                            else name=name or object.Name:lower();match=name:find(v,1,true)~=nil end
                            if term.excluded then match=not match end
                            if not match then pass=false;break end
                        end
                        if pass then return true end
                    end
                    return false
                end
                FrostznLife.Spawn(function()
                    local stack={nodes[game]};local scanned,hits,lastPaint=0,0,os.clock()
                    if nodes[nilNode.Obj] then stack[#stack+1]=nilNode end
                    while #stack>0 and FrostznLife.Alive and token==FrostznLife.SearchId do
                        local node=table.remove(stack)
                        if not node.Del then
                            scanned+=1
                            local ok,match=pcall(matches,node.Obj)
                            if ok and match then
                                hits+=1;Explorer.SearchExpanded[node]=0;searchResults[node]=true
                                local parent=node.Parent
                                while parent do
                                    Explorer.SearchExpanded[parent]=true;searchResults[parent]=true;parent=parent.Parent
                                end
                            end
                            for i=#node,1,-1 do
                                local child=node[i]
                                if child and not child.Del then stack[#stack+1]=child end
                                if i%128==0 then FrostznLife.Yield();if token~=FrostznLife.SearchId then return end end
                            end
                        end
                        if scanned%128==0 then
                            FrostznLife.Yield()
                            if os.clock()-lastPaint>.2 then
                                FrostznLife.Status(string.format("Busca • %d lidos · %d encontrados",scanned,hits));lastPaint=os.clock()
                            end
                        end
                    end
                    if not FrostznLife.Alive or token~=FrostznLife.SearchId then return end
                    Explorer.SearchBusy=false;FrostznLife.SearchCount=hits
                    Explorer.ForceUpdate();FrostznLife.Status(string.format("%d resultados • %d objetos",hits,scanned))
                end)
            end

			Explorer.ClearSearch = function()
                FrostznLife.SearchId+=1;Explorer.SearchBusy=false
				Explorer.GuiElems.SearchBar.Text = ""
				expanded = Explorer.Expanded
				searchFunc = nil
			end

			Explorer.InitSearch = function()
				local TweenService = service.TweenService
				local SearchFrame = Explorer.GuiElems.ToolBar.SearchFrame
				local searchBox = SearchFrame.SearchBox
				Explorer.GuiElems.SearchBar = searchBox
                searchBox.PlaceholderText='Buscar • nome, class:, path:, "frase"'
                local searchRevision=0
                FrostznLife.Connect(searchBox:GetPropertyChangedSignal("Text"),function()
                    searchRevision+=1;local revision=searchRevision
                    FrostznLife.Spawn(function()
                        task.wait(.35)
                        if FrostznLife.Alive and revision==searchRevision then Explorer.DoSearch(searchBox.Text) end
                    end)
                end)

				local TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint)
				local Tweens = {
					Start = TweenService:Create(SearchFrame.UIStroke, TweenInfo, { Color = Color3.fromRGB(0, 120, 215) }),
					End = TweenService:Create(SearchFrame.UIStroke, TweenInfo, { Color = Color3.fromRGB(42, 42, 42) })
				}

				FrostznLife.Connect(searchBox.FocusLost,function() Tweens.End:Play() end)
				FrostznLife.Connect(searchBox.Focused,function() Tweens.Start:Play() end)

				Lib.ViewportTextBox.convert(searchBox)

				FrostznLife.Connect(searchBox.FocusLost,function()
					Explorer.DoSearch(searchBox.Text)
				end)
			end

			Explorer.InitEntryTemplate = function()
				entryTemplate = create({
					{1,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,BorderColor3=Color3.new(0,0,0),Font=3,Name="Entry",Position=UDim2.new(0,1,0,1),Size=UDim2.new(0,250,0,20),Text="",TextSize=14,}},
					{2,"Frame",{BackgroundColor3=Color3.new(0.04313725605607,0.35294118523598,0.68627452850342),BackgroundTransparency=1,BorderColor3=Color3.new(0.33725491166115,0.49019610881805,0.73725491762161),BorderSizePixel=0,Name="Indent",Parent={1},Position=UDim2.new(0,20,0,0),Size=UDim2.new(1,-20,1,0),}},
					{3,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="EntryName",Parent={2},Position=UDim2.new(0,26,0,0),Size=UDim2.new(1,-26,1,0),Text="Workspace",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
					{4,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ClipsDescendants=true,Font=3,Name="Expand",Parent={2},Position=UDim2.new(0,-20,0,0),Size=UDim2.new(0,20,0,20),Text="",TextSize=14,}},
					{5,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5642383285",ImageRectOffset=Vector2.new(144,16),ImageRectSize=Vector2.new(16,16),Name="Icon",Parent={4},Position=UDim2.new(0,2,0,2),ScaleType=4,Size=UDim2.new(0,16,0,16),}},
					{6,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ImageRectOffset=Vector2.new(304,0),ImageRectSize=Vector2.new(16,16),Name="Icon",Parent={2},Position=UDim2.new(0,4,0,2),ScaleType=4,Size=UDim2.new(0,16,0,16),}},
				})

				local sys = Lib.ClickSystem.new()
				sys.AllowedButtons = {1,2}
				FrostznLife.Connect(sys.OnDown,function(item,combo,button)
					local ind = table.find(listEntries,item)
					if not ind then return end
					local node = tree[ind + Explorer.Index]
					if not node then return end

					local entry = listEntries[ind]

					if button == 1 then
						if combo == 2 then
							if node.Obj:IsA("LuaSourceContainer") then
								ScriptViewer.ViewScript(node.Obj)
							elseif #node > 0 and expanded[node] ~= 0 then
								expanded[node] = not expanded[node]
								Explorer.Update()
							end
						end

						if Properties.SelectObject(node.Obj) then
							sys.IsRenaming = false
							return
						end

						sys.IsRenaming = selection.Map[node]

						if Lib.IsShiftDown() then
							if not selection.Piviot then return end

							local fromIndex = table.find(tree,selection.Piviot)
							local toIndex = table.find(tree,node)
							if not fromIndex or not toIndex then return end
							fromIndex,toIndex = math.min(fromIndex,toIndex),math.max(fromIndex,toIndex)

							local sList = selection.List
							for i = #sList,1,-1 do
								local elem = sList[i]
								if selection.ShiftSet[elem] then
									selection.Map[elem] = nil
									table.remove(sList,i)
								end
							end
							selection.ShiftSet = {}
							for i = fromIndex,toIndex do
								local elem = tree[i]
								if not selection.Map[elem] then
									selection.ShiftSet[elem] = true
									selection.Map[elem] = true
									sList[#sList+1] = elem
								end
							end
							selection.Changed:Fire()
						elseif Lib.IsCtrlDown() then
							selection.ShiftSet = {}
							if selection.Map[node] then selection:Remove(node) else selection:Add(node) end
							selection.Piviot = node
							sys.IsRenaming = false
						elseif not selection.Map[node] then
							selection.ShiftSet = {}
							selection:Set(node)
							selection.Piviot = node
						end
					elseif button == 2 then
						if Properties.SelectObject(node.Obj) then
							return
						end

						if not Lib.IsCtrlDown() and not selection.Map[node] then
							selection.ShiftSet = {}
							selection:Set(node)
							selection.Piviot = node
							Explorer.Refresh()
						end
					end

					Explorer.Refresh()
				end)

				FrostznLife.Connect(sys.OnRelease,function(item,combo,button,position)
					local ind = table.find(listEntries,item)
					if not ind then return end
					local node = tree[ind + Explorer.Index]
					if not node then return end

					if button == 1 then
						if selection.Map[node] and not Lib.IsShiftDown() and not Lib.IsCtrlDown() then
							selection.ShiftSet = {}
							selection:Set(node)
							selection.Piviot = node
							Explorer.Refresh()
						end

						local id = sys.ClickId
						Lib.FastWait(sys.ComboTime)
						if combo == 1 and id == sys.ClickId and sys.IsRenaming and selection.Map[node] then
							Explorer.SetRenamingNode(node)
						end
					elseif button == 2 then
						Explorer.ShowRightClick(position)
					end
				end)
				Explorer.ClickSystem = sys
			end

            Explorer.InitDelCleaner=function()
                FrostznLife.Spawn(function()
                    while FrostznLife.Alive do
                        task.wait(.5)
                        local changed=false
                        for node in pairs(dirtyParents) do
                            dirtyParents[node]=nil
                            local write=1
                            for read=1,#node do
                                local child=node[read]
                                if not child.Del then node[write]=child;write+=1 end
                            end
                            for index=write,#node do node[index]=nil end
                            node.HasDel=false;changed=true;FrostznLife.Yield()
                        end
                        if changed and Explorer.Active and not refreshDebounce then Explorer.PerformRefresh() end
                    end
                end)
            end

			Explorer.UpdateSelectionVisuals = function()
				local holder = Explorer.SelectionVisualsHolder
				local isa = game.IsA
				local clone = game.Clone
				if not holder then
					holder = Instance.new("ScreenGui")
					holder.Name = "ExplorerSelections"
					holder.DisplayOrder = Main.DisplayOrders.Core
					Lib.ShowGui(holder)
					Explorer.SelectionVisualsHolder = holder
					Explorer.SelectionVisualCons = {}

					local guiTemplate = create({
						{1,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Size=UDim2.new(0,100,0,100),}},
						{2,"Frame",{BackgroundColor3=Color3.new(0.04313725605607,0.35294118523598,0.68627452850342),BorderSizePixel=0,Parent={1},Position=UDim2.new(0,-1,0,-1),Size=UDim2.new(1,2,0,1),}},
						{3,"Frame",{BackgroundColor3=Color3.new(0.04313725605607,0.35294118523598,0.68627452850342),BorderSizePixel=0,Parent={1},Position=UDim2.new(0,-1,1,0),Size=UDim2.new(1,2,0,1),}},
						{4,"Frame",{BackgroundColor3=Color3.new(0.04313725605607,0.35294118523598,0.68627452850342),BorderSizePixel=0,Parent={1},Position=UDim2.new(0,-1,0,0),Size=UDim2.new(0,1,1,0),}},
						{5,"Frame",{BackgroundColor3=Color3.new(0.04313725605607,0.35294118523598,0.68627452850342),BorderSizePixel=0,Parent={1},Position=UDim2.new(1,0,0,0),Size=UDim2.new(0,1,1,0),}},
					})
					Explorer.SelectionVisualGui = guiTemplate

					local boxTemplate = Instance.new("SelectionBox")
					boxTemplate.LineThickness = 0.03
					boxTemplate.Color3 = Color3.fromRGB(0, 170, 255)
					Explorer.SelectionVisualBox = boxTemplate
				end
				holder:ClearAllChildren()

				-- Updates theme
				for i,v in pairs(Explorer.SelectionVisualGui:GetChildren()) do
					v.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
				end

				local attachCons = Explorer.SelectionVisualCons
				for i = 1,#attachCons do
					attachCons[i].Destroy()
				end
				table.clear(attachCons)

				local partEnabled = Settings.Explorer.PartSelectionBox
				local guiEnabled = Settings.Explorer.GuiSelectionBox
				if not partEnabled and not guiEnabled then return end

				local svg = Explorer.SelectionVisualGui
				local svb = Explorer.SelectionVisualBox
				local attachTo = Lib.AttachTo
				local sList = selection.List
				local count = 1
				local boxCount = 0
				local workspaceNode = nodes[workspace]
				for i = 1,#sList do
					if boxCount >= 80 then break end
					local node = sList[i]
					local obj = node.Obj

					if node ~= workspaceNode then
						if isa(obj,"GuiObject") and guiEnabled then
							local newVisual = clone(svg)
							attachCons[count] = attachTo(newVisual,{Target = obj, Resize = true})
							count = count + 1
							newVisual.Parent = holder
							boxCount = boxCount + 1
						elseif isa(obj,"PVInstance") and partEnabled then
							local newBox = clone(svb)
							newBox.Adornee = obj
							newBox.Parent = holder
							boxCount = boxCount + 1
						end
					end
				end
			end

			Explorer.Init = function()
				Explorer.ClassIcons = Lib.IconMap.newLinear("rbxasset://textures/ClassImages.PNG", 16, 16)
				Explorer.MiscIcons = Main.MiscIcons

				clipboard = {}

				selection = Lib.Set.new()
				selection.ShiftSet = {}
				FrostznLife.Connect(selection.Changed,Properties.ShowExplorerProps)
				Explorer.Selection = selection

				Explorer.InitRightClick()
				Explorer.InitInsertObject()
				Explorer.SetSortingEnabled(Settings.Explorer.Sorting)
				Explorer.Expanded = setmetatable({},{__mode = "k"})
				Explorer.SearchExpanded = setmetatable({},{__mode = "k"})
				expanded = Explorer.Expanded

				nilNode.Obj.Name = "Nil Instances"
				nilNode.Locked = true

				local explorerItems = create({
					{1,"Folder",{Name="ExplorerItems",}},
					{2,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="ToolBar",Parent={1},Size=UDim2.new(1,0,0,22),}},
					{3,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.1176470592618,0.1176470592618,0.1176470592618),BorderSizePixel=0,Name="SearchFrame",Parent={2},Position=UDim2.new(0,3,0,1),Size=UDim2.new(1,-6,0,18),}},
					{4,"TextBox",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ClearTextOnFocus=false,Font=3,Name="SearchBox",Parent={3},PlaceholderColor3=Color3.new(0.39215689897537,0.39215689897537,0.39215689897537),PlaceholderText="Search workspace",Position=UDim2.new(0,4,0,0),Size=UDim2.new(1,-24,0,18),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,}},
					{5,"UICorner",{CornerRadius=UDim.new(0,2),Parent={3},}},
					{6,"UIStroke",{Thickness=1.4,Parent={3},Color=Color3.fromRGB(42,42,42)}},
					{7,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Reset",Parent={3},Position=UDim2.new(1,-17,0,1),Size=UDim2.new(0,16,0,16),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
					{8,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5034718129",ImageColor3=Color3.new(0.39215686917305,0.39215686917305,0.39215686917305),Parent={7},Size=UDim2.new(0,16,0,16),}},
					{9,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Refresh",Parent={2},Position=UDim2.new(1,-20,0,1),Size=UDim2.new(0,18,0,18),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,Visible=false,}},
					{10,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5642310344",Parent={9},Position=UDim2.new(0,3,0,3),Size=UDim2.new(0,12,0,12),}},
					{11,"Frame",{BackgroundColor3=Color3.new(0.15686275064945,0.15686275064945,0.15686275064945),BorderSizePixel=0,Name="ScrollCorner",Parent={1},Position=UDim2.new(1,-16,1,-16),Size=UDim2.new(0,16,0,16),Visible=false,}},
					{12,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ClipsDescendants=true,Name="List",Parent={1},Position=UDim2.new(0,0,0,23),Size=UDim2.new(1,0,1,-23),}}
				})

				toolBar = explorerItems.ToolBar
				treeFrame = explorerItems.List

				Explorer.GuiElems.ToolBar = toolBar
				Explorer.GuiElems.TreeFrame = treeFrame

				scrollV = Lib.ScrollBar.new()		
				scrollV.WheelIncrement = 3
				scrollV.Gui.Position = UDim2.new(1,-16,0,23)
				scrollV:SetScrollFrame(treeFrame)
				FrostznLife.Connect(scrollV.Scrolled,function()
					Explorer.Index = scrollV.Index
					Explorer.Refresh()
				end)

				scrollH = Lib.ScrollBar.new(true)
				scrollH.Increment = 5
				scrollH.WheelIncrement = Explorer.EntryIndent
				scrollH.Gui.Position = UDim2.new(0,0,1,-16)
				FrostznLife.Connect(scrollH.Scrolled,function()
					Explorer.Refresh()
				end)

				local window = Lib.Window.new()
				Explorer.Window = window
				window:SetTitle("Explorer")
				window.GuiElems.Line.Position = UDim2.new(0,0,0,22)

				Explorer.InitEntryTemplate()
				toolBar.Parent = window.GuiElems.Content
				treeFrame.Parent = window.GuiElems.Content
				explorerItems.ScrollCorner.Parent = window.GuiElems.Content
				scrollV.Gui.Parent = window.GuiElems.Content
				scrollH.Gui.Parent = window.GuiElems.Content

				-- Init stuff that requires the window
				Explorer.InitRenameBox()
				Explorer.InitSearch()
				Explorer.InitDelCleaner()
				FrostznLife.Connect(selection.Changed,Explorer.UpdateSelectionVisuals)

				-- Window events
				FrostznLife.Connect(window.GuiElems.Main:GetPropertyChangedSignal("AbsoluteSize"),function()
					if Explorer.Active then
						Explorer.UpdateView()
						Explorer.Refresh()
					end
				end)
				FrostznLife.Connect(window.OnActivate,function()
					Explorer.Active = true
					Explorer.UpdateView()
					Explorer.Update()
					Explorer.Refresh()
				end)
				FrostznLife.Connect(window.OnRestore,function()
					Explorer.Active = true
					Explorer.UpdateView()
					Explorer.Update()
					Explorer.Refresh()
				end)
				FrostznLife.Connect(window.OnDeactivate,function() Explorer.Active = false end)
				FrostznLife.Connect(window.OnMinimize,function() Explorer.Active = false end)

				-- Settings
				autoUpdateSearch = Settings.Explorer.AutoUpdateSearch

				-- Fill in nodes
				nodes[game] = {Obj = game}
				expanded[nodes[game]] = true

				-- Nil Instances
				if env.getnilinstances then
					nodes[nilNode.Obj] = nilNode
				end

				Explorer.SetupConnections()

				pcall(game.GetService,game,"ServerScriptService")
                pcall(game.GetService,game,"ServerStorage")
                local stack={game}
                while #stack>0 and FrostznLife.Alive do
                    local object=table.remove(stack)
                    local parentNode=nodes[object]
                    local list=(parentNode and not parentNode.Del) and object:GetChildren() or {}
                    for _,child in ipairs(list) do
                        if not FrostznLife.Owned(child) then
                            if not nodes[child] then
                                local node={Obj=child,Parent=parentNode};nodes[child]=node;parentNode[#parentNode+1]=node
                                FrostznLife.Scanned+=1
                            end
                            stack[#stack+1]=child
                        end
                        FrostznLife.Yield()
                    end
                end
                local insts = {} -- Indexacao incremental acima; evita GetDescendants(game).
				if Main.Elevated then
					for i = 1,#insts do
						local obj = insts[i]
						local par = nodes[ffa(obj,"Instance")]
						if not par then continue end
						local newNode = {
							Obj = obj,
							Parent = par,
						}
						nodes[obj] = newNode
						par[#par+1] = newNode
					end
				else
					for i = 1,#insts do
						local obj = insts[i]
						local s,parObj = pcall(ffa,obj,"Instance")
						local par = nodes[parObj]
						if not par then continue end
						local newNode = {
							Obj = obj,
							Parent = par,
						}
						nodes[obj] = newNode
						par[#par+1] = newNode
					end
				end
			end

			return Explorer
		end

		return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
	end,
	Properties = function()
--[[
	Properties App Module
	
	The main properties interface
]]

		-- Common Locals
		local Main,Lib,Apps,Settings -- Main Containers
		local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
		local API,RMD,env,service,plr,create,createSimple -- Main Locals

		local function initDeps(data)
			Main = data.Main
			Lib = data.Lib
			Apps = data.Apps
			Settings = data.Settings

			API = data.API
			RMD = data.RMD
			env = data.env
			service = data.service
			plr = data.plr
			create = data.create
			createSimple = data.createSimple
		end

		local function initAfterMain()
			Explorer = Apps.Explorer
			Properties = Apps.Properties
			ScriptViewer = Apps.ScriptViewer
			Notebook = Apps.Notebook
		end

		local function main()
			local Properties = {}

			local window, toolBar, propsFrame
			local scrollV, scrollH
			local categoryOrder
			local props,viewList,expanded,indexableProps,propEntries,autoUpdateObjs = {},{},{},{},{},{}
			local inputBox,inputTextBox,inputProp
			local checkboxes,propCons = {},{}
			local table,string = table,string
			local getPropChangedSignal = game.GetPropertyChangedSignal
			local getAttributeChangedSignal = game.GetAttributeChangedSignal
			local isa = game.IsA
			local getAttribute = game.GetAttribute
			local setAttribute = game.SetAttribute

			Properties.GuiElems = {}
			Properties.Index = 0
			Properties.ViewWidth = 0
			Properties.MinInputWidth = 100
			Properties.EntryIndent = 16
			Properties.EntryOffset = 4
			Properties.NameWidthCache = {}
			Properties.SubPropCache = {}
			Properties.ClassLists = {}
			Properties.SearchText = ""

			Properties.AddAttributeProp = {Category = "Attributes", Class = "", Name = "", SpecialRow = "AddAttribute", Tags = {}}
			Properties.SoundPreviewProp = {Category = "Data", ValueType = {Name = "SoundPlayer"}, Class = "Sound", Name = "Preview", Tags = {}}

			Properties.IgnoreProps = {
				["DataModel"] = {
					["PrivateServerId"] = true,
					["PrivateServerOwnerId"] = true,
					["VIPServerId"] = true,
					["VIPServerOwnerId"] = true
				}
			}

			Properties.ExpandableTypes = {
				["Vector2"] = true,
				["Vector3"] = true,
				["UDim"] = true,
				["UDim2"] = true,
				["CFrame"] = true,
				["Rect"] = true,
				["PhysicalProperties"] = true,
				["Ray"] = true,
				["NumberRange"] = true,
				["Faces"] = true,
				["Axes"] = true
			}

			Properties.ExpandableProps = {
				["Sound.SoundId"] = true
			}

			Properties.CollapsedCategories = {
				["Surface Inputs"] = true,
				["Surface"] = true
			}

			Properties.ConflictSubProps = {
				["Vector2"] = {"X","Y"},
				["Vector3"] = {"X","Y","Z"},
				["UDim"] = {"Scale","Offset"},
				["UDim2"] = {"X","X.Scale","X.Offset","Y","Y.Scale","Y.Offset"},
				["CFrame"] = {"Position","Position.X","Position.Y","Position.Z",
					"RightVector","RightVector.X","RightVector.Y","RightVector.Z",
					"UpVector","UpVector.X","UpVector.Y","UpVector.Z",
					"LookVector","LookVector.X","LookVector.Y","LookVector.Z"},
				["Rect"] = {"Min.X","Min.Y","Max.X","Max.Y"},
				["PhysicalProperties"] = {"Density","Elasticity","ElasticityWeight","Friction","FrictionWeight"},
				["Ray"] = {"Origin","Origin.X","Origin.Y","Origin.Z","Direction","Direction.X","Direction.Y","Direction.Z"},
				["NumberRange"] = {"Min","Max"},
				["Faces"] = {"Back","Bottom","Front","Left","Right","Top"},
				["Axes"] = {"X","Y","Z"}
			}

			Properties.ConflictIgnore = {
				["BasePart"] = {
					["ResizableFaces"] = true
				}
			}

			Properties.RoundableTypes = {
				["float"] = true,
				["double"] = true,
				["Color3"] = true,
				["UDim"] = true,
				["UDim2"] = true,
				["Vector2"] = true,
				["Vector3"] = true,
				["NumberRange"] = true,
				["Rect"] = true,
				["NumberSequence"] = true,
				["ColorSequence"] = true,
				["Ray"] = true,
				["CFrame"] = true
			}

			Properties.TypeNameConvert = {
				["number"] = "double",
				["boolean"] = "bool"
			}

			Properties.ToNumberTypes = {
				["int"] = true,
				["int64"] = true,
				["float"] = true,
				["double"] = true
			}

			Properties.DefaultPropValue = {
				string = "",
				bool = false,
				double = 0,
				UDim = UDim.new(0,0),
				UDim2 = UDim2.new(0,0,0,0),
				BrickColor = BrickColor.new("Medium stone grey"),
				Color3 = Color3.new(1,1,1),
				Vector2 = Vector2.new(0,0),
				Vector3 = Vector3.new(0,0,0),
				NumberSequence = NumberSequence.new(1),
				ColorSequence = ColorSequence.new(Color3.new(1,1,1)),
				NumberRange = NumberRange.new(0),
				Rect = Rect.new(0,0,0,0)
			}

			Properties.AllowedAttributeTypes = {"string","boolean","number","UDim","UDim2","BrickColor","Color3","Vector2","Vector3","NumberSequence","ColorSequence","NumberRange","Rect"}

			Properties.StringToValue = function(prop,str)
				local typeData = prop.ValueType
				local typeName = typeData.Name

				if typeName == "string" or typeName == "Content" then
					return str
				elseif Properties.ToNumberTypes[typeName] then
					return tonumber(str)
				elseif typeName == "Vector2" then
					local vals = str:split(",")
					local x,y = tonumber(vals[1]),tonumber(vals[2])
					if x and y and #vals >= 2 then return Vector2.new(x,y) end
				elseif typeName == "Vector3" then
					local vals = str:split(",")
					local x,y,z = tonumber(vals[1]),tonumber(vals[2]),tonumber(vals[3])
					if x and y and z and #vals >= 3 then return Vector3.new(x,y,z) end
				elseif typeName == "UDim" then
					local vals = str:split(",")
					local scale,offset = tonumber(vals[1]),tonumber(vals[2])
					if scale and offset and #vals >= 2 then return UDim.new(scale,offset) end
				elseif typeName == "UDim2" then
					local vals = str:gsub("[{}]",""):split(",")
					local xScale,xOffset,yScale,yOffset = tonumber(vals[1]),tonumber(vals[2]),tonumber(vals[3]),tonumber(vals[4])
					if xScale and xOffset and yScale and yOffset and #vals >= 4 then return UDim2.new(xScale,xOffset,yScale,yOffset) end
				elseif typeName == "CFrame" then
					local vals = str:split(",")
					local s,result = pcall(CFrame.new, unpack(vals))
					if s and #vals >= 12 then return result end
				elseif typeName == "Rect" then
					local vals = str:split(",")
					local s,result = pcall(Rect.new,unpack(vals))
					if s and #vals >= 4 then return result end
				elseif typeName == "Ray" then
					local vals = str:gsub("[{}]",""):split(",")
					local s,origin = pcall(Vector3.new,unpack(vals,1,3))
					local s2,direction = pcall(Vector3.new,unpack(vals,4,6))
					if s and s2 and #vals >= 6 then return Ray.new(origin,direction) end
				elseif typeName == "NumberRange" then
					local vals = str:split(",")
					local s,result = pcall(NumberRange.new,unpack(vals))
					if s and #vals >= 1 then return result end
				elseif typeName == "Color3" then
					local vals = str:gsub("[{}]",""):split(",")
					local s,result = pcall(Color3.fromRGB,unpack(vals))
					if s and #vals >= 3 then return result end
				end

				return nil
			end

			Properties.ValueToString = function(prop,val)
				local typeData = prop.ValueType
				local typeName = typeData.Name

				if typeName == "Color3" then
					return Lib.ColorToBytes(val)
				elseif typeName == "NumberRange" then
					return val.Min..", "..val.Max
				end

				return tostring(val)
			end

			Properties.GetIndexableProps = function(obj,classData)
				if not Main.Elevated then
					if not pcall(function() return obj.ClassName end) then return nil end
				end

				local ignoreProps = Properties.IgnoreProps[classData.Name] or {}

				local result = {}
				local count = 1
				local props = classData.Properties
				for i = 1,#props do
					local prop = props[i]
					if not ignoreProps[prop.Name] then
						local s = pcall(function() return obj[prop.Name] end)
						if s then
							result[count] = prop
							count = count + 1
						end
					end
				end

				return result
			end

			Properties.FindFirstObjWhichIsA = function(class)
				local classList = Properties.ClassLists[class] or {}
				if classList and #classList > 0 then
					return classList[1]
				end

				return nil
			end

			Properties.ComputeConflicts = function(p)
				local maxConflictCheck = Settings.Properties.MaxConflictCheck
				local sList = Explorer.Selection.List
				local classLists = Properties.ClassLists
				local stringSplit = string.split
				local t_clear = table.clear
				local conflictIgnore = Properties.ConflictIgnore
				local conflictMap = {}
				local propList = p and {p} or props

				if p then
					local gName = p.Class.."."..p.Name
					autoUpdateObjs[gName] = nil
					local subProps = Properties.ConflictSubProps[p.ValueType.Name] or {}
					for i = 1,#subProps do
						autoUpdateObjs[gName.."."..subProps[i]] = nil
					end
				else
					table.clear(autoUpdateObjs)
				end

				if #sList > 0 then
					for i = 1,#propList do
						local prop = propList[i]
						local propName,propClass = prop.Name,prop.Class
						local typeData = prop.RootType or prop.ValueType
						local typeName = typeData.Name
						local attributeName = prop.AttributeName
						local gName = propClass.."."..propName

						local checked = 0
						local subProps = Properties.ConflictSubProps[typeName] or {}
						local subPropCount = #subProps
						local toCheck = subPropCount + 1
						local conflictsFound = 0
						local indexNames = {}
						local ignored = conflictIgnore[propClass] and conflictIgnore[propClass][propName]
						local truthyCheck = (typeName == "PhysicalProperties")
						local isAttribute = prop.IsAttribute
						local isMultiType = prop.MultiType

						t_clear(conflictMap)

						if not isMultiType then
							local firstVal,firstObj,firstSet
							local classList = classLists[prop.Class] or {}
							for c = 1,#classList do
								local obj = classList[c]
								if not firstSet then
									if isAttribute then
										firstVal = getAttribute(obj,attributeName)
										if firstVal ~= nil then
											firstObj = obj
											firstSet = true
										end
									else
										firstVal = obj[propName]
										firstObj = obj
										firstSet = true
									end
									if ignored then break end
								else
									local propVal,skip
									if isAttribute then
										propVal = getAttribute(obj,attributeName)
										if propVal == nil then skip = true end
									else
										propVal = obj[propName]
									end

									if not skip then
										if not conflictMap[1] then
											if truthyCheck then
												if (firstVal and true or false) ~= (propVal and true or false) then
													conflictMap[1] = true
													conflictsFound = conflictsFound + 1
												end
											elseif firstVal ~= propVal then
												conflictMap[1] = true
												conflictsFound = conflictsFound + 1
											end
										end

										if subPropCount > 0 then
											for sPropInd = 1,subPropCount do
												local indexes = indexNames[sPropInd]
												if not indexes then indexes = stringSplit(subProps[sPropInd],".") indexNames[sPropInd] = indexes end

												local firstValSub = firstVal
												local propValSub = propVal

												for j = 1,#indexes do
													if not firstValSub or not propValSub then break end -- PhysicalProperties
													local indexName = indexes[j]
													firstValSub = firstValSub[indexName]
													propValSub = propValSub[indexName]
												end

												local mapInd = sPropInd + 1
												if not conflictMap[mapInd] and firstValSub ~= propValSub then
													conflictMap[mapInd] = true
													conflictsFound = conflictsFound + 1
												end
											end
										end

										if conflictsFound == toCheck then break end
									end
								end

								checked = checked + 1
								if checked == maxConflictCheck then break end
							end

							if not conflictMap[1] then autoUpdateObjs[gName] = firstObj end
							for sPropInd = 1,subPropCount do
								if not conflictMap[sPropInd+1] then
									autoUpdateObjs[gName.."."..subProps[sPropInd]] = firstObj
								end
							end
						end
					end
				end

				if p then
					Properties.Refresh()
				end
			end

			-- Fetches the properties to be displayed based on the explorer selection
			Settings.Properties.ShowAttributes = true -- im making it true anyway since its useful by default and people complain
			Properties.ShowExplorerProps = function()
				local maxConflictCheck = Settings.Properties.MaxConflictCheck
				local sList = Explorer.Selection.List
				local foundClasses = {}
				local propCount = 1
				local elevated = Main.Elevated
				local showDeprecated,showHidden = Settings.Properties.ShowDeprecated,Settings.Properties.ShowHidden
				local Classes = API.Classes
				local classLists = {}
				local lower = string.lower
				local RMDCustomOrders = RMD.PropertyOrders
				local getAttributes = game.GetAttributes
				local maxAttrs = Settings.Properties.MaxAttributes
				local showingAttrs = Settings.Properties.ShowAttributes
				local foundAttrs = {}
				local attrCount = 0
				local typeof = typeof
				local typeNameConvert = Properties.TypeNameConvert

				table.clear(props)

				for i = 1,#sList do
					local node = sList[i]
					local obj = node.Obj
					local class = node.Class
					if not class then class = obj.ClassName node.Class = class end

					local apiClass = Classes[class]
					while apiClass do
						local APIClassName = apiClass.Name
						if not foundClasses[APIClassName] then
							local apiProps = indexableProps[APIClassName]
							if not apiProps then apiProps = Properties.GetIndexableProps(obj,apiClass) indexableProps[APIClassName] = apiProps end

							for i = 1,#apiProps do
								local prop = apiProps[i]
								local tags = prop.Tags
								if (not tags.Deprecated or showDeprecated) and (not tags.Hidden or showHidden) then
									props[propCount] = prop
									propCount = propCount + 1
								end
							end
							foundClasses[APIClassName] = true
						end

						local classList = classLists[APIClassName]
						if not classList then classList = {} classLists[APIClassName] = classList end
						classList[#classList+1] = obj

						apiClass = apiClass.Superclass
					end

					if showingAttrs and attrCount < maxAttrs then
						local attrs = getAttributes(obj)
						for name,val in pairs(attrs) do
							local typ = typeof(val)
							if not foundAttrs[name] then
								local category = (typ == "Instance" and "Class") or (typ == "EnumItem" and "Enum") or "Other"
								local valType = {Name = typeNameConvert[typ] or typ, Category = category}
								local attrProp = {IsAttribute = true, Name = "ATTR_"..name, AttributeName = name, DisplayName = name, Class = "Instance", ValueType = valType, Category = "Attributes", Tags = {}}
								props[propCount] = attrProp
								propCount = propCount + 1
								attrCount = attrCount + 1
								foundAttrs[name] = {typ,attrProp}
								if attrCount == maxAttrs then break end
							elseif foundAttrs[name][1] ~= typ then
								foundAttrs[name][2].MultiType = true
								foundAttrs[name][2].Tags.ReadOnly = true
								foundAttrs[name][2].ValueType = {Name = "string"}
							end
						end
					end
				end

				table.sort(props,function(a,b)
					if a.Category ~= b.Category then
						return (categoryOrder[a.Category] or 9999) < (categoryOrder[b.Category] or 9999)
					else
						local aOrder = (RMDCustomOrders[a.Class] and RMDCustomOrders[a.Class][a.Name]) or 9999999
						local bOrder = (RMDCustomOrders[b.Class] and RMDCustomOrders[b.Class][b.Name]) or 9999999
						if aOrder ~= bOrder then
							return aOrder < bOrder
						else
							return lower(a.Name) < lower(b.Name)
						end
					end
				end)

				-- Find conflicts and get auto-update instances
				Properties.ClassLists = classLists
				Properties.ComputeConflicts()
				--warn("CONFLICT",tick()-start)
				if #props > 0 then
					props[#props+1] = Properties.AddAttributeProp
				end

				Properties.Update()
				Properties.Refresh()
			end

			Properties.UpdateView = function()
				local maxEntries = math.ceil(propsFrame.AbsoluteSize.Y / 23)
				local maxX = propsFrame.AbsoluteSize.X
				local totalWidth = Properties.ViewWidth + Properties.MinInputWidth

				scrollV.VisibleSpace = maxEntries
				scrollV.TotalSpace = #viewList + 1
				scrollH.VisibleSpace = maxX
				scrollH.TotalSpace = totalWidth

				scrollV.Gui.Visible = #viewList + 1 > maxEntries
				scrollH.Gui.Visible = Settings.Properties.ScaleType == 0 and totalWidth > maxX

				local oldSize = propsFrame.Size
				propsFrame.Size = UDim2.new(1,(scrollV.Gui.Visible and -16 or 0),1,(scrollH.Gui.Visible and -39 or -23))
				if oldSize ~= propsFrame.Size then
					Properties.UpdateView()
				else
					scrollV:Update()
					scrollH:Update()

					if scrollV.Gui.Visible and scrollH.Gui.Visible then
						scrollV.Gui.Size = UDim2.new(0,16,1,-39)
						scrollH.Gui.Size = UDim2.new(1,-16,0,16)
						Properties.Window.GuiElems.Content.ScrollCorner.Visible = true
					else
						scrollV.Gui.Size = UDim2.new(0,16,1,-23)
						scrollH.Gui.Size = UDim2.new(1,0,0,16)
						Properties.Window.GuiElems.Content.ScrollCorner.Visible = false
					end

					Properties.Index = scrollV.Index
				end
			end

			Properties.MakeSubProp = function(prop,subName,valueType,displayName)
				local subProp = {}
				for i,v in pairs(prop) do
					subProp[i] = v
				end
				subProp.RootType = subProp.RootType or subProp.ValueType
				subProp.ValueType = valueType
				subProp.SubName = subProp.SubName and (subProp.SubName..subName) or subName
				subProp.DisplayName = displayName

				return subProp
			end

			Properties.GetExpandedProps = function(prop) -- TODO: Optimize using table
				local result = {}
				local typeData = prop.ValueType
				local typeName = typeData.Name
				local makeSubProp = Properties.MakeSubProp

				if typeName == "Vector2" then
					result[1] = makeSubProp(prop,".X",{Name = "float"})
					result[2] = makeSubProp(prop,".Y",{Name = "float"})
				elseif typeName == "Vector3" then
					result[1] = makeSubProp(prop,".X",{Name = "float"})
					result[2] = makeSubProp(prop,".Y",{Name = "float"})
					result[3] = makeSubProp(prop,".Z",{Name = "float"})
				elseif typeName == "CFrame" then
					result[1] = makeSubProp(prop,".Position",{Name = "Vector3"})
					result[2] = makeSubProp(prop,".RightVector",{Name = "Vector3"})
					result[3] = makeSubProp(prop,".UpVector",{Name = "Vector3"})
					result[4] = makeSubProp(prop,".LookVector",{Name = "Vector3"})
				elseif typeName == "UDim" then
					result[1] = makeSubProp(prop,".Scale",{Name = "float"})
					result[2] = makeSubProp(prop,".Offset",{Name = "int"})
				elseif typeName == "UDim2" then
					result[1] = makeSubProp(prop,".X",{Name = "UDim"})
					result[2] = makeSubProp(prop,".Y",{Name = "UDim"})
				elseif typeName == "Rect" then
					result[1] = makeSubProp(prop,".Min.X",{Name = "float"},"X0")
					result[2] = makeSubProp(prop,".Min.Y",{Name = "float"},"Y0")
					result[3] = makeSubProp(prop,".Max.X",{Name = "float"},"X1")
					result[4] = makeSubProp(prop,".Max.Y",{Name = "float"},"Y1")
				elseif typeName == "PhysicalProperties" then
					result[1] = makeSubProp(prop,".Density",{Name = "float"})
					result[2] = makeSubProp(prop,".Elasticity",{Name = "float"})
					result[3] = makeSubProp(prop,".ElasticityWeight",{Name = "float"})
					result[4] = makeSubProp(prop,".Friction",{Name = "float"})
					result[5] = makeSubProp(prop,".FrictionWeight",{Name = "float"})
				elseif typeName == "Ray" then
					result[1] = makeSubProp(prop,".Origin",{Name = "Vector3"})
					result[2] = makeSubProp(prop,".Direction",{Name = "Vector3"})
				elseif typeName == "NumberRange" then
					result[1] = makeSubProp(prop,".Min",{Name = "float"})
					result[2] = makeSubProp(prop,".Max",{Name = "float"})
				elseif typeName == "Faces" then
					result[1] = makeSubProp(prop,".Back",{Name = "bool"})
					result[2] = makeSubProp(prop,".Bottom",{Name = "bool"})
					result[3] = makeSubProp(prop,".Front",{Name = "bool"})
					result[4] = makeSubProp(prop,".Left",{Name = "bool"})
					result[5] = makeSubProp(prop,".Right",{Name = "bool"})
					result[6] = makeSubProp(prop,".Top",{Name = "bool"})
				elseif typeName == "Axes" then
					result[1] = makeSubProp(prop,".X",{Name = "bool"})
					result[2] = makeSubProp(prop,".Y",{Name = "bool"})
					result[3] = makeSubProp(prop,".Z",{Name = "bool"})
				end

				if prop.Name == "SoundId" and prop.Class == "Sound" then
					result[1] = Properties.SoundPreviewProp
				end

				return result
			end

			Properties.Update = function()
				table.clear(viewList)

				local nameWidthCache = Properties.NameWidthCache
				local lastCategory
				local count = 1
				local maxWidth,maxDepth = 0,1

				local textServ = service.TextService
				local getTextSize = textServ.GetTextSize
				local font = Enum.Font.SourceSans
				local size = Vector2.new(math.huge,20)
				local stringSplit = string.split
				local entryIndent = Properties.EntryIndent
				local isFirstScaleType = Settings.Properties.ScaleType == 0
				local find,lower = string.find,string.lower
				local searchText = (#Properties.SearchText > 0 and lower(Properties.SearchText))

				local function recur(props,depth)
					for i = 1,#props do
						local prop = props[i]
						local propName = prop.Name
						local subName = prop.SubName
						local category = prop.Category

						local visible
						if searchText and depth == 1 then
							if find(lower(propName),searchText,1,true) then
								visible = true
							end
						else
							visible = true
						end

						if visible and lastCategory ~= category then
							viewList[count] = {CategoryName = category}
							count = count + 1
							lastCategory = category
						end

						if (expanded["CAT_"..category] and visible) or prop.SpecialRow then
							if depth > 1 then prop.Depth = depth if depth > maxDepth then maxDepth = depth end end

							if isFirstScaleType then
								local nameArr = subName and stringSplit(subName,".")
								local displayName = prop.DisplayName or (nameArr and nameArr[#nameArr]) or propName

								local nameWidth = nameWidthCache[displayName]
								if not nameWidth then nameWidth = getTextSize(textServ,displayName,14,font,size).X nameWidthCache[displayName] = nameWidth end

								local totalWidth = nameWidth + entryIndent*depth
								if totalWidth > maxWidth then
									maxWidth = totalWidth
								end
							end

							viewList[count] = prop
							count = count + 1

							local fullName = prop.Class.."."..prop.Name..(prop.SubName or "")
							if expanded[fullName] then
								local nextDepth = depth+1
								local expandedProps = Properties.GetExpandedProps(prop)
								if #expandedProps > 0 then
									recur(expandedProps,nextDepth)
								end
							end
						end
					end
				end
				recur(props,1)

				inputProp = nil
				Properties.ViewWidth = maxWidth + 9 + Properties.EntryOffset
				Properties.UpdateView()
			end

			Properties.NewPropEntry = function(index)
				local newEntry = Properties.EntryTemplate:Clone()
				local nameFrame = newEntry.NameFrame
				local valueFrame = newEntry.ValueFrame
				local newCheckbox = Lib.Checkbox.new(1)
				newCheckbox.Gui.Position = UDim2.new(0,3,0,3)
				newCheckbox.Gui.Parent = valueFrame
				FrostznLife.Connect(newCheckbox.OnInput,function()
					local prop = viewList[index + Properties.Index]
					if not prop then return end

					if prop.ValueType.Name == "PhysicalProperties" then
						Properties.SetProp(prop,newCheckbox.Toggled and true or nil)
					else
						Properties.SetProp(prop,newCheckbox.Toggled)
					end
				end)
				checkboxes[index] = newCheckbox

				local iconFrame = Main.MiscIcons:GetLabel()
				iconFrame.Position = UDim2.new(0,2,0,3)
				iconFrame.Parent = newEntry.ValueFrame.RightButton

				newEntry.Position = UDim2.new(0,0,0,23*(index-1))

				FrostznLife.Connect(nameFrame.Expand.InputBegan,function(input)
					local prop = viewList[index + Properties.Index]
					if not prop or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end

					local fullName = (prop.CategoryName and "CAT_"..prop.CategoryName) or prop.Class.."."..prop.Name..(prop.SubName or "")

					Main.MiscIcons:DisplayByKey(newEntry.NameFrame.Expand.Icon, expanded[fullName] and "Collapse_Over" or "Expand_Over")
				end)

				FrostznLife.Connect(nameFrame.Expand.InputEnded,function(input)
					local prop = viewList[index + Properties.Index]
					if not prop or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end

					local fullName = (prop.CategoryName and "CAT_"..prop.CategoryName) or prop.Class.."."..prop.Name..(prop.SubName or "")

					Main.MiscIcons:DisplayByKey(newEntry.NameFrame.Expand.Icon, expanded[fullName] and "Collapse" or "Expand")
				end)

				FrostznLife.Connect(nameFrame.Expand.MouseButton1Down,function()
					local prop = viewList[index + Properties.Index]
					if not prop then return end

					local fullName = (prop.CategoryName and "CAT_"..prop.CategoryName) or prop.Class.."."..prop.Name..(prop.SubName or "")
					if not prop.CategoryName and not Properties.ExpandableTypes[prop.ValueType and prop.ValueType.Name] and not Properties.ExpandableProps[fullName] then return end

					expanded[fullName] = not expanded[fullName]
					Properties.Update()
					Properties.Refresh()
				end)

				FrostznLife.Connect(nameFrame.PropName.InputBegan,function(input)
					local prop = viewList[index + Properties.Index]
					if not prop then return end
					if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and not nameFrame.PropName.TextFits then
						local fullNameFrame = Properties.FullNameFrame	
						local nameArr = string.split(prop.Class.."."..prop.Name..(prop.SubName or ""), ".")
						local dispName = prop.DisplayName or nameArr[#nameArr]
						local sizeX = service.TextService:GetTextSize(dispName, 14, Enum.Font.SourceSans, Vector2.new(math.huge, 20)).X

						fullNameFrame.TextLabel.Text = dispName
						fullNameFrame.Size = UDim2.new(0, sizeX + 4, 0, 22)
						fullNameFrame.Visible = true
						Properties.FullNameFrameIndex = index
						Properties.FullNameFrameAttach.SetData(fullNameFrame, {Target = nameFrame})
						Properties.FullNameFrameAttach.Enable()
					end
				end)

				FrostznLife.Connect(nameFrame.PropName.InputEnded,function(input)
					if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and Properties.FullNameFrameIndex == index then
						Properties.FullNameFrame.Visible = false
						Properties.FullNameFrameAttach.Disable()
					end
				end)


				FrostznLife.Connect(valueFrame.ValueBox.MouseButton1Down,function()
					local prop = viewList[index + Properties.Index]
					if not prop then return end

					Properties.SetInputProp(prop,index)
				end)

				FrostznLife.Connect(valueFrame.ColorButton.MouseButton1Down,function()
					local prop = viewList[index + Properties.Index]
					if not prop then return end

					Properties.SetInputProp(prop,index,"color")
				end)

				FrostznLife.Connect(valueFrame.RightButton.MouseButton1Click,function()
					local prop = viewList[index + Properties.Index]
					if not prop then return end

					local fullName = prop.Class.."."..prop.Name..(prop.SubName or "")
					local inputFullName = inputProp and (inputProp.Class.."."..inputProp.Name..(inputProp.SubName or ""))

					if fullName == inputFullName and inputProp.ValueType.Category == "Class" then
						inputProp = nil
						Properties.SetProp(prop,nil)
					else
						Properties.SetInputProp(prop,index,"right")
					end
				end)

				FrostznLife.Connect(nameFrame.ToggleAttributes.MouseButton1Click,function()
					Settings.Properties.ShowAttributes = not Settings.Properties.ShowAttributes
					Properties.ShowExplorerProps()
				end)

				FrostznLife.Connect(newEntry.RowButton.MouseButton1Click,function()
					Properties.DisplayAddAttributeWindow()
				end)

				FrostznLife.Connect(newEntry.EditAttributeButton.MouseButton1Down,function()
					local prop = viewList[index + Properties.Index]
					if not prop then return end

					Properties.DisplayAttributeContext(prop)
				end)

				FrostznLife.Connect(valueFrame.SoundPreview.ControlButton.MouseButton1Click,function()
					if Properties.PreviewSound and Properties.PreviewSound.Playing then
						Properties.SetSoundPreview(false)
					else
						local soundObj = Properties.FindFirstObjWhichIsA("Sound")
						if soundObj then Properties.SetSoundPreview(soundObj) end
					end
				end)

				FrostznLife.Connect(valueFrame.SoundPreview.InputBegan,function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end

					local releaseEvent, inputEvent
					releaseEvent = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							releaseEvent:Disconnect()
							if inputEvent then
								inputEvent:Disconnect()
							end
						end
					end)

					local timeLine = newEntry.ValueFrame.SoundPreview.TimeLine
					local soundObj = Properties.FindFirstObjWhichIsA("Sound")
					if soundObj then Properties.SetSoundPreview(soundObj, true) end

					local function update(input)
						local sound = Properties.PreviewSound
						if not sound or sound.TimeLength == 0 then return end

						local inputX = (input.UserInputType == Enum.UserInputType.Touch) and input.Position.X or input.Position.X
						local timeLineSize = timeLine.AbsoluteSize
						local relaX = inputX - timeLine.AbsolutePosition.X

						if timeLineSize.X <= 1 then return end
						if relaX < 0 then relaX = 0 elseif relaX >= timeLineSize.X then relaX = timeLineSize.X - 1 end

						local perc = (relaX / (timeLineSize.X - 1))
						sound.TimePosition = perc * sound.TimeLength
						timeLine.Slider.Position = UDim2.new(perc, -4, 0, -8)
					end

					update(input)

					inputEvent = FrostznLife.Connect(service.UserInputService.InputChanged,function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							update(input)
						end
					end)
				end)


				newEntry.Parent = propsFrame

				return {
					Gui = newEntry,
					GuiElems = {
						NameFrame = nameFrame,
						ValueFrame = valueFrame,
						PropName = nameFrame.PropName,
						ValueBox = valueFrame.ValueBox,
						Expand = nameFrame.Expand,
						ColorButton = valueFrame.ColorButton,
						ColorPreview = valueFrame.ColorButton.ColorPreview,
						Gradient = valueFrame.ColorButton.ColorPreview.UIGradient,
						EnumArrow = valueFrame.EnumArrow,
						Checkbox = valueFrame.Checkbox,
						RightButton = valueFrame.RightButton,
						RightButtonIcon = iconFrame,
						RowButton = newEntry.RowButton,
						EditAttributeButton = newEntry.EditAttributeButton,
						ToggleAttributes = nameFrame.ToggleAttributes,
						SoundPreview = valueFrame.SoundPreview,
						SoundPreviewSlider = valueFrame.SoundPreview.TimeLine.Slider
					}
				}
			end

			Properties.GetSoundPreviewEntry = function()
				for i = 1,#viewList do
					if viewList[i] == Properties.SoundPreviewProp then
						return propEntries[i - Properties.Index]
					end
				end
			end

			Properties.SetSoundPreview = function(soundObj,noplay)
				local sound = Properties.PreviewSound
				if not sound then
					sound = Instance.new("Sound")
					sound.Name = "Preview"
					FrostznLife.Connect(sound.Paused,function()
						local entry = Properties.GetSoundPreviewEntry()
						if entry then Main.MiscIcons:DisplayByKey(entry.GuiElems.SoundPreview.ControlButton.Icon, "Play") end
					end)
					FrostznLife.Connect(sound.Resumed,function() Properties.Refresh() end)
					FrostznLife.Connect(sound.Ended,function()
						local entry = Properties.GetSoundPreviewEntry()
						if entry then entry.GuiElems.SoundPreviewSlider.Position = UDim2.new(0,-4,0,-8) end
						Properties.Refresh()
					end)
					sound.Parent = window.Gui
					Properties.PreviewSound = sound
				end

				if not soundObj then
					sound:Pause()
				else
					local newId = sound.SoundId ~= soundObj.SoundId
					sound.SoundId = soundObj.SoundId
					sound.PlaybackSpeed = soundObj.PlaybackSpeed
					sound.Volume = soundObj.Volume
					if newId then sound.TimePosition = 0 end
					if not noplay then sound:Resume() end

					FrostznLife.Wrap(function()
						local previewTime = tick()
						Properties.SoundPreviewTime = previewTime
						while previewTime == Properties.SoundPreviewTime and sound.Playing do
							local entry = Properties.GetSoundPreviewEntry()
							if entry then
								local tl = sound.TimeLength
								local perc = sound.TimePosition/(tl == 0 and 1 or tl)
								entry.GuiElems.SoundPreviewSlider.Position = UDim2.new(perc,-4,0,-8)
							end
							Lib.FastWait()
						end
					end)()
					Properties.Refresh()
				end
			end

			Properties.DisplayAttributeContext = function(prop)
				local context = Properties.AttributeContext
				if not context then
					context = Lib.ContextMenu.new()
					context.Iconless = true
					context.Width = 80
				end
				context:Clear()

				context:Add({Name = "Edit", OnClick = function()
					Properties.DisplayAddAttributeWindow(prop)
				end})
				context:Add({Name = "Delete", OnClick = function()
					Properties.SetProp(prop,nil,true)
					Properties.ShowExplorerProps()
				end})

				context:Show()
			end

			Properties.DisplayAddAttributeWindow = function(editAttr)
				local win = Properties.AddAttributeWindow
				if not win then
					win = Lib.Window.new()
					win.Alignable = false
					win.Resizable = false
					win:SetTitle("Add Attribute")
					win:SetSize(200,130)

					local saveButton = Lib.Button.new()
					local nameLabel = Lib.Label.new()
					nameLabel.Text = "Name"
					nameLabel.Position = UDim2.new(0,30,0,10)
					nameLabel.Size = UDim2.new(0,40,0,20)
					win:Add(nameLabel)

					local nameBox = Lib.ViewportTextBox.new()
					nameBox.Position = UDim2.new(0,75,0,10)
					nameBox.Size = UDim2.new(0,120,0,20)
					win:Add(nameBox,"NameBox")
					FrostznLife.Connect(nameBox.TextBox:GetPropertyChangedSignal("Text"),function()
						saveButton:SetDisabled(#nameBox:GetText() == 0)
					end)

					local typeLabel = Lib.Label.new()
					typeLabel.Text = "Type"
					typeLabel.Position = UDim2.new(0,30,0,40)
					typeLabel.Size = UDim2.new(0,40,0,20)
					win:Add(typeLabel)

					local typeChooser = Lib.DropDown.new()
					typeChooser.CanBeEmpty = false
					typeChooser.Position = UDim2.new(0,75,0,40)
					typeChooser.Size = UDim2.new(0,120,0,20)
					typeChooser:SetOptions(Properties.AllowedAttributeTypes)
					win:Add(typeChooser,"TypeChooser")

					local errorLabel = Lib.Label.new()
					errorLabel.Text = ""
					errorLabel.Position = UDim2.new(0,5,1,-45)
					errorLabel.Size = UDim2.new(1,-10,0,20)
					errorLabel.TextColor3 = Settings.Theme.Important
					win.ErrorLabel = errorLabel
					win:Add(errorLabel,"Error")

					local cancelButton = Lib.Button.new()
					cancelButton.Text = "Cancel"
					cancelButton.Position = UDim2.new(1,-97,1,-25)
					cancelButton.Size = UDim2.new(0,92,0,20)
					FrostznLife.Connect(cancelButton.OnClick,function()
						win:Close()
					end)
					win:Add(cancelButton)

					saveButton.Text = "Save"
					saveButton.Position = UDim2.new(0,5,1,-25)
					saveButton.Size = UDim2.new(0,92,0,20)
					FrostznLife.Connect(saveButton.OnClick,function()
						local name = nameBox:GetText()
						if #name > 100 then
							errorLabel.Text = "Error: Name over 100 chars"
							return
						elseif name:sub(1,3) == "RBX" then
							errorLabel.Text = "Error: Name begins with 'RBX'"
							return
						end

						local typ = typeChooser.Selected
						local valType = {Name = Properties.TypeNameConvert[typ] or typ, Category = "DataType"}
						local attrProp = {IsAttribute = true, Name = "ATTR_"..name, AttributeName = name, DisplayName = name, Class = "Instance", ValueType = valType, Category = "Attributes", Tags = {}}

						Settings.Properties.ShowAttributes = true
						Properties.SetProp(attrProp,Properties.DefaultPropValue[valType.Name],true,Properties.EditingAttribute)
						Properties.ShowExplorerProps()
						win:Close()
					end)
					win:Add(saveButton,"SaveButton")

					Properties.AddAttributeWindow = win
				end

				Properties.EditingAttribute = editAttr
				win:SetTitle(editAttr and "Edit Attribute "..editAttr.AttributeName or "Add Attribute")
				win.Elements.Error.Text = ""
				win.Elements.NameBox:SetText("")
				win.Elements.SaveButton:SetDisabled(true)
				win.Elements.TypeChooser:SetSelected(1)
				win:Show()
			end

			Properties.IsTextEditable = function(prop)
				local typeData = prop.ValueType
				local typeName = typeData.Name

				return typeName ~= "bool" and typeData.Category ~= "Enum" and typeData.Category ~= "Class" and typeName ~= "BrickColor"
			end

			Properties.DisplayEnumDropdown = function(entryIndex)
				local context = Properties.EnumContext
				if not context then
					context = Lib.ContextMenu.new()
					context.Iconless = true
					context.MaxHeight = 200
					context.ReverseYOffset = 22
					Properties.EnumDropdown = context
				end

				if not inputProp or inputProp.ValueType.Category ~= "Enum" then return end
				local prop = inputProp

				local entry = propEntries[entryIndex]
				local valueFrame = entry.GuiElems.ValueFrame

				local enum = Enum[prop.ValueType.Name]
				if not enum then return end

				local sorted = {}
				for name,enum in next,enum:GetEnumItems() do
					sorted[#sorted+1] = enum
				end
				table.sort(sorted,function(a,b) return a.Name < b.Name end)

				context:Clear()

				local function onClick(name)
					if prop ~= inputProp then return end

					local enumItem = enum[name]
					inputProp = nil
					Properties.SetProp(prop,enumItem)
				end

				for i = 1,#sorted do
					local enumItem = sorted[i]
					context:Add({Name = enumItem.Name, OnClick = onClick})
				end

				context.Width = valueFrame.AbsoluteSize.X
				context:Show(valueFrame.AbsolutePosition.X, valueFrame.AbsolutePosition.Y + 22)
			end

			Properties.DisplayBrickColorEditor = function(prop,entryIndex,col)
				local editor = Properties.BrickColorEditor
				if not editor then
					editor = Lib.BrickColorPicker.new()
					editor.Gui.DisplayOrder = Main.DisplayOrders.Menu
					editor.ReverseYOffset = 22

					FrostznLife.Connect(editor.OnSelect,function(col)
						if not editor.CurrentProp or editor.CurrentProp.ValueType.Name ~= "BrickColor" then return end

						if editor.CurrentProp == inputProp then inputProp = nil end
						Properties.SetProp(editor.CurrentProp,BrickColor.new(col))
					end)

					FrostznLife.Connect(editor.OnMoreColors,function() -- TODO: Special Case BasePart.BrickColor to BasePart.Color
						editor:Close()
						local colProp
						for i,v in pairs(API.Classes.BasePart.Properties) do
							if v.Name == "Color" then
								colProp = v
								break
							end
						end
						Properties.DisplayColorEditor(colProp,editor.SavedColor.Color)
					end)

					Properties.BrickColorEditor = editor
				end

				local entry = propEntries[entryIndex]
				local valueFrame = entry.GuiElems.ValueFrame

				editor.CurrentProp = prop
				editor.SavedColor = col
				if prop and prop.Class == "BasePart" and prop.Name == "BrickColor" then
					editor:SetMoreColorsVisible(true)
				else
					editor:SetMoreColorsVisible(false)
				end
				editor:Show(valueFrame.AbsolutePosition.X, valueFrame.AbsolutePosition.Y + 22)
			end

			Properties.DisplayColorEditor = function(prop,col)
				local editor = Properties.ColorEditor
				if not editor then
					editor = Lib.ColorPicker.new()

					FrostznLife.Connect(editor.OnSelect,function(col)
						if not editor.CurrentProp then return end
						local typeName = editor.CurrentProp.ValueType.Name
						if typeName ~= "Color3" and typeName ~= "BrickColor" then return end

						local colVal = (typeName == "Color3" and col or BrickColor.new(col))

						if editor.CurrentProp == inputProp then inputProp = nil end
						Properties.SetProp(editor.CurrentProp,colVal)
					end)

					Properties.ColorEditor = editor
				end

				editor.CurrentProp = prop
				if col then
					editor:SetColor(col)
				else
					local firstVal = Properties.GetFirstPropVal(prop)
					if firstVal then editor:SetColor(firstVal) end
				end
				editor:Show()
			end

			Properties.DisplayNumberSequenceEditor = function(prop,seq)
				local editor = Properties.NumberSequenceEditor
				if not editor then
					editor = Lib.NumberSequenceEditor.new()

					FrostznLife.Connect(editor.OnSelect,function(val)
						if not editor.CurrentProp or editor.CurrentProp.ValueType.Name ~= "NumberSequence" then return end

						if editor.CurrentProp == inputProp then inputProp = nil end
						Properties.SetProp(editor.CurrentProp,val)
					end)

					Properties.NumberSequenceEditor = editor
				end

				editor.CurrentProp = prop
				if seq then
					editor:SetSequence(seq)
				else
					local firstVal = Properties.GetFirstPropVal(prop)
					if firstVal then editor:SetSequence(firstVal) end
				end
				editor:Show()
			end

			Properties.DisplayColorSequenceEditor = function(prop,seq)
				local editor = Properties.ColorSequenceEditor
				if not editor then
					editor = Lib.ColorSequenceEditor.new()

					FrostznLife.Connect(editor.OnSelect,function(val)
						if not editor.CurrentProp or editor.CurrentProp.ValueType.Name ~= "ColorSequence" then return end

						if editor.CurrentProp == inputProp then inputProp = nil end
						Properties.SetProp(editor.CurrentProp,val)
					end)

					Properties.ColorSequenceEditor = editor
				end

				editor.CurrentProp = prop
				if seq then
					editor:SetSequence(seq)
				else
					local firstVal = Properties.GetFirstPropVal(prop)
					if firstVal then editor:SetSequence(firstVal) end
				end
				editor:Show()
			end

			Properties.GetFirstPropVal = function(prop)
				local first = Properties.FindFirstObjWhichIsA(prop.Class)
				if first then
					return Properties.GetPropVal(prop,first)
				end
			end

			Properties.GetPropVal = function(prop,obj)
				if prop.MultiType then return "<Multiple Types>" end
				if not obj then return end

				local propVal
				if prop.IsAttribute then
					propVal = getAttribute(obj,prop.AttributeName)
					if propVal == nil then return nil end

					local typ = typeof(propVal)
					local currentType = Properties.TypeNameConvert[typ] or typ
					if prop.RootType then
						if prop.RootType.Name ~= currentType then
							return nil
						end
					elseif prop.ValueType.Name ~= currentType then
						return nil
					end
				else
					propVal = obj[prop.Name]
				end
				if prop.SubName then
					local indexes = string.split(prop.SubName,".")
					for i = 1,#indexes do
						local indexName = indexes[i]
						if #indexName > 0 and propVal then
							propVal = propVal[indexName]
						end
					end
				end

				return propVal
			end

			Properties.SelectObject = function(obj)
				if inputProp and inputProp.ValueType.Category == "Class" then
					local prop = inputProp
					inputProp = nil

					if isa(obj,prop.ValueType.Name) then
						Properties.SetProp(prop,obj)
					else
						Properties.Refresh()
					end

					return true
				end

				return false
			end

			Properties.DisplayProp = function(prop,entryIndex)
				local propName = prop.Name
				local typeData = prop.ValueType
				local typeName = typeData.Name
				local tags = prop.Tags
				local gName = prop.Class.."."..prop.Name..(prop.SubName or "")
				local propObj = autoUpdateObjs[gName]
				local entryData = propEntries[entryIndex]
				local UDim2 = UDim2

				local guiElems = entryData.GuiElems
				local valueFrame = guiElems.ValueFrame
				local valueBox = guiElems.ValueBox
				local colorButton = guiElems.ColorButton
				local colorPreview = guiElems.ColorPreview
				local gradient = guiElems.Gradient
				local enumArrow = guiElems.EnumArrow
				local checkbox = guiElems.Checkbox
				local rightButton = guiElems.RightButton
				local soundPreview = guiElems.SoundPreview

				local propVal = Properties.GetPropVal(prop,propObj)
				local inputFullName = inputProp and (inputProp.Class.."."..inputProp.Name..(inputProp.SubName or ""))

				local offset = 4
				local endOffset = 6

				-- Offsetting the ValueBox for ValueType specific buttons
				if (typeName == "Color3" or typeName == "BrickColor" or typeName == "ColorSequence") then
					colorButton.Visible = true
					enumArrow.Visible = false
					if propVal then
						gradient.Color = (typeName == "Color3" and ColorSequence.new(propVal)) or (typeName == "BrickColor" and ColorSequence.new(propVal.Color)) or propVal
					else
						gradient.Color = ColorSequence.new(Color3.new(1,1,1))
					end
					colorPreview.BorderColor3 = (typeName == "ColorSequence" and Color3.new(1,1,1) or Color3.new(0,0,0))
					offset = 22
					endOffset = 24 + (typeName == "ColorSequence" and 20 or 0)
				elseif typeData.Category == "Enum" then
					colorButton.Visible = false
					enumArrow.Visible = not prop.Tags.ReadOnly
					endOffset = 22
				elseif (gName == inputFullName and typeData.Category == "Class") or typeName == "NumberSequence" then
					colorButton.Visible = false
					enumArrow.Visible = false
					endOffset = 26
				else
					colorButton.Visible = false
					enumArrow.Visible = false
				end

				valueBox.Position = UDim2.new(0,offset,0,0)
				valueBox.Size = UDim2.new(1,-endOffset,1,0)

				-- Right button
				if inputFullName == gName and typeData.Category == "Class" then
					Main.MiscIcons:DisplayByKey(guiElems.RightButtonIcon, "Delete")
					guiElems.RightButtonIcon.Visible = true
					rightButton.Text = ""
					rightButton.Visible = true
				elseif typeName == "NumberSequence" or typeName == "ColorSequence" then
					guiElems.RightButtonIcon.Visible = false
					rightButton.Text = "..."
					rightButton.Visible = true
				else
					rightButton.Visible = false
				end

				-- Displays the correct ValueBox for the ValueType, and sets it to the prop value
				if typeName == "bool" or typeName == "PhysicalProperties" then
					valueBox.Visible = false
					checkbox.Visible = true
					soundPreview.Visible = false
					checkboxes[entryIndex].Disabled = tags.ReadOnly
					if typeName == "PhysicalProperties" and autoUpdateObjs[gName] then
						checkboxes[entryIndex]:SetState(propVal and true or false)
					else
						checkboxes[entryIndex]:SetState(propVal)
					end
				elseif typeName == "SoundPlayer" then
					valueBox.Visible = false
					checkbox.Visible = false
					soundPreview.Visible = true
					local playing = Properties.PreviewSound and Properties.PreviewSound.Playing
					Main.MiscIcons:DisplayByKey(soundPreview.ControlButton.Icon, playing and "Pause" or "Play")
				else
					valueBox.Visible = true
					checkbox.Visible = false
					soundPreview.Visible = false

					if propVal ~= nil then
						if typeName == "Color3" then
							valueBox.Text = "["..Lib.ColorToBytes(propVal).."]"
						elseif typeData.Category == "Enum" then
							valueBox.Text = propVal.Name
						elseif Properties.RoundableTypes[typeName] and Settings.Properties.NumberRounding then
							local rawStr = Properties.ValueToString(prop,propVal)
							valueBox.Text = rawStr:gsub("-?%d+%.%d+",function(num)
								return tostring(tonumber(("%."..Settings.Properties.NumberRounding.."f"):format(num)))
							end)
						else
							valueBox.Text = Properties.ValueToString(prop,propVal)
						end
					else
						valueBox.Text = ""
					end

					valueBox.TextColor3 = tags.ReadOnly and Settings.Theme.PlaceholderText or Settings.Theme.Text
				end
			end

			Properties.Refresh = function()
				local maxEntries = math.max(math.ceil((propsFrame.AbsoluteSize.Y) / 23),0)	
				local maxX = propsFrame.AbsoluteSize.X
				local valueWidth = math.max(Properties.MinInputWidth,maxX-Properties.ViewWidth)
				local inputPropVisible = false
				local isa = game.IsA
				local UDim2 = UDim2
				local stringSplit = string.split
				local scaleType = Settings.Properties.ScaleType

				-- Clear connections
				for i = 1,#propCons do
					propCons[i]:Disconnect()
				end
				table.clear(propCons)

				-- Hide full name viewer
				Properties.FullNameFrame.Visible = false
				Properties.FullNameFrameAttach.Disable()

				for i = 1,maxEntries do
					local entryData = propEntries[i]
					if not propEntries[i] then entryData = Properties.NewPropEntry(i) propEntries[i] = entryData end

					local entry = entryData.Gui
					local guiElems = entryData.GuiElems
					local nameFrame = guiElems.NameFrame
					local propNameLabel = guiElems.PropName
					local valueFrame = guiElems.ValueFrame
					local expand = guiElems.Expand
					local valueBox = guiElems.ValueBox
					local propNameBox = guiElems.PropName
					local rightButton = guiElems.RightButton
					local editAttributeButton = guiElems.EditAttributeButton
					local toggleAttributes = guiElems.ToggleAttributes

					local prop = viewList[i + Properties.Index]
					if prop then
						local entryXOffset = (scaleType == 0 and scrollH.Index or 0)
						entry.Visible = true
						entry.Position = UDim2.new(0,-entryXOffset,0,entry.Position.Y.Offset)
						entry.Size = UDim2.new(scaleType == 0 and 0 or 1, scaleType == 0 and Properties.ViewWidth + valueWidth or 0,0,22)

						if prop.SpecialRow then
							if prop.SpecialRow == "AddAttribute" then
								nameFrame.Visible = false
								valueFrame.Visible = false
								guiElems.RowButton.Visible = true
							end
						else
							-- Revert special row stuff
							nameFrame.Visible = true
							guiElems.RowButton.Visible = false

							local depth = Properties.EntryIndent*(prop.Depth or 1)
							local leftOffset = depth + Properties.EntryOffset
							nameFrame.Position = UDim2.new(0,leftOffset,0,0)
							propNameLabel.Size = UDim2.new(1,-2 - (scaleType == 0 and 0 or 6),1,0)

							local gName = (prop.CategoryName and "CAT_"..prop.CategoryName) or prop.Class.."."..prop.Name..(prop.SubName or "")

							if prop.CategoryName then
								entry.BackgroundColor3 = Settings.Theme.Main1
								valueFrame.Visible = false

								propNameBox.Text = prop.CategoryName
								propNameBox.Font = Enum.Font.SourceSansBold
								expand.Visible = true
								propNameBox.TextColor3 = Settings.Theme.Text
								nameFrame.BackgroundTransparency = 1
								nameFrame.Size = UDim2.new(1,0,1,0)
								editAttributeButton.Visible = false

								local showingAttrs = Settings.Properties.ShowAttributes
								toggleAttributes.Position = UDim2.new(1,-85-leftOffset,0,0)
								toggleAttributes.Text = (showingAttrs and "[Setting: ON]" or "[Setting: OFF]")
								toggleAttributes.TextColor3 = Settings.Theme.Text
								toggleAttributes.Visible = (prop.CategoryName == "Attributes")
							else
								local propName = prop.Name
								local typeData = prop.ValueType
								local typeName = typeData.Name
								local tags = prop.Tags
								local propObj = autoUpdateObjs[gName]

								local attributeOffset = (prop.IsAttribute and 20 or 0)
								editAttributeButton.Visible = (prop.IsAttribute and not prop.RootType)
								toggleAttributes.Visible = false

								-- Moving around the frames
								if scaleType == 0 then
									nameFrame.Size = UDim2.new(0,Properties.ViewWidth - leftOffset - 1,1,0)
									valueFrame.Position = UDim2.new(0,Properties.ViewWidth,0,0)
									valueFrame.Size = UDim2.new(0,valueWidth - attributeOffset,1,0)
								else
									nameFrame.Size = UDim2.new(0.5,-leftOffset - 1,1,0)
									valueFrame.Position = UDim2.new(0.5,0,0,0)
									valueFrame.Size = UDim2.new(0.5,-attributeOffset,1,0)
								end

								local nameArr = stringSplit(gName,".")
								propNameBox.Text = prop.DisplayName or nameArr[#nameArr]
								propNameBox.Font = Enum.Font.SourceSans
								entry.BackgroundColor3 = Settings.Theme.Main2
								valueFrame.Visible = true

								expand.Visible = typeData.Category == "DataType" and Properties.ExpandableTypes[typeName] or Properties.ExpandableProps[gName]
								propNameBox.TextColor3 = tags.ReadOnly and Settings.Theme.PlaceholderText or Settings.Theme.Text

								-- Display property value
								Properties.DisplayProp(prop,i)
								if propObj then
									if prop.IsAttribute then
										propCons[#propCons+1] = FrostznLife.Connect(getAttributeChangedSignal(propObj,prop.AttributeName),function()
											Properties.DisplayProp(prop,i)
										end)
									else
										propCons[#propCons+1] = FrostznLife.Connect(getPropChangedSignal(propObj,propName),function()
											Properties.DisplayProp(prop,i)
										end)
									end
								end

								-- Position and resize Input Box
								local beforeVisible = valueBox.Visible
								local inputFullName = inputProp and (inputProp.Class.."."..inputProp.Name..(inputProp.SubName or ""))
								if gName == inputFullName then
									nameFrame.BackgroundColor3 = Settings.Theme.ListSelection
									nameFrame.BackgroundTransparency = 0
									if typeData.Category == "Class" or typeData.Category == "Enum" or typeName == "BrickColor" then
										valueFrame.BackgroundColor3 = Settings.Theme.TextBox
										valueFrame.BackgroundTransparency = 0
										valueBox.Visible = true
									else
										inputPropVisible = true
										local scale = (scaleType == 0 and 0 or 0.5)
										local offset = (scaleType == 0 and Properties.ViewWidth-scrollH.Index or 0)
										local endOffset = 0

										if typeName == "Color3" or typeName == "ColorSequence" then
											offset = offset + 22
										end

										if typeName == "NumberSequence" or typeName == "ColorSequence" then
											endOffset = 20
										end

										inputBox.Position = UDim2.new(scale,offset,0,entry.Position.Y.Offset)
										inputBox.Size = UDim2.new(1-scale,-offset-endOffset-attributeOffset,0,22)
										inputBox.Visible = true
										valueBox.Visible = false
									end
								else
									nameFrame.BackgroundColor3 = Settings.Theme.Main1
									nameFrame.BackgroundTransparency = 1
									valueFrame.BackgroundColor3 = Settings.Theme.Main1
									valueFrame.BackgroundTransparency = 1
									valueBox.Visible = beforeVisible
								end
							end

							-- Expand
							if prop.CategoryName or Properties.ExpandableTypes[prop.ValueType and prop.ValueType.Name] or Properties.ExpandableProps[gName] then
								if Lib.CheckMouseInGui(expand) then
									Main.MiscIcons:DisplayByKey(expand.Icon, expanded[gName] and "Collapse_Over" or "Expand_Over")
								else
									Main.MiscIcons:DisplayByKey(expand.Icon, expanded[gName] and "Collapse" or "Expand")
								end
								expand.Visible = true
							else
								expand.Visible = false
							end
						end
						entry.Visible = true
					else
						entry.Visible = false
					end
				end

				if not inputPropVisible then
					inputBox.Visible = false
				end

				for i = maxEntries+1,#propEntries do
					propEntries[i].Gui:Destroy()
					propEntries[i] = nil
					checkboxes[i] = nil
				end
			end

			Properties.SetProp = function(prop,val,noupdate,prevAttribute)
				local sList = Explorer.Selection.List
				local propName = prop.Name
				local subName = prop.SubName
				local propClass = prop.Class
				local typeData = prop.ValueType
				local typeName = typeData.Name
				local attributeName = prop.AttributeName
				local rootTypeData = prop.RootType
				local rootTypeName = rootTypeData and rootTypeData.Name
				local fullName = prop.Class.."."..prop.Name..(prop.SubName or "")
				local Vector3 = Vector3

				for i = 1,#sList do
					local node = sList[i]
					local obj = node.Obj

					if isa(obj,propClass) then
						pcall(function()
							local setVal = val
							local root
							if prop.IsAttribute then
								root = getAttribute(obj,attributeName)
							else
								root = obj[propName]
							end

							if prevAttribute then
								if prevAttribute.ValueType.Name == typeName then
									setVal = getAttribute(obj,prevAttribute.AttributeName) or setVal
								end
								setAttribute(obj,prevAttribute.AttributeName,nil)
							end

							if rootTypeName then
								if rootTypeName == "Vector2" then
									setVal = Vector2.new((subName == ".X" and setVal) or root.X, (subName == ".Y" and setVal) or root.Y)
								elseif rootTypeName == "Vector3" then
									setVal = Vector3.new((subName == ".X" and setVal) or root.X, (subName == ".Y" and setVal) or root.Y, (subName == ".Z" and setVal) or root.Z)
								elseif rootTypeName == "UDim" then
									setVal = UDim.new((subName == ".Scale" and setVal) or root.Scale, (subName == ".Offset" and setVal) or root.Offset)
								elseif rootTypeName == "UDim2" then
									local rootX,rootY = root.X,root.Y
									local X_UDim = (subName == ".X" and setVal) or UDim.new((subName == ".X.Scale" and setVal) or rootX.Scale, (subName == ".X.Offset" and setVal) or rootX.Offset)
									local Y_UDim = (subName == ".Y" and setVal) or UDim.new((subName == ".Y.Scale" and setVal) or rootY.Scale, (subName == ".Y.Offset" and setVal) or rootY.Offset)
									setVal = UDim2.new(X_UDim,Y_UDim)
								elseif rootTypeName == "CFrame" then
									local rootPos,rootRight,rootUp,rootLook = root.Position,root.RightVector,root.UpVector,root.LookVector
									local pos = (subName == ".Position" and setVal) or Vector3.new((subName == ".Position.X" and setVal) or rootPos.X, (subName == ".Position.Y" and setVal) or rootPos.Y, (subName == ".Position.Z" and setVal) or rootPos.Z)
									local rightV = (subName == ".RightVector" and setVal) or Vector3.new((subName == ".RightVector.X" and setVal) or rootRight.X, (subName == ".RightVector.Y" and setVal) or rootRight.Y, (subName == ".RightVector.Z" and setVal) or rootRight.Z)
									local upV = (subName == ".UpVector" and setVal) or Vector3.new((subName == ".UpVector.X" and setVal) or rootUp.X, (subName == ".UpVector.Y" and setVal) or rootUp.Y, (subName == ".UpVector.Z" and setVal) or rootUp.Z)
									local lookV = (subName == ".LookVector" and setVal) or Vector3.new((subName == ".LookVector.X" and setVal) or rootLook.X, (subName == ".RightVector.Y" and setVal) or rootLook.Y, (subName == ".RightVector.Z" and setVal) or rootLook.Z)
									setVal = CFrame.fromMatrix(pos,rightV,upV,-lookV)
								elseif rootTypeName == "Rect" then
									local rootMin,rootMax = root.Min,root.Max
									local min = Vector2.new((subName == ".Min.X" and setVal) or rootMin.X, (subName == ".Min.Y" and setVal) or rootMin.Y)
									local max = Vector2.new((subName == ".Max.X" and setVal) or rootMax.X, (subName == ".Max.Y" and setVal) or rootMax.Y)
									setVal = Rect.new(min,max)
								elseif rootTypeName == "PhysicalProperties" then
									local rootProps = PhysicalProperties.new(obj.Material)
									local density = (subName == ".Density" and setVal) or (root and root.Density) or rootProps.Density
									local friction = (subName == ".Friction" and setVal) or (root and root.Friction) or rootProps.Friction
									local elasticity = (subName == ".Elasticity" and setVal) or (root and root.Elasticity) or rootProps.Elasticity
									local frictionWeight = (subName == ".FrictionWeight" and setVal) or (root and root.FrictionWeight) or rootProps.FrictionWeight
									local elasticityWeight = (subName == ".ElasticityWeight" and setVal) or (root and root.ElasticityWeight) or rootProps.ElasticityWeight
									setVal = PhysicalProperties.new(density,friction,elasticity,frictionWeight,elasticityWeight)
								elseif rootTypeName == "Ray" then
									local rootOrigin,rootDirection = root.Origin,root.Direction
									local origin = (subName == ".Origin" and setVal) or Vector3.new((subName == ".Origin.X" and setVal) or rootOrigin.X, (subName == ".Origin.Y" and setVal) or rootOrigin.Y, (subName == ".Origin.Z" and setVal) or rootOrigin.Z)
									local direction = (subName == ".Direction" and setVal) or Vector3.new((subName == ".Direction.X" and setVal) or rootDirection.X, (subName == ".Direction.Y" and setVal) or rootDirection.Y, (subName == ".Direction.Z" and setVal) or rootDirection.Z)
									setVal = Ray.new(origin,direction)
								elseif rootTypeName == "Faces" then
									local faces = {}
									local faceList = {"Back","Bottom","Front","Left","Right","Top"}
									for _,face in pairs(faceList) do
										local val
										if subName == "."..face then
											val = setVal
										else
											val = root[face]
										end
										if val then faces[#faces+1] = Enum.NormalId[face] end
									end
									setVal = Faces.new(unpack(faces))
								elseif rootTypeName == "Axes" then
									local axes = {}
									local axesList = {"X","Y","Z"}
									for _,axe in pairs(axesList) do
										local val
										if subName == "."..axe then
											val = setVal
										else
											val = root[axe]
										end
										if val then axes[#axes+1] = Enum.Axis[axe] end
									end
									setVal = Axes.new(unpack(axes))
								elseif rootTypeName == "NumberRange" then
									setVal = NumberRange.new(subName == ".Min" and setVal or root.Min, subName == ".Max" and setVal or root.Max)
								end
							end

							if typeName == "PhysicalProperties" and setVal then
								setVal = root or PhysicalProperties.new(obj.Material)
							end

							if prop.IsAttribute then
								setAttribute(obj,attributeName,setVal)
							else
								obj[propName] = setVal
							end
						end)
					end
				end

				if not noupdate then
					Properties.ComputeConflicts(prop)
				end
			end

			Properties.InitInputBox = function()
				inputBox = create({
					{1,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderSizePixel=0,Name="InputBox",Size=UDim2.new(0,200,0,22),Visible=false,ZIndex=2,}},
					{2,"TextBox",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BackgroundTransparency=1,BorderColor3=Color3.new(0.062745101749897,0.51764708757401,1),BorderSizePixel=0,ClearTextOnFocus=false,Font=3,Parent={1},PlaceholderColor3=Color3.new(0.69803923368454,0.69803923368454,0.69803923368454),Position=UDim2.new(0,3,0,0),Size=UDim2.new(1,-6,1,0),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,ZIndex=2,}},
				})
				inputTextBox = inputBox.TextBox
				inputBox.BackgroundColor3 = Settings.Theme.TextBox
				inputBox.Parent = Properties.Window.GuiElems.Content.List

				FrostznLife.Connect(inputTextBox.FocusLost,function()
					if not inputProp then return end

					local prop = inputProp
					inputProp = nil
					local val = Properties.StringToValue(prop,inputTextBox.Text)
					if val then Properties.SetProp(prop,val) else Properties.Refresh() end
				end)

				FrostznLife.Connect(inputTextBox.Focused,function()
					inputTextBox.SelectionStart = 1
					inputTextBox.CursorPosition = #inputTextBox.Text + 1
				end)

				Lib.ViewportTextBox.convert(inputTextBox)
			end

			Properties.SetInputProp = function(prop,entryIndex,special)
				local typeData = prop.ValueType
				local typeName = typeData.Name
				local fullName = prop.Class.."."..prop.Name..(prop.SubName or "")
				local propObj = autoUpdateObjs[fullName]
				local propVal = Properties.GetPropVal(prop,propObj)

				if prop.Tags.ReadOnly then return end

				inputProp = prop
				if special then
					if special == "color" then
						if typeName == "Color3" then
							inputTextBox.Text = propVal and Properties.ValueToString(prop,propVal) or ""
							Properties.DisplayColorEditor(prop,propVal)
						elseif typeName == "BrickColor" then
							Properties.DisplayBrickColorEditor(prop,entryIndex,propVal)
						elseif typeName == "ColorSequence" then
							inputTextBox.Text = propVal and Properties.ValueToString(prop,propVal) or ""
							Properties.DisplayColorSequenceEditor(prop,propVal)
						end
					elseif special == "right" then
						if typeName == "NumberSequence" then
							inputTextBox.Text = propVal and Properties.ValueToString(prop,propVal) or ""
							Properties.DisplayNumberSequenceEditor(prop,propVal)
						elseif typeName == "ColorSequence" then
							inputTextBox.Text = propVal and Properties.ValueToString(prop,propVal) or ""
							Properties.DisplayColorSequenceEditor(prop,propVal)
						end
					end
				else
					if Properties.IsTextEditable(prop) then
						inputTextBox.Text = propVal and Properties.ValueToString(prop,propVal) or ""
						inputTextBox:CaptureFocus()
					elseif typeData.Category == "Enum" then
						Properties.DisplayEnumDropdown(entryIndex)
					elseif typeName == "BrickColor" then
						Properties.DisplayBrickColorEditor(prop,entryIndex,propVal)
					end
				end
				Properties.Refresh()
			end

			Properties.InitSearch = function()
				local TweenService = service.TweenService
				local SearchFrame = Properties.GuiElems.ToolBar.SearchFrame
				local searchBox = SearchFrame.SearchBox

				local TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint)

				local Tweens = {
					Start = TweenService:Create(SearchFrame.UIStroke, TweenInfo, { Color = Color3.fromRGB(0, 120, 215) }),
					End = TweenService:Create(SearchFrame.UIStroke, TweenInfo, { Color = Color3.fromRGB(42, 42, 42) })
				}

				Lib.ViewportTextBox.convert(searchBox)

				FrostznLife.Connect(searchBox.FocusLost,function() Tweens.End:Play() end)
				FrostznLife.Connect(searchBox.Focused,function() Tweens.Start:Play() end)

				FrostznLife.Connect(searchBox:GetPropertyChangedSignal("Text"),function()
					Properties.SearchText = searchBox.Text
					Properties.Update()
					Properties.Refresh()
				end)
			end

			Properties.InitEntryStuff = function()
				Properties.EntryTemplate = create({
					{1,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderColor3=Color3.new(0.1294117718935,0.1294117718935,0.1294117718935),Font=3,Name="Entry",Position=UDim2.new(0,1,0,1),Size=UDim2.new(0,250,0,22),Text="",TextSize=14,}},
					{2,"Frame",{BackgroundColor3=Color3.new(0.04313725605607,0.35294118523598,0.68627452850342),BackgroundTransparency=1,BorderColor3=Color3.new(0.33725491166115,0.49019610881805,0.73725491762161),BorderSizePixel=0,Name="NameFrame",Parent={1},Position=UDim2.new(0,20,0,0),Size=UDim2.new(1,-40,1,0),}},
					{3,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="PropName",Parent={2},Position=UDim2.new(0,2,0,0),Size=UDim2.new(1,-2,1,0),Text="Anchored",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=0.10000000149012,TextTruncate=1,TextXAlignment=0,}},
					{4,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ClipsDescendants=true,Font=3,Name="Expand",Parent={2},Position=UDim2.new(0,-20,0,1),Size=UDim2.new(0,20,0,20),Text="",TextSize=14,Visible=false,}},
					{5,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5642383285",ImageRectOffset=Vector2.new(144,16),ImageRectSize=Vector2.new(16,16),Name="Icon",Parent={4},Position=UDim2.new(0,2,0,2),ScaleType=4,Size=UDim2.new(0,16,0,16),}},
					{6,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=4,Name="ToggleAttributes",Parent={2},Position=UDim2.new(1,-85,0,0),Size=UDim2.new(0,85,0,22),Text="[SETTING: OFF]",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=0.10000000149012,Visible=false,}},
					{7,"Frame",{BackgroundColor3=Color3.new(0.04313725605607,0.35294118523598,0.68627452850342),BackgroundTransparency=1,BorderColor3=Color3.new(0.33725491166115,0.49019607901573,0.73725491762161),BorderSizePixel=0,Name="ValueFrame",Parent={1},Position=UDim2.new(1,-100,0,0),Size=UDim2.new(0,80,1,0),}},
					{8,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderColor3=Color3.new(0.33725491166115,0.49019610881805,0.73725491762161),BorderSizePixel=0,Name="Line",Parent={7},Position=UDim2.new(0,-1,0,0),Size=UDim2.new(0,1,1,0),}},
					{9,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="ColorButton",Parent={7},Size=UDim2.new(0,20,0,22),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,Visible=false,}},
					{10,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0,0,0),Name="ColorPreview",Parent={9},Position=UDim2.new(0,5,0,6),Size=UDim2.new(0,10,0,10),}},
					{11,"UIGradient",{Parent={10},}},
					{12,"Frame",{BackgroundTransparency=1,Name="EnumArrow",Parent={7},Position=UDim2.new(1,-16,0,3),Size=UDim2.new(0,16,0,16),Visible=false,}},
					{13,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={12},Position=UDim2.new(0,8,0,9),Size=UDim2.new(0,1,0,1),}},
					{14,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={12},Position=UDim2.new(0,7,0,8),Size=UDim2.new(0,3,0,1),}},
					{15,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={12},Position=UDim2.new(0,6,0,7),Size=UDim2.new(0,5,0,1),}},
					{16,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="ValueBox",Parent={7},Position=UDim2.new(0,4,0,0),Size=UDim2.new(1,-8,1,0),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=0.10000000149012,TextTruncate=1,TextXAlignment=0,}},
					{17,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="RightButton",Parent={7},Position=UDim2.new(1,-20,0,0),Size=UDim2.new(0,20,0,22),Text="...",TextColor3=Color3.new(1,1,1),TextSize=14,Visible=false,}},
					{18,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="SettingsButton",Parent={7},Position=UDim2.new(1,-20,0,0),Size=UDim2.new(0,20,0,22),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,Visible=false,}},
					{19,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="SoundPreview",Parent={7},Size=UDim2.new(1,0,1,0),Visible=false,}},
					{20,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="ControlButton",Parent={19},Size=UDim2.new(0,20,0,22),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
					{21,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5642383285",ImageRectOffset=Vector2.new(144,16),ImageRectSize=Vector2.new(16,16),Name="Icon",Parent={20},Position=UDim2.new(0,2,0,3),ScaleType=4,Size=UDim2.new(0,16,0,16),}},
					{22,"Frame",{BackgroundColor3=Color3.new(0.3137255012989,0.3137255012989,0.3137255012989),BorderSizePixel=0,Name="TimeLine",Parent={19},Position=UDim2.new(0,26,0.5,-1),Size=UDim2.new(1,-34,0,2),}},
					{23,"Frame",{BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.1294117718935,0.1294117718935,0.1294117718935),Name="Slider",Parent={22},Position=UDim2.new(0,-4,0,-8),Size=UDim2.new(0,8,0,18),}},
					{24,"TextButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="EditAttributeButton",Parent={1},Position=UDim2.new(1,-20,0,0),Size=UDim2.new(0,20,0,22),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
					{25,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5034718180",ImageTransparency=0.20000000298023,Name="Icon",Parent={24},Position=UDim2.new(0,2,0,3),Size=UDim2.new(0,16,0,16),}},
					{26,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderSizePixel=0,Font=3,Name="RowButton",Parent={1},Size=UDim2.new(1,0,1,0),Text="Add Attribute",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=0.10000000149012,Visible=false,}},
				})

				local fullNameFrame = Lib.Frame.new()
				local label = Lib.Label.new()
				label.Parent = fullNameFrame.Gui
				label.Position = UDim2.new(0,2,0,0)
				label.Size = UDim2.new(1,-4,1,0)
				fullNameFrame.Visible = false
				fullNameFrame.Parent = window.Gui

				Properties.FullNameFrame = fullNameFrame
				Properties.FullNameFrameAttach = Lib.AttachTo(fullNameFrame)
			end

			Properties.Init = function() -- TODO: MAKE BETTER
				local guiItems = create({
					{1,"Folder",{Name="Items",}},
					{2,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="ToolBar",Parent={1},Size=UDim2.new(1,0,0,22),}},
					{3,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.1176470592618,0.1176470592618,0.1176470592618),BorderSizePixel=0,Name="SearchFrame",Parent={2},Position=UDim2.new(0,3,0,1),Size=UDim2.new(1,-6,0,18),}},
					{4,"TextBox",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ClearTextOnFocus=false,Font=3,Name="SearchBox",Parent={3},PlaceholderColor3=Color3.new(0.39215689897537,0.39215689897537,0.39215689897537),PlaceholderText="Search properties",Position=UDim2.new(0,4,0,0),Size=UDim2.new(1,-24,0,18),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,}},
					{5,"UICorner",{CornerRadius=UDim.new(0,2),Parent={3},}},
					{6,"UIStroke",{Thickness=1.4,Parent={3},Color=Color3.fromRGB(42,42,42)}},
					{7,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Reset",Parent={3},Position=UDim2.new(1,-17,0,1),Size=UDim2.new(0,16,0,16),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
					{8,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5034718129",ImageColor3=Color3.new(0.39215686917305,0.39215686917305,0.39215686917305),Parent={7},Size=UDim2.new(0,16,0,16),}},
					{9,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Refresh",Parent={2},Position=UDim2.new(1,-20,0,1),Size=UDim2.new(0,18,0,18),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,Visible=false,}},
					{10,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5642310344",Parent={9},Position=UDim2.new(0,3,0,3),Size=UDim2.new(0,12,0,12),}},
					{11,"Frame",{BackgroundColor3=Color3.new(0.15686275064945,0.15686275064945,0.15686275064945),BorderSizePixel=0,Name="ScrollCorner",Parent={1},Position=UDim2.new(1,-16,1,-16),Size=UDim2.new(0,16,0,16),Visible=false,}},
					{12,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ClipsDescendants=true,Name="List",Parent={1},Position=UDim2.new(0,0,0,23),Size=UDim2.new(1,0,1,-23),}},
				})

				-- Vars
				categoryOrder =	API.CategoryOrder
				for category,_ in next,categoryOrder do
					if not Properties.CollapsedCategories[category] then
						expanded["CAT_"..category] = true
					end
				end
				expanded["Sound.SoundId"] = true

				-- Init window
				window = Lib.Window.new()
				Properties.Window = window
				window:SetTitle("Properties")

				toolBar = guiItems.ToolBar
				propsFrame = guiItems.List

				Properties.GuiElems.ToolBar = toolBar
				Properties.GuiElems.PropsFrame = propsFrame

				Properties.InitEntryStuff()

				-- Window events
				FrostznLife.Connect(window.GuiElems.Main:GetPropertyChangedSignal("AbsoluteSize"),function()
					if Properties.Window:IsContentVisible() then
						Properties.UpdateView()
						Properties.Refresh()
					end
				end)
				FrostznLife.Connect(window.OnActivate,function()
					Properties.UpdateView()
					Properties.Update()
					Properties.Refresh()
				end)
				FrostznLife.Connect(window.OnRestore,function()
					Properties.UpdateView()
					Properties.Update()
					Properties.Refresh()
				end)

				-- Init scrollbars
				scrollV = Lib.ScrollBar.new()		
				scrollV.WheelIncrement = 3
				scrollV.Gui.Position = UDim2.new(1,-16,0,23)
				scrollV:SetScrollFrame(propsFrame)
				FrostznLife.Connect(scrollV.Scrolled,function()
					Properties.Index = scrollV.Index
					Properties.Refresh()
				end)

				scrollH = Lib.ScrollBar.new(true)
				scrollH.Increment = 5
				scrollH.WheelIncrement = 20
				scrollH.Gui.Position = UDim2.new(0,0,1,-16)
				FrostznLife.Connect(scrollH.Scrolled,function()
					Properties.Refresh()
				end)

				-- Setup Gui
				window.GuiElems.Line.Position = UDim2.new(0,0,0,22)
				toolBar.Parent = window.GuiElems.Content
				propsFrame.Parent = window.GuiElems.Content
				guiItems.ScrollCorner.Parent = window.GuiElems.Content
				scrollV.Gui.Parent = window.GuiElems.Content
				scrollH.Gui.Parent = window.GuiElems.Content
				Properties.InitInputBox()
				Properties.InitSearch()
			end

			return Properties
		end

		return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
	end,
    ScriptViewer=function()
        local Main,Lib,Apps,Settings,API,RMD,env,service,plr,create,createSimple
        local function initDeps(data)
            Main,Lib,Apps,Settings=data.Main,data.Lib,data.Apps,data.Settings
            API,RMD,env,service,plr,create,createSimple=data.API,data.RMD,data.env,data.service,data.plr,data.create,data.createSimple
        end
        local function main()
            local app={};local window,codeFrame,tabs,status
            local documents,current={},nil
            local generation=0
            local function sync()
                if current and codeFrame then current.text=codeFrame:GetText() end
            end
            local function activate(doc)
                generation+=1;sync();current=doc;app.SelectedScript=doc and doc.source
                codeFrame.Editable=doc and not doc.readonly or false
                codeFrame:SetText(doc and doc.text or "")
                status.Text=doc and doc.status or "Nenhuma aba aberta"
            end
            local function renderTabs()
                for _,o in ipairs(tabs:GetChildren()) do o:Destroy() end
                for i,doc in ipairs(documents) do
                    local b=createSimple("TextButton",{Position=UDim2.fromOffset((i-1)*140,0),Size=UDim2.fromOffset(136,25),
                        Text=doc.name,Font=Enum.Font.SourceSans,TextSize=14,TextColor3=Settings.Theme.Text,
                        BackgroundColor3=doc==current and Settings.Theme.ListSelection or Settings.Theme.Button,BorderSizePixel=0,
                        TextTruncate=Enum.TextTruncate.AtEnd,Parent=tabs})
                    FrostznLife.Connect(b.MouseButton1Click,function()activate(doc);renderTabs()end)
                end
                tabs.CanvasSize=UDim2.fromOffset(#documents*140,0)
            end
            local function add(name,text,readonly,source,message)
                sync()
                if #documents>=20 then status.Text="20 abas abertas • feche uma aba antes de continuar";return end
                local doc={name=name,text=text,readonly=readonly,source=source,status=message or "Rascunho local"}
                documents[#documents+1]=doc;activate(doc);renderTabs()
                return doc
            end
            app.NewDocument=function(name,text)
                add(name or "Rascunho.lua",text or "-- Frostzn • rascunho local\n",false,nil);window:Show()
            end
            app.GetText=function()sync();return current and current.text or "" end
            app.CloseDocument=function()
                if not current then return end
                sync()
                -- Rascunhos ficam recuperaveis durante a sessao, inclusive apos fechar a aba.
                app.ClosedDrafts=app.ClosedDrafts or {}
                if not current.readonly then app.ClosedDrafts[#app.ClosedDrafts+1]=current end
                table.remove(documents,table.find(documents,current))
                current=nil;activate(documents[#documents]);renderTabs()
            end
            app.ViewScript=function(scriptObject)
                generation+=1;local token=generation
                for _,doc in ipairs(documents) do if doc.source==scriptObject then
                    activate(doc);renderTabs();window:Show();return
                end end
                window:Show()
                local path=scriptObject:GetFullName()
                local server=scriptObject:IsA("Script") and scriptObject.RunContext~=Enum.RunContext.Client
                local ok,source=pcall(function()return scriptObject.Source end)
                if server and not (ok and type(source)=="string" and source~="") then
                    add(scriptObject.Name.." [servidor]","-- "..path.."\n\n-- Instancia presente no cliente; a fonte do servidor nao e replicada.\n-- Nao existe acesso ao codigo exclusivo do servidor por este cliente.\n",true,scriptObject,"Servidor • fonte indisponível no cliente")
                    return
                end
                if ok and type(source)=="string" and source~="" then
                    if #source>250000 then status.Text="Fonte acima de 250 KB • não carregada para preservar a interface";return end
                    add(scriptObject.Name..".lua",source,false,scriptObject,"Fonte legível • edição local")
                else
                    add(scriptObject.Name.." [cliente]","-- "..path.."\n\n-- A fonte original nao esta legivel neste ambiente.\n-- Decompilar cliente usa apenas a funcao ja fornecida pelo executor, se existir.\n-- Nenhum decompilador externo sera instalado automaticamente.\n",true,scriptObject,"Cliente • Source indisponível")
                end
                app.SelectedScript=scriptObject
            end
            app.Init=function()
                window=Lib.Window.new();window:SetTitle("Frostzn • Editor de scripts");window:Resize(700,470);app.Window=window
                window.MinX=360;window.MinY=240
                local content=window.GuiElems.Content
                local toolbar=createSimple("ScrollingFrame",{Name="Actions",Position=UDim2.fromOffset(0,36),Size=UDim2.new(1,0,0,29),BackgroundTransparency=1,BorderSizePixel=0,
                    ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.fromOffset(675,0),Parent=content})
                tabs=createSimple("ScrollingFrame",{Position=UDim2.fromOffset(5,4),Size=UDim2.new(1,-10,0,28),
                    BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new(),Parent=content})
                local function action(text,x,width,callback)
                    local b=createSimple("TextButton",{Text=text,Font=Enum.Font.SourceSans,TextSize=13,TextColor3=Settings.Theme.Text,
                        BackgroundColor3=Settings.Theme.Button,BorderSizePixel=0,Position=UDim2.fromOffset(x,0),Size=UDim2.fromOffset(width,25),Parent=toolbar})
                    FrostznLife.Connect(b.MouseButton1Click,callback);return b
                end
                codeFrame=Lib.CodeFrame.new();codeFrame.Frame.Position=UDim2.fromOffset(0,66);codeFrame.Frame.Size=UDim2.new(1,0,1,-90);codeFrame.Frame.Parent=content
                status=createSimple("TextLabel",{Text="",Font=Enum.Font.SourceSans,TextSize=12,TextColor3=Settings.Theme.PlaceholderText,
                    BackgroundColor3=Settings.Theme.Main2,BorderSizePixel=0,Position=UDim2.new(0,0,1,-22),Size=UDim2.new(1,0,0,22),TextXAlignment=Enum.TextXAlignment.Left,Parent=content})
                action("+ Rascunho",5,82,function()app.NewDocument()end)
                action("Copiar",92,65,function()
                    sync();if env.setclipboard then env.setclipboard(app.GetText());status.Text="Texto copiado" else status.Text="Clipboard indisponível" end
                end)
                action("Exportar",162,70,function()
                    sync();if not env.writefile then status.Text="API de arquivo indisponível";return end
                    local name=(current and current.name or "Rascunho.lua"):gsub("[^%w_.%-]","_")
                    local file="FrostznDex/saved/"..os.time().."_"..math.random(1000,9999).."_"..name
                    local ok,err=pcall(env.writefile,file,app.GetText());status.Text=ok and "Exportado em FrostznDex/saved" or tostring(err):sub(1,100)
                end)
                action("Aplicar Source",237,94,function()
                    sync();if not current or not current.source or current.readonly then status.Text="Abra uma fonte legível para aplicar";return end
                    local ok=pcall(function()current.source.Source=current.text end)
                    status.Text=ok and "Source local atualizado; script não reiniciado" or "Source protegido • rascunho preservado"
                end)
                action("Decompilar cliente",336,120,function()
                    local target=app.SelectedScript
                    if not target or not env.isViableDecompileScript(target) then status.Text="Selecione um script de cliente compatível";return end
                    if not env.decompile then status.Text="Executor sem decompilador local • nenhuma fonte foi recuperada";return end
                    generation+=1;local token=generation
                    status.Text="Processando o script selecionado..."
                    FrostznLife.Spawn(function()
                        local ok,result=pcall(env.decompile,target)
                        if not FrostznLife.Alive or token~=generation then return end
                        if not ok or type(result)~="string" or result=="" then status.Text="Não foi possível recuperar código neste ambiente";return end
                        if #result>250000 then status.Text="Resultado acima de 250 KB • limite de apresentação";return end
                        add(target.Name.." [reconstruído]",result,false,target,"Reconstrução do cliente • pode diferir do original")
                    end)
                end)
                action("Fechar aba",461,80,app.CloseDocument)
                action("Reabrir rascunho",546,120,function()
                    local drafts=app.ClosedDrafts or {}
                    local doc=drafts[#drafts]
                    if not doc then status.Text="Nenhum rascunho fechado";return end
                    if #documents>=20 then status.Text="Feche uma aba antes de reabrir";return end
                    table.remove(drafts);documents[#documents+1]=doc;activate(doc);renderTabs()
                end)
                app.GetCurrent=function()sync();return current end
                app.CodeFrame=codeFrame
                add("Bem-vindo","-- FROSTZN DEX\n-- Base: Dex / Moon / LorekeeperZinnia / Infinite Yield\n-- Editor com sintaxe, abas e rascunhos locais.\n-- Scripts exclusivos do servidor nao sao replicados.\n",true,nil,"Cliente • fontes do servidor indisponíveis")
            end
            return app
        end
        return {InitDeps=initDeps,InitAfterMain=function()end,Main=main}
    end,
	Lib = function()
--[[
	Lib Module
	
	Container for functions and classes
]]

		-- Common Locals
		local Main,Lib,Apps,Settings -- Main Containers
		local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
		local API,RMD,env,service,plr,create,createSimple -- Main Locals

		local function initDeps(data)
			Main = data.Main
			Lib = data.Lib
			Apps = data.Apps
			Settings = data.Settings

			API = data.API
			RMD = data.RMD
			env = data.env
			service = data.service
			plr = data.plr
			create = data.create
			createSimple = data.createSimple
		end

		local function initAfterMain()
			Explorer = Apps.Explorer
			Properties = Apps.Properties
			ScriptViewer = Apps.ScriptViewer
			Notebook = Apps.Notebook
		end

		local function main()
			local Lib = {}

			local renderStepped = service.RunService.RenderStepped
			local signalWait = renderStepped.wait
			local PH = newproxy() -- Placeholder, must be replaced in constructor
			local SIGNAL = newproxy()

			-- Usually for classes that work with a Roblox Object
			local function initObj(props,mt)
				local type = type
				local function copy(t)
					local res = {}
					for i,v in pairs(t) do
						if v == SIGNAL then
							res[i] = Lib.Signal.new()
						elseif type(v) == "table" then
							res[i] = copy(v)
						else
							res[i] = v
						end
					end		
					return res
				end

				local newObj = copy(props)
				return setmetatable(newObj,mt)
			end

			local function getGuiMT(props,funcs)
				return {__index = function(self,ind) if not props[ind] then return funcs[ind] or self.Gui[ind] end end,
				__newindex = function(self,ind,val) if not props[ind] then self.Gui[ind] = val else rawset(self,ind,val) end end}
			end

			-- Functions

			Lib.FormatLuaString = (function()
				local string = string
				local gsub = string.gsub
				local format = string.format
				local char = string.char
				local cleanTable = {['"'] = '\\"', ['\\'] = '\\\\'}
				for i = 0,31 do
					cleanTable[char(i)] = "\\"..format("%03d",i)
				end
				for i = 127,255 do
					cleanTable[char(i)] = "\\"..format("%03d",i)
				end

				return function(str)
					return gsub(str,"[\"\\\0-\31\127-\255]",cleanTable)
				end
			end)()

			Lib.CheckMouseInGui = function(gui)
				if gui == nil then return false end
				local mouse = Main.Mouse
				local guiPosition = gui.AbsolutePosition
				local guiSize = gui.AbsoluteSize	

				return mouse.X >= guiPosition.X and mouse.X < guiPosition.X + guiSize.X and mouse.Y >= guiPosition.Y and mouse.Y < guiPosition.Y + guiSize.Y
			end

			Lib.IsShiftDown = function()
				return service.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or service.UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			end

			Lib.IsCtrlDown = function()
				return service.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or service.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			end

			Lib.CreateArrow = function(size,num,dir)
				local max = num
				local arrowFrame = createSimple("Frame",{
					BackgroundTransparency = 1,
					Name = "Arrow",
					Size = UDim2.new(0,size,0,size)
				})
				if dir == "up" then
					for i = 1,num do
						local newLine = createSimple("Frame",{
							BackgroundColor3 = Color3.new(220/255,220/255,220/255),
							BorderSizePixel = 0,
							Position = UDim2.new(0,math.floor(size/2)-(i-1),0,math.floor(size/2)+i-math.floor(max/2)-1),
							Size = UDim2.new(0,i+(i-1),0,1),
							Parent = arrowFrame
						})
					end
					return arrowFrame
				elseif dir == "down" then
					for i = 1,num do
						local newLine = createSimple("Frame",{
							BackgroundColor3 = Color3.new(220/255,220/255,220/255),
							BorderSizePixel = 0,
							Position = UDim2.new(0,math.floor(size/2)-(i-1),0,math.floor(size/2)-i+math.floor(max/2)+1),
							Size = UDim2.new(0,i+(i-1),0,1),
							Parent = arrowFrame
						})
					end
					return arrowFrame
				elseif dir == "left" then
					for i = 1,num do
						local newLine = createSimple("Frame",{
							BackgroundColor3 = Color3.new(220/255,220/255,220/255),
							BorderSizePixel = 0,
							Position = UDim2.new(0,math.floor(size/2)+i-math.floor(max/2)-1,0,math.floor(size/2)-(i-1)),
							Size = UDim2.new(0,1,0,i+(i-1)),
							Parent = arrowFrame
						})
					end
					return arrowFrame
				elseif dir == "right" then
					for i = 1,num do
						local newLine = createSimple("Frame",{
							BackgroundColor3 = Color3.new(220/255,220/255,220/255),
							BorderSizePixel = 0,
							Position = UDim2.new(0,math.floor(size/2)-i+math.floor(max/2)+1,0,math.floor(size/2)-(i-1)),
							Size = UDim2.new(0,1,0,i+(i-1)),
							Parent = arrowFrame
						})
					end
					return arrowFrame
				end
				error("r u ok")
			end

			Lib.ParseXML = (function()
				local func = function()
					-- Only exists to parse RMD
					-- from https://github.com/jonathanpoelen/xmlparser

					local string, print, pairs = string, print, pairs

					-- http://lua-users.org/wiki/StringTrim
					local trim = function(s)
						local from = s:match"^%s*()"
						return from > #s and "" or s:match(".*%S", from)
					end

					local gtchar = string.byte('>', 1)
					local slashchar = string.byte('/', 1)
					local D = string.byte('D', 1)
					local E = string.byte('E', 1)

					function parse(s, evalEntities)
						-- remove comments
						s = s:gsub('<!%-%-(.-)%-%->', '')

						local entities, tentities = {}

						if evalEntities then
							local pos = s:find('<[_%w]')
							if pos then
								s:sub(1, pos):gsub('<!ENTITY%s+([_%w]+)%s+(.)(.-)%2', function(name, q, entity)
									entities[#entities+1] = {name=name, value=entity}
								end)
								tentities = createEntityTable(entities)
								s = replaceEntities(s:sub(pos), tentities)
							end
						end

						local t, l = {}, {}

						local addtext = function(txt)
							txt = txt:match'^%s*(.*%S)' or ''
							if #txt ~= 0 then
								t[#t+1] = {text=txt}
							end		
						end

						s:gsub('<([?!/]?)([-:_%w]+)%s*(/?>?)([^<]*)', function(type, name, closed, txt)
							-- open
							if #type == 0 then
								local a = {}
								if #closed == 0 then
									local len = 0
									for all,aname,_,value,starttxt in string.gmatch(txt, "(.-([-_%w]+)%s*=%s*(.)(.-)%3%s*(/?>?))") do
										len = len + #all
										a[aname] = value
										if #starttxt ~= 0 then
											txt = txt:sub(len+1)
											closed = starttxt
											break
										end
									end
								end
								t[#t+1] = {tag=name, attrs=a, children={}}

								if closed:byte(1) ~= slashchar then
									l[#l+1] = t
									t = t[#t].children
								end

								addtext(txt)
								-- close
							elseif '/' == type then
								t = l[#l]
								l[#l] = nil

								addtext(txt)
								-- ENTITY
							elseif '!' == type then
								if E == name:byte(1) then
									txt:gsub('([_%w]+)%s+(.)(.-)%2', function(name, q, entity)
										entities[#entities+1] = {name=name, value=entity}
									end, 1)
								end
								-- elseif '?' == type then
								--	 print('?	' .. name .. ' // ' .. attrs .. '$$')
								-- elseif '-' == type then
								--	 print('comment	' .. name .. ' // ' .. attrs .. '$$')
								-- else
								--	 print('o	' .. #p .. ' // ' .. name .. ' // ' .. attrs .. '$$')
							end
						end)

						return {children=t, entities=entities, tentities=tentities}
					end

					function parseText(txt)
						return parse(txt)
					end

					function defaultEntityTable()
						return { quot='"', apos='\'', lt='<', gt='>', amp='&', tab='\t', nbsp=' ', }
					end

					function replaceEntities(s, entities)
						return s:gsub('&([^;]+);', entities)
					end

					function createEntityTable(docEntities, resultEntities)
						entities = resultEntities or defaultEntityTable()
						for _,e in pairs(docEntities) do
							e.value = replaceEntities(e.value, entities)
							entities[e.name] = e.value
						end
						return entities
					end

					return parseText
				end
				local newEnv = setmetatable({},{__index = getfenv()})
				setfenv(func,newEnv)
				return func()
			end)()

			Lib.FastWait = function(s)
				if not s then return signalWait(renderStepped) end
				local start = tick()
				while tick() - start < s do signalWait(renderStepped) end
			end

			Lib.ButtonAnim = function(button,data)
				local holding = false
				local disabled = false
				local mode = data and data.Mode or 1
				local control = {}

				if mode == 2 then
					local lerpTo = data.LerpTo or Color3.new(0,0,0)
					local delta = data.LerpDelta or 0.2
					control.StartColor = data.StartColor or button.BackgroundColor3
					control.PressColor = data.PressColor or control.StartColor:lerp(lerpTo,delta)
					control.HoverColor = data.HoverColor or control.StartColor:lerp(control.PressColor,0.6)
					control.OutlineColor = data.OutlineColor
				end

				FrostznLife.Connect(button.InputBegan,function(input)
					if disabled then return end

					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						if not holding then
							if mode == 1 then
								button.BackgroundTransparency = 0.4
							elseif mode == 2 then
								button.BackgroundColor3 = control.HoverColor
							end
						end
					elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						holding = true
						if mode == 1 then
							button.BackgroundTransparency = 0
						elseif mode == 2 then
							button.BackgroundColor3 = control.PressColor
							if control.OutlineColor then button.BorderColor3 = control.PressColor end
						end
					end
				end)

				FrostznLife.Connect(button.InputEnded,function(input)
					if disabled then return end

					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						if not holding then
							if mode == 1 then
								button.BackgroundTransparency = 1
							elseif mode == 2 then
								button.BackgroundColor3 = control.StartColor
							end
						end
					elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						holding = false
						if mode == 1 then
							button.BackgroundTransparency = Lib.CheckMouseInGui(button) and 0.4 or 1
						elseif mode == 2 then
							button.BackgroundColor3 = Lib.CheckMouseInGui(button) and control.HoverColor or control.StartColor
							if control.OutlineColor then button.BorderColor3 = control.OutlineColor end
						end
					end
				end)

				control.Disable = function()
					disabled = true
					holding = false

					if mode == 1 then
						button.BackgroundTransparency = 1
					elseif mode == 2 then
						button.BackgroundColor3 = control.StartColor
					end
				end

				control.Enable = function()
					disabled = false
				end

				return control
			end

			Lib.FindAndRemove = function(t,item)
				local pos = table.find(t,item)
				if pos then table.remove(t,pos) end
			end

			Lib.AttachTo = function(obj,data)
				local target,posOffX,posOffY,sizeOffX,sizeOffY,resize,con
				local disabled = false

				local function update()
					if not obj or not target then return end

					local targetPos = target.AbsolutePosition
					local targetSize = target.AbsoluteSize
					obj.Position = UDim2.new(0,targetPos.X + posOffX,0,targetPos.Y + posOffY)
					if resize then obj.Size = UDim2.new(0,targetSize.X + sizeOffX,0,targetSize.Y + sizeOffY) end
				end

				local function setup(o,data)
					obj = o
					data = data or {}
					target = data.Target
					posOffX = data.PosOffX or 0
					posOffY = data.PosOffY or 0
					sizeOffX = data.SizeOffX or 0
					sizeOffY = data.SizeOffY or 0
					resize = data.Resize or false

					if con then con:Disconnect() con = nil end
					if target then
						con = FrostznLife.Connect(target.Changed,function(prop)
							if not disabled and prop == "AbsolutePosition" or prop == "AbsoluteSize" then
								update()
							end
						end)
					end

					update()
				end
				setup(obj,data)

				return {
					SetData = function(obj,data)
						setup(obj,data)
					end,
					Enable = function()
						disabled = false
						update()
					end,
					Disable = function()
						disabled = true
					end,
					Destroy = function()
						con:Disconnect()
						con = nil
					end,
				}
			end

			Lib.ProtectedGuis = {}

			Lib.ShowGui = function(gui)
                FrostznLife.TrackGui(gui)
				if env.gethui then
					gui.Parent = env.gethui()
				elseif env.protectgui then
					env.protectgui(gui)
					gui.Parent = Main.GuiHolder
				else
					gui.Parent = Main.GuiHolder
				end
			end

			Lib.ColorToBytes = function(col)
				local round = math.round
				return string.format("%d, %d, %d",round(col.r*255),round(col.g*255),round(col.b*255))
			end

			Lib.ReadFile = function(filename)
				if not env.readfile then return end

				local s,contents = pcall(env.readfile,filename)
				if s and contents then return contents end
			end

			Lib.DeferFunc = function(f,...)
				signalWait(renderStepped)
				return f(...)
			end

			Lib.LoadCustomAsset = function(filepath)
				if not env.getcustomasset or not env.isfile or not env.isfile(filepath) then return end

				return env.getcustomasset(filepath)
			end

			Lib.FetchCustomAsset = function(url,filepath)
				if not env.writefile then return end

				local s,data = pcall(oldgame.HttpGet,game,url)
				if not s then return end

				env.writefile(filepath,data)
				return Lib.LoadCustomAsset(filepath)
			end

			-- Classes

			Lib.Signal = (function()
				local funcs = {}

				local disconnect = function(con)
					local pos = table.find(con.Signal.Connections,con)
					if pos then table.remove(con.Signal.Connections,pos) end
				end

				funcs.Connect = function(self,func)
					if type(func) ~= "function" then error("Attempt to connect a non-function") end		
					local con = {
						Signal = self,
						Func = func,
						Disconnect = disconnect
					}
					self.Connections[#self.Connections+1] = con
					return con
				end

				funcs.Fire = function(self,...)
					for i,v in next,self.Connections do
						xpcall(FrostznLife.Wrap(v.Func),function(e) warn(e.."\n"..debug.traceback()) end,...)
					end
				end

				local mt = {
					__index = funcs,
					__tostring = function(self)
						return "Signal: " .. tostring(#self.Connections) .. " Connections"
					end
				}

				local function new()
					local obj = {}
					obj.Connections = {}

					return setmetatable(obj,mt)
				end

				return {new = new}
			end)()

			Lib.Set = (function()
				local funcs = {}

				funcs.Add = function(self,obj)
					if self.Map[obj] then return end

					local list = self.List
					list[#list+1] = obj
					self.Map[obj] = true
					self.Changed:Fire()
				end

				funcs.AddTable = function(self,t)
					local changed
					local list,map = self.List,self.Map
					for i = 1,#t do
						local elem = t[i]
						if not map[elem] then
							list[#list+1] = elem
							map[elem] = true
							changed = true
						end
					end
					if changed then self.Changed:Fire() end
				end

				funcs.Remove = function(self,obj)
					if not self.Map[obj] then return end

					local list = self.List
					local pos = table.find(list,obj)
					if pos then table.remove(list,pos) end
					self.Map[obj] = nil
					self.Changed:Fire()
				end

				funcs.RemoveTable = function(self,t)
					local changed
					local list,map = self.List,self.Map
					local removeSet = {}
					for i = 1,#t do
						local elem = t[i]
						map[elem] = nil
						removeSet[elem] = true
					end

					for i = #list,1,-1 do
						local elem = list[i]
						if removeSet[elem] then
							table.remove(list,i)
							changed = true
						end
					end
					if changed then self.Changed:Fire() end
				end

				funcs.Set = function(self,obj)
					if #self.List == 1 and self.List[1] == obj then return end

					self.List = {obj}
					self.Map = {[obj] = true}
					self.Changed:Fire()
				end

				funcs.SetTable = function(self,t)
					local newList,newMap = {},{}
					self.List,self.Map = newList,newMap
					table.move(t,1,#t,1,newList)
					for i = 1,#t do
						newMap[t[i]] = true
					end
					self.Changed:Fire()
				end

				funcs.Clear = function(self)
					if #self.List == 0 then return end
					self.List = {}
					self.Map = {}
					self.Changed:Fire()
				end

				local mt = {__index = funcs}

				local function new()
					local obj = setmetatable({
						List = {},
						Map = {},
						Changed = Lib.Signal.new()
					},mt)

					return obj
				end

				return {new = new}
			end)()

			Lib.IconMap = (function()
				local funcs = {}
				local _MapId, _Icons = (483448923), {
					["Accessory"] = 32;
					["Accoutrement"] = 32;
					["AdService"] = 73;
					["Animation"] = 60;
					["AnimationController"] = 60;
					["AnimationTrack"] = 60;
					["Animator"] = 60;
					["ArcHandles"] = 56;
					["AssetService"] = 72;
					["Attachment"] = 34;
					["Backpack"] = 20;
					["BadgeService"] = 75;
					["BallSocketConstraint"] = 89;
					["BillboardGui"] = 64;
					["BinaryStringValue"] = 4;
					["BindableEvent"] = 67;
					["BindableFunction"] = 66;
					["BlockMesh"] = 8;
					["BloomEffect"] = 90;
					["BlurEffect"] = 90;
					["BodyAngularVelocity"] = 14;
					["BodyForce"] = 14;
					["BodyGyro"] = 14;
					["BodyPosition"] = 14;
					["BodyThrust"] = 14;
					["BodyVelocity"] = 14;
					["BoolValue"] = 4;
					["BoxHandleAdornment"] = 54;
					["BrickColorValue"] = 4;
					["Camera"] = 5;
					["CFrameValue"] = 4;
					["CharacterMesh"] = 60;
					["Chat"] = 33;
					["ClickDetector"] = 41;
					["CollectionService"] = 30;
					["Color3Value"] = 4;
					["ColorCorrectionEffect"] = 90;
					["ConeHandleAdornment"] = 54;
					["Configuration"] = 58;
					["ContentProvider"] = 72;
					["ContextActionService"] = 41;
					["CoreGui"] = 46;
					["CoreScript"] = 18;
					["CornerWedgePart"] = 1;
					["CustomEvent"] = 4;
					["CustomEventReceiver"] = 4;
					["CylinderHandleAdornment"] = 54;
					["CylinderMesh"] = 8;
					["CylindricalConstraint"] = 89;
					["Debris"] = 30;
					["Decal"] = 7;
					["Dialog"] = 62;
					["DialogChoice"] = 63;
					["DoubleConstrainedValue"] = 4;
					["Explosion"] = 36;
					["FileMesh"] = 8;
					["Fire"] = 61;
					["Flag"] = 38;
					["FlagStand"] = 39;
					["FloorWire"] = 4;
					["Folder"] = 70;
					["ForceField"] = 37;
					["Frame"] = 48;
					["GamePassService"] = 19;
					["Glue"] = 34;
					["GuiButton"] = 52;
					["GuiMain"] = 47;
					["GuiService"] = 47;
					["Handles"] = 53;
					["HapticService"] = 84;
					["Hat"] = 45;
					["HingeConstraint"] = 89;
					["Hint"] = 33;
					["HopperBin"] = 22;
					["HttpService"] = 76;
					["Humanoid"] = 9;
					["ImageButton"] = 52;
					["ImageLabel"] = 49;
					["InsertService"] = 72;
					["IntConstrainedValue"] = 4;
					["IntValue"] = 4;
					["JointInstance"] = 34;
					["JointsService"] = 34;
					["Keyframe"] = 60;
					["KeyframeSequence"] = 60;
					["KeyframeSequenceProvider"] = 60;
					["Lighting"] = 13;
					["LineHandleAdornment"] = 54;
					["LocalScript"] = 18;
					["LogService"] = 87;
					["MarketplaceService"] = 46;
					["Message"] = 33;
					["Model"] = 2;
					["ModuleScript"] = 71;
					["Motor"] = 34;
					["Motor6D"] = 34;
					["MoveToConstraint"] = 89;
					["NegateOperation"] = 78;
					["NetworkClient"] = 16;
					["NetworkReplicator"] = 29;
					["NetworkServer"] = 15;
					["NumberValue"] = 4;
					["ObjectValue"] = 4;
					["Pants"] = 44;
					["ParallelRampPart"] = 1;
					["Part"] = 1;
					["ParticleEmitter"] = 69;
					["PartPairLasso"] = 57;
					["PathfindingService"] = 37;
					["Platform"] = 35;
					["Player"] = 12;
					["PlayerGui"] = 46;
					["Players"] = 21;
					["PlayerScripts"] = 82;
					["PointLight"] = 13;
					["PointsService"] = 83;
					["Pose"] = 60;
					["PrismaticConstraint"] = 89;
					["PrismPart"] = 1;
					["PyramidPart"] = 1;
					["RayValue"] = 4;
					["ReflectionMetadata"] = 86;
					["ReflectionMetadataCallbacks"] = 86;
					["ReflectionMetadataClass"] = 86;
					["ReflectionMetadataClasses"] = 86;
					["ReflectionMetadataEnum"] = 86;
					["ReflectionMetadataEnumItem"] = 86;
					["ReflectionMetadataEnums"] = 86;
					["ReflectionMetadataEvents"] = 86;
					["ReflectionMetadataFunctions"] = 86;
					["ReflectionMetadataMember"] = 86;
					["ReflectionMetadataProperties"] = 86;
					["ReflectionMetadataYieldFunctions"] = 86;
					["RemoteEvent"] = 80;
					["RemoteFunction"] = 79;
					["ReplicatedFirst"] = 72;
					["ReplicatedStorage"] = 72;
					["RightAngleRampPart"] = 1;
					["RocketPropulsion"] = 14;
					["RodConstraint"] = 89;
					["RopeConstraint"] = 89;
					["Rotate"] = 34;
					["RotateP"] = 34;
					["RotateV"] = 34;
					["RunService"] = 66;
					["ScreenGui"] = 47;
					["Script"] = 6;
					["ScrollingFrame"] = 48;
					["Seat"] = 35;
					["Selection"] = 55;
					["SelectionBox"] = 54;
					["SelectionPartLasso"] = 57;
					["SelectionPointLasso"] = 57;
					["SelectionSphere"] = 54;
					["ServerScriptService"] = 0;
					["ServerStorage"] = 74;
					["Shirt"] = 43;
					["ShirtGraphic"] = 40;
					["SkateboardPlatform"] = 35;
					["Sky"] = 28;
					["SlidingBallConstraint"] = 89;
					["Smoke"] = 59;
					["Snap"] = 34;
					["Sound"] = 11;
					["SoundService"] = 31;
					["Sparkles"] = 42;
					["SpawnLocation"] = 25;
					["SpecialMesh"] = 8;
					["SphereHandleAdornment"] = 54;
					["SpotLight"] = 13;
					["SpringConstraint"] = 89;
					["StarterCharacterScripts"] = 82;
					["StarterGear"] = 20;
					["StarterGui"] = 46;
					["StarterPack"] = 20;
					["StarterPlayer"] = 88;
					["StarterPlayerScripts"] = 82;
					["Status"] = 2;
					["StringValue"] = 4;
					["SunRaysEffect"] = 90;
					["SurfaceGui"] = 64;
					["SurfaceLight"] = 13;
					["SurfaceSelection"] = 55;
					["Team"] = 24;
					["Teams"] = 23;
					["TeleportService"] = 81;
					["Terrain"] = 65;
					["TerrainRegion"] = 65;
					["TestService"] = 68;
					["TextBox"] = 51;
					["TextButton"] = 51;
					["TextLabel"] = 50;
					["Texture"] = 10;
					["TextureTrail"] = 4;
					["Tool"] = 17;
					["TouchTransmitter"] = 37;
					["TrussPart"] = 1;
					["UnionOperation"] = 77;
					["UserInputService"] = 84;
					["Vector3Value"] = 4;
					["VehicleSeat"] = 35;
					["VelocityMotor"] = 34;
					["WedgePart"] = 1;
					["Weld"] = 34;
					["Workspace"] = 19;

				}
				funcs.ExplorerIcons = { ["MapId"] = _MapId, ["Icons"] = _Icons }

				funcs.GetLabel = function(self)
					local label = Instance.new("ImageLabel")
					self:SetupLabel(label)
					return label
				end

				funcs.SetupLabel = function(self,obj)
					obj.BackgroundTransparency = 1
					obj.ImageRectOffset = Vector2.new(0, 0)
					obj.ImageRectSize = Vector2.new(self.IconSizeX, self.IconSizeY)
					obj.ScaleType = Enum.ScaleType.Crop
					obj.Size = UDim2.new(0, self.IconSizeX, 0, self.IconSizeY)
				end

				funcs.Display = function(self,obj,index)
					obj.Image = self.MapId
					if not self.NumX then
						obj.ImageRectOffset = Vector2.new(self.IconSizeX*index, 0)
					else
						obj.ImageRectOffset = Vector2.new(self.IconSizeX*(index % self.NumX), self.IconSizeY*math.floor(index / self.NumX))
					end
				end

				funcs.DisplayByKey = function(self, obj, key)
					if self.IndexDict[key] then
						self:Display(obj, self.IndexDict[key])
					else
						local rmdEntry = RMD.Classes[obj.ClassName]
						Explorer.ClassIcons:Display(obj, rmdEntry and rmdEntry.ExplorerImageIndex or 0)
					end
				end

				funcs.IconDehash = function(self, _id)
					return math.floor(_id / 14 % 14), math.floor(_id % 14)
				end

				funcs.GetExplorerIcon = function(self, obj, index)
					index = (self.ExplorerIcons.Icons[index] or 0)
					local row, col = self:IconDehash(index)
					local MapSize = Vector2.new(256, 256)
					local pad, border = 2, 1
					local IconSize = 16

					obj.Position = UDim2.new(-col - (pad * (col + 1) + border) / IconSize, 0, -row - (pad * (row + 1) + border) / IconSize, 0)
					obj.Size = UDim2.new(MapSize.X / IconSize, 0, MapSize.Y / IconSize, 0)
				end

				funcs.DisplayExplorerIcons = function(self, Frame, index)
					if Frame:FindFirstChild("IconMap") then
						self:GetExplorerIcon(Frame.IconMap, index)
					else
						Frame.ClipsDescendants = true

						local obj = Instance.new("ImageLabel", Frame)
						obj.BackgroundTransparency = 1
						obj.Image = ("http://www.roblox.com/asset/?id=" .. (self.ExplorerIcons.MapId))
						obj.Name = "IconMap"
						self:GetExplorerIcon(obj, index)
					end
				end

				funcs.SetDict = function(self,dict)
					self.IndexDict = dict
				end

				local mt = {}
				mt.__index = funcs

				local function new(mapId,mapSizeX,mapSizeY,iconSizeX,iconSizeY)
					local obj = setmetatable({
						MapId = mapId,
						MapSizeX = mapSizeX,
						MapSizeY = mapSizeY,
						IconSizeX = iconSizeX,
						IconSizeY = iconSizeY,
						NumX = mapSizeX/iconSizeX,
						IndexDict = {}
					}, mt)
					return obj
				end

				local function newLinear(mapId,iconSizeX,iconSizeY)
					local obj = setmetatable({
						MapId = mapId,
						IconSizeX = iconSizeX,
						IconSizeY = iconSizeY,
						IndexDict = {}
					},mt)
					return obj
				end

				return {new = new, newLinear = newLinear}
			end)()

			Lib.ScrollBar = (function()
				local funcs = {}
				local user = service.UserInputService
				local mouse = plr:GetMouse()
				local checkMouseInGui = Lib.CheckMouseInGui
				local createArrow = Lib.CreateArrow

				local function drawThumb(self)
					local total = self.TotalSpace
					local visible = self.VisibleSpace
					local index = self.Index
					local scrollThumb = self.GuiElems.ScrollThumb
					local scrollThumbFrame = self.GuiElems.ScrollThumbFrame

					if not (self:CanScrollUp()	or self:CanScrollDown()) then
						scrollThumb.Visible = false
					else
						scrollThumb.Visible = true
					end

					if self.Horizontal then
						scrollThumb.Size = UDim2.new(visible/total,0,1,0)
						if scrollThumb.AbsoluteSize.X < 16 then
							scrollThumb.Size = UDim2.new(0,16,1,0)
						end
						local fs = scrollThumbFrame.AbsoluteSize.X
						local bs = scrollThumb.AbsoluteSize.X
						scrollThumb.Position = UDim2.new(self:GetScrollPercent()*(fs-bs)/fs,0,0,0)
					else
						scrollThumb.Size = UDim2.new(1,0,visible/total,0)
						if scrollThumb.AbsoluteSize.Y < 16 then
							scrollThumb.Size = UDim2.new(1,0,0,16)
						end
						local fs = scrollThumbFrame.AbsoluteSize.Y
						local bs = scrollThumb.AbsoluteSize.Y
						scrollThumb.Position = UDim2.new(0,0,self:GetScrollPercent()*(fs-bs)/fs,0)
					end
				end

				local function createFrame(self)
					local newFrame = createSimple("Frame",{Style=0,Active=true,AnchorPoint=Vector2.new(0,0),BackgroundColor3=Color3.new(0.35294118523598,0.35294118523598,0.35294118523598),BackgroundTransparency=0,BorderColor3=Color3.new(0.10588236153126,0.16470588743687,0.20784315466881),BorderSizePixel=0,ClipsDescendants=false,Draggable=false,Position=UDim2.new(1,-16,0,0),Rotation=0,Selectable=false,Size=UDim2.new(0,16,1,0),SizeConstraint=0,Visible=true,ZIndex=1,Name="ScrollBar",})
					local button1, button2

					if self.Horizontal then
						newFrame.Size = UDim2.new(1,0,0,16)
						button1 = createSimple("ImageButton",{
							Parent = newFrame,
							Name = "Left",
							Size = UDim2.new(0,16,0,16),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							AutoButtonColor = false
						})
						createArrow(16,4,"left").Parent = button1
						button2 = createSimple("ImageButton",{
							Parent = newFrame,
							Name = "Right",
							Position = UDim2.new(1,-16,0,0),
							Size = UDim2.new(0,16,0,16),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							AutoButtonColor = false
						})
						createArrow(16,4,"right").Parent = button2
					else
						newFrame.Size = UDim2.new(0,16,1,0)
						button1 = createSimple("ImageButton",{
							Parent = newFrame,
							Name = "Up",
							Size = UDim2.new(0,16,0,16),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							AutoButtonColor = false
						})
						createArrow(16,4,"up").Parent = button1
						button2 = createSimple("ImageButton",{
							Parent = newFrame,
							Name = "Down",
							Position = UDim2.new(0,0,1,-16),
							Size = UDim2.new(0,16,0,16),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							AutoButtonColor = false
						})
						createArrow(16,4,"down").Parent = button2
					end

					local scrollThumbFrame = createSimple("ImageButton", {
						BackgroundTransparency = 1,
						Parent = newFrame
					})
					if self.Horizontal then
						scrollThumbFrame.Position = UDim2.new(0,16,0,0)
						scrollThumbFrame.Size = UDim2.new(1,-32,1,0)
					else
						scrollThumbFrame.Position = UDim2.new(0,0,0,16)
						scrollThumbFrame.Size = UDim2.new(1,0,1,-32)
					end

					local scrollThumb = createSimple("Frame", {
						BackgroundColor3 = Color3.new(120/255, 120/255, 120/255),
						BorderSizePixel = 0,
						Parent = scrollThumbFrame
					})

					local markerFrame = createSimple("Frame", {
						BackgroundTransparency = 1,
						Name = "Markers",
						Size = UDim2.new(1, 0, 1, 0),
						Parent = scrollThumbFrame
					})

					local buttonPress = false
					local thumbPress = false
					local thumbFramePress = false

					local function handleButtonPress(button, scrollDirection)
						if self:CanScroll(scrollDirection) then
							button.BackgroundTransparency = 0.5
							self:ScrollToDirection(scrollDirection)
							self.Scrolled:Fire()
							local buttonTick = tick()
							local releaseEvent
							releaseEvent = FrostznLife.Connect(user.InputEnded,function(input)
								if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
									releaseEvent:Disconnect()
									button.BackgroundTransparency = checkMouseInGui(button) and 0.8 or 1
									buttonPress = false
								end
							end)
							while buttonPress do
								if tick() - buttonTick >= 0.25 and self:CanScroll(scrollDirection) then
									self:ScrollToDirection(scrollDirection)
									self.Scrolled:Fire()
								end
								task.wait()
							end
						end
					end

					FrostznLife.Connect(button1.MouseButton1Down,function(input)
						buttonPress = true
						handleButtonPress(button1, "Up")
					end)

					FrostznLife.Connect(button1.InputEnded,function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							button1.BackgroundTransparency = 1
						end
					end)

					FrostznLife.Connect(button2.MouseButton1Down,function(input)
						buttonPress = true
						handleButtonPress(button2, "Down")
					end)

					FrostznLife.Connect(button2.InputEnded,function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							button2.BackgroundTransparency = 1
						end
					end)

					FrostznLife.Connect(scrollThumb.InputBegan,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
							local dir = self.Horizontal and "X" or "Y"
							local lastThumbPos = nil
							thumbPress = true
							scrollThumb.BackgroundTransparency = 0
							local mouseOffset = mouse[dir] - scrollThumb.AbsolutePosition[dir]
							local releaseEvent
							local mouseEvent

							releaseEvent = FrostznLife.Connect(user.InputEnded,function(input)
								if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
									releaseEvent:Disconnect()
									if mouseEvent then mouseEvent:Disconnect() end
									scrollThumb.BackgroundTransparency = 0.2
									thumbPress = false
								end
							end)

							mouseEvent = FrostznLife.Connect(user.InputChanged,function(input)
								if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and thumbPress then
									local thumbFrameSize = scrollThumbFrame.AbsoluteSize[dir] - scrollThumb.AbsoluteSize[dir]
									local pos = mouse[dir] - scrollThumbFrame.AbsolutePosition[dir] - mouseOffset
									if pos > thumbFrameSize then pos = thumbFrameSize
									elseif pos < 0 then pos = 0 end
									if lastThumbPos ~= pos then
										lastThumbPos = pos
										self:ScrollTo(math.floor(0.5 + pos / thumbFrameSize * (self.TotalSpace - self.VisibleSpace)))
									end
								end
							end)
						end
					end)

					FrostznLife.Connect(scrollThumb.InputEnded,function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							scrollThumb.BackgroundTransparency = 0
						end
					end)

					FrostznLife.Connect(scrollThumbFrame.InputBegan,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not checkMouseInGui(scrollThumb) then
							local dir = self.Horizontal and "X" or "Y"
							local scrollDir = (mouse[dir] >= scrollThumb.AbsolutePosition[dir] + scrollThumb.AbsoluteSize[dir]) and 1 or 0
							local function doTick()
								local scrollSize = self.VisibleSpace - 1
								if scrollDir == 0 and mouse[dir] < scrollThumb.AbsolutePosition[dir] then
									self:ScrollTo(self.Index - scrollSize)
								elseif scrollDir == 1 and mouse[dir] >= scrollThumb.AbsolutePosition[dir] + scrollThumb.AbsoluteSize[dir] then
									self:ScrollTo(self.Index + scrollSize)
								end
							end

							thumbPress = false
							thumbFramePress = true
							doTick()
							local thumbFrameTick = tick()
							local releaseEvent
							releaseEvent = FrostznLife.Connect(user.InputEnded,function(input)
								if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
									releaseEvent:Disconnect()
									thumbFramePress = false
								end
							end)

							while thumbFramePress do
								if tick() - thumbFrameTick >= 0.3 and checkMouseInGui(scrollThumbFrame) then
									doTick()
								end
								task.wait()
							end
						end
					end)

					FrostznLife.Connect(newFrame.MouseWheelForward,function()
						self:ScrollTo(self.Index - self.WheelIncrement)
					end)

					FrostznLife.Connect(newFrame.MouseWheelBackward,function()
						self:ScrollTo(self.Index + self.WheelIncrement)
					end)

					self.GuiElems.ScrollThumb = scrollThumb
					self.GuiElems.ScrollThumbFrame = scrollThumbFrame
					self.GuiElems.Button1 = button1
					self.GuiElems.Button2 = button2
					self.GuiElems.MarkerFrame = markerFrame

					return newFrame
				end

				funcs.Update = function(self,nocallback)
					local total = self.TotalSpace
					local visible = self.VisibleSpace
					local index = self.Index
					local button1 = self.GuiElems.Button1
					local button2 = self.GuiElems.Button2

					self.Index = math.clamp(self.Index, 0, math.max(0, total - visible))

					if self.LastTotalSpace ~= self.TotalSpace then
						self.LastTotalSpace = self.TotalSpace
						self:UpdateMarkers()
					end

					if self:CanScrollUp() then
						for i,v in pairs(button1.Arrow:GetChildren()) do
							v.BackgroundTransparency = 0
						end
					else
						button1.BackgroundTransparency = 1
						for i,v in pairs(button1.Arrow:GetChildren()) do
							v.BackgroundTransparency = 0.5
						end
					end
					if self:CanScrollDown() then
						for i,v in pairs(button2.Arrow:GetChildren()) do
							v.BackgroundTransparency = 0
						end
					else
						button2.BackgroundTransparency = 1
						for i,v in pairs(button2.Arrow:GetChildren()) do
							v.BackgroundTransparency = 0.5
						end
					end

					drawThumb(self)
				end

				funcs.UpdateMarkers = function(self)
					local markerFrame = self.GuiElems.MarkerFrame
					markerFrame:ClearAllChildren()

					for i,v in pairs(self.Markers) do
						if i < self.TotalSpace then
							createSimple("Frame", {
								BackgroundTransparency = 0,
								BackgroundColor3 = v,
								BorderSizePixel = 0,
								Position = self.Horizontal and UDim2.new(i/self.TotalSpace,0,1,-6) or UDim2.new(1,-6,i/self.TotalSpace,0),
								Size = self.Horizontal and UDim2.new(0,1,0,6) or UDim2.new(0,6,0,1),
								Name = "Marker"..tostring(i),
								Parent = markerFrame
							})
						end
					end
				end

				funcs.AddMarker = function(self,ind,color)
					self.Markers[ind] = color or Color3.new(0,0,0)
				end
				funcs.ScrollTo = function(self, ind, nocallback)
					self.Index = ind
					self:Update()
					if not nocallback then
						self.Scrolled:Fire()
					end
				end
				funcs.ScrollUp = function(self)
					self.Index = self.Index - self.Increment
					self:Update()
				end
				funcs.CanScroll = function(self, direction)
					if direction == "Up" then
						return self:CanScrollUp()
					elseif direction == "Down" then
						return self:CanScrollDown()
					end
					return false
				end
				funcs.ScrollDown = function(self)
					self.Index = self.Index + self.Increment
					self:Update()
				end
				funcs.CanScrollUp = function(self)
					return self.Index > 0
				end
				funcs.CanScrollDown = function(self)
					return self.Index + self.VisibleSpace < self.TotalSpace
				end
				funcs.GetScrollPercent = function(self)
					return self.Index/(self.TotalSpace-self.VisibleSpace)
				end
				funcs.SetScrollPercent = function(self,perc)
					self.Index = math.floor(perc*(self.TotalSpace-self.VisibleSpace))
					self:Update()
				end
				funcs.ScrollToDirection = function(self, Direaction)
					if Direaction == "Up" then
						self:ScrollUp()
					elseif Direaction == "Down" then
						self:ScrollDown()
					end
				end

				funcs.Texture = function(self,data)
					self.ThumbColor = data.ThumbColor or Color3.new(0,0,0)
					self.ThumbSelectColor = data.ThumbSelectColor or Color3.new(0,0,0)
					self.GuiElems.ScrollThumb.BackgroundColor3 = data.ThumbColor or Color3.new(0,0,0)
					self.Gui.BackgroundColor3 = data.FrameColor or Color3.new(0,0,0)
					self.GuiElems.Button1.BackgroundColor3 = data.ButtonColor or Color3.new(0,0,0)
					self.GuiElems.Button2.BackgroundColor3 = data.ButtonColor or Color3.new(0,0,0)
					for i,v in pairs(self.GuiElems.Button1.Arrow:GetChildren()) do
						v.BackgroundColor3 = data.ArrowColor or Color3.new(0,0,0)
					end
					for i,v in pairs(self.GuiElems.Button2.Arrow:GetChildren()) do
						v.BackgroundColor3 = data.ArrowColor or Color3.new(0,0,0)
					end
				end

				funcs.SetScrollFrame = function(self,frame)
					if self.ScrollUpEvent then self.ScrollUpEvent:Disconnect() self.ScrollUpEvent = nil end
					if self.ScrollDownEvent then self.ScrollDownEvent:Disconnect() self.ScrollDownEvent = nil end
					self.ScrollUpEvent = FrostznLife.Connect(frame.MouseWheelForward,function() self:ScrollTo(self.Index - self.WheelIncrement) end)
					self.ScrollDownEvent = FrostznLife.Connect(frame.MouseWheelBackward,function() self:ScrollTo(self.Index + self.WheelIncrement) end)
				end

				local mt = {}
				mt.__index = funcs

				local function new(hor)
					local obj = setmetatable({
						Index = 0,
						VisibleSpace = 0,
						TotalSpace = 0,
						Increment = 1,
						WheelIncrement = 1,
						Markers = {},
						GuiElems = {},
						Horizontal = hor,
						LastTotalSpace = 0,
						Scrolled = Lib.Signal.new()
					},mt)
					obj.Gui = createFrame(obj)
					obj:Texture({
						ThumbColor = Color3.fromRGB(60,60,60),
						ThumbSelectColor = Color3.fromRGB(75,75,75),
						ArrowColor = Color3.new(1,1,1),
						FrameColor = Color3.fromRGB(40,40,40),
						ButtonColor = Color3.fromRGB(75,75,75)
					})
					return obj
				end

				return {new = new}
			end)()

			Lib.Window = (function()
				local funcs = {}
				local static = {MinWidth = 200, FreeWidth = 200}
				local mouse = plr:GetMouse()
				local sidesGui, alignIndicator
				local visibleWindows = {}
				local leftSide = {Width = 300, Windows = {}, ResizeCons = {}, Hidden = true}
				local rightSide = {Width = 300, Windows = {}, ResizeCons = {}, Hidden = true}

				local displayOrderStart
				local sideDisplayOrder
				local sideTweenInfo = TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
				local tweens = {}
				local isA = game.IsA

				local theme = {
					MainColor1 = Color3.fromRGB(52,52,52),
					MainColor2 = Color3.fromRGB(45,45,45),
					Button = Color3.fromRGB(60,60,60)
				}

				local function stopTweens()
					for i = 1,#tweens do
						tweens[i]:Cancel()
					end
					tweens = {}
				end

				local function resizeHook(self,resizer,dir)
					local guiMain = self.GuiElems.Main
					FrostznLife.Connect(resizer.InputBegan,function(input)
						if not self.Dragging and not self.Resizing and self.Resizable and self.ResizableInternal then
							local isH = dir:find("[WE]") and true
							local isV = dir:find("[NS]") and true
							local signX = dir:find("W",1,true) and -1 or 1
							local signY = dir:find("N",1,true) and -1 or 1

							if self.Minimized and isV then return end

							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								resizer.BackgroundTransparency = 0.5
							elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								local releaseEvent, mouseEvent

								local offX = input.Position.X - resizer.AbsolutePosition.X
								local offY = input.Position.Y - resizer.AbsolutePosition.Y

								self.Resizing = resizer
								resizer.BackgroundTransparency = 1

								releaseEvent = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
									if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
										releaseEvent:Disconnect()
										if mouseEvent then mouseEvent:Disconnect() end
										self.Resizing = false
                                        self:MoveInBoundary()
										resizer.BackgroundTransparency = 1
									end
								end)

								mouseEvent = FrostznLife.Connect(service.UserInputService.InputChanged,function(input)
									if self.Resizable and self.ResizableInternal and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
										self:StopTweens()
										local deltaX = input.Position.X - resizer.AbsolutePosition.X - offX
										local deltaY = input.Position.Y - resizer.AbsolutePosition.Y - offY

										if guiMain.AbsoluteSize.X + deltaX * signX < self.MinX then deltaX = signX * (self.MinX - guiMain.AbsoluteSize.X) end
										if guiMain.AbsoluteSize.Y + deltaY * signY < self.MinY then deltaY = signY * (self.MinY - guiMain.AbsoluteSize.Y) end
										if signY < 0 and guiMain.AbsolutePosition.Y + deltaY < 0 then deltaY = -guiMain.AbsolutePosition.Y end

										guiMain.Position = guiMain.Position + UDim2.new(0, (signX < 0 and deltaX or 0), 0, (signY < 0 and deltaY or 0))
										self.SizeX = self.SizeX + (isH and deltaX * signX or 0)
										self.SizeY = self.SizeY + (isV and deltaY * signY or 0)
										guiMain.Size = UDim2.new(0, self.SizeX, 0, self.Minimized and 20 or self.SizeY)
									end
								end)
							end
						end
					end)

					FrostznLife.Connect(resizer.InputEnded,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and self.Resizing ~= resizer then
							resizer.BackgroundTransparency = 1
						end
					end)
				end

				local updateWindows

				local function moveToTop(window)
					local found = table.find(visibleWindows,window)
					if found then
						table.remove(visibleWindows,found)
						table.insert(visibleWindows,1,window)
						updateWindows()
					end
				end

				local function sideHasRoom(side,neededSize)
					local maxY = sidesGui.AbsoluteSize.Y - 32 - (math.max(0,#side.Windows - 1) * 4)
					local inc = 0
					for i,v in pairs(side.Windows) do
						inc = inc + (v.MinY or 100)
						if inc > maxY - neededSize then return false end
					end

					return true
				end

				local function getSideInsertPos(side,curY)
					local pos = #side.Windows + 1
					local range = {0,sidesGui.AbsoluteSize.Y}

					for i,v in pairs(side.Windows) do
						local midPos = v.PosY + v.SizeY/2
						if curY <= midPos then
							pos = i
							range[2] = midPos
							break
						else
							range[1] = midPos
						end
					end

					return pos,range
				end

				local function focusInput(self,obj)
					if isA(obj,"GuiButton") then
						FrostznLife.Connect(obj.MouseButton1Down,function()
							moveToTop(self)
						end)
					elseif isA(obj,"TextBox") then
						FrostznLife.Connect(obj.Focused,function()
							moveToTop(self)
						end)
					end
				end

				local createGui = function(self)
					local gui = create({
						{1,"ScreenGui",{Name="Window",}},
						{2,"Frame",{Active=true,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="Main",Parent={1},Position=UDim2.new(0.40000000596046,0,0.40000000596046,0),Size=UDim2.new(0,300,0,300),}},
						{3,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,Name="Content",Parent={2},Position=UDim2.new(0,0,0,20),Size=UDim2.new(1,0,1,-20),ClipsDescendants=true}},
						{4,"Frame",{BackgroundColor3=Color3.fromRGB(33,33,33),BorderSizePixel=0,Name="Line",Parent={3},Size=UDim2.new(1,0,0,1),}},
						{5,"TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="TopBar",Parent={2},Size=UDim2.new(1,0,0,20),}},
						{6,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={5},Position=UDim2.new(0,5,0,0),Size=UDim2.new(1,-10,0,20),Text="Window",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,}},
						{7,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Close",Parent={5},Position=UDim2.new(1,-18,0,2),Size=UDim2.new(0,16,0,16),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
						{8,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5054663650",Parent={7},Position=UDim2.new(0,3,0,3),Size=UDim2.new(0,10,0,10),}},
						{9,"UICorner",{CornerRadius=UDim.new(0,4),Parent={7},}},
						{10,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Minimize",Parent={5},Position=UDim2.new(1,-36,0,2),Size=UDim2.new(0,16,0,16),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,}},
						{11,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://5034768003",Parent={10},Position=UDim2.new(0,3,0,3),Size=UDim2.new(0,10,0,10),}},
						{12,"UICorner",{CornerRadius=UDim.new(0,4),Parent={10},}},
						{13,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Image="rbxassetid://1427967925",Name="Outlines",Parent={2},Position=UDim2.new(0,-5,0,-5),ScaleType=1,Size=UDim2.new(1,10,1,10),SliceCenter=Rect.new(6,6,25,25),TileSize=UDim2.new(0,20,0,20),}},
						{14,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="ResizeControls",Parent={2},Position=UDim2.new(0,-5,0,-5),Size=UDim2.new(1,10,1,10),}},
						{15,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="North",Parent={14},Position=UDim2.new(0,5,0,0),Size=UDim2.new(1,-10,0,5),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{16,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="South",Parent={14},Position=UDim2.new(0,5,1,-5),Size=UDim2.new(1,-10,0,5),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{17,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="NorthEast",Parent={14},Position=UDim2.new(1,-5,0,0),Size=UDim2.new(0,5,0,5),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{18,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="East",Parent={14},Position=UDim2.new(1,-5,0,5),Size=UDim2.new(0,5,1,-10),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{19,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="West",Parent={14},Position=UDim2.new(0,0,0,5),Size=UDim2.new(0,5,1,-10),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{20,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="SouthEast",Parent={14},Position=UDim2.new(1,-5,1,-5),Size=UDim2.new(0,5,0,5),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{21,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="NorthWest",Parent={14},Size=UDim2.new(0,5,0,5),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{22,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.27450981736183,0.27450981736183,0.27450981736183),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="SouthWest",Parent={14},Position=UDim2.new(0,0,1,-5),Size=UDim2.new(0,5,0,5),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
					})

					local guiMain = gui.Main
					local guiTopBar = guiMain.TopBar
					local guiResizeControls = guiMain.ResizeControls

					self.GuiElems.Main = guiMain
					self.GuiElems.TopBar = guiMain.TopBar
					self.GuiElems.Content = guiMain.Content
                    guiMain.Content.ClipsDescendants=true
					self.GuiElems.Line = guiMain.Content.Line
					self.GuiElems.Outlines = guiMain.Outlines
					self.GuiElems.Title = guiTopBar.Title
					self.GuiElems.Close = guiTopBar.Close
					self.GuiElems.Minimize = guiTopBar.Minimize
					self.GuiElems.ResizeControls = guiResizeControls
					self.ContentPane = guiMain.Content

					local ButtonDown = false
					FrostznLife.Connect(guiTopBar.MouseButton1Down,function() ButtonDown = true end)
					FrostznLife.Connect(guiTopBar.MouseButton1Up,function() ButtonDown = false end)

					FrostznLife.Connect(guiTopBar.InputBegan,function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							if self.Draggable then
								local releaseEvent, mouseEvent

								local maxX = sidesGui.AbsoluteSize.X
								local initX = guiMain.AbsolutePosition.X
								local initY = guiMain.AbsolutePosition.Y
								local offX = input.Position.X - initX
								local offY = input.Position.Y - initY

								local alignInsertPos, alignInsertSide

								guiDragging = true

								releaseEvent = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
									if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
										releaseEvent:Disconnect()
										if mouseEvent then mouseEvent:Disconnect() end
										guiDragging = false
                                        self:MoveInBoundary()
                                        alignIndicator.Parent = nil
										if alignInsertSide then
											local targetSide = (alignInsertSide == "left" and leftSide) or (alignInsertSide == "right" and rightSide)
											self:AlignTo(targetSide, alignInsertPos)
										end
									end
								end)

								mouseEvent = FrostznLife.Connect(service.UserInputService.InputChanged,function(input)
									if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and self.Draggable and not self.Closed and ButtonDown then
										if self.Aligned then
											if leftSide.Resizing or rightSide.Resizing then return end
											local posX, posY = input.Position.X - offX, input.Position.Y - offY
											local delta = math.sqrt((posX - initX)^2 + (posY - initY)^2)
											if delta >= 5 then
												self:SetAligned(false)
											end
										else
											local inputX, inputY = input.Position.X, input.Position.Y
											local posX, posY = inputX - offX, inputY - offY
											if posY < 0 then posY = 0 end
											guiMain.Position = UDim2.new(0, posX, 0, posY)

											if self.Resizable and self.Alignable then
												if inputX < 25 then
													if sideHasRoom(leftSide, self.MinY or 100) then
														local insertPos, range = getSideInsertPos(leftSide, inputY)
														alignIndicator.Indicator.Position = UDim2.new(0, -15, 0, range[1])
														alignIndicator.Indicator.Size = UDim2.new(0, 40, 0, range[2] - range[1])
														Lib.ShowGui(alignIndicator)
														alignInsertPos = insertPos
														alignInsertSide = "left"
														return
													end
												elseif inputX >= maxX - 25 then
													if sideHasRoom(rightSide, self.MinY or 100) then
														local insertPos, range = getSideInsertPos(rightSide, inputY)
														alignIndicator.Indicator.Position = UDim2.new(0, maxX - 25, 0, range[1])
														alignIndicator.Indicator.Size = UDim2.new(0, 40, 0, range[2] - range[1])
														Lib.ShowGui(alignIndicator)
														alignInsertPos = insertPos
														alignInsertSide = "right"
														return
													end
												end
											end
											alignIndicator.Parent = nil
											alignInsertPos = nil
											alignInsertSide = nil
										end
									end
								end)
							end
						end
					end)

					FrostznLife.Connect(guiTopBar.Close.MouseButton1Click,function()
						if self.Closed then return end
						self:Close()
					end)

					FrostznLife.Connect(guiTopBar.Minimize.MouseButton1Click,function()
						if self.Closed then return end
						if self.Aligned then
							self:SetAligned(false)
						else
							self:SetMinimized()
						end
					end)

					FrostznLife.Connect(guiTopBar.Minimize.MouseButton2Click,function()
						if self.Closed then return end
						if not self.Aligned then
							self:SetMinimized(nil,2)
							guiTopBar.Minimize.BackgroundTransparency = 1
						end
					end)

					FrostznLife.Connect(guiMain.InputBegan,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not self.Aligned and not self.Closed then
							moveToTop(self)
						end
					end)

					FrostznLife.Connect(guiMain:GetPropertyChangedSignal("AbsolutePosition"),function()
						local absPos = guiMain.AbsolutePosition
						self.PosX = absPos.X
						self.PosY = absPos.Y
					end)

					resizeHook(self,guiResizeControls.North,"N")
					resizeHook(self,guiResizeControls.NorthEast,"NE")
					resizeHook(self,guiResizeControls.East,"E")
					resizeHook(self,guiResizeControls.SouthEast,"SE")
					resizeHook(self,guiResizeControls.South,"S")
					resizeHook(self,guiResizeControls.SouthWest,"SW")
					resizeHook(self,guiResizeControls.West,"W")
					resizeHook(self,guiResizeControls.NorthWest,"NW")

					guiMain.Size = UDim2.new(0,self.SizeX,0,self.SizeY)

					FrostznLife.Connect(gui.DescendantAdded,function(obj) focusInput(self,obj) end)
					local descs = gui:GetDescendants()
					for i = 1,#descs do
						focusInput(self,descs[i])
					end

					self.MinimizeAnim = Lib.ButtonAnim(guiTopBar.Minimize)
					self.CloseAnim = Lib.ButtonAnim(guiTopBar.Close)

					return gui
				end

				local function updateSideFrames(noTween)
					stopTweens()
					leftSide.Frame.Size = UDim2.new(0,leftSide.Width,1,-32)
					rightSide.Frame.Size = UDim2.new(0,rightSide.Width,1,-32)
					leftSide.Frame.Resizer.Position = UDim2.new(0,leftSide.Width,0,0)
					rightSide.Frame.Resizer.Position = UDim2.new(0,-5,0,0)

					--leftSide.Frame.Visible = (#leftSide.Windows > 0)
					--rightSide.Frame.Visible = (#rightSide.Windows > 0)

			--[[if #leftSide.Windows > 0 and leftSide.Frame.Position == UDim2.new(0,-leftSide.Width-5,0,0) then
				leftSide.Frame:TweenPosition(UDim2.new(0,0,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
			elseif #leftSide.Windows == 0 and leftSide.Frame.Position == UDim2.new(0,0,0,0) then
				leftSide.Frame:TweenPosition(UDim2.new(0,-leftSide.Width-5,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
			end
			local rightTweenPos = (#rightSide.Windows == 0 and UDim2.new(1,5,0,0) or UDim2.new(1,-rightSide.Width,0,0))
			rightSide.Frame:TweenPosition(rightTweenPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)]]
					local leftHidden = #leftSide.Windows == 0 or leftSide.Hidden
					local rightHidden = #rightSide.Windows == 0 or rightSide.Hidden
					local leftPos = (leftHidden and UDim2.new(0,-leftSide.Width-10,0,0) or UDim2.new(0,0,0,0))
					local rightPos = (rightHidden and UDim2.new(1,10,0,0) or UDim2.new(1,-rightSide.Width-76,0,0))

					sidesGui.LeftToggle.Text = leftHidden and ">" or "<"
					sidesGui.RightToggle.Text = rightHidden and "<" or ">"

					if not noTween then
						local function insertTween(...)
							local tween = service.TweenService:Create(...)
							tweens[#tweens+1] = tween
							tween:Play()
						end
						insertTween(leftSide.Frame,sideTweenInfo,{Position = leftPos})
						insertTween(rightSide.Frame,sideTweenInfo,{Position = rightPos})
						insertTween(sidesGui.LeftToggle,sideTweenInfo,{Position = UDim2.new(0,#leftSide.Windows == 0 and -16 or 0,0,-36)})
						insertTween(sidesGui.RightToggle,sideTweenInfo,{Position = UDim2.new(1,#rightSide.Windows == 0 and -76 or -92,0,-36)})
					else
						leftSide.Frame.Position = leftPos
						rightSide.Frame.Position = rightPos
						sidesGui.LeftToggle.Position = UDim2.new(0,#leftSide.Windows == 0 and -16 or 0,0,-36)
						sidesGui.RightToggle.Position = UDim2.new(1,#rightSide.Windows == 0 and -76 or -92,0,-36)
					end
				end

				local function getSideFramePos(side)
					local leftHidden = #leftSide.Windows == 0 or leftSide.Hidden
					local rightHidden = #rightSide.Windows == 0 or rightSide.Hidden
					if side == leftSide then
						return (leftHidden and UDim2.new(0,-leftSide.Width-10,0,0) or UDim2.new(0,0,0,0))
					else
						return (rightHidden and UDim2.new(1,10,0,0) or UDim2.new(1,-rightSide.Width-76,0,0))
					end
				end

				local function sideResized(side)
					local currentPos = 0
					local sideFramePos = getSideFramePos(side)
					for i,v in pairs(side.Windows) do
						v.SizeX = side.Width
						v.GuiElems.Main.Size = UDim2.new(0,side.Width,0,v.SizeY)
						v.GuiElems.Main.Position = UDim2.new(sideFramePos.X.Scale,sideFramePos.X.Offset,0,currentPos)
						currentPos = currentPos + v.SizeY+4
					end
				end

				local function sideResizerHook(resizer,dir,side,pos)
					local mouse = Main.Mouse
					local windows = side.Windows

					FrostznLife.Connect(resizer.InputBegan,function(input)
						if not side.Resizing then
							if input.UserInputType == Enum.UserInputType.MouseMovement then
								resizer.BackgroundColor3 = theme.MainColor2
							elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								local releaseEvent, inputEvent

								local offX = input.Position.X - resizer.AbsolutePosition.X
								local offY = input.Position.Y - resizer.AbsolutePosition.Y

								side.Resizing = resizer
								resizer.BackgroundColor3 = theme.MainColor2

								releaseEvent = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
									if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
										releaseEvent:Disconnect()
										if inputEvent then inputEvent:Disconnect() end
										side.Resizing = false
										resizer.BackgroundColor3 = theme.Button
									end
								end)

								inputEvent = FrostznLife.Connect(service.UserInputService.InputChanged,function(input)
									if not resizer.Parent then
										releaseEvent:Disconnect()
										if inputEvent then inputEvent:Disconnect() end
										side.Resizing = false
										return
									end

									if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
										if dir == "V" then
											local delta = input.Position.Y - resizer.AbsolutePosition.Y - offY

											if delta > 0 then
												local neededSize = delta
												for i = pos + 1, #windows do
													local window = windows[i]
													local newSize = math.max(window.SizeY - neededSize, (window.MinY or 100))
													neededSize = neededSize - (window.SizeY - newSize)
													window.SizeY = newSize
												end
												windows[pos].SizeY = windows[pos].SizeY + math.max(0, delta - neededSize)
											else
												local neededSize = -delta
												for i = pos, 1, -1 do
													local window = windows[i]
													local newSize = math.max(window.SizeY - neededSize, (window.MinY or 100))
													neededSize = neededSize - (window.SizeY - newSize)
													window.SizeY = newSize
												end
												windows[pos + 1].SizeY = windows[pos + 1].SizeY + math.max(0, -delta - neededSize)
											end

											updateSideFrames()
											sideResized(side)
										elseif dir == "H" then
											local maxWidth = math.max(300, sidesGui.AbsoluteSize.X - static.FreeWidth - 76)
											local otherSide = (side == leftSide and rightSide or leftSide)
											local delta = input.Position.X - resizer.AbsolutePosition.X - offX
											delta = (side == leftSide and delta or -delta)

											local proposedSize = math.max(static.MinWidth, side.Width + delta)
											if proposedSize + otherSide.Width <= maxWidth then
												side.Width = proposedSize
											else
												local newOtherSize = maxWidth - proposedSize
												if newOtherSize >= static.MinWidth then
													side.Width = proposedSize
													otherSide.Width = newOtherSize
												else
													side.Width = maxWidth - static.MinWidth
													otherSide.Width = static.MinWidth
												end
											end

											updateSideFrames(true)
											sideResized(side)
											sideResized(otherSide)
										end
									end
								end)
							end
						end
					end)

					FrostznLife.Connect(resizer.InputEnded,function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							if side.Resizing ~= resizer then
								resizer.BackgroundColor3 = theme.Button
							end
						end
					end)

				end

				local function renderSide(side,noTween) -- TODO: Use existing resizers
					local currentPos = 0
					local sideFramePos = getSideFramePos(side)
					local template = side.WindowResizer:Clone()
					for i,v in pairs(side.ResizeCons) do v:Disconnect() end
					for i,v in pairs(side.Frame:GetChildren()) do if v.Name == "WindowResizer" then v:Destroy() end end
					side.ResizeCons = {}
					side.Resizing = nil

					for i,v in pairs(side.Windows) do
						v.SidePos = i
						local isEnd = i == #side.Windows
						local size = UDim2.new(0,side.Width,0,v.SizeY)
						local pos = UDim2.new(sideFramePos.X.Scale,sideFramePos.X.Offset,0,currentPos)
						Lib.ShowGui(v.Gui)
						--v.GuiElems.Main:TweenSizeAndPosition(size,pos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
						if noTween then
							v.GuiElems.Main.Size = size
							v.GuiElems.Main.Position = pos
						else
							local tween = service.TweenService:Create(v.GuiElems.Main,sideTweenInfo,{Size = size, Position = pos})
							tweens[#tweens+1] = tween
							tween:Play()
						end
						currentPos = currentPos + v.SizeY+4

						if not isEnd then
							local newTemplate = template:Clone()
							newTemplate.Position = UDim2.new(1,-side.Width,0,currentPos-4)
							side.ResizeCons[#side.ResizeCons+1] = FrostznLife.Connect(v.Gui.Main:GetPropertyChangedSignal("Size"),function()
								newTemplate.Position = UDim2.new(1,-side.Width,0, v.GuiElems.Main.Position.Y.Offset + v.GuiElems.Main.Size.Y.Offset)
							end)
							side.ResizeCons[#side.ResizeCons+1] = FrostznLife.Connect(v.Gui.Main:GetPropertyChangedSignal("Position"),function()
								newTemplate.Position = UDim2.new(1,-side.Width,0, v.GuiElems.Main.Position.Y.Offset + v.GuiElems.Main.Size.Y.Offset)
							end)
							sideResizerHook(newTemplate,"V",side,i)
							newTemplate.Parent = side.Frame
						end
					end

					--side.Frame.Back.Position = UDim2.new(0,0,0,0)
					--side.Frame.Back.Size = UDim2.new(0,side.Width,1,0)
				end

                local function updateSide(side,noTween)
                    local windows=side.Windows
                    local count=#windows
                    if count==0 then renderSide(side,noTween);return end
                    local height=math.max(count*28,sidesGui.AbsoluteSize.Y-32-math.max(0,count-1)*4)
                    local weights,minSum,total={},0,0
                    for i,w in ipairs(windows) do weights[i]=math.max(1,w.SizeY);total+=weights[i];minSum+=(w.MinY or 100) end
                    local used=0
                    if minSum>height then
                        for i,w in ipairs(windows) do w.SizeY=i==count and height-used or math.floor(height/count);used+=w.SizeY end
                    else
                        local remaining=height-minSum
                        for i,w in ipairs(windows) do
                            w.SizeY=i==count and height-used or (w.MinY or 100)+math.floor(remaining*weights[i]/total)
                            used+=w.SizeY
                        end
                    end
                    renderSide(side,noTween)
                end

				updateWindows = function(noTween)
					updateSideFrames(noTween)
					updateSide(leftSide,noTween)
					updateSide(rightSide,noTween)
					local count = 0
					for i = #visibleWindows,1,-1 do
						visibleWindows[i].Gui.DisplayOrder = displayOrderStart + count
						Lib.ShowGui(visibleWindows[i].Gui)
						count = count + 1
					end

			--[[local leftTweenPos = (#leftSide.Windows == 0 and UDim2.new(0,-leftSide.Width-5,0,0) or UDim2.new(0,0,0,0))
			leftSide.Frame:TweenPosition(leftTweenPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)
			local rightTweenPos = (#rightSide.Windows == 0 and UDim2.new(1,5,0,0) or UDim2.new(1,-rightSide.Width,0,0))
			rightSide.Frame:TweenPosition(rightTweenPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.3,true)]]
				end

				funcs.SetMinimized = function(self,set,mode)
					local oldVal = self.Minimized
					local newVal
					if set == nil then newVal = not self.Minimized else newVal = set end
					self.Minimized = newVal
					if not mode then mode = 1 end

					local resizeControls = self.GuiElems.ResizeControls
					local minimizeControls = {"North","NorthEast","NorthWest","South","SouthEast","SouthWest"}
					for i = 1,#minimizeControls do
						local control = resizeControls:FindFirstChild(minimizeControls[i])
						if control then control.Visible = not newVal end
					end

					if mode == 1 or mode == 2 then
						self:StopTweens()
						if mode == 1 then
							self.GuiElems.Main:TweenSize(UDim2.new(0,self.SizeX,0,newVal and 20 or self.SizeY),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.25,true)
						else
							local maxY = sidesGui.AbsoluteSize.Y
							local newPos = UDim2.new(0,self.PosX,0,newVal and math.min(maxY-20,self.PosY + self.SizeY - 20) or math.max(0,self.PosY - self.SizeY + 20))

							self.GuiElems.Main:TweenPosition(newPos,Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.25,true)
							self.GuiElems.Main:TweenSize(UDim2.new(0,self.SizeX,0,newVal and 20 or self.SizeY),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.25,true)
						end
						self.GuiElems.Minimize.ImageLabel.Image = newVal and "rbxassetid://5060023708" or "rbxassetid://5034768003"
					end

					if oldVal ~= newVal then
						if newVal then
							self.OnMinimize:Fire()
						else
							self.OnRestore:Fire()
						end
					end
				end

				funcs.Resize = function(self,sizeX,sizeY)
					self.SizeX = sizeX or self.SizeX
					self.SizeY = sizeY or self.SizeY
					self.GuiElems.Main.Size = UDim2.new(0,self.SizeX,0,self.SizeY)
				end

				funcs.SetSize = funcs.Resize

				funcs.SetTitle = function(self,title)
					self.GuiElems.Title.Text = title
				end

				funcs.SetResizable = function(self,val)
					self.Resizable = val
					self.GuiElems.ResizeControls.Visible = self.Resizable and self.ResizableInternal
				end

				funcs.SetResizableInternal = function(self,val)
					self.ResizableInternal = val
					self.GuiElems.ResizeControls.Visible = self.Resizable and self.ResizableInternal
				end

				funcs.SetAligned = function(self,val)
					self.Aligned = val
					self:SetResizableInternal(not val)
					self.GuiElems.Main.Active = not val
					self.GuiElems.Main.Outlines.Visible = not val
					if not val then
						for i,v in pairs(leftSide.Windows) do if v == self then table.remove(leftSide.Windows,i) break end end
						for i,v in pairs(rightSide.Windows) do if v == self then table.remove(rightSide.Windows,i) break end end
						if not table.find(visibleWindows,self) then table.insert(visibleWindows,1,self) end
						self.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5034768003"
						self.Side = nil
						updateWindows()
					else
						self:SetMinimized(false,3)
						for i,v in pairs(visibleWindows) do if v == self then table.remove(visibleWindows,i) break end end
						self.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5448127505"
					end
				end

				funcs.Add = function(self,obj,name)
					if type(obj) == "table" and obj.Gui and obj.Gui:IsA("GuiObject") then
						obj.Gui.Parent = self.ContentPane
					else
						obj.Parent = self.ContentPane
					end
					if name then self.Elements[name] = obj end
				end

				funcs.GetElement = function(self,obj,name)
					return self.Elements[name]
				end

				funcs.AlignTo = function(self,side,pos,size,silent)
					if table.find(side.Windows,self) or self.Closed then return end

					size = size or self.SizeY
					if size > 0 and size <= 1 then
						local totalSideHeight = 0
						for i,v in pairs(side.Windows) do totalSideHeight = totalSideHeight + v.SizeY end
						self.SizeY = (totalSideHeight > 0 and totalSideHeight * size * 2) or size
					else
						self.SizeY = (size > 0 and size or 100)
					end

					self:SetAligned(true)
					self.Side = side
					self.SizeX = side.Width
					self.Gui.DisplayOrder = sideDisplayOrder + 1
					for i,v in pairs(side.Windows) do v.Gui.DisplayOrder = sideDisplayOrder end
					pos = math.min(#side.Windows+1, pos or 1)
					self.SidePos = pos
					table.insert(side.Windows, pos, self)

					if not silent then
						side.Hidden = false
					end
					-- updateWindows(silent)
				end

				funcs.Close = function(self)
					self.Closed = true
					self:SetResizableInternal(false)

					Lib.FindAndRemove(leftSide.Windows,self)
					Lib.FindAndRemove(rightSide.Windows,self)
					Lib.FindAndRemove(visibleWindows,self)

					self.MinimizeAnim.Disable()
					self.CloseAnim.Disable()
					self.ClosedSide = self.Side
					self.Side = nil
					self.OnDeactivate:Fire()

					if not self.Aligned then
						self:StopTweens()
						local ti = TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)

						local closeTime = tick()
						self.LastClose = closeTime

						self:DoTween(self.GuiElems.Main,ti,{Size = UDim2.new(0,self.SizeX,0,20)})
						self:DoTween(self.GuiElems.Title,ti,{TextTransparency = 1})
						self:DoTween(self.GuiElems.Minimize.ImageLabel,ti,{ImageTransparency = 1})
						self:DoTween(self.GuiElems.Close.ImageLabel,ti,{ImageTransparency = 1})
						Lib.FastWait(0.2)
						if closeTime ~= self.LastClose then return end

						self:DoTween(self.GuiElems.TopBar,ti,{BackgroundTransparency = 1})
						self:DoTween(self.GuiElems.Outlines,ti,{ImageTransparency = 1})
						Lib.FastWait(0.2)
						if closeTime ~= self.LastClose then return end
					end

					self.Aligned = false
					self.Gui.Parent = nil
					updateWindows(true)
				end

				funcs.Hide = funcs.Close

				funcs.IsVisible = function(self)
					return not self.Closed and ((self.Side and not self.Side.Hidden) or not self.Side)
				end

				funcs.IsContentVisible = function(self)
					return self:IsVisible() and not self.Minimized
				end

				funcs.Focus = function(self)
					moveToTop(self)
				end

                funcs.MoveInBoundary=function(self)
                    if self.Aligned or not sidesGui then return end
                    local maxX,maxY=math.max(180,sidesGui.AbsoluteSize.X-92),math.max(100,sidesGui.AbsoluteSize.Y-40)
                    self.SizeX=math.min(self.SizeX,maxX);self.SizeY=math.min(self.SizeY,maxY)
                    local x=math.clamp(self.PosX,8,math.max(8,maxX-self.SizeX+8))
                    local y=math.clamp(self.PosY,0,math.max(0,maxY-self.SizeY))
                    self.PosX=x;self.PosY=y
                    self.GuiElems.Main.Position=UDim2.fromOffset(x,y)
                    self.GuiElems.Main.Size=UDim2.fromOffset(self.SizeX,self.Minimized and 20 or self.SizeY)
                end

				funcs.DoTween = function(self,...)
					local tween = service.TweenService:Create(...)
					self.Tweens[#self.Tweens+1] = tween
					tween:Play()
				end

				funcs.StopTweens = function(self)
					for i,v in pairs(self.Tweens) do
						v:Cancel()
					end
					self.Tweens = {}
				end

				funcs.Show = function(self,data)
					return static.ShowWindow(self,data)
				end

				funcs.ShowAndFocus = function(self,data)
					static.ShowWindow(self,data)
					service.RunService.RenderStepped:wait()
					self:Focus()
				end

				static.ShowWindow = function(window,data)
					data = data or {}
					local align = data.Align
					local pos = data.Pos
					local size = data.Size
					local targetSide = (align == "left" and leftSide) or (align == "right" and rightSide)

					if not window.Closed then
						if not window.Aligned then
							window:SetMinimized(false)
						elseif window.Side and not data.Silent then
							static.SetSideVisible(window.Side,true)
						end
						return
					end

					window.Closed = false
					window.LastClose = tick()
					window.GuiElems.Title.TextTransparency = 0
					window.GuiElems.Minimize.ImageLabel.ImageTransparency = 0
					window.GuiElems.Close.ImageLabel.ImageTransparency = 0
					window.GuiElems.TopBar.BackgroundTransparency = 0
					window.GuiElems.Outlines.ImageTransparency = 0
					window.GuiElems.Minimize.ImageLabel.Image = "rbxassetid://5034768003"
					window.GuiElems.Main.Active = true
					window.GuiElems.Main.Outlines.Visible = true
					window:SetMinimized(false,3)
					window:SetResizableInternal(true)
					window.MinimizeAnim.Enable()
					window.CloseAnim.Enable()

					if align then
						window:AlignTo(targetSide,pos,size,data.Silent)
					else
						if align == nil and window.ClosedSide then -- Regular open
							window:AlignTo(window.ClosedSide,window.SidePos,size,true)
							static.SetSideVisible(window.ClosedSide,true)
						else
							if table.find(visibleWindows,window) then return end

							-- TODO: make better
							window.GuiElems.Main.Size = UDim2.new(0,window.SizeX,0,20)
							local ti = TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
							window:StopTweens()
							window:DoTween(window.GuiElems.Main,ti,{Size = UDim2.new(0,window.SizeX,0,window.SizeY)})

							window.SizeY = size or window.SizeY
							table.insert(visibleWindows,1,window)
							updateWindows()
						end
					end

					window.ClosedSide = nil
					if not window.Aligned then window:MoveInBoundary() end
                    window.OnActivate:Fire()
				end

				static.Reflow=function()
                    for _,w in ipairs(visibleWindows) do w:MoveInBoundary() end
                    updateWindows(true)
                end
                static.GetLayout=function()return {left=leftSide,right=rightSide,size=sidesGui.AbsoluteSize}end
                static.ToggleSide = function(name)
					local side = (name == "left" and leftSide or rightSide)
					side.Hidden = not side.Hidden
					for i,v in pairs(side.Windows) do
						if side.Hidden then
							v.OnDeactivate:Fire()
						else
							v.OnActivate:Fire()
						end
					end
					updateWindows()
				end

				static.SetSideVisible = function(s,vis)
					local side = (type(s) == "table" and s) or (s == "left" and leftSide or rightSide)
					side.Hidden = not vis
					for i,v in pairs(side.Windows) do
						if side.Hidden then
							v.OnDeactivate:Fire()
						else
							v.OnActivate:Fire()
						end
					end
					updateWindows()
				end

				static.Init = function()
					displayOrderStart = Main.DisplayOrders.Window
					sideDisplayOrder = Main.DisplayOrders.SideWindow

					sidesGui = Instance.new("ScreenGui")
					local leftFrame = create({
						{1,"Frame",{Active=true,Name="LeftSide",BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,}},
						{2,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2549019753933,0.2549019753933,0.2549019753933),BorderSizePixel=0,Font=3,Name="Resizer",Parent={1},Size=UDim2.new(0,5,1,0),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{3,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderSizePixel=0,Name="Line",Parent={2},Position=UDim2.new(0,0,0,0),Size=UDim2.new(0,1,1,0),}},
						{4,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2549019753933,0.2549019753933,0.2549019753933),BorderSizePixel=0,Font=3,Name="WindowResizer",Parent={1},Position=UDim2.new(1,-300,0,0),Size=UDim2.new(1,0,0,4),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{5,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderSizePixel=0,Name="Line",Parent={4},Size=UDim2.new(1,0,0,1),}},
					})
					leftSide.Frame = leftFrame
					leftFrame.Position = UDim2.new(0,-leftSide.Width-10,0,0)
					leftSide.WindowResizer = leftFrame.WindowResizer
					leftFrame.WindowResizer.Parent = nil
					leftFrame.Parent = sidesGui

					local rightFrame = create({
						{1,"Frame",{Active=true,Name="RightSide",BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,}},
						{2,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2549019753933,0.2549019753933,0.2549019753933),BorderSizePixel=0,Font=3,Name="Resizer",Parent={1},Size=UDim2.new(0,5,1,0),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{3,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderSizePixel=0,Name="Line",Parent={2},Position=UDim2.new(0,4,0,0),Size=UDim2.new(0,1,1,0),}},
						{4,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2549019753933,0.2549019753933,0.2549019753933),BorderSizePixel=0,Font=3,Name="WindowResizer",Parent={1},Position=UDim2.new(1,-300,0,0),Size=UDim2.new(1,0,0,4),Text="",TextColor3=Color3.new(0,0,0),TextSize=14,}},
						{5,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderSizePixel=0,Name="Line",Parent={4},Size=UDim2.new(1,0,0,1),}},
					})
					rightSide.Frame = rightFrame
					rightFrame.Position = UDim2.new(1,10,0,0)
					rightSide.WindowResizer = rightFrame.WindowResizer
					rightFrame.WindowResizer.Parent = nil
					rightFrame.Parent = sidesGui

					sideResizerHook(leftFrame.Resizer,"H",leftSide)
					sideResizerHook(rightFrame.Resizer,"H",rightSide)

					alignIndicator = Instance.new("ScreenGui")
					alignIndicator.DisplayOrder = Main.DisplayOrders.Core
					local indicator = Instance.new("Frame",alignIndicator)
					indicator.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
					indicator.BorderSizePixel = 0
					indicator.BackgroundTransparency = 0.8
					indicator.Name = "Indicator"
					local corner = Instance.new("UICorner",indicator)
					corner.CornerRadius = UDim.new(0,10)

					local leftToggle = create({{1,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderMode=2,Font=10,Name="LeftToggle",Position=UDim2.new(0,0,0,-36),Size=UDim2.new(0,16,0,36),Text="<",TextColor3=Color3.new(1,1,1),TextSize=14,}}})
					local rightToggle = leftToggle:Clone()
					rightToggle.Name = "RightToggle"
					rightToggle.Position = UDim2.new(1,-16,0,-36)
					Lib.ButtonAnim(leftToggle,{Mode = 2,PressColor = Color3.fromRGB(32,32,32)})
					Lib.ButtonAnim(rightToggle,{Mode = 2,PressColor = Color3.fromRGB(32,32,32)})

					FrostznLife.Connect(leftToggle.MouseButton1Click,function()
						static.ToggleSide("left")
					end)

					FrostznLife.Connect(rightToggle.MouseButton1Click,function()
						static.ToggleSide("right")
					end)

					leftToggle.Parent = sidesGui
					rightToggle.Parent = sidesGui

					FrostznLife.Connect(sidesGui:GetPropertyChangedSignal("AbsoluteSize"),function()
						local maxWidth = math.max(300,sidesGui.AbsoluteSize.X-static.FreeWidth)
						leftSide.Width = math.max(static.MinWidth,math.min(leftSide.Width,maxWidth-rightSide.Width))
						rightSide.Width = math.max(static.MinWidth,math.min(rightSide.Width,maxWidth-leftSide.Width))
						for i = 1,#visibleWindows do
							visibleWindows[i]:MoveInBoundary()
						end
						updateWindows(true)
					end)

					sidesGui.DisplayOrder = sideDisplayOrder - 1
					Lib.ShowGui(sidesGui)
					updateSideFrames()
				end

				local mt = {__index = funcs}
				static.new = function()
					local obj = setmetatable({
						Minimized = false,
						Dragging = false,
						Resizing = false,
						Aligned = false,
						Draggable = true,
						Resizable = true,
						ResizableInternal = true,
						Alignable = true,
						Closed = true,
						SizeX = 300,
						SizeY = 300,
						MinX = 200,
						MinY = 200,
						PosX = 0,
						PosY = 0,
						GuiElems = {},
						Tweens = {},
						Elements = {},
						OnActivate = Lib.Signal.new(),
						OnDeactivate = Lib.Signal.new(),
						OnMinimize = Lib.Signal.new(),
						OnRestore = Lib.Signal.new()
					},mt)
					obj.Gui = createGui(obj)
					return obj
				end

				return static
			end)()

			Lib.ContextMenu = (function()
				local funcs = {}
				local mouse

				local function createGui(self)
					local contextGui = create({
						{1,"ScreenGui",{DisplayOrder=1000000,Name="Context",ZIndexBehavior=1,}},
						{2,"Frame",{Active=true,BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),Name="Main",Parent={1},Position=UDim2.new(0.5,-100,0.5,-150),Size=UDim2.new(0,200,0,100),}},
						{3,"UICorner",{CornerRadius=UDim.new(0,4),Parent={2},}},
						{4,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),Name="Container",Parent={2},Position=UDim2.new(0,1,0,1),Size=UDim2.new(1,-2,1,-2),}},
						{5,"UICorner",{CornerRadius=UDim.new(0,4),Parent={4},}},
						{6,"ScrollingFrame",{Active=true,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),Name="List",Parent={4},Position=UDim2.new(0,2,0,2),ScrollBarImageColor3=Color3.new(0,0,0),ScrollBarThickness=4,Size=UDim2.new(1,-4,1,-4),VerticalScrollBarInset=1,}},
						{7,"UIListLayout",{Parent={6},SortOrder=2,}},
						{8,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="SearchFrame",Parent={4},Size=UDim2.new(1,0,0,24),Visible=false,}},
						{9,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.1176470592618,0.1176470592618,0.1176470592618),BorderSizePixel=0,Name="SearchContainer",Parent={8},Position=UDim2.new(0,3,0,3),Size=UDim2.new(1,-6,0,18),}},
						{10,"TextBox",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="SearchBox",Parent={9},PlaceholderColor3=Color3.new(0.39215689897537,0.39215689897537,0.39215689897537),PlaceholderText="Search",Position=UDim2.new(0,4,0,0),Size=UDim2.new(1,-8,0,18),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,}},
						{11,"UICorner",{CornerRadius=UDim.new(0,2),Parent={9},}},
						{12,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderSizePixel=0,Name="Line",Parent={8},Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,1),}},
						{13,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BackgroundTransparency=1,BorderColor3=Color3.new(0.33725491166115,0.49019610881805,0.73725491762161),BorderSizePixel=0,Font=3,Name="Entry",Parent={1},Size=UDim2.new(1,0,0,22),Text="",TextSize=14,Visible=false,}},
						{14,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="EntryName",Parent={13},Position=UDim2.new(0,24,0,0),Size=UDim2.new(1,-24,1,0),Text="Duplicate",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{15,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Shortcut",Parent={13},Position=UDim2.new(0,24,0,0),Size=UDim2.new(1,-30,1,0),Text="Ctrl+D",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{16,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,ImageRectOffset=Vector2.new(304,0),ImageRectSize=Vector2.new(16,16),Name="Icon",Parent={13},Position=UDim2.new(0,2,0,3),ScaleType=4,Size=UDim2.new(0,16,0,16),}},
						{17,"UICorner",{CornerRadius=UDim.new(0,4),Parent={13},}},
						{18,"Frame",{BackgroundColor3=Color3.new(0.21568629145622,0.21568629145622,0.21568629145622),BackgroundTransparency=1,BorderSizePixel=0,Name="Divider",Parent={1},Position=UDim2.new(0,0,0,20),Size=UDim2.new(1,0,0,7),Visible=false,}},
						{19,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="Line",Parent={18},Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(1,0,0,1),}},
						{20,"TextLabel",{AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="DividerName",Parent={18},Position=UDim2.new(0,2,0.5,0),Size=UDim2.new(1,-4,1,0),Text="Objects",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=0.60000002384186,TextXAlignment=0,Visible=false,}}
					})

					self.GuiElems.Main = contextGui.Main
					self.GuiElems.List = contextGui.Main.Container.List
					self.GuiElems.Entry = contextGui.Entry
					self.GuiElems.Divider = contextGui.Divider
					self.GuiElems.SearchFrame = contextGui.Main.Container.SearchFrame
					self.GuiElems.SearchBar = self.GuiElems.SearchFrame.SearchContainer.SearchBox
					Lib.ViewportTextBox.convert(self.GuiElems.SearchBar)

					FrostznLife.Connect(self.GuiElems.SearchBar:GetPropertyChangedSignal("Text"),function()
						local lower,find = string.lower,string.find
						local searchText = lower(self.GuiElems.SearchBar.Text)
						local items = self.Items
						local map = self.ItemToEntryMap

						if searchText ~= "" then
							local results = {}
							local count = 1
							for i = 1,#items do
								local item = items[i]
								local entry = map[item]
								if entry then
									if not item.Divider and find(lower(item.Name),searchText,1,true) then
										results[count] = item
										count = count + 1
									else
										entry.Visible = false
									end
								end
							end
							table.sort(results,function(a,b) return a.Name < b.Name end)
							for i = 1,#results do
								local entry = map[results[i]]
								entry.LayoutOrder = i
								entry.Visible = true
							end
						else
							for i = 1,#items do
								local entry = map[items[i]]
								if entry then entry.LayoutOrder = i entry.Visible = true end
							end
						end

						local toSize = self.GuiElems.List.UIListLayout.AbsoluteContentSize.Y + 6
						self.GuiElems.List.CanvasSize = UDim2.new(0,0,0,toSize-6)
					end)

					return contextGui
				end

				funcs.Add = function(self,item)
					local newItem = {
						Name = item.Name or "Item",
						Icon = item.Icon or "",
						Shortcut = item.Shortcut or "",
						OnClick = item.OnClick,
						OnHover = item.OnHover,
						Disabled = item.Disabled or false,
						DisabledIcon = item.DisabledIcon or "",
						IconMap = item.IconMap,
						OnRightClick = item.OnRightClick
					}

					if self.QueuedDivider then
						local text = self.QueuedDividerText and #self.QueuedDividerText > 0 and self.QueuedDividerText
						self:AddDivider(text)
					end
					self.Items[#self.Items+1] = newItem
					self.Updated = nil
				end

				funcs.AddRegistered = function(self,name,disabled)
					if not self.Registered[name] then error(name.." is not registered") end

					if self.QueuedDivider then
						local text = self.QueuedDividerText and #self.QueuedDividerText > 0 and self.QueuedDividerText
						self:AddDivider(text)
					end
					self.Registered[name].Disabled = disabled
					self.Items[#self.Items+1] = self.Registered[name]
					self.Updated = nil
				end

				funcs.Register = function(self,name,item)
					self.Registered[name] = {
						Name = item.Name or "Item",
						Icon = item.Icon or "",
						Shortcut = item.Shortcut or "",
						OnClick = item.OnClick,
						OnHover = item.OnHover,
						DisabledIcon = item.DisabledIcon or "",
						IconMap = item.IconMap,
						OnRightClick = item.OnRightClick
					}
				end

				funcs.UnRegister = function(self,name)
					self.Registered[name] = nil
				end

				funcs.AddDivider = function(self,text)
					self.QueuedDivider = false
					local textWidth = text and service.TextService:GetTextSize(text,14,Enum.Font.SourceSans,Vector2.new(999999999,20)).X or nil
					table.insert(self.Items,{Divider = true, Text = text, TextSize = textWidth and textWidth+4})
					self.Updated = nil
				end

				funcs.QueueDivider = function(self,text)
					self.QueuedDivider = true
					self.QueuedDividerText = text or ""
				end

				funcs.Clear = function(self)
					self.Items = {}
					self.Updated = nil
				end

				funcs.Refresh = function(self)
					for i,v in pairs(self.GuiElems.List:GetChildren()) do
						if not v:IsA("UIListLayout") then
							v:Destroy()
						end
					end
					local map = {}
					self.ItemToEntryMap = map

					local dividerFrame = self.GuiElems.Divider
					local contextList = self.GuiElems.List
					local entryFrame = self.GuiElems.Entry
					local items = self.Items

					for i = 1,#items do
						local item = items[i]
						if item.Divider then
							local newDivider = dividerFrame:Clone()
							newDivider.Line.BackgroundColor3 = self.Theme.DividerColor
							if item.Text then
								newDivider.Size = UDim2.new(1,0,0,20)
								newDivider.Line.Position = UDim2.new(0,item.TextSize,0.5,0)
								newDivider.Line.Size = UDim2.new(1,-item.TextSize,0,1)
								newDivider.DividerName.TextColor3 = self.Theme.TextColor
								newDivider.DividerName.Text = item.Text
								newDivider.DividerName.Visible = true
							end
							newDivider.Visible = true
							map[item] = newDivider
							newDivider.Parent = contextList
						else
							local newEntry = entryFrame:Clone()
							newEntry.BackgroundColor3 = self.Theme.HighlightColor
							newEntry.EntryName.TextColor3 = self.Theme.TextColor
							newEntry.EntryName.Text = item.Name
							newEntry.Shortcut.Text = item.Shortcut
							if item.Disabled then
								newEntry.EntryName.TextColor3 = Color3.new(150/255,150/255,150/255)
								newEntry.Shortcut.TextColor3 = Color3.new(150/255,150/255,150/255)
							end

							if self.Iconless then
								newEntry.EntryName.Position = UDim2.new(0,2,0,0)
								newEntry.EntryName.Size = UDim2.new(1,-4,0,20)
								newEntry.Icon.Visible = false
							else
								local iconIndex = item.Disabled and item.DisabledIcon or item.Icon
								-- Explorer.MiscIcons:DisplayExplorerIcons(newEntry.Icon, iconIndex)
								if item.IconMap then
									if type(iconIndex) == "number" then
										item.IconMap:Display(newEntry.Icon, iconIndex)
									elseif type(iconIndex) == "string" then
										item.IconMap:DisplayByKey(newEntry.Icon, iconIndex)
									end
								elseif type(iconIndex) == "string" then
									newEntry.Icon.Image = iconIndex
								end
							end

							if not item.Disabled then
								if item.OnClick then
									FrostznLife.Connect(newEntry.MouseButton1Click,function()
										item.OnClick(item.Name)
										if not item.NoHide then
											self:Hide()
										end
									end)
								end

								if item.OnRightClick then
									FrostznLife.Connect(newEntry.MouseButton2Click,function()
										item.OnRightClick(item.Name)
										if not item.NoHide then
											self:Hide()
										end
									end)
								end
							end

							FrostznLife.Connect(newEntry.InputBegan,function(input)
								if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
									newEntry.BackgroundTransparency = 0
								end
							end)

							FrostznLife.Connect(newEntry.InputEnded,function(input)
								if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
									newEntry.BackgroundTransparency = 1
								end
							end)

							newEntry.Visible = true
							map[item] = newEntry
							newEntry.Parent = contextList
						end
					end
					self.Updated = true
				end

				funcs.Show = function(self,x,y)
					local elems = self.GuiElems
					elems.SearchFrame.Visible = self.SearchEnabled
					elems.List.Position = UDim2.new(0,2,0,2 + (self.SearchEnabled and 24 or 0))
					elems.List.Size = UDim2.new(1,-4,1,-4 - (self.SearchEnabled and 24 or 0))
					if self.SearchEnabled and self.ClearSearchOnShow then elems.SearchBar.Text = "" end
					self.GuiElems.List.CanvasPosition = Vector2.new(0,0)

					if not self.Updated then
						self:Refresh()
					end

					-- Vars
					local reverseY = false
					local x,y = x or mouse.X, y or mouse.Y
					local maxX,maxY = mouse.ViewSizeX,mouse.ViewSizeY

					-- Position and show
					if x + self.Width > maxX then
						x = self.ReverseX and x - self.Width or maxX - self.Width
					end
					elems.Main.Position = UDim2.new(0,x,0,y)
					elems.Main.Size = UDim2.new(0,self.Width,0,0)
					self.Gui.DisplayOrder = Main.DisplayOrders.Menu
					Lib.ShowGui(self.Gui)

					-- Size adjustment
					local toSize = elems.List.UIListLayout.AbsoluteContentSize.Y + 6 -- Padding
					if self.MaxHeight and toSize > self.MaxHeight then
						elems.List.CanvasSize = UDim2.new(0,0,0,toSize-6)
						toSize = self.MaxHeight
					else
						elems.List.CanvasSize = UDim2.new(0,0,0,0)
					end
					if y + toSize > maxY then reverseY = true end

					-- Close event
					local closable
					if self.CloseEvent then self.CloseEvent:Disconnect() end
					self.CloseEvent = FrostznLife.Connect(service.UserInputService.InputBegan,function(input)
						if not closable then return end

						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							if not Lib.CheckMouseInGui(elems.Main) then
								self.CloseEvent:Disconnect()
								self:Hide()
							end
						end
					end)

					-- Resize
					if reverseY then
						elems.Main.Position = UDim2.new(0,x,0,y-(self.ReverseYOffset or 0))
						local newY = y - toSize - (self.ReverseYOffset or 0)
						y = newY >= 0 and newY or 0
						elems.Main:TweenSizeAndPosition(UDim2.new(0,self.Width,0,toSize),UDim2.new(0,x,0,y),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.2,true)
					else
						elems.Main:TweenSize(UDim2.new(0,self.Width,0,toSize),Enum.EasingDirection.Out,Enum.EasingStyle.Quart,0.2,true)
					end

					-- Close debounce
					Lib.FastWait()
					if self.SearchEnabled and self.FocusSearchOnShow then elems.SearchBar:CaptureFocus() end
					closable = true
				end

				funcs.Hide = function(self)
					self.Gui.Parent = nil
				end

				funcs.ApplyTheme = function(self,data)
					local theme = self.Theme
					theme.ContentColor = data.ContentColor or Settings.Theme.Menu
					theme.OutlineColor = data.OutlineColor or Settings.Theme.Menu
					theme.DividerColor = data.DividerColor or Settings.Theme.Outline2
					theme.TextColor = data.TextColor or Settings.Theme.Text
					theme.HighlightColor = data.HighlightColor or Settings.Theme.Main1

					self.GuiElems.Main.BackgroundColor3 = theme.OutlineColor
					self.GuiElems.Main.Container.BackgroundColor3 = theme.ContentColor
				end

				local mt = {__index = funcs}
				local function new()
					if not mouse then mouse = Main.Mouse or service.Players.LocalPlayer:GetMouse() end

					local obj = setmetatable({
						Width = 200,
						MaxHeight = nil,
						Iconless = false,
						SearchEnabled = false,
						ClearSearchOnShow = true,
						FocusSearchOnShow = true,
						Updated = false,
						QueuedDivider = false,
						QueuedDividerText = "",
						Items = {},
						Registered = {},
						GuiElems = {},
						Theme = {}
					},mt)
					obj.Gui = createGui(obj)
					obj:ApplyTheme({})
					return obj
				end

				return {new = new}
			end)()

			Lib.CodeFrame = (function()
				local funcs = {}

				local typeMap = {
					[1] = "String",
					[2] = "String",
					[3] = "String",
					[4] = "Comment",
					[5] = "Operator",
					[6] = "Number",
					[7] = "Keyword",
					[8] = "BuiltIn",
					[9] = "LocalMethod",
					[10] = "LocalProperty",
					[11] = "Nil",
					[12] = "Bool",
					[13] = "Function",
					[14] = "Local",
					[15] = "Self",
					[16] = "FunctionName",
					[17] = "Bracket"
				}

				local specialKeywordsTypes = {
					["nil"] = 11,
					["true"] = 12,
					["false"] = 12,
					["function"] = 13,
					["local"] = 14,
					["self"] = 15
				}

				local keywords = {
					["and"] = true,
					["break"] = true, 
					["do"] = true,
					["else"] = true,
					["elseif"] = true,
					["end"] = true,
					["false"] = true,
					["for"] = true,
					["function"] = true,
					["if"] = true,
					["in"] = true,
					["local"] = true,
					["nil"] = true,
					["not"] = true,
					["or"] = true,
					["repeat"] = true,
					["return"] = true,
					["then"] = true,
					["true"] = true,
					["until"] = true,
					["while"] = true,
					["plugin"] = true
				}

				local builtIns = {
					["delay"] = true,
					["elapsedTime"] = true,
					["require"] = true,
					["spawn"] = true,
					["tick"] = true,
					["time"] = true,
					["typeof"] = true,
					["UserSettings"] = true,
					["wait"] = true,
					["warn"] = true,
					["game"] = true,
					["shared"] = true,
					["script"] = true,
					["workspace"] = true,
					["assert"] = true,
					["collectgarbage"] = true,
					["error"] = true,
					["getfenv"] = true,
					["getmetatable"] = true,
					["ipairs"] = true,
					["loadstring"] = true,
					["newproxy"] = true,
					["next"] = true,
					["pairs"] = true,
					["pcall"] = true,
					["print"] = true,
					["rawequal"] = true,
					["rawget"] = true,
					["rawset"] = true,
					["select"] = true,
					["setfenv"] = true,
					["setmetatable"] = true,
					["tonumber"] = true,
					["tostring"] = true,
					["type"] = true,
					["unpack"] = true,
					["xpcall"] = true,
					["_G"] = true,
					["_VERSION"] = true,
					["coroutine"] = true,
					["debug"] = true,
					["math"] = true,
					["os"] = true,
					["string"] = true,
					["table"] = true,
					["bit32"] = true,
					["utf8"] = true,
					["Axes"] = true,
					["BrickColor"] = true,
					["CFrame"] = true,
					["Color3"] = true,
					["ColorSequence"] = true,
					["ColorSequenceKeypoint"] = true,
					["DockWidgetPluginGuiInfo"] = true,
					["Enum"] = true,
					["Faces"] = true,
					["Instance"] = true,
					["NumberRange"] = true,
					["NumberSequence"] = true,
					["NumberSequenceKeypoint"] = true,
					["PathWaypoint"] = true,
					["PhysicalProperties"] = true,
					["Random"] = true,
					["Ray"] = true,
					["Rect"] = true,
					["Region3"] = true,
					["Region3int16"] = true,
					["TweenInfo"] = true,
					["UDim"] = true,
					["UDim2"] = true,
					["Vector2"] = true,
					["Vector2int16"] = true,
					["Vector3"] = true,
					["Vector3int16"] = true
				}

				local builtInInited = false

				local richReplace = {
					["'"] = "&apos;",
					["\""] = "&quot;",
					["<"] = "&lt;",
					[">"] = "&gt;",
					["&"] = "&amp;"
				}

				local tabSub = "\t"
				local tabReplacement = (" %s "):format(tabSub)

				local tabJumps = {
					[("[^%s] "):format(tabSub)] = 0,
					[(" %s"):format(tabSub)] = -1,
					[("%s "):format(tabSub)] = 2,
					[(" [^%s]"):format(tabSub)] = 1,
				}

				local tweenService = service.TweenService
				local lineTweens = {}

				local function initBuiltIn()
					local env = getfenv()
					local type = type
					local tostring = tostring
					for name,_ in next,builtIns do
						local envVal = env[name]
						if type(envVal) == "table" then
							local items = {}
							for i,v in next,envVal do
								items[i] = true
							end
							builtIns[name] = items
						end
					end

					local enumEntries = {}
					local enums = Enum:GetEnums()
					for i = 1,#enums do
						enumEntries[tostring(enums[i])] = true
					end
					builtIns["Enum"] = enumEntries

					builtInInited = true
				end

				local function setupEditBox(obj)
					local editBox = obj.GuiElems.EditBox

					FrostznLife.Connect(editBox.Focused,function()
						obj:ConnectEditBoxEvent()
						obj.Editing = true
					end)

					FrostznLife.Connect(editBox.FocusLost,function()
						obj:DisconnectEditBoxEvent()
						obj.Editing = false
					end)

					FrostznLife.Connect(editBox:GetPropertyChangedSignal("Text"),function()
						local text = editBox.Text
						if #text == 0 or obj.EditBoxCopying then return end
						editBox.Text = ""
						obj:AppendText(text)
					end)
				end

				local function setupMouseSelection(obj)
					local mouse = plr:GetMouse()
					local codeFrame = obj.GuiElems.LinesFrame
					local lines = obj.Lines

					FrostznLife.Connect(codeFrame.InputBegan,function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							local fontSizeX, fontSizeY = math.ceil(obj.FontSize / 2), obj.FontSize
							local relX = input.Position.X - codeFrame.AbsolutePosition.X
							local relY = input.Position.Y - codeFrame.AbsolutePosition.Y
							local selX = math.round(relX / fontSizeX) + obj.ViewX
							local selY = math.floor(relY / fontSizeY) + obj.ViewY
							local releaseEvent, inputEvent, scrollEvent
							local scrollPowerV, scrollPowerH = 0, 0
							selY = math.min(#lines - 1, selY)
							local relativeLine = lines[selY + 1] or ""
							selX = math.min(#relativeLine, selX + obj:TabAdjust(selX, selY))

							obj.SelectionRange = {{-1, -1}, {-1, -1}}
							obj:MoveCursor(selX, selY)
							obj.FloatCursorX = selX

							local function updateSelection()
								local relX = input.Position.X - codeFrame.AbsolutePosition.X
								local relY = input.Position.Y - codeFrame.AbsolutePosition.Y
								local sel2X = math.max(0, math.round(relX / fontSizeX) + obj.ViewX)
								local sel2Y = math.max(0, math.floor(relY / fontSizeY) + obj.ViewY)

								sel2Y = math.min(#lines - 1, sel2Y)
								local relativeLine = lines[sel2Y + 1] or ""
								sel2X = math.min(#relativeLine, sel2X + obj:TabAdjust(sel2X, sel2Y))

								if sel2Y < selY or (sel2Y == selY and sel2X < selX) then
									obj.SelectionRange = {{sel2X, sel2Y}, {selX, selY}}
								else						
									obj.SelectionRange = {{selX, selY}, {sel2X, sel2Y}}
								end

								obj:MoveCursor(sel2X, sel2Y)
								obj.FloatCursorX = sel2X
								obj:Refresh()
							end

							releaseEvent = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
								if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
									releaseEvent:Disconnect()
									inputEvent:Disconnect()
									scrollEvent:Disconnect()
									obj:SetCopyableSelection()
								end
							end)

							inputEvent = FrostznLife.Connect(service.UserInputService.InputChanged,function(input)
								if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
									local upDelta = input.Position.Y - codeFrame.AbsolutePosition.Y
									local downDelta = input.Position.Y - codeFrame.AbsolutePosition.Y - codeFrame.AbsoluteSize.Y
									local leftDelta = input.Position.X - codeFrame.AbsolutePosition.X
									local rightDelta = input.Position.X - codeFrame.AbsolutePosition.X - codeFrame.AbsoluteSize.X

									scrollPowerV = 0
									scrollPowerH = 0
									if downDelta > 0 then
										scrollPowerV = math.floor(downDelta * 0.05) + 1
									elseif upDelta < 0 then
										scrollPowerV = math.ceil(upDelta * 0.05) - 1
									end
									if rightDelta > 0 then
										scrollPowerH = math.floor(rightDelta * 0.05) + 1
									elseif leftDelta < 0 then
										scrollPowerH = math.ceil(leftDelta * 0.05) - 1
									end
									updateSelection()
								end
							end)

							scrollEvent = FrostznLife.Connect(service.RunService.RenderStepped,function()
								if scrollPowerV ~= 0 or scrollPowerH ~= 0 then
									obj:ScrollDelta(scrollPowerH, scrollPowerV)
									updateSelection()
								end
							end)

							obj:Refresh()
						end
					end)

				end

				local function makeFrame(obj)
					local frame = create({
						{1,"Frame",{BackgroundColor3=Color3.new(0.15686275064945,0.15686275064945,0.15686275064945),BorderSizePixel = 0,Position=UDim2.new(0.5,-300,0.5,-200),Size=UDim2.new(0,600,0,400),}},
					})
					local elems = {}

					local linesFrame = Instance.new("Frame")
					linesFrame.Name = "Lines"
					linesFrame.BackgroundTransparency = 1
					linesFrame.Size = UDim2.new(1,0,1,0)
					linesFrame.ClipsDescendants = true
					linesFrame.Parent = frame

					local lineNumbersLabel = Instance.new("TextLabel")
					lineNumbersLabel.Name = "LineNumbers"
					lineNumbersLabel.BackgroundTransparency = 1
					lineNumbersLabel.Font = Enum.Font.Code
					lineNumbersLabel.TextXAlignment = Enum.TextXAlignment.Right
					lineNumbersLabel.TextYAlignment = Enum.TextYAlignment.Top
					lineNumbersLabel.ClipsDescendants = true
					lineNumbersLabel.RichText = true
					lineNumbersLabel.Parent = frame

					local cursor = Instance.new("Frame")
					cursor.Name = "Cursor"
					cursor.BackgroundColor3 = Color3.fromRGB(220,220,220)
					cursor.BorderSizePixel = 0
					cursor.Parent = frame

					local editBox = Instance.new("TextBox")
					editBox.Name = "EditBox"
					editBox.MultiLine = true
					editBox.Visible = false
					editBox.Parent = frame

					lineTweens.Invis = tweenService:Create(cursor,TweenInfo.new(0.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundTransparency = 1})
					lineTweens.Vis = tweenService:Create(cursor,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{BackgroundTransparency = 0})

					elems.LinesFrame = linesFrame
					elems.LineNumbersLabel = lineNumbersLabel
					elems.Cursor = cursor
					elems.EditBox = editBox
					elems.ScrollCorner = create({{1,"Frame",{BackgroundColor3=Color3.new(0.15686275064945,0.15686275064945,0.15686275064945),BorderSizePixel=0,Name="ScrollCorner",Position=UDim2.new(1,-16,1,-16),Size=UDim2.new(0,16,0,16),Visible=false,}}})

					elems.ScrollCorner.Parent = frame
					FrostznLife.Connect(linesFrame.InputBegan,function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							obj:SetEditing(true, input)
						end
					end)


					obj.Frame = frame
					obj.Gui = frame
					obj.GuiElems = elems
					setupEditBox(obj)
					setupMouseSelection(obj)

					return frame
				end

				funcs.GetSelectionText = function(self)
					if not self:IsValidRange() then return "" end

					local selectionRange = self.SelectionRange
					local selX,selY = selectionRange[1][1], selectionRange[1][2]
					local sel2X,sel2Y = selectionRange[2][1], selectionRange[2][2]
					local deltaLines = sel2Y-selY
					local lines = self.Lines

					if not lines[selY+1] or not lines[sel2Y+1] then return "" end

					if deltaLines == 0 then
						return self:ConvertText(lines[selY+1]:sub(selX+1,sel2X), false)
					end

					local leftSub = lines[selY+1]:sub(selX+1)
					local rightSub = lines[sel2Y+1]:sub(1,sel2X)

					local result = leftSub.."\n" 
					for i = selY+1,sel2Y-1 do
						result = result..lines[i+1].."\n"
					end
					result = result..rightSub

					return self:ConvertText(result,false)
				end

				funcs.SetCopyableSelection = function(self)
					local text = self:GetSelectionText()
					local editBox = self.GuiElems.EditBox

					self.EditBoxCopying = true
					editBox.Text = text
					editBox.SelectionStart = 1
					editBox.CursorPosition = #editBox.Text + 1
					self.EditBoxCopying = false
				end

				funcs.ConnectEditBoxEvent = function(self)
					if self.EditBoxEvent then
						self.EditBoxEvent:Disconnect()
					end

					self.EditBoxEvent = FrostznLife.Connect(service.UserInputService.InputBegan,function(input)
						if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

						local keycodes = Enum.KeyCode
						local keycode = input.KeyCode

						local function setupMove(key,func)
							local endCon,finished
							endCon = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
								if input.KeyCode ~= key then return end
								endCon:Disconnect()
								finished = true
							end)
							func()
							Lib.FastWait(0.5)
							while not finished do func() Lib.FastWait(0.03) end
						end

						if keycode == keycodes.Down then
							setupMove(keycodes.Down,function()
								self.CursorX = self.FloatCursorX
								self.CursorY = self.CursorY + 1
								self:UpdateCursor()
								self:JumpToCursor()
							end)
						elseif keycode == keycodes.Up then
							setupMove(keycodes.Up,function()
								self.CursorX = self.FloatCursorX
								self.CursorY = self.CursorY - 1
								self:UpdateCursor()
								self:JumpToCursor()
							end)
						elseif keycode == keycodes.Left then
							setupMove(keycodes.Left,function()
								local line = self.Lines[self.CursorY+1] or ""
								self.CursorX = self.CursorX - 1 - (line:sub(self.CursorX-3,self.CursorX) == tabReplacement and 3 or 0)
								if self.CursorX < 0 then
									self.CursorY = self.CursorY - 1
									local line2 = self.Lines[self.CursorY+1] or ""
									self.CursorX = #line2
								end
								self.FloatCursorX = self.CursorX
								self:UpdateCursor()
								self:JumpToCursor()
							end)
						elseif keycode == keycodes.Right then
							setupMove(keycodes.Right,function()
								local line = self.Lines[self.CursorY+1] or ""
								self.CursorX = self.CursorX + 1 + (line:sub(self.CursorX+1,self.CursorX+4) == tabReplacement and 3 or 0)
								if self.CursorX > #line then
									self.CursorY = self.CursorY + 1
									self.CursorX = 0
								end
								self.FloatCursorX = self.CursorX
								self:UpdateCursor()
								self:JumpToCursor()
							end)
						elseif keycode == keycodes.Backspace then
							setupMove(keycodes.Backspace,function()
								local startRange,endRange
								if self:IsValidRange() then
									startRange = self.SelectionRange[1]
									endRange = self.SelectionRange[2]
								else
									endRange = {self.CursorX,self.CursorY}
								end

								if not startRange then
									local line = self.Lines[self.CursorY+1] or ""
									self.CursorX = self.CursorX - 1 - (line:sub(self.CursorX-3,self.CursorX) == tabReplacement and 3 or 0)
									if self.CursorX < 0 then
										self.CursorY = self.CursorY - 1
										local line2 = self.Lines[self.CursorY+1] or ""
										self.CursorX = #line2
									end
									self.FloatCursorX = self.CursorX
									self:UpdateCursor()

									startRange = startRange or {self.CursorX,self.CursorY}
								end

								self:DeleteRange({startRange,endRange},false,true)
								self:ResetSelection(true)
								self:JumpToCursor()
							end)
						elseif keycode == keycodes.Delete then
							setupMove(keycodes.Delete,function()
								local startRange,endRange
								if self:IsValidRange() then
									startRange = self.SelectionRange[1]
									endRange = self.SelectionRange[2]
								else
									startRange = {self.CursorX,self.CursorY}
								end

								if not endRange then
									local line = self.Lines[self.CursorY+1] or ""
									local endCursorX = self.CursorX + 1 + (line:sub(self.CursorX+1,self.CursorX+4) == tabReplacement and 3 or 0)
									local endCursorY = self.CursorY
									if endCursorX > #line then
										endCursorY = endCursorY + 1
										endCursorX = 0
									end
									self:UpdateCursor()

									endRange = endRange or {endCursorX,endCursorY}
								end

								self:DeleteRange({startRange,endRange},false,true)
								self:ResetSelection(true)
								self:JumpToCursor()
							end)
						elseif service.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
							if keycode == keycodes.A then
								self.SelectionRange = {{0,0},{#self.Lines[#self.Lines],#self.Lines-1}}
								self:SetCopyableSelection()
								self:Refresh()
							end
						end
					end)
				end

				funcs.DisconnectEditBoxEvent = function(self)
					if self.EditBoxEvent then
						self.EditBoxEvent:Disconnect()
					end
				end

				funcs.ResetSelection = function(self,norefresh)
					self.SelectionRange = {{-1,-1},{-1,-1}}
					if not norefresh then self:Refresh() end
				end

				funcs.IsValidRange = function(self,range)
					local selectionRange = range or self.SelectionRange
					local selX,selY = selectionRange[1][1], selectionRange[1][2]
					local sel2X,sel2Y = selectionRange[2][1], selectionRange[2][2]

					if selX == -1 or (selX == sel2X and selY == sel2Y) then return false end

					return true
				end

				funcs.DeleteRange = function(self,range,noprocess,updatemouse)
					range = range or self.SelectionRange
					if not self:IsValidRange(range) then return end

					local lines = self.Lines
					local selX,selY = range[1][1], range[1][2]
					local sel2X,sel2Y = range[2][1], range[2][2]
					local deltaLines = sel2Y-selY

					if not lines[selY+1] or not lines[sel2Y+1] then return end

					local leftSub = lines[selY+1]:sub(1,selX)
					local rightSub = lines[sel2Y+1]:sub(sel2X+1)
					lines[selY+1] = leftSub..rightSub

					local remove = table.remove
					for i = 1,deltaLines do
						remove(lines,selY+2)
					end

					if range == self.SelectionRange then self.SelectionRange = {{-1,-1},{-1,-1}} end
					if updatemouse then
						self.CursorX = selX
						self.CursorY = selY
						self:UpdateCursor()
					end

					if not noprocess then
						self:ProcessTextChange()
					end
				end

				funcs.AppendText = function(self,text)
					self:DeleteRange(nil,true,true)
					local lines,cursorX,cursorY = self.Lines,self.CursorX,self.CursorY
					local line = lines[cursorY+1]
					local before = line:sub(1,cursorX)
					local after = line:sub(cursorX+1)

					text = text:gsub("\r\n","\n")
					text = self:ConvertText(text,true) -- Tab Convert

					local textLines = text:split("\n")
					local insert = table.insert

					for i = 1,#textLines do
						local linePos = cursorY+i
						if i > 1 then insert(lines,linePos,"") end

						local textLine = textLines[i]
						local newBefore = (i == 1 and before or "")
						local newAfter = (i == #textLines and after or "")

						lines[linePos] = newBefore..textLine..newAfter
					end

					if #textLines > 1 then cursorX = 0 end

					self:ProcessTextChange()
					self.CursorX = cursorX + #textLines[#textLines]
					self.CursorY = cursorY + #textLines-1
					self:UpdateCursor()
				end

				funcs.ScrollDelta = function(self,x,y)
					self.ScrollV:ScrollTo(self.ScrollV.Index + y)
					self.ScrollH:ScrollTo(self.ScrollH.Index + x)
				end

				-- x and y starts at 0
				funcs.TabAdjust = function(self,x,y)
					local lines = self.Lines
					local line = lines[y+1]
					x=x+1

					if line then
						local left = line:sub(x-1,x-1)
						local middle = line:sub(x,x)
						local right = line:sub(x+1,x+1)
						local selRange = (#left > 0 and left or " ") .. (#middle > 0 and middle or " ") .. (#right > 0 and right or " ")

						for i,v in pairs(tabJumps) do
							if selRange:find(i) then
								return v
							end
						end
					end
					return 0
				end

				funcs.SetEditing = function(self,on,input)			
					self:UpdateCursor(input)

					if on then
						if self.Editable then
							self.GuiElems.EditBox.Text = ""
							self.GuiElems.EditBox:CaptureFocus()
						end
					else
						self.GuiElems.EditBox:ReleaseFocus()
					end
				end

				funcs.CursorAnim = function(self,on)
					local cursor = self.GuiElems.Cursor
					local animTime = tick()
					self.LastAnimTime = animTime

					if not on then return end

					lineTweens.Invis:Cancel()
					lineTweens.Vis:Cancel()
					cursor.BackgroundTransparency = 0

					FrostznLife.Wrap(function()
						while FrostznLife.Alive and self.Editable do
							Lib.FastWait(0.5)
							if self.LastAnimTime ~= animTime then return end
							lineTweens.Invis:Play()
							Lib.FastWait(0.4)
							if self.LastAnimTime ~= animTime then return end
							lineTweens.Vis:Play()
							Lib.FastWait(0.2)
						end
					end)()
				end

				funcs.MoveCursor = function(self,x,y)
					self.CursorX = x
					self.CursorY = y
					self:UpdateCursor()
					self:JumpToCursor()
				end

				funcs.JumpToCursor = function(self)
					self:Refresh()
				end

				funcs.UpdateCursor = function(self,input)
					local linesFrame = self.GuiElems.LinesFrame
					local cursor = self.GuiElems.Cursor			
					local hSize = math.max(0,linesFrame.AbsoluteSize.X)
					local vSize = math.max(0,linesFrame.AbsoluteSize.Y)
					local maxLines = math.ceil(vSize / self.FontSize)
					local maxCols = math.ceil(hSize / math.ceil(self.FontSize/2))
					local viewX,viewY = self.ViewX,self.ViewY
					local totalLinesStr = tostring(#self.Lines)
					local fontWidth = math.ceil(self.FontSize / 2)
					local linesOffset = #totalLinesStr*fontWidth + 4*fontWidth

					if input then
						local linesFrame = self.GuiElems.LinesFrame
						local frameX,frameY = linesFrame.AbsolutePosition.X,linesFrame.AbsolutePosition.Y
						local mouseX,mouseY = input.Position.X,input.Position.Y
						local fontSizeX,fontSizeY = math.ceil(self.FontSize/2),self.FontSize

						self.CursorX = self.ViewX + math.round((mouseX - frameX) / fontSizeX)
						self.CursorY = self.ViewY + math.floor((mouseY - frameY) / fontSizeY)
					end

					local cursorX,cursorY = self.CursorX,self.CursorY

					local line = self.Lines[cursorY+1] or ""
					if cursorX > #line then cursorX = #line
					elseif cursorX < 0 then cursorX = 0 end

					if cursorY >= #self.Lines then
						cursorY = math.max(0,#self.Lines-1)
					elseif cursorY < 0 then
						cursorY = 0
					end

					cursorX = cursorX + self:TabAdjust(cursorX,cursorY)

					-- Update modified
					self.CursorX = cursorX
					self.CursorY = cursorY

					local cursorVisible = (cursorX >= viewX) and (cursorY >= viewY) and (cursorX <= viewX + maxCols) and (cursorY <= viewY + maxLines)
					if cursorVisible then
						local offX = (cursorX - viewX)
						local offY = (cursorY - viewY)
						cursor.Position = UDim2.new(0,linesOffset + offX*math.ceil(self.FontSize/2) - 1,0,offY*self.FontSize)
						cursor.Size = UDim2.new(0,1,0,self.FontSize+2)
						cursor.Visible = true
						self:CursorAnim(true)
					else
						cursor.Visible = false
					end
				end

				funcs.MapNewLines = function(self)
					local newLines = {}
					local count = 1
					local text = self.Text
					local find = string.find
					local init = 1

					local pos = find(text,"\n",init,true)
					while pos do
						newLines[count] = pos
						count = count + 1
						init = pos + 1
						pos = find(text,"\n",init,true)
					end

					self.NewLines = newLines
				end

				funcs.PreHighlight = function(self)
					local start = tick()
					local text = self.Text:gsub("\\\\","	")
					--print("BACKSLASH SUB",tick()-start)
					local textLen = #text
					local found = {}
					local foundMap = {}
					local extras = {}
					local find = string.find
					local sub = string.sub
					self.ColoredLines = {}

					local function findAll(str,pattern,typ,raw)
						local count = #found+1
						local init = 1
						local x,y,extra = find(str,pattern,init,raw)
						while x do
							found[count] = x
							foundMap[x] = typ
							if extra then
								extras[x] = extra
							end

							count = count+1
							init = y+1
							x,y,extra = find(str,pattern,init,raw)
						end
					end
					local start = tick()
					findAll(text,'"',1,true)
					findAll(text,"'",2,true)
					findAll(text,"%[(=*)%[",3)
					findAll(text,"--",4,true)
					table.sort(found)

					local newLines = self.NewLines
					local curLine = 0
					local lineTableCount = 1
					local lineStart = 0
					local lineEnd = 0
					local lastEnding = 0
					local foundHighlights = {}

					for i = 1,#found do
						local pos = found[i]
						if pos <= lastEnding then continue end

						local ending = pos
						local typ = foundMap[pos]
						if typ == 1 then
							ending = find(text,'"',pos+1,true)
							while ending and sub(text,ending-1,ending-1) == "\\" do
								ending = find(text,'"',ending+1,true)
							end
							if not ending then ending = textLen end
						elseif typ == 2 then
							ending = find(text,"'",pos+1,true)
							while ending and sub(text,ending-1,ending-1) == "\\" do
								ending = find(text,"'",ending+1,true)
							end
							if not ending then ending = textLen end
						elseif typ == 3 then
							_,ending = find(text,"]"..extras[pos].."]",pos+1,true)
							if not ending then ending = textLen end
						elseif typ == 4 then
							local ahead = foundMap[pos+2]

							if ahead == 3 then
								_,ending = find(text,"]"..extras[pos+2].."]",pos+1,true)
								if not ending then ending = textLen end
							else
								ending = find(text,"\n",pos+1,true) or textLen
							end
						end

						while pos > lineEnd do
							curLine = curLine + 1
							--lineTableCount = 1
							lineEnd = newLines[curLine] or textLen+1
						end
						while FrostznLife.Alive do
							local lineTable = foundHighlights[curLine]
							if not lineTable then lineTable = {} foundHighlights[curLine] = lineTable end
							lineTable[pos] = {typ,ending}
							--lineTableCount = lineTableCount + 1

							if ending > lineEnd then
								curLine = curLine + 1
								lineEnd = newLines[curLine] or textLen+1
							else
								break
							end
						end

						lastEnding = ending
						--if i < 200 then print(curLine) end
					end
					self.PreHighlights = foundHighlights
					--print(tick()-start)
					--print(#found,curLine)
				end

				funcs.HighlightLine = function(self,line)
					local cached = self.ColoredLines[line]
					if cached then return cached end

					local sub = string.sub
					local find = string.find
					local match = string.match
					local highlights = {}
					local preHighlights = self.PreHighlights[line] or {}
					local lineText = self.Lines[line] or ""
					local lineLen = #lineText
					local lastEnding = 0
					local currentType = 0
					local lastWord = nil
					local wordBeginsDotted = false
					local funcStatus = 0
					local lineStart = self.NewLines[line-1] or 0

					local preHighlightMap = {}
					for pos,data in next,preHighlights do
						local relativePos = pos-lineStart
						if relativePos < 1 then
							currentType = data[1]
							lastEnding = data[2] - lineStart
							--warn(pos,data[2])
						else
							preHighlightMap[relativePos] = {data[1],data[2]-lineStart}
						end
					end

					for col = 1,#lineText do
						if col <= lastEnding then highlights[col] = currentType continue end

						local pre = preHighlightMap[col]
						if pre then
							currentType = pre[1]
							lastEnding = pre[2]
							highlights[col] = currentType
							wordBeginsDotted = false
							lastWord = nil
							funcStatus = 0
						else
							local char = sub(lineText,col,col)
							if find(char,"[%a_]") then
								local word = match(lineText,"[%a%d_]+",col)
								local wordType = (keywords[word] and 7) or (builtIns[word] and 8)

								lastEnding = col+#word-1

								if wordType ~= 7 then
									if wordBeginsDotted then
										local prevBuiltIn = lastWord and builtIns[lastWord]
										wordType = (prevBuiltIn and type(prevBuiltIn) == "table" and prevBuiltIn[word] and 8) or 10
									end

									if wordType ~= 8 then
										local x,y,br = find(lineText,"^%s*([%({\"'])",lastEnding+1)
										if x then
											wordType = (funcStatus > 0 and br == "(" and 16) or 9
											funcStatus = 0
										end
									end
								else
									wordType = specialKeywordsTypes[word] or wordType
									funcStatus = (word == "function" and 1 or 0)
								end

								lastWord = word
								wordBeginsDotted = false
								if funcStatus > 0 then funcStatus = 1 end

								if wordType then
									currentType = wordType
									highlights[col] = currentType
								else
									currentType = nil
								end
							elseif find(char,"%p") then
								local isDot = (char == ".")
								local isNum = isDot and find(sub(lineText,col+1,col+1),"%d")
								highlights[col] = (isNum and 6 or 5)

								if not isNum then
									local dotStr = isDot and match(lineText,"%.%.?%.?",col)
									if dotStr and #dotStr > 1 then
										currentType = 5
										lastEnding = col+#dotStr-1
										wordBeginsDotted = false
										lastWord = nil
										funcStatus = 0
									else
										if isDot then
											if wordBeginsDotted then
												lastWord = nil
											else
												wordBeginsDotted = true
											end
										else
											wordBeginsDotted = false
											lastWord = nil
										end

										funcStatus = ((isDot or char == ":") and funcStatus == 1 and 2) or 0
									end
								end
							elseif find(char,"%d") then
								local _,endPos = find(lineText,"%x+",col)
								local endPart = sub(lineText,endPos,endPos+1)
								if (endPart == "e+" or endPart == "e-") and find(sub(lineText,endPos+2,endPos+2),"%d") then
									endPos = endPos + 1
								end
								currentType = 6
								lastEnding = endPos
								highlights[col] = 6
								wordBeginsDotted = false
								lastWord = nil
								funcStatus = 0
							else
								highlights[col] = currentType
								local _,endPos = find(lineText,"%s+",col)
								if endPos then
									lastEnding = endPos
								end
							end
						end
					end

					self.ColoredLines[line] = highlights
					return highlights
				end

				funcs.Refresh = function(self)
					local start = tick()

					local linesFrame = self.Frame.Lines
					local hSize = math.max(0,linesFrame.AbsoluteSize.X)
					local vSize = math.max(0,linesFrame.AbsoluteSize.Y)
					local maxLines = math.ceil(vSize / self.FontSize)
					local maxCols = math.ceil(hSize / math.ceil(self.FontSize/2))
					local gsub = string.gsub
					local sub = string.sub

					local viewX,viewY = self.ViewX,self.ViewY

					local lineNumberStr = ""

					for row = 1,maxLines do
						local lineFrame = self.LineFrames[row]
						if not lineFrame then
							lineFrame = Instance.new("Frame")
							lineFrame.Name = "Line"
							lineFrame.Position = UDim2.new(0,0,0,(row-1)*self.FontSize)
							lineFrame.Size = UDim2.new(1,0,0,self.FontSize)
							lineFrame.BorderSizePixel = 0
							lineFrame.BackgroundTransparency = 1

							local selectionHighlight = Instance.new("Frame")
							selectionHighlight.Name = "SelectionHighlight"
							selectionHighlight.BorderSizePixel = 0
							selectionHighlight.BackgroundColor3 = Settings.Theme.Syntax.SelectionBack
							selectionHighlight.Parent = lineFrame

							local label = Instance.new("TextLabel")
							label.Name = "Label"
							label.BackgroundTransparency = 1
							label.Font = Enum.Font.Code
							label.TextSize = self.FontSize
							label.Size = UDim2.new(1,0,0,self.FontSize)
							label.RichText = true
							label.TextXAlignment = Enum.TextXAlignment.Left
							label.TextColor3 = self.Colors.Text
							label.ZIndex = 2
							label.Parent = lineFrame

							lineFrame.Parent = linesFrame
							self.LineFrames[row] = lineFrame
						end

						local relaY = viewY + row
						local lineText = self.Lines[relaY] or ""
						local resText = ""
						local highlights = self:HighlightLine(relaY)
						local colStart = viewX + 1

						local richTemplates = self.RichTemplates
						local textTemplate = richTemplates.Text
						local selectionTemplate = richTemplates.Selection
						local curType = highlights[colStart]
						local curTemplate = richTemplates[typeMap[curType]] or textTemplate

						-- Selection Highlight
						local selectionRange = self.SelectionRange
						local selPos1 = selectionRange[1]
						local selPos2 = selectionRange[2]
						local selRow,selColumn = selPos1[2],selPos1[1]
						local sel2Row,sel2Column = selPos2[2],selPos2[1]
						local selRelaX,selRelaY = viewX,relaY-1

						if selRelaY >= selPos1[2] and selRelaY <= selPos2[2] then
							local fontSizeX = math.ceil(self.FontSize/2)
							local posX = (selRelaY == selPos1[2] and selPos1[1] or 0) - viewX
							local sizeX = (selRelaY == selPos2[2] and selPos2[1]-posX-viewX or maxCols+viewX)

							lineFrame.SelectionHighlight.Position = UDim2.new(0,posX*fontSizeX,0,0)
							lineFrame.SelectionHighlight.Size = UDim2.new(0,sizeX*fontSizeX,1,0)
							lineFrame.SelectionHighlight.Visible = true
						else
							lineFrame.SelectionHighlight.Visible = false
						end

						-- Selection Text Color for first char
						local inSelection = selRelaY >= selRow and selRelaY <= sel2Row and (selRelaY == selRow and viewX >= selColumn or selRelaY ~= selRow) and (selRelaY == sel2Row and viewX < sel2Column or selRelaY ~= sel2Row)
						if inSelection then
							curType = -999
							curTemplate = selectionTemplate
						end

						for col = 2,maxCols do
							local relaX = viewX + col
							local selRelaX = relaX-1
							local posType = highlights[relaX]

							-- Selection Text Color
							local inSelection = selRelaY >= selRow and selRelaY <= sel2Row and (selRelaY == selRow and selRelaX >= selColumn or selRelaY ~= selRow) and (selRelaY == sel2Row and selRelaX < sel2Column or selRelaY ~= sel2Row)
							if inSelection then
								posType = -999
							end

							if posType ~= curType then
								local template = (inSelection and selectionTemplate) or richTemplates[typeMap[posType]] or textTemplate

								if template ~= curTemplate then
									local nextText = gsub(sub(lineText,colStart,relaX-1),"['\"<>&]",richReplace)
									resText = resText .. (curTemplate ~= textTemplate and (curTemplate .. nextText .. "</font>") or nextText)
									colStart = relaX
									curTemplate = template
								end
								curType = posType
							end
						end

						local lastText = gsub(sub(lineText,colStart,viewX+maxCols),"['\"<>&]",richReplace)
						--warn("SUB",colStart,viewX+maxCols-1)
						if #lastText > 0 then
							resText = resText .. (curTemplate ~= textTemplate and (curTemplate .. lastText .. "</font>") or lastText)
						end

						if self.Lines[relaY] then
							lineNumberStr = lineNumberStr .. (relaY == self.CursorY and ("<b>"..relaY.."</b>\n") or relaY .. "\n")
						end

						lineFrame.Label.Text = resText
					end

					for i = maxLines+1,#self.LineFrames do
						self.LineFrames[i]:Destroy()
						self.LineFrames[i] = nil
					end

					self.Frame.LineNumbers.Text = lineNumberStr
					self:UpdateCursor()

					--print("REFRESH TIME",tick()-start)
				end

				funcs.UpdateView = function(self)
					local totalLinesStr = tostring(#self.Lines)
					local fontWidth = math.ceil(self.FontSize / 2)
					local linesOffset = #totalLinesStr*fontWidth + 4*fontWidth

					local linesFrame = self.Frame.Lines
					local hSize = linesFrame.AbsoluteSize.X
					local vSize = linesFrame.AbsoluteSize.Y
					local maxLines = math.ceil(vSize / self.FontSize)
					local totalWidth = self.MaxTextCols*fontWidth
					local scrollV = self.ScrollV
					local scrollH = self.ScrollH

					scrollV.VisibleSpace = maxLines
					scrollV.TotalSpace = #self.Lines + 1
					scrollH.VisibleSpace = math.ceil(hSize/fontWidth)
					scrollH.TotalSpace = self.MaxTextCols + 1

					scrollV.Gui.Visible = #self.Lines + 1 > maxLines
					scrollH.Gui.Visible = totalWidth > hSize

					local oldOffsets = self.FrameOffsets
					self.FrameOffsets = Vector2.new(scrollV.Gui.Visible and -16 or 0, scrollH.Gui.Visible and -16 or 0)
					if oldOffsets ~= self.FrameOffsets then
						self:UpdateView()
					else
						scrollV:ScrollTo(self.ViewY,true)
						scrollH:ScrollTo(self.ViewX,true)

						if scrollV.Gui.Visible and scrollH.Gui.Visible then
							scrollV.Gui.Size = UDim2.new(0,16,1,-16)
							scrollH.Gui.Size = UDim2.new(1,-16,0,16)
							self.GuiElems.ScrollCorner.Visible = true
						else
							scrollV.Gui.Size = UDim2.new(0,16,1,0)
							scrollH.Gui.Size = UDim2.new(1,0,0,16)
							self.GuiElems.ScrollCorner.Visible = false
						end

						self.ViewY = scrollV.Index
						self.ViewX = scrollH.Index
						self.Frame.Lines.Position = UDim2.new(0,linesOffset,0,0)
						self.Frame.Lines.Size = UDim2.new(1,-linesOffset+oldOffsets.X,1,oldOffsets.Y)
						self.Frame.LineNumbers.Position = UDim2.new(0,fontWidth,0,0)
						self.Frame.LineNumbers.Size = UDim2.new(0,#totalLinesStr*fontWidth,1,oldOffsets.Y)
						self.Frame.LineNumbers.TextSize = self.FontSize
					end
				end

				funcs.ProcessTextChange = function(self)
					local maxCols = 0
					local lines = self.Lines

					for i = 1,#lines do
						local lineLen = #lines[i]
						if lineLen > maxCols then
							maxCols = lineLen
						end
					end

					self.MaxTextCols = maxCols
					self:UpdateView()	
					self.Text = table.concat(self.Lines,"\n")
					self:MapNewLines()
					self:PreHighlight()
					self:Refresh()
					--self.TextChanged:Fire()
				end

				funcs.ConvertText = function(self,text,toEditor)
					if toEditor then
						return text:gsub("\t",(" %s "):format(tabSub))
					else
						return text:gsub((" %s "):format(tabSub),"\t")
					end
				end

				funcs.GetText = function(self) -- TODO: better (use new tab format)
					local source = table.concat(self.Lines,"\n")
					return self:ConvertText(source,false) -- Tab Convert
				end

				funcs.SetText = function(self,txt)
					txt = self:ConvertText(txt,true) -- Tab Convert
					local lines = self.Lines
					table.clear(lines)
					local count = 1

					for line in txt:gmatch("([^\n\r]*)[\n\r]?") do
						local len = #line
						lines[count] = line
						count = count + 1
					end

					self:ProcessTextChange()
				end

				funcs.MakeRichTemplates = function(self)
					local floor = math.floor
					local templates = {}

					for name,color in pairs(self.Colors) do
						templates[name] = ('<font color="rgb(%s,%s,%s)">'):format(floor(color.r*255),floor(color.g*255),floor(color.b*255))
					end

					self.RichTemplates = templates
				end

				funcs.ApplyTheme = function(self)
					local colors = Settings.Theme.Syntax
					self.Colors = colors
					self.Frame.LineNumbers.TextColor3 = colors.Text
					self.Frame.BackgroundColor3 = colors.Background
				end

				local mt = {__index = funcs}

				local function new()
					if not builtInInited then initBuiltIn() end

					local scrollV = Lib.ScrollBar.new()
					local scrollH = Lib.ScrollBar.new(true)
					scrollH.Gui.Position = UDim2.new(0,0,1,-16)
					local obj = setmetatable({
						FontSize = 15,
						ViewX = 0,
						ViewY = 0,
						Colors = Settings.Theme.Syntax,
						ColoredLines = {},
						Lines = {""},
						LineFrames = {},
						Editable = true,
						Editing = false,
						CursorX = 0,
						CursorY = 0,
						FloatCursorX = 0,
						Text = "",
						PreHighlights = {},
						SelectionRange = {{-1,-1},{-1,-1}},
						NewLines = {},
						FrameOffsets = Vector2.new(0,0),
						MaxTextCols = 0,
						ScrollV = scrollV,
						ScrollH = scrollH
					},mt)

					scrollV.WheelIncrement = 3
					scrollH.Increment = 2
					scrollH.WheelIncrement = 7

					FrostznLife.Connect(scrollV.Scrolled,function()
						obj.ViewY = scrollV.Index
						obj:Refresh()
					end)

					FrostznLife.Connect(scrollH.Scrolled,function()
						obj.ViewX = scrollH.Index
						obj:Refresh()
					end)

					makeFrame(obj)
					obj:MakeRichTemplates()
					obj:ApplyTheme()
					scrollV:SetScrollFrame(obj.Frame.Lines)
					scrollV.Gui.Parent = obj.Frame
					scrollH.Gui.Parent = obj.Frame

					obj:UpdateView()
					FrostznLife.Connect(obj.Frame:GetPropertyChangedSignal("AbsoluteSize"),function()
						obj:UpdateView()
						obj:Refresh()
					end)

					return obj
				end

				return {new = new}
			end)()

			Lib.Checkbox = (function()
				local funcs = {}
				local c3 = Color3.fromRGB
				local v2 = Vector2.new
				local ud2s = UDim2.fromScale
				local ud2o = UDim2.fromOffset
				local ud = UDim.new
				local max = math.max
				local new = Instance.new
				local TweenSize = new("Frame").TweenSize
				local ti = TweenInfo.new
				local delay = delay

				local function ripple(object, color)
					local circle = new('Frame')
					circle.BackgroundColor3 = color
					circle.BackgroundTransparency = 0.75
					circle.BorderSizePixel = 0
					circle.AnchorPoint = v2(0.5, 0.5)
					circle.Size = ud2o()
					circle.Position = ud2s(0.5, 0.5)
					circle.Parent = object
					local rounding = new('UICorner')
					rounding.CornerRadius = ud(1)
					rounding.Parent = circle

					local abssz = object.AbsoluteSize
					local size = max(abssz.X, abssz.Y) * 5/3

					TweenSize(circle, ud2o(size, size), "Out", "Quart", 0.4)
					service.TweenService:Create(circle, ti(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()

					service.Debris:AddItem(circle, 0.4)
				end

				local function initGui(self,frame)
					local checkbox = frame or create({
						{1,"ImageButton",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="Checkbox",Position=UDim2.new(0,3,0,3),Size=UDim2.new(0,16,0,16),}},
						{2,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="ripples",Parent={1},Size=UDim2.new(1,0,1,0),}},
						{3,"Frame",{BackgroundColor3=Color3.new(0.10196078568697,0.10196078568697,0.10196078568697),BorderSizePixel=0,Name="outline",Parent={1},Size=UDim2.new(0,16,0,16),}},
						{4,"Frame",{BackgroundColor3=Color3.new(0.14117647707462,0.14117647707462,0.14117647707462),BorderSizePixel=0,Name="filler",Parent={3},Position=UDim2.new(0,1,0,1),Size=UDim2.new(0,14,0,14),}},
						{5,"Frame",{BackgroundColor3=Color3.new(0.90196084976196,0.90196084976196,0.90196084976196),BorderSizePixel=0,Name="top",Parent={4},Size=UDim2.new(0,16,0,0),}},
						{6,"Frame",{AnchorPoint=Vector2.new(0,1),BackgroundColor3=Color3.new(0.90196084976196,0.90196084976196,0.90196084976196),BorderSizePixel=0,Name="bottom",Parent={4},Position=UDim2.new(0,0,0,14),Size=UDim2.new(0,16,0,0),}},
						{7,"Frame",{BackgroundColor3=Color3.new(0.90196084976196,0.90196084976196,0.90196084976196),BorderSizePixel=0,Name="left",Parent={4},Size=UDim2.new(0,0,0,16),}},
						{8,"Frame",{AnchorPoint=Vector2.new(1,0),BackgroundColor3=Color3.new(0.90196084976196,0.90196084976196,0.90196084976196),BorderSizePixel=0,Name="right",Parent={4},Position=UDim2.new(0,14,0,0),Size=UDim2.new(0,0,0,16),}},
						{9,"Frame",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Name="checkmark",Parent={4},Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,0,0,20),}},
						{10,"ImageLabel",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Image="rbxassetid://6234266378",Parent={9},Position=UDim2.new(0.5,0,0.5,0),ScaleType=3,Size=UDim2.new(0,15,0,11),}},
						{11,"ImageLabel",{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6401617475",ImageColor3=Color3.new(0.20784313976765,0.69803923368454,0.98431372642517),Name="checkmark2",Parent={4},Position=UDim2.new(0.5,0,0.5,0),Size=UDim2.new(0,12,0,12),Visible=false,}},
						{12,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://6425281788",ImageTransparency=0.20000000298023,Name="middle",Parent={4},ScaleType=2,Size=UDim2.new(1,0,1,0),TileSize=UDim2.new(0,2,0,2),Visible=false,}},
						{13,"UICorner",{CornerRadius=UDim.new(0,2),Parent={3},}},
					})
					local outline = checkbox.outline
					local filler = outline.filler
					local checkmark = filler.checkmark
					local ripples_container = checkbox.ripples

					-- walls
					local top, bottom, left, right = filler.top, filler.bottom, filler.left, filler.right

					self.Gui = checkbox
					self.GuiElems = {
						Top = top,
						Bottom = bottom,
						Left = left,
						Right = right,
						Outline = outline,
						Filler = filler,
						Checkmark = checkmark,
						Checkmark2 = filler.checkmark2,
						Middle = filler.middle
					}

					FrostznLife.Connect(checkbox.Activated,function()
						if Lib.CheckMouseInGui(checkbox) then
							if self.Style == 0 then
								ripple(ripples_container, self.Disabled and self.Colors.Disabled or self.Colors.Primary)
							end

							if not self.Disabled then
								self:SetState(not self.Toggled,true)
							else
								self:Paint()
							end

							self.OnInput:Fire()
						end
					end)

					-- Old:
			--[[checkbox.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					local release
					release = service.UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							release:Disconnect()

							if Lib.CheckMouseInGui(checkbox) then
								if self.Style == 0 then
									ripple(ripples_container, self.Disabled and self.Colors.Disabled or self.Colors.Primary)
								end

								if not self.Disabled then
									self:SetState(not self.Toggled,true)
								else
									self:Paint()
								end
								
								self.OnInput:Fire()
							end
						end
					end)
				end
			end)]]

					self:Paint()
				end

				funcs.Collapse = function(self,anim)
					local guiElems = self.GuiElems
					if anim then
						TweenSize(guiElems.Top, ud2o(14, 14), "In", "Quart", 4/15, true)
						TweenSize(guiElems.Bottom, ud2o(14, 14), "In", "Quart", 4/15, true)
						TweenSize(guiElems.Left, ud2o(14, 14), "In", "Quart", 4/15, true)
						TweenSize(guiElems.Right, ud2o(14, 14), "In", "Quart", 4/15, true)
					else
						guiElems.Top.Size = ud2o(14, 14)
						guiElems.Bottom.Size = ud2o(14, 14)
						guiElems.Left.Size = ud2o(14, 14)
						guiElems.Right.Size = ud2o(14, 14)
					end
				end

				funcs.Expand = function(self,anim)
					local guiElems = self.GuiElems
					if anim then
						TweenSize(guiElems.Top, ud2o(14, 0), "InOut", "Quart", 4/15, true)
						TweenSize(guiElems.Bottom, ud2o(14, 0), "InOut", "Quart", 4/15, true)
						TweenSize(guiElems.Left, ud2o(0, 14), "InOut", "Quart", 4/15, true)
						TweenSize(guiElems.Right, ud2o(0, 14), "InOut", "Quart", 4/15, true)
					else
						guiElems.Top.Size = ud2o(14, 0)
						guiElems.Bottom.Size = ud2o(14, 0)
						guiElems.Left.Size = ud2o(0, 14)
						guiElems.Right.Size = ud2o(0, 14)
					end
				end

				funcs.Paint = function(self)
					local guiElems = self.GuiElems

					if self.Style == 0 then
						local color_base = self.Disabled and self.Colors.Disabled
						guiElems.Outline.BackgroundColor3 = color_base or (self.Toggled and self.Colors.Primary) or self.Colors.Secondary
						local walls_color = color_base or self.Colors.Primary
						guiElems.Top.BackgroundColor3 = walls_color
						guiElems.Bottom.BackgroundColor3 = walls_color
						guiElems.Left.BackgroundColor3 = walls_color
						guiElems.Right.BackgroundColor3 = walls_color
					else
						guiElems.Outline.BackgroundColor3 = self.Disabled and self.Colors.Disabled or self.Colors.Secondary
						guiElems.Filler.BackgroundColor3 = self.Disabled and self.Colors.DisabledBackground or self.Colors.Background
						guiElems.Checkmark2.ImageColor3 = self.Disabled and self.Colors.DisabledCheck or self.Colors.Primary
					end
				end

				funcs.SetState = function(self,val,anim)
					self.Toggled = val

					if self.OutlineColorTween then self.OutlineColorTween:Cancel() end
					local setStateTime = tick()
					self.LastSetStateTime = setStateTime

					if self.Toggled then
						if self.Style == 0 then
							if anim then
								self.OutlineColorTween = service.TweenService:Create(self.GuiElems.Outline, ti(4/15, Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {BackgroundColor3 = self.Colors.Primary})
								self.OutlineColorTween:Play()
								delay(0.15, function()
									if setStateTime ~= self.LastSetStateTime then return end
									self:Paint()
									TweenSize(self.GuiElems.Checkmark, ud2o(14, 20), "Out", "Bounce", 2/15, true)
								end)
							else
								self.GuiElems.Outline.BackgroundColor3 = self.Colors.Primary
								self:Paint()
								self.GuiElems.Checkmark.Size = ud2o(14, 20)
							end
							self:Collapse(anim)
						else
							self:Paint()
							self.GuiElems.Checkmark2.Visible = true
							self.GuiElems.Middle.Visible = false
						end
					else
						if self.Style == 0 then
							if anim then
								self.OutlineColorTween = service.TweenService:Create(self.GuiElems.Outline, ti(4/15, Enum.EasingStyle.Circular, Enum.EasingDirection.In), {BackgroundColor3 = self.Colors.Secondary})
								self.OutlineColorTween:Play()
								delay(0.15, function()
									if setStateTime ~= self.LastSetStateTime then return end
									self:Paint()
									TweenSize(self.GuiElems.Checkmark, ud2o(0, 20), "Out", "Quad", 1/15, true)
								end)
							else
								self.GuiElems.Outline.BackgroundColor3 = self.Colors.Secondary
								self:Paint()
								self.GuiElems.Checkmark.Size = ud2o(0, 20)
							end
							self:Expand(anim)
						else
							self:Paint()
							self.GuiElems.Checkmark2.Visible = false
							self.GuiElems.Middle.Visible = self.Toggled == nil
						end
					end
				end

				local mt = {__index = funcs}

				local function new(style)
					local obj = setmetatable({
						Toggled = false,
						Disabled = false,
						OnInput = Lib.Signal.new(),
						Style = style or 0,
						Colors = {
							Background = c3(36,36,36),
							Primary = c3(49,176,230),
							Secondary = c3(25,25,25),
							Disabled = c3(64,64,64),
							DisabledBackground = c3(52,52,52),
							DisabledCheck = c3(80,80,80)
						}
					},mt)
					initGui(obj)
					return obj
				end

				local function fromFrame(frame)
					local obj = setmetatable({
						Toggled = false,
						Disabled = false,
						Colors = {
							Background = c3(36,36,36),
							Primary = c3(49,176,230),
							Secondary = c3(25,25,25),
							Disabled = c3(64,64,64),
							DisabledBackground = c3(52,52,52)
						}
					},mt)
					initGui(obj,frame)
					return obj
				end

				return {new = new, fromFrame}
			end)()

			Lib.BrickColorPicker = (function()
				local funcs = {}
				local paletteCount = 0
				local mouse = service.Players.LocalPlayer:GetMouse()
				local hexStartX = 4
				local hexSizeX = 27
				local hexTriangleStart = 1
				local hexTriangleSize = 8

				local bottomColors = {
					Color3.fromRGB(17,17,17),
					Color3.fromRGB(99,95,98),
					Color3.fromRGB(163,162,165),
					Color3.fromRGB(205,205,205),
					Color3.fromRGB(223,223,222),
					Color3.fromRGB(237,234,234),
					Color3.fromRGB(27,42,53),
					Color3.fromRGB(91,93,105),
					Color3.fromRGB(159,161,172),
					Color3.fromRGB(202,203,209),
					Color3.fromRGB(231,231,236),
					Color3.fromRGB(248,248,248)
				}

				local function isMouseInHexagon(hex, touchPos)
					local relativeX = touchPos.X - hex.AbsolutePosition.X
					local relativeY = touchPos.Y - hex.AbsolutePosition.Y
					if relativeX >= hexStartX and relativeX < hexStartX + hexSizeX then
						relativeX = relativeX - 4
						local relativeWidth = (13 - math.min(relativeX, 26 - relativeX)) / 13
						if relativeY >= hexTriangleStart + hexTriangleSize * relativeWidth and relativeY < hex.AbsoluteSize.Y - hexTriangleStart - hexTriangleSize * relativeWidth then
							return true
						end
					end
					return false
				end

				local function hexInput(self, hex, color)
					FrostznLife.Connect(hex.InputBegan,function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							if isMouseInHexagon(hex, input.Position) then
								self.OnSelect:Fire(color)
								self:Close()
							end
						end
					end)

					FrostznLife.Connect(hex.InputChanged,function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
							if isMouseInHexagon(hex, input.Position) then
								self.OnPreview:Fire(color)
							end
						end
					end)
				end

				local function createGui(self)
					local gui = create({
						{1,"ScreenGui",{Name="BrickColor",}},
						{2,"Frame",{Active=true,BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderColor3=Color3.new(0.1294117718935,0.1294117718935,0.1294117718935),Parent={1},Position=UDim2.new(0.40000000596046,0,0.40000000596046,0),Size=UDim2.new(0,337,0,380),}},
						{3,"TextButton",{BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),BorderSizePixel=0,Font=3,Name="MoreColors",Parent={2},Position=UDim2.new(0,5,1,-30),Size=UDim2.new(1,-10,0,25),Text="More Colors",TextColor3=Color3.new(1,1,1),TextSize=14,}},
						{4,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Image="rbxassetid://1281023007",ImageColor3=Color3.new(0.33333334326744,0.33333334326744,0.49803924560547),Name="Hex",Parent={2},Size=UDim2.new(0,35,0,35),Visible=false,}},
					})
					local colorFrame = gui.Frame
					local hex = colorFrame.Hex

					for row = 1,13 do
						local columns = math.min(row,14-row)+6
						for column = 1,columns do
							local nextColor = BrickColor.palette(paletteCount).Color
							local newHex = hex:Clone()
							newHex.Position = UDim2.new(0, (column-1)*25-(columns-7)*13+3*26 + 1, 0, (row-1)*23 + 4)
							newHex.ImageColor3 = nextColor
							newHex.Visible = true
							hexInput(self,newHex,nextColor)
							newHex.Parent = colorFrame
							paletteCount = paletteCount + 1
						end
					end

					for column = 1,12 do
						local nextColor = bottomColors[column]
						local newHex = hex:Clone()
						newHex.Position = UDim2.new(0, (column-1)*25-(12-7)*13+3*26 + 3, 0, 308)
						newHex.ImageColor3 = nextColor
						newHex.Visible = true
						hexInput(self,newHex,nextColor)
						newHex.Parent = colorFrame
						paletteCount = paletteCount + 1
					end

					FrostznLife.Connect(colorFrame.MoreColors.MouseButton1Click,function()
						self.OnMoreColors:Fire()
						self:Close()
					end)

					self.Gui = gui
				end

				funcs.SetMoreColorsVisible = function(self,vis)
					local colorFrame = self.Gui.Frame
					colorFrame.Size = UDim2.new(0,337,0,380 - (not vis and 33 or 0))
					colorFrame.MoreColors.Visible = vis
				end

				funcs.Show = function(self,x,y,prevColor)
					self.PrevColor = prevColor or self.PrevColor

					local reverseY = false

					local x,y = x or mouse.X, y or mouse.Y
					local maxX,maxY = mouse.ViewSizeX,mouse.ViewSizeY
					Lib.ShowGui(self.Gui)
					local sizeX,sizeY = self.Gui.Frame.AbsoluteSize.X,self.Gui.Frame.AbsoluteSize.Y

					if x + sizeX > maxX then x = self.ReverseX and x - sizeX or maxX - sizeX end
					if y + sizeY > maxY then reverseY = true end

					local closable = false
					if self.CloseEvent then self.CloseEvent:Disconnect() end

					self.CloseEvent = FrostznLife.Connect(service.UserInputService.InputBegan,function(input)
						if not closable or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then
							return
						end

						if not Lib.CheckMouseInGui(self.Gui.Frame) then
							self.CloseEvent:Disconnect()
							self:Close()
						end
					end)


					if reverseY then
						local newY = y - sizeY - (self.ReverseYOffset or 0)
						y = newY >= 0 and newY or 0
					end

					self.Gui.Frame.Position = UDim2.new(0,x,0,y)

					Lib.FastWait()
					closable = true
				end

				funcs.Close = function(self)
					self.Gui.Parent = nil
					self.OnCancel:Fire()
				end

				local mt = {__index = funcs}

				local function new()
					local obj = setmetatable({
						OnPreview = Lib.Signal.new(),
						OnSelect = Lib.Signal.new(),
						OnCancel = Lib.Signal.new(),
						OnMoreColors = Lib.Signal.new(),
						PrevColor = Color3.new(0,0,0)
					}, mt)
					createGui(obj)
					return obj
				end

				return {new = new}
			end)()

			Lib.ColorPicker = (function() -- TODO: Convert to newer class model
				local funcs = {}

				local function new()
					local newMt = setmetatable({},{})

					newMt.OnSelect = Lib.Signal.new()
					newMt.OnCancel = Lib.Signal.new()
					newMt.OnPreview = Lib.Signal.new()

					local guiContents = create({
						{1,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,ClipsDescendants=true,Name="Content",Position=UDim2.new(0,0,0,20),Size=UDim2.new(1,0,1,-20),}},
						{2,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="BasicColors",Parent={1},Position=UDim2.new(0,5,0,5),Size=UDim2.new(0,180,0,200),}},
						{3,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={2},Position=UDim2.new(0,0,0,-5),Size=UDim2.new(1,0,0,26),Text="Basic Colors",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{4,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Blue",Parent={1},Position=UDim2.new(1,-63,0,255),Size=UDim2.new(0,52,0,16),}},
						{5,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),Font=3,Name="Input",Parent={4},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,50,0,16),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{6,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="ArrowFrame",Parent={5},Position=UDim2.new(1,-16,0,0),Size=UDim2.new(0,16,1,0),}},
						{7,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Up",Parent={6},Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{8,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={7},Size=UDim2.new(0,16,0,8),}},
						{9,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={8},Position=UDim2.new(0,8,0,3),Size=UDim2.new(0,1,0,1),}},
						{10,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={8},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{11,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={8},Position=UDim2.new(0,6,0,5),Size=UDim2.new(0,5,0,1),}},
						{12,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Down",Parent={6},Position=UDim2.new(0,0,0,8),Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{13,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={12},Size=UDim2.new(0,16,0,8),}},
						{14,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={13},Position=UDim2.new(0,8,0,5),Size=UDim2.new(0,1,0,1),}},
						{15,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={13},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{16,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={13},Position=UDim2.new(0,6,0,3),Size=UDim2.new(0,5,0,1),}},
						{17,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={4},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Blue:",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{18,"Frame",{BackgroundColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),BorderSizePixel=0,ClipsDescendants=true,Name="ColorSpaceFrame",Parent={1},Position=UDim2.new(1,-261,0,4),Size=UDim2.new(0,222,0,202),}},
						{19,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),BorderSizePixel=0,Image="rbxassetid://1072518406",Name="ColorSpace",Parent={18},Position=UDim2.new(0,1,0,1),Size=UDim2.new(0,220,0,200),}},
						{20,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="Scope",Parent={19},Position=UDim2.new(0,210,0,190),Size=UDim2.new(0,20,0,20),}},
						{21,"Frame",{BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Name="Line",Parent={20},Position=UDim2.new(0,9,0,0),Size=UDim2.new(0,2,0,20),}},
						{22,"Frame",{BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Name="Line",Parent={20},Position=UDim2.new(0,0,0,9),Size=UDim2.new(0,20,0,2),}},
						{23,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="CustomColors",Parent={1},Position=UDim2.new(0,5,0,210),Size=UDim2.new(0,180,0,90),}},
						{24,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={23},Size=UDim2.new(1,0,0,20),Text="Custom Colors (RC = Set)",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{25,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Green",Parent={1},Position=UDim2.new(1,-63,0,233),Size=UDim2.new(0,52,0,16),}},
						{26,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),Font=3,Name="Input",Parent={25},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,50,0,16),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{27,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="ArrowFrame",Parent={26},Position=UDim2.new(1,-16,0,0),Size=UDim2.new(0,16,1,0),}},
						{28,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Up",Parent={27},Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{29,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={28},Size=UDim2.new(0,16,0,8),}},
						{30,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={29},Position=UDim2.new(0,8,0,3),Size=UDim2.new(0,1,0,1),}},
						{31,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={29},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{32,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={29},Position=UDim2.new(0,6,0,5),Size=UDim2.new(0,5,0,1),}},
						{33,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Down",Parent={27},Position=UDim2.new(0,0,0,8),Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{34,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={33},Size=UDim2.new(0,16,0,8),}},
						{35,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={34},Position=UDim2.new(0,8,0,5),Size=UDim2.new(0,1,0,1),}},
						{36,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={34},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{37,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={34},Position=UDim2.new(0,6,0,3),Size=UDim2.new(0,5,0,1),}},
						{38,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={25},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Green:",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{39,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Hue",Parent={1},Position=UDim2.new(1,-180,0,211),Size=UDim2.new(0,52,0,16),}},
						{40,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),Font=3,Name="Input",Parent={39},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,50,0,16),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{41,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="ArrowFrame",Parent={40},Position=UDim2.new(1,-16,0,0),Size=UDim2.new(0,16,1,0),}},
						{42,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Up",Parent={41},Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{43,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={42},Size=UDim2.new(0,16,0,8),}},
						{44,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={43},Position=UDim2.new(0,8,0,3),Size=UDim2.new(0,1,0,1),}},
						{45,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={43},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{46,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={43},Position=UDim2.new(0,6,0,5),Size=UDim2.new(0,5,0,1),}},
						{47,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Down",Parent={41},Position=UDim2.new(0,0,0,8),Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{48,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={47},Size=UDim2.new(0,16,0,8),}},
						{49,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={48},Position=UDim2.new(0,8,0,5),Size=UDim2.new(0,1,0,1),}},
						{50,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={48},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{51,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={48},Position=UDim2.new(0,6,0,3),Size=UDim2.new(0,5,0,1),}},
						{52,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={39},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Hue:",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{53,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Name="Preview",Parent={1},Position=UDim2.new(1,-260,0,211),Size=UDim2.new(0,35,1,-245),}},
						{54,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Red",Parent={1},Position=UDim2.new(1,-63,0,211),Size=UDim2.new(0,52,0,16),}},
						{55,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),Font=3,Name="Input",Parent={54},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,50,0,16),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{56,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="ArrowFrame",Parent={55},Position=UDim2.new(1,-16,0,0),Size=UDim2.new(0,16,1,0),}},
						{57,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Up",Parent={56},Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{58,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={57},Size=UDim2.new(0,16,0,8),}},
						{59,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={58},Position=UDim2.new(0,8,0,3),Size=UDim2.new(0,1,0,1),}},
						{60,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={58},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{61,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={58},Position=UDim2.new(0,6,0,5),Size=UDim2.new(0,5,0,1),}},
						{62,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Down",Parent={56},Position=UDim2.new(0,0,0,8),Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{63,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={62},Size=UDim2.new(0,16,0,8),}},
						{64,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={63},Position=UDim2.new(0,8,0,5),Size=UDim2.new(0,1,0,1),}},
						{65,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={63},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{66,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={63},Position=UDim2.new(0,6,0,3),Size=UDim2.new(0,5,0,1),}},
						{67,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={54},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Red:",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{68,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Sat",Parent={1},Position=UDim2.new(1,-180,0,233),Size=UDim2.new(0,52,0,16),}},
						{69,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),Font=3,Name="Input",Parent={68},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,50,0,16),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{70,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="ArrowFrame",Parent={69},Position=UDim2.new(1,-16,0,0),Size=UDim2.new(0,16,1,0),}},
						{71,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Up",Parent={70},Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{72,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={71},Size=UDim2.new(0,16,0,8),}},
						{73,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={72},Position=UDim2.new(0,8,0,3),Size=UDim2.new(0,1,0,1),}},
						{74,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={72},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{75,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={72},Position=UDim2.new(0,6,0,5),Size=UDim2.new(0,5,0,1),}},
						{76,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Down",Parent={70},Position=UDim2.new(0,0,0,8),Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{77,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={76},Size=UDim2.new(0,16,0,8),}},
						{78,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={77},Position=UDim2.new(0,8,0,5),Size=UDim2.new(0,1,0,1),}},
						{79,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={77},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{80,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={77},Position=UDim2.new(0,6,0,3),Size=UDim2.new(0,5,0,1),}},
						{81,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={68},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Sat:",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{82,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Val",Parent={1},Position=UDim2.new(1,-180,0,255),Size=UDim2.new(0,52,0,16),}},
						{83,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),Font=3,Name="Input",Parent={82},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,50,0,16),Text="255",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{84,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="ArrowFrame",Parent={83},Position=UDim2.new(1,-16,0,0),Size=UDim2.new(0,16,1,0),}},
						{85,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Up",Parent={84},Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{86,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={85},Size=UDim2.new(0,16,0,8),}},
						{87,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={86},Position=UDim2.new(0,8,0,3),Size=UDim2.new(0,1,0,1),}},
						{88,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={86},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{89,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={86},Position=UDim2.new(0,6,0,5),Size=UDim2.new(0,5,0,1),}},
						{90,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Font=3,Name="Down",Parent={84},Position=UDim2.new(0,0,0,8),Size=UDim2.new(1,0,0,8),Text="",TextSize=14,}},
						{91,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={90},Size=UDim2.new(0,16,0,8),}},
						{92,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={91},Position=UDim2.new(0,8,0,5),Size=UDim2.new(0,1,0,1),}},
						{93,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={91},Position=UDim2.new(0,7,0,4),Size=UDim2.new(0,3,0,1),}},
						{94,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={91},Position=UDim2.new(0,6,0,3),Size=UDim2.new(0,5,0,1),}},
						{95,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={82},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Val:",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{96,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Font=3,Name="Cancel",Parent={1},Position=UDim2.new(1,-105,1,-28),Size=UDim2.new(0,100,0,25),Text="Cancel",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{97,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Font=3,Name="Ok",Parent={1},Position=UDim2.new(1,-210,1,-28),Size=UDim2.new(0,100,0,25),Text="OK",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{98,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Image="rbxassetid://1072518502",Name="ColorStrip",Parent={1},Position=UDim2.new(1,-30,0,5),Size=UDim2.new(0,13,0,200),}},
						{99,"Frame",{BackgroundColor3=Color3.new(0.3137255012989,0.3137255012989,0.3137255012989),BackgroundTransparency=1,BorderSizePixel=0,Name="ArrowFrame",Parent={1},Position=UDim2.new(1,-16,0,1),Size=UDim2.new(0,5,0,208),}},
						{100,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={99},Position=UDim2.new(0,-2,0,-4),Size=UDim2.new(0,8,0,16),}},
						{101,"Frame",{BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Parent={100},Position=UDim2.new(0,2,0,8),Size=UDim2.new(0,1,0,1),}},
						{102,"Frame",{BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Parent={100},Position=UDim2.new(0,3,0,7),Size=UDim2.new(0,1,0,3),}},
						{103,"Frame",{BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Parent={100},Position=UDim2.new(0,4,0,6),Size=UDim2.new(0,1,0,5),}},
						{104,"Frame",{BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Parent={100},Position=UDim2.new(0,5,0,5),Size=UDim2.new(0,1,0,7),}},
						{105,"Frame",{BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Parent={100},Position=UDim2.new(0,6,0,4),Size=UDim2.new(0,1,0,9),}},
					})
					local window = Lib.Window.new()
					window.Resizable = false
					window.Alignable = false
					window:SetTitle("Color Picker")
					window:Resize(450,330)
					for i,v in pairs(guiContents:GetChildren()) do
						v.Parent = window.GuiElems.Content
					end
					newMt.Window = window
					newMt.Gui = window.Gui
					local pickerGui = window.Gui.Main
					local pickerTopBar = pickerGui.TopBar
					local pickerFrame = pickerGui.Content
					local colorSpace = pickerFrame.ColorSpaceFrame.ColorSpace
					local colorStrip = pickerFrame.ColorStrip
					local previewFrame = pickerFrame.Preview
					local basicColorsFrame = pickerFrame.BasicColors
					local customColorsFrame = pickerFrame.CustomColors
					local okButton = pickerFrame.Ok
					local cancelButton = pickerFrame.Cancel
					local closeButton = pickerTopBar.Close

					local colorScope = colorSpace.Scope
					local colorArrow = pickerFrame.ArrowFrame.Arrow

					local hueInput = pickerFrame.Hue.Input
					local satInput = pickerFrame.Sat.Input
					local valInput = pickerFrame.Val.Input

					local redInput = pickerFrame.Red.Input
					local greenInput = pickerFrame.Green.Input
					local blueInput = pickerFrame.Blue.Input

					local user = service.UserInputService
					local mouse = service.Players.LocalPlayer:GetMouse()

					local hue,sat,val = 0,0,1
					local red,green,blue = 1,1,1
					local chosenColor = Color3.new(0,0,0)

					local basicColors = {Color3.new(0,0,0),Color3.new(0.66666668653488,0,0),Color3.new(0,0.33333334326744,0),Color3.new(0.66666668653488,0.33333334326744,0),Color3.new(0,0.66666668653488,0),Color3.new(0.66666668653488,0.66666668653488,0),Color3.new(0,1,0),Color3.new(0.66666668653488,1,0),Color3.new(0,0,0.49803924560547),Color3.new(0.66666668653488,0,0.49803924560547),Color3.new(0,0.33333334326744,0.49803924560547),Color3.new(0.66666668653488,0.33333334326744,0.49803924560547),Color3.new(0,0.66666668653488,0.49803924560547),Color3.new(0.66666668653488,0.66666668653488,0.49803924560547),Color3.new(0,1,0.49803924560547),Color3.new(0.66666668653488,1,0.49803924560547),Color3.new(0,0,1),Color3.new(0.66666668653488,0,1),Color3.new(0,0.33333334326744,1),Color3.new(0.66666668653488,0.33333334326744,1),Color3.new(0,0.66666668653488,1),Color3.new(0.66666668653488,0.66666668653488,1),Color3.new(0,1,1),Color3.new(0.66666668653488,1,1),Color3.new(0.33333334326744,0,0),Color3.new(1,0,0),Color3.new(0.33333334326744,0.33333334326744,0),Color3.new(1,0.33333334326744,0),Color3.new(0.33333334326744,0.66666668653488,0),Color3.new(1,0.66666668653488,0),Color3.new(0.33333334326744,1,0),Color3.new(1,1,0),Color3.new(0.33333334326744,0,0.49803924560547),Color3.new(1,0,0.49803924560547),Color3.new(0.33333334326744,0.33333334326744,0.49803924560547),Color3.new(1,0.33333334326744,0.49803924560547),Color3.new(0.33333334326744,0.66666668653488,0.49803924560547),Color3.new(1,0.66666668653488,0.49803924560547),Color3.new(0.33333334326744,1,0.49803924560547),Color3.new(1,1,0.49803924560547),Color3.new(0.33333334326744,0,1),Color3.new(1,0,1),Color3.new(0.33333334326744,0.33333334326744,1),Color3.new(1,0.33333334326744,1),Color3.new(0.33333334326744,0.66666668653488,1),Color3.new(1,0.66666668653488,1),Color3.new(0.33333334326744,1,1),Color3.new(1,1,1)}
					local customColors = {}

					local function updateColor(noupdate)
						local relativeX, relativeY, relativeStripY = 219 - hue * 219, 199 - sat * 199, 199 - val * 199
						local hsvColor = Color3.fromHSV(hue, sat, val)

						if noupdate == 2 or not noupdate then
							hueInput.Text = tostring(math.ceil(359 * hue))
							satInput.Text = tostring(math.ceil(255 * sat))
							valInput.Text = tostring(math.floor(255 * val))
						end
						if noupdate == 1 or not noupdate then
							redInput.Text = tostring(math.floor(255 * red))
							greenInput.Text = tostring(math.floor(255 * green))
							blueInput.Text = tostring(math.floor(255 * blue))
						end

						chosenColor = Color3.new(red, green, blue)
						colorScope.Position = UDim2.new(0, (relativeX - 9), 0, (relativeY - 9))
						colorStrip.ImageColor3 = Color3.fromHSV(hue, sat, 1)
						colorArrow.Position = UDim2.new(0, -2, 0, (relativeStripY - 4))
						previewFrame.BackgroundColor3 = chosenColor

						newMt.Color = chosenColor
						newMt.OnPreview:Fire(chosenColor)
					end

					local function handleInputBegan(input, updateFunc)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							while user:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
								updateFunc()task.wait()
							end
						end
					end

					local function colorSpaceInput()
						local relativeX = mouse.X - colorSpace.AbsolutePosition.X
						local relativeY = mouse.Y - colorSpace.AbsolutePosition.Y

						if relativeX < 0 then relativeX = 0 elseif relativeX > 219 then relativeX = 219 end
						if relativeY < 0 then relativeY = 0 elseif relativeY > 199 then relativeY = 199 end

						hue = (219 - relativeX) / 219
						sat = (199 - relativeY) / 199

						local hsvColor = Color3.fromHSV(hue, sat, val)
						red, green, blue = hsvColor.R, hsvColor.G, hsvColor.B
						updateColor()
					end

					local function colorStripInput()
						local relativeY = mouse.Y - colorStrip.AbsolutePosition.Y

						if relativeY < 0 then relativeY = 0 elseif relativeY > 199 then relativeY = 199 end	

						val = (199 - relativeY) / 199

						local hsvColor = Color3.fromHSV(hue, sat, val)
						red, green, blue = hsvColor.R, hsvColor.G, hsvColor.B
						updateColor()
					end

					FrostznLife.Connect(colorSpace.InputBegan,function(input) handleInputBegan(input, colorSpaceInput) end)
					FrostznLife.Connect(colorStrip.InputBegan,function(input) handleInputBegan(input, colorStripInput) end)

					local function hookButtons(frame, func)
						FrostznLife.Connect(frame.ArrowFrame.Up.InputBegan,function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								local releaseEvent, runEvent
								local startTime = tick()
								local pressing = true
								local startNum = tonumber(frame.Text)

								if not startNum then return end

								releaseEvent = FrostznLife.Connect(user.InputEnded,function(endInput)
									if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
										releaseEvent:Disconnect()
										pressing = false
									end
								end)

								startNum = startNum + 1
								func(startNum)
								while pressing do
									if tick() - startTime > 0.3 then
										startNum = startNum + 1
										func(startNum)
										startTime = tick()
									end
									task.wait(0.1)
								end
							end
						end)

						FrostznLife.Connect(frame.ArrowFrame.Down.InputBegan,function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								local releaseEvent, runEvent
								local startTime = tick()
								local pressing = true
								local startNum = tonumber(frame.Text)

								if not startNum then return end

								releaseEvent = FrostznLife.Connect(user.InputEnded,function(endInput)
									if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
										releaseEvent:Disconnect()
										pressing = false
									end
								end)

								startNum = startNum - 1
								func(startNum)
								while pressing do
									if tick() - startTime > 0.3 then
										startNum = startNum - 1
										func(startNum)
										startTime = tick()
									end
									task.wait(0.1)
								end
							end
						end)
					end

			--[[local function UpdateBox(TextBox, Value, IsHSV, ...)
				local number = tonumber(TextBox.Text)
				if number then
					number = math.clamp(math.floor(number), 0, Value) / Value
					local HSV = Color3.fromHSV(func(number))
					red, green, blue = HSV.R, HSV.G, HSV.B
					
					TextBox.Text = tostring(number):sub(4)
					updateColor(IsHSV)
				end
			end]]

					local function updateHue(str)
						local num = tonumber(str)
						if num then
							hue = math.clamp(math.floor(num),0,359)/359
							local hsvColor = Color3.fromHSV(hue,sat,val)
							red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b

							hueInput.Text = tostring(hue*359)
							updateColor(1)
						end
					end
					FrostznLife.Connect(hueInput.FocusLost,function() updateHue(hueInput.Text) end) hookButtons(hueInput, hueInput)

					local function updateSat(str)
						local num = tonumber(str)
						if num then
							sat = math.clamp(math.floor(num),0,255)/255
							local hsvColor = Color3.fromHSV(hue,sat,val)
							red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b
							satInput.Text = tostring(sat*255)
							updateColor(1)
						end
					end
					FrostznLife.Connect(satInput.FocusLost,function() updateSat(satInput.Text) end) hookButtons(satInput,updateSat)

					local function updateVal(str)
						local num = tonumber(str)
						if num then
							val = math.clamp(math.floor(num),0,255)/255
							local hsvColor = Color3.fromHSV(hue,sat,val)
							red,green,blue = hsvColor.r,hsvColor.g,hsvColor.b
							valInput.Text = tostring(val*255)
							updateColor(1)
						end
					end
					FrostznLife.Connect(valInput.FocusLost,function() updateVal(valInput.Text) end) hookButtons(valInput,updateVal)

					local function updateRed(str)
						local num = tonumber(str)
						if num then
							red = math.clamp(math.floor(num),0,255)/255
							local newColor = Color3.new(red,green,blue)
							hue,sat,val = Color3.toHSV(newColor)
							redInput.Text = tostring(red*255)
							updateColor(2)
						end
					end
					FrostznLife.Connect(redInput.FocusLost,function() updateRed(redInput.Text) end) hookButtons(redInput,updateRed)

					local function updateGreen(str)
						local num = tonumber(str)
						if num then
							green = math.clamp(math.floor(num),0,255)/255
							local newColor = Color3.new(red,green,blue)
							hue,sat,val = Color3.toHSV(newColor)
							greenInput.Text = tostring(green*255)
							updateColor(2)
						end
					end
					FrostznLife.Connect(greenInput.FocusLost,function() updateGreen(greenInput.Text) end) hookButtons(greenInput,updateGreen)

					local function updateBlue(str)
						local num = tonumber(str)
						if num then
							blue = math.clamp(math.floor(num),0,255)/255
							local newColor = Color3.new(red,green,blue)
							hue,sat,val = Color3.toHSV(newColor)
							blueInput.Text = tostring(blue*255)
							updateColor(2)
						end
					end
					FrostznLife.Connect(blueInput.FocusLost,function() updateBlue(blueInput.Text) end) hookButtons(blueInput,updateBlue)

					local colorChoice = Instance.new("TextButton")
					colorChoice.Name = "Choice"
					colorChoice.Size = UDim2.new(0,25,0,18)
					colorChoice.BorderColor3 = Color3.fromRGB(55,55,55)
					colorChoice.Text = ""
					colorChoice.AutoButtonColor = false

					local row = 0
					local column = 0
					for i,v in pairs(basicColors) do
						local newColor = colorChoice:Clone()
						newColor.BackgroundColor3 = v
						newColor.Position = UDim2.new(0,1 + 30*column,0,21 + 23*row)

						FrostznLife.Connect(newColor.MouseButton1Click,function()
							red,green,blue = v.r,v.g,v.b
							local newColor = Color3.new(red,green,blue)
							hue,sat,val = Color3.toHSV(newColor)
							updateColor()
						end)

						newColor.Parent = basicColorsFrame
						column = column + 1
						if column == 6 then row = row + 1 column = 0 end
					end

					row = 0
					column = 0
					for i = 1,12 do
						local color = customColors[i] or Color3.new(0,0,0)
						local newColor = colorChoice:Clone()
						newColor.BackgroundColor3 = color
						newColor.Position = UDim2.new(0,1 + 30*column,0,20 + 23*row)

						FrostznLife.Connect(newColor.MouseButton1Click,function()
							local curColor = customColors[i] or Color3.new(0,0,0)
							red,green,blue = curColor.r,curColor.g,curColor.b
							hue,sat,val = Color3.toHSV(curColor)
							updateColor()
						end)

						FrostznLife.Connect(newColor.MouseButton2Click,function()
							customColors[i] = chosenColor
							newColor.BackgroundColor3 = chosenColor
						end)

						newColor.Parent = customColorsFrame
						column = column + 1
						if column == 6 then row = row + 1 column = 0 end
					end

					FrostznLife.Connect(okButton.MouseButton1Click,function() newMt.OnSelect:Fire(chosenColor) window:Close() end)
					FrostznLife.Connect(okButton.InputBegan,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then okButton.BackgroundTransparency = 0.4 end end)
					FrostznLife.Connect(okButton.InputEnded,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then okButton.BackgroundTransparency = 0 end end)


					FrostznLife.Connect(cancelButton.MouseButton1Click,function() newMt.OnCancel:Fire() window:Close() end)
					FrostznLife.Connect(cancelButton.InputBegan,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then cancelButton.BackgroundTransparency = 0.4 end end)
					FrostznLife.Connect(cancelButton.InputEnded,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then cancelButton.BackgroundTransparency = 0 end end)

					updateColor()

					newMt.SetColor = function(self,color)
						red,green,blue = color.r,color.g,color.b
						hue,sat,val = Color3.toHSV(color)
						updateColor()
					end

					newMt.Show = function(self)
						self.Window:Show()
					end

					return newMt
				end

				return {new = new}
			end)()

			Lib.NumberSequenceEditor = (function()
				local function new() -- TODO: Convert to newer class model
					local newMt = setmetatable({},{})
					newMt.OnSelect = Lib.Signal.new()
					newMt.OnCancel = Lib.Signal.new()
					newMt.OnPreview = Lib.Signal.new()

					local guiContents = create({
						{1,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,ClipsDescendants=true,Name="Content",Position=UDim2.new(0,0,0,20),Size=UDim2.new(1,0,1,-20),}},
						{2,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Time",Parent={1},Position=UDim2.new(0,40,0,210),Size=UDim2.new(0,60,0,20),}},
						{3,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),ClipsDescendants=true,Font=3,Name="Input",Parent={2},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,58,0,20),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{4,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={2},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Time",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{5,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Font=3,Name="Close",Parent={1},Position=UDim2.new(1,-90,0,210),Size=UDim2.new(0,80,0,20),Text="Close",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{6,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Font=3,Name="Reset",Parent={1},Position=UDim2.new(1,-180,0,210),Size=UDim2.new(0,80,0,20),Text="Reset",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{7,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Font=3,Name="Delete",Parent={1},Position=UDim2.new(0,380,0,210),Size=UDim2.new(0,80,0,20),Text="Delete",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{8,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Name="NumberLineOutlines",Parent={1},Position=UDim2.new(0,10,0,20),Size=UDim2.new(1,-20,0,170),}},
						{9,"Frame",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),Name="NumberLine",Parent={1},Position=UDim2.new(0,10,0,20),Size=UDim2.new(1,-20,0,170),}},
						{10,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Value",Parent={1},Position=UDim2.new(0,170,0,210),Size=UDim2.new(0,60,0,20),}},
						{11,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={10},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Value",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{12,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),ClipsDescendants=true,Font=3,Name="Input",Parent={10},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,58,0,20),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{13,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Envelope",Parent={1},Position=UDim2.new(0,300,0,210),Size=UDim2.new(0,60,0,20),}},
						{14,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),ClipsDescendants=true,Font=3,Name="Input",Parent={13},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,58,0,20),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{15,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={13},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Envelope",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
					})
					local window = Lib.Window.new()
					window.Resizable = false
					window:Resize(680,265)
					window:SetTitle("NumberSequence Editor")
					newMt.Window = window
					newMt.Gui = window.Gui
					for i,v in pairs(guiContents:GetChildren()) do
						v.Parent = window.GuiElems.Content
					end
					local gui = window.Gui
					local pickerGui = gui.Main
					local pickerTopBar = pickerGui.TopBar
					local pickerFrame = pickerGui.Content
					local numberLine = pickerFrame.NumberLine
					local numberLineOutlines = pickerFrame.NumberLineOutlines
					local timeBox = pickerFrame.Time.Input
					local valueBox = pickerFrame.Value.Input
					local envelopeBox = pickerFrame.Envelope.Input
					local deleteButton = pickerFrame.Delete
					local resetButton = pickerFrame.Reset
					local closeButton = pickerFrame.Close
					local topClose = pickerTopBar.Close

					local points = {{1,0,3},{8,0.05,1},{5,0.6,2},{4,0.7,4},{6,1,4}}
					local lines = {}
					local eLines = {}
					local beginPoint = points[1]
					local endPoint = points[#points]
					local currentlySelected = nil
					local currentPoint = nil
					local resetSequence = nil

					local user = service.UserInputService
					local mouse = service.Players.LocalPlayer:GetMouse()

					for i = 2,10 do
						local newLine = Instance.new("Frame")
						newLine.BackgroundTransparency = 0.5
						newLine.BackgroundColor3 = Color3.new(96/255,96/255,96/255)
						newLine.BorderSizePixel = 0
						newLine.Size = UDim2.new(0,1,1,0)
						newLine.Position = UDim2.new((i-1)/(11-1),0,0,0)
						newLine.Parent = numberLineOutlines
					end

					for i = 2,4 do
						local newLine = Instance.new("Frame")
						newLine.BackgroundTransparency = 0.5
						newLine.BackgroundColor3 = Color3.new(96/255,96/255,96/255)
						newLine.BorderSizePixel = 0
						newLine.Size = UDim2.new(1,0,0,1)
						newLine.Position = UDim2.new(0,0,(i-1)/(5-1),0)
						newLine.Parent = numberLineOutlines
					end

					local lineTemp = Instance.new("Frame")
					lineTemp.BackgroundColor3 = Color3.new(0,0,0)
					lineTemp.BorderSizePixel = 0
					lineTemp.Size = UDim2.new(0,1,0,1)

					local sequenceLine = Instance.new("Frame")
					sequenceLine.BackgroundColor3 = Color3.new(0,0,0)
					sequenceLine.BorderSizePixel = 0
					sequenceLine.Size = UDim2.new(0,1,0,0)

					for i = 1,numberLine.AbsoluteSize.X do
						local line = sequenceLine:Clone()
						eLines[i] = line
						line.Name = "E"..tostring(i)
						line.BackgroundTransparency = 0.5
						line.BackgroundColor3 = Color3.new(199/255,44/255,28/255)
						line.Position = UDim2.new(0,i-1,0,0)
						line.Parent = numberLine
					end

					for i = 1,numberLine.AbsoluteSize.X do
						local line = sequenceLine:Clone()
						lines[i] = line
						line.Name = tostring(i)
						line.Position = UDim2.new(0,i-1,0,0)
						line.Parent = numberLine
					end

					local envelopeDrag = Instance.new("Frame")
					envelopeDrag.BackgroundTransparency = 1
					envelopeDrag.BackgroundColor3 = Color3.new(0,0,0)
					envelopeDrag.BorderSizePixel = 0
					envelopeDrag.Size = UDim2.new(0,7,0,20)
					envelopeDrag.Visible = false
					envelopeDrag.ZIndex = 2
					local envelopeDragLine = Instance.new("Frame",envelopeDrag)
					envelopeDragLine.Name = "Line"
					envelopeDragLine.BackgroundColor3 = Color3.new(0,0,0)
					envelopeDragLine.BorderSizePixel = 0
					envelopeDragLine.Position = UDim2.new(0,3,0,0)
					envelopeDragLine.Size = UDim2.new(0,1,0,20)
					envelopeDragLine.ZIndex = 2

					local envelopeDragTop,envelopeDragBottom = envelopeDrag:Clone(),envelopeDrag:Clone()
					envelopeDragTop.Parent = numberLine
					envelopeDragBottom.Parent = numberLine

					local function buildSequence()
						local newPoints = {}
						for i,v in pairs(points) do
							table.insert(newPoints,NumberSequenceKeypoint.new(v[2],v[1],v[3]))
						end
						newMt.Sequence = NumberSequence.new(newPoints)
						newMt.OnSelect:Fire(newMt.Sequence)
					end

					local function round(num,places)
						local multi = 10^places
						return math.floor(num*multi + 0.5)/multi
					end

					local function updateInputs(point)
						if point then
							currentPoint = point
							local rawT,rawV,rawE = point[2],point[1],point[3]
							timeBox.Text = round(rawT,(rawT < 0.01 and 5) or (rawT < 0.1 and 4) or 3)
							valueBox.Text = round(rawV,(rawV < 0.01 and 5) or (rawV < 0.1 and 4) or (rawV < 1 and 3) or 2)
							envelopeBox.Text = round(rawE,(rawE < 0.01 and 5) or (rawE < 0.1 and 4) or (rawV < 1 and 3) or 2)

							local envelopeDistance = numberLine.AbsoluteSize.Y*(point[3]/10)
							envelopeDragTop.Position = UDim2.new(0,point[4].Position.X.Offset-1,0,point[4].Position.Y.Offset-envelopeDistance-17)
							envelopeDragTop.Visible = true
							envelopeDragBottom.Position = UDim2.new(0,point[4].Position.X.Offset-1,0,point[4].Position.Y.Offset+envelopeDistance+2)
							envelopeDragBottom.Visible = true
						end
					end

					FrostznLife.Connect(envelopeDragTop.InputBegan,function(input)
						if (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) or not currentPoint or Lib.CheckMouseInGui(currentPoint[4].Select) then return end

						local mouseEvent, releaseEvent
						local maxSize = numberLine.AbsoluteSize.Y
						local mouseDelta = math.abs(envelopeDragTop.AbsolutePosition.Y - mouse.Y)

						envelopeDragTop.Line.Position = UDim2.new(0, 2, 0, 0)
						envelopeDragTop.Line.Size = UDim2.new(0, 3, 0, 20)

						releaseEvent = FrostznLife.Connect(user.InputEnded,function(input)
							if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
							mouseEvent:Disconnect()
							releaseEvent:Disconnect()
							envelopeDragTop.Line.Position = UDim2.new(0, 3, 0, 0)
							envelopeDragTop.Line.Size = UDim2.new(0, 1, 0, 20)
						end)

						mouseEvent = FrostznLife.Connect(user.InputChanged,function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								local topDiff = (currentPoint[4].AbsolutePosition.Y + 2) - (mouse.Y - mouseDelta) - 19
								local newEnvelope = 10 * (math.max(topDiff, 0) / maxSize)
								local maxEnvelope = math.min(currentPoint[1], 10 - currentPoint[1])
								currentPoint[3] = math.min(newEnvelope, maxEnvelope)
								newMt:Redraw()
								buildSequence()
								updateInputs(currentPoint)
							end
						end)
					end)

					FrostznLife.Connect(envelopeDragBottom.InputBegan,function(input)
						if (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) or not currentPoint or Lib.CheckMouseInGui(currentPoint[4].Select) then return end

						local mouseEvent, releaseEvent
						local maxSize = numberLine.AbsoluteSize.Y
						local mouseDelta = math.abs(envelopeDragBottom.AbsolutePosition.Y - mouse.Y)

						envelopeDragBottom.Line.Position = UDim2.new(0, 2, 0, 0)
						envelopeDragBottom.Line.Size = UDim2.new(0, 3, 0, 20)

						releaseEvent = FrostznLife.Connect(user.InputEnded,function(input)
							if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
							mouseEvent:Disconnect()
							releaseEvent:Disconnect()
							envelopeDragBottom.Line.Position = UDim2.new(0, 3, 0, 0)
							envelopeDragBottom.Line.Size = UDim2.new(0, 1, 0, 20)
						end)

						mouseEvent = FrostznLife.Connect(user.InputChanged,function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								local bottomDiff = (mouse.Y + (20 - mouseDelta)) - (currentPoint[4].AbsolutePosition.Y + 2) - 19
								local newEnvelope = 10 * (math.max(bottomDiff, 0) / maxSize)
								local maxEnvelope = math.min(currentPoint[1], 10 - currentPoint[1])
								currentPoint[3] = math.min(newEnvelope, maxEnvelope)
								newMt:Redraw()
								buildSequence()
								updateInputs(currentPoint)
							end
						end)
					end)

					local function placePoint(point)
						local newPoint = Instance.new("Frame")
						newPoint.Name = "Point"
						newPoint.BorderSizePixel = 0
						newPoint.Size = UDim2.new(0,5,0,5)
						newPoint.Position = UDim2.new(0,math.floor((numberLine.AbsoluteSize.X-1) * point[2])-2,0,numberLine.AbsoluteSize.Y*(10-point[1])/10-2)
						newPoint.BackgroundColor3 = Color3.new(0,0,0)

						local newSelect = Instance.new("Frame")
						newSelect.Name = "Select"
						newSelect.BackgroundTransparency = 1
						newSelect.BackgroundColor3 = Color3.new(199/255,44/255,28/255)
						newSelect.Position = UDim2.new(0,-2,0,-2)
						newSelect.Size = UDim2.new(0,9,0,9)
						newSelect.Parent = newPoint

						newPoint.Parent = numberLine


						FrostznLife.Connect(newSelect.InputBegan,function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								for i, v in pairs(points) do 
									v[4].Select.BackgroundTransparency = 1 
								end

								newSelect.BackgroundTransparency = 0
								updateInputs(point)
							end

							if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not currentlySelected then
								currentPoint = point
								local mouseEvent, releaseEvent
								currentlySelected = true
								newSelect.BackgroundColor3 = Color3.new(249/255, 191/255, 59/255)

								local oldEnvelope = point[3]

								releaseEvent = FrostznLife.Connect(user.InputEnded,function(input)
									if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then	return end

									mouseEvent:Disconnect()
									releaseEvent:Disconnect()
									currentlySelected = nil
									newSelect.BackgroundColor3 = Color3.new(199/255, 44/255, 28/255)
								end)

								mouseEvent = FrostznLife.Connect(user.InputChanged,function(input)
									if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
										local maxX = numberLine.AbsoluteSize.X - 1
										local relativeX = (input.Position.X - numberLine.AbsolutePosition.X)
										if relativeX < 0 then relativeX = 0 end
										if relativeX > maxX then relativeX = maxX end

										local maxY = numberLine.AbsoluteSize.Y - 1
										local relativeY = (input.Position.Y - numberLine.AbsolutePosition.Y)
										if relativeY < 0 then relativeY = 0 end
										if relativeY > maxY then relativeY = maxY end

										if point ~= beginPoint and point ~= endPoint then
											point[2] = relativeX / maxX
										end

										point[1] = 10 - (relativeY / maxY) * 10
										local maxEnvelope = math.min(point[1], 10 - point[1])
										point[3] = math.min(oldEnvelope, maxEnvelope)
										newMt:Redraw()
										updateInputs(point)

										for i, v in pairs(points) do 
											v[4].Select.BackgroundTransparency = 1 
										end

										newSelect.BackgroundTransparency = 0
										buildSequence()
									end
								end)
							end
						end)

						return newPoint
					end

					local function placePoints()
						for i,v in pairs(points) do
							v[4] = placePoint(v)
						end
					end

					local function redraw(self)
						local numberLineSize = numberLine.AbsoluteSize
						table.sort(points,function(a,b) return a[2] < b[2] end)
						for i,v in pairs(points) do
							v[4].Position = UDim2.new(0,math.floor((numberLineSize.X-1) * v[2])-2,0,(numberLineSize.Y-1)*(10-v[1])/10-2)
						end
						lines[1].Size = UDim2.new(0,1,0,0)
						for i = 1,#points-1 do
							local fromPoint = points[i]
							local toPoint = points[i+1]
							local deltaY = toPoint[4].Position.Y.Offset-fromPoint[4].Position.Y.Offset
							local deltaX = toPoint[4].Position.X.Offset-fromPoint[4].Position.X.Offset
							local slope = deltaY/deltaX

							local fromEnvelope = fromPoint[3]
							local nextEnvelope = toPoint[3]

							local currentRise = math.abs(slope)
							local totalRise = 0
							local maxRise = math.abs(toPoint[4].Position.Y.Offset-fromPoint[4].Position.Y.Offset)

							for lineCount = math.min(fromPoint[4].Position.X.Offset+1,toPoint[4].Position.X.Offset),toPoint[4].Position.X.Offset do
								if deltaX == 0 and deltaY == 0 then return end
								local riseNow = math.floor(currentRise)
								local line = lines[lineCount+3]
								if line then
									if totalRise+riseNow > maxRise then riseNow = maxRise-totalRise end
									if math.sign(slope) == -1 then
										line.Position = UDim2.new(0,lineCount+2,0,fromPoint[4].Position.Y.Offset + -(totalRise+riseNow)+2)
									else
										line.Position = UDim2.new(0,lineCount+2,0,fromPoint[4].Position.Y.Offset + totalRise+2)
									end
									line.Size = UDim2.new(0,1,0,math.max(riseNow,1))
								end
								totalRise = totalRise + riseNow
								currentRise = currentRise - riseNow + math.abs(slope)

								local envPercent = (lineCount-fromPoint[4].Position.X.Offset)/(toPoint[4].Position.X.Offset-fromPoint[4].Position.X.Offset)
								local envLerp = fromEnvelope+(nextEnvelope-fromEnvelope)*envPercent
								local relativeSize = (envLerp/10)*numberLineSize.Y						

								local line = eLines[lineCount + 3]
								if line then
									line.Position = UDim2.new(0,lineCount+2,0,lines[lineCount+3].Position.Y.Offset-math.floor(relativeSize))
									line.Size = UDim2.new(0,1,0,math.floor(relativeSize*2))
								end
							end
						end
					end
					newMt.Redraw = redraw



					local function loadSequence(self,seq)
						resetSequence = seq
						for i,v in pairs(points) do if v[4] then v[4]:Destroy() end end
						points = {}
						for i,v in pairs(seq.Keypoints) do
							local maxEnvelope = math.min(v.Value,10-v.Value)
							local newPoint = {v.Value,v.Time,math.min(v.Envelope,maxEnvelope)}
							newPoint[4] = placePoint(newPoint)
							table.insert(points,newPoint)
						end
						beginPoint = points[1]
						endPoint = points[#points]
						currentlySelected = nil
						redraw()
						envelopeDragTop.Visible = false
						envelopeDragBottom.Visible = false
					end
					newMt.SetSequence = loadSequence

					FrostznLife.Connect(timeBox.FocusLost,function()
						local point = currentPoint
						local num = tonumber(timeBox.Text)
						if point and num and point ~= beginPoint and point ~= endPoint then
							num = math.clamp(num,0,1)
							point[2] = num
							redraw()
							buildSequence()
							updateInputs(point)
						end
					end)

					FrostznLife.Connect(valueBox.FocusLost,function()
						local point = currentPoint
						local num = tonumber(valueBox.Text)
						if point and num then
							local oldEnvelope = point[3]
							num = math.clamp(num,0,10)
							point[1] = num
							local maxEnvelope = math.min(point[1],10-point[1])
							point[3] = math.min(oldEnvelope,maxEnvelope)
							redraw()
							buildSequence()
							updateInputs(point)
						end
					end)

					FrostznLife.Connect(envelopeBox.FocusLost,function()
						local point = currentPoint
						local num = tonumber(envelopeBox.Text)
						if point and num then
							num = math.clamp(num,0,5)
							local maxEnvelope = math.min(point[1],10-point[1])
							point[3] = math.min(num,maxEnvelope)
							redraw()
							buildSequence()
							updateInputs(point)
						end
					end)

					local function buttonAnimations(button,inverse)
						FrostznLife.Connect(button.InputBegan,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then button.BackgroundTransparency = (inverse and 0.5 or 0.4) end end)
						FrostznLife.Connect(button.InputEnded,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then button.BackgroundTransparency = (inverse and 1 or 0) end end)
					end

					FrostznLife.Connect(numberLine.InputBegan,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and #points < 20 then

							if Lib.CheckMouseInGui(envelopeDragTop) or Lib.CheckMouseInGui(envelopeDragBottom) then return end

							for i, v in pairs(points) do
								if Lib.CheckMouseInGui(v[4].Select) then
									return
								end
							end

							local maxX = numberLine.AbsoluteSize.X - 1
							local relativeX = (input.Position.X - numberLine.AbsolutePosition.X)
							if relativeX < 0 then relativeX = 0 end
							if relativeX > maxX then relativeX = maxX end

							local maxY = numberLine.AbsoluteSize.Y - 1
							local relativeY = (input.Position.Y - numberLine.AbsolutePosition.Y)
							if relativeY < 0 then relativeY = 0 end
							if relativeY > maxY then relativeY = maxY end

							local raw = relativeX / maxX
							local newPoint = {10 - (relativeY / maxY) * 10, raw, 0}
							newPoint[4] = placePoint(newPoint)
							table.insert(points, newPoint)
							redraw()
							buildSequence()
						end
					end)

					FrostznLife.Connect(deleteButton.MouseButton1Click,function()
						if currentPoint and currentPoint ~= beginPoint and currentPoint ~= endPoint then
							for i,v in pairs(points) do
								if v == currentPoint then
									v[4]:Destroy()
									table.remove(points,i)
									break
								end
							end
							currentlySelected = nil
							redraw()
							buildSequence()
							updateInputs(points[1])
						end
					end)

					FrostznLife.Connect(resetButton.MouseButton1Click,function()
						if resetSequence then
							newMt:SetSequence(resetSequence)
							buildSequence()
						end
					end)

					FrostznLife.Connect(closeButton.MouseButton1Click,function()
						window:Close()
					end)

					buttonAnimations(deleteButton)
					buttonAnimations(resetButton)
					buttonAnimations(closeButton)

					placePoints()
					redraw()

					newMt.Show = function(self)
						window:Show()
					end

					return newMt
				end

				return {new = new}
			end)()

			Lib.ColorSequenceEditor = (function() -- TODO: Convert to newer class model
				local function new()
					local newMt = setmetatable({},{})
					newMt.OnSelect = Lib.Signal.new()
					newMt.OnCancel = Lib.Signal.new()
					newMt.OnPreview = Lib.Signal.new()
					newMt.OnPickColor = Lib.Signal.new()

					local guiContents = create({
						{1,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,ClipsDescendants=true,Name="Content",Position=UDim2.new(0,0,0,20),Size=UDim2.new(1,0,1,-20),}},
						{2,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Name="ColorLine",Parent={1},Position=UDim2.new(0,10,0,5),Size=UDim2.new(1,-20,0,70),}},
						{3,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Gradient",Parent={2},Size=UDim2.new(1,0,1,0),}},
						{4,"UIGradient",{Parent={3},}},
						{5,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Name="Arrows",Parent={1},Position=UDim2.new(0,1,0,73),Size=UDim2.new(1,-2,0,16),}},
						{6,"Frame",{BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.5,BorderSizePixel=0,Name="Cursor",Parent={1},Position=UDim2.new(0,10,0,0),Size=UDim2.new(0,1,0,80),}},
						{7,"Frame",{BackgroundColor3=Color3.new(0.14901961386204,0.14901961386204,0.14901961386204),BorderColor3=Color3.new(0.12549020349979,0.12549020349979,0.12549020349979),Name="Time",Parent={1},Position=UDim2.new(0,40,0,95),Size=UDim2.new(0,100,0,20),}},
						{8,"TextBox",{BackgroundColor3=Color3.new(0.25098040699959,0.25098040699959,0.25098040699959),BackgroundTransparency=1,BorderColor3=Color3.new(0.37647062540054,0.37647062540054,0.37647062540054),ClipsDescendants=true,Font=3,Name="Input",Parent={7},Position=UDim2.new(0,2,0,0),Size=UDim2.new(0,98,0,20),Text="0",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=0,}},
						{9,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={7},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Time",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{10,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),Name="ColorBox",Parent={1},Position=UDim2.new(0,220,0,95),Size=UDim2.new(0,20,0,20),}},
						{11,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Title",Parent={10},Position=UDim2.new(0,-40,0,0),Size=UDim2.new(0,34,1,0),Text="Color",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,TextXAlignment=1,}},
						{12,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),BorderSizePixel=0,Font=3,Name="Close",Parent={1},Position=UDim2.new(1,-90,0,95),Size=UDim2.new(0,80,0,20),Text="Close",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{13,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),BorderSizePixel=0,Font=3,Name="Reset",Parent={1},Position=UDim2.new(1,-180,0,95),Size=UDim2.new(0,80,0,20),Text="Reset",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{14,"TextButton",{AutoButtonColor=false,BackgroundColor3=Color3.new(0.2352941185236,0.2352941185236,0.2352941185236),BorderColor3=Color3.new(0.21568627655506,0.21568627655506,0.21568627655506),BorderSizePixel=0,Font=3,Name="Delete",Parent={1},Position=UDim2.new(0,280,0,95),Size=UDim2.new(0,80,0,20),Text="Delete",TextColor3=Color3.new(0.86274516582489,0.86274516582489,0.86274516582489),TextSize=14,}},
						{15,"Frame",{BackgroundTransparency=1,Name="Arrow",Parent={1},Size=UDim2.new(0,16,0,16),Visible=false,}},
						{16,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={15},Position=UDim2.new(0,8,0,3),Size=UDim2.new(0,1,0,2),}},
						{17,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={15},Position=UDim2.new(0,7,0,5),Size=UDim2.new(0,3,0,2),}},
						{18,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={15},Position=UDim2.new(0,6,0,7),Size=UDim2.new(0,5,0,2),}},
						{19,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={15},Position=UDim2.new(0,5,0,9),Size=UDim2.new(0,7,0,2),}},
						{20,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={15},Position=UDim2.new(0,4,0,11),Size=UDim2.new(0,9,0,2),}},
					})
					local window = Lib.Window.new()
					window.Resizable = false
					window:Resize(650,150)
					window:SetTitle("ColorSequence Editor")
					newMt.Window = window
					newMt.Gui = window.Gui
					for i,v in pairs(guiContents:GetChildren()) do
						v.Parent = window.GuiElems.Content
					end
					local gui = window.Gui
					local pickerGui = gui.Main
					local pickerTopBar = pickerGui.TopBar
					local pickerFrame = pickerGui.Content
					local colorLine = pickerFrame.ColorLine
					local gradient = colorLine.Gradient.UIGradient
					local arrowFrame = pickerFrame.Arrows
					local arrow = pickerFrame.Arrow
					local cursor = pickerFrame.Cursor
					local timeBox = pickerFrame.Time.Input
					local colorBox = pickerFrame.ColorBox
					local deleteButton = pickerFrame.Delete
					local resetButton = pickerFrame.Reset
					local closeButton = pickerFrame.Close
					local topClose = pickerTopBar.Close

					local user = service.UserInputService
					local mouse = service.Players.LocalPlayer:GetMouse()

					local colors = {{Color3.new(1,0,1),0},{Color3.new(0.2,0.9,0.2),0.2},{Color3.new(0.4,0.5,0.9),0.7},{Color3.new(0.6,1,1),1}}
					local resetSequence = nil

					local beginPoint = colors[1]
					local endPoint = colors[#colors]

					local currentlySelected = nil
					local currentPoint = nil

					local sequenceLine = Instance.new("Frame")
					sequenceLine.BorderSizePixel = 0
					sequenceLine.Size = UDim2.new(0,1,1,0)

					newMt.Sequence = ColorSequence.new(Color3.new(1,1,1))
					local function buildSequence(noupdate)
						local newPoints = {}
						table.sort(colors,function(a,b) return a[2] < b[2] end)
						for i,v in pairs(colors) do
							table.insert(newPoints,ColorSequenceKeypoint.new(v[2],v[1]))
						end
						newMt.Sequence = ColorSequence.new(newPoints)
						if not noupdate then newMt.OnSelect:Fire(newMt.Sequence) end
					end

					local function round(num,places)
						local multi = 10^places
						return math.floor(num*multi + 0.5)/multi
					end

					local function updateInputs(point)
						if point then
							currentPoint = point
							local raw = point[2]
							timeBox.Text = round(raw,(raw < 0.01 and 5) or (raw < 0.1 and 4) or 3)
							colorBox.BackgroundColor3 = point[1]
						end
					end

					local function placeArrow(ind,point)
						local newArrow = arrow:Clone()
						newArrow.Position = UDim2.new(0,ind-1,0,0)
						newArrow.Visible = true
						newArrow.Parent = arrowFrame

						FrostznLife.Connect(newArrow.InputBegan,function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								cursor.Visible = true
								cursor.Position = UDim2.new(0, 9 + newArrow.Position.X.Offset, 0, 0)
							end

							if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
								updateInputs(point)
								if point == beginPoint or point == endPoint or currentlySelected then return end

								local mouseEvent, releaseEvent
								currentlySelected = true

								releaseEvent = FrostznLife.Connect(user.InputEnded,function(input)
									if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
									mouseEvent:Disconnect()
									releaseEvent:Disconnect()
									currentlySelected = nil
									cursor.Visible = false
								end)

								mouseEvent = FrostznLife.Connect(user.InputChanged,function(input)
									if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
										local maxSize = colorLine.AbsoluteSize.X - 1
										local relativeX = (input.Position.X - colorLine.AbsolutePosition.X)
										if relativeX < 0 then relativeX = 0 end
										if relativeX > maxSize then relativeX = maxSize end
										local raw = relativeX / maxSize
										point[2] = relativeX / maxSize
										updateInputs(point)
										cursor.Visible = true
										cursor.Position = UDim2.new(0, 9 + newArrow.Position.X.Offset, 0, 0)
										buildSequence()
										newMt:Redraw()
									end
								end)
							end
						end)

						FrostznLife.Connect(newArrow.InputEnded,function(input)
							if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
								cursor.Visible = false
							end
						end)



						return newArrow
					end

					local function placeArrows()
						for i,v in pairs(colors) do
							v[3] = placeArrow(math.floor((colorLine.AbsoluteSize.X-1) * v[2]) + 1,v)
						end
					end

					local function redraw(self)
						gradient.Color = newMt.Sequence or ColorSequence.new(Color3.new(1,1,1))

						for i = 2,#colors do
							local nextColor = colors[i]
							local endPos = math.floor((colorLine.AbsoluteSize.X-1) * nextColor[2]) + 1
							nextColor[3].Position = UDim2.new(0,endPos,0,0)
						end		
					end
					newMt.Redraw = redraw

					local function loadSequence(self,seq)
						resetSequence = seq
						for i,v in pairs(colors) do if v[3] then v[3]:Destroy() end end
						colors = {}
						currentlySelected = nil
						for i,v in pairs(seq.Keypoints) do
							local newPoint = {v.Value,v.Time}
							newPoint[3] = placeArrow(v.Time,newPoint)
							table.insert(colors,newPoint)
						end
						beginPoint = colors[1]
						endPoint = colors[#colors]
						currentlySelected = nil
						updateInputs(colors[1])
						buildSequence(true)
						redraw()
					end
					newMt.SetSequence = loadSequence

					local function buttonAnimations(button,inverse)
						FrostznLife.Connect(button.InputBegan,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then button.BackgroundTransparency = (inverse and 0.5 or 0.4) end end)
						FrostznLife.Connect(button.InputEnded,function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then button.BackgroundTransparency = (inverse and 1 or 0) end end)
					end

					FrostznLife.Connect(colorLine.InputBegan,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and #colors < 20 then
							local maxSize = colorLine.AbsoluteSize.X - 1
							local relativeX = (input.Position.X - colorLine.AbsolutePosition.X)
							if relativeX < 0 then relativeX = 0 end
							if relativeX > maxSize then relativeX = maxSize end

							local raw = relativeX / maxSize
							local fromColor = nil
							local toColor = nil
							for i, col in pairs(colors) do
								if col[2] >= raw then
									fromColor = colors[math.max(i - 1, 1)]
									toColor = colors[i]
									break
								end
							end
							local lerpColor = fromColor[1]:lerp(toColor[1], (raw - fromColor[2]) / (toColor[2] - fromColor[2]))
							local newPoint = {lerpColor, raw}
							newPoint[3] = placeArrow(newPoint[2], newPoint)
							table.insert(colors, newPoint)
							updateInputs(newPoint)
							buildSequence()
							redraw()
						end
					end)

					FrostznLife.Connect(colorLine.InputChanged,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							local maxSize = colorLine.AbsoluteSize.X - 1
							local relativeX = (input.Position.X - colorLine.AbsolutePosition.X)
							if relativeX < 0 then relativeX = 0 end
							if relativeX > maxSize then relativeX = maxSize end
							cursor.Visible = true
							cursor.Position = UDim2.new(0, 10 + relativeX, 0, 0)
						end
					end)

					FrostznLife.Connect(colorLine.InputEnded,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							local inArrow = false
							for i, v in pairs(colors) do
								if Lib.CheckMouseInGui(v[3]) then
									inArrow = v[3]
								end
							end
							cursor.Visible = inArrow and true or false
							if inArrow then cursor.Position = UDim2.new(0, 9 + inArrow.Position.X.Offset, 0, 0) end
						end
					end)

					FrostznLife.Connect(timeBox:GetPropertyChangedSignal("Text"),function()
						local point = currentPoint
						local num = tonumber(timeBox.Text)
						if point and num and point ~= beginPoint and point ~= endPoint then
							num = math.clamp(num,0,1)
							point[2] = num
							buildSequence()
							redraw()
						end
					end)

					FrostznLife.Connect(colorBox.InputBegan,function(input)
						if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
							local editor = newMt.ColorPicker
							if not editor then
								editor = Lib.ColorPicker.new()
								editor.Window:SetTitle("ColorSequence Color Picker")

								FrostznLife.Connect(editor.OnSelect,function(col)
									if currentPoint then
										currentPoint[1] = col
									end
									buildSequence()
									redraw()
								end)

								newMt.ColorPicker = editor
							end

							editor.Window:ShowAndFocus()
						end
					end)

					FrostznLife.Connect(deleteButton.MouseButton1Click,function()
						if currentPoint and currentPoint ~= beginPoint and currentPoint ~= endPoint then
							for i,v in pairs(colors) do
								if v == currentPoint then
									v[3]:Destroy()
									table.remove(colors,i)
									break
								end
							end
							currentlySelected = nil
							updateInputs(colors[1])
							buildSequence()
							redraw()
						end
					end)

					FrostznLife.Connect(resetButton.MouseButton1Click,function()
						if resetSequence then
							newMt:SetSequence(resetSequence)
						end
					end)

					FrostznLife.Connect(closeButton.MouseButton1Click,function()
						window:Close()
					end)

					FrostznLife.Connect(topClose.MouseButton1Click,function()
						window:Close()
					end)

					buttonAnimations(deleteButton)
					buttonAnimations(resetButton)
					buttonAnimations(closeButton)

					placeArrows()
					redraw()

					newMt.Show = function(self)
						window:Show()
					end

					return newMt
				end

				return {new = new}
			end)()

			Lib.ViewportTextBox = (function()
				local textService = service.TextService

				local props = {
					OffsetX = 0,
					TextBox = PH,
					CursorPos = -1,
					Gui = PH,
					View = PH
				}
				local funcs = {}
				funcs.Update = function(self)
					local cursorPos = self.CursorPos or -1
					local text = self.TextBox.Text
					if text == "" then self.TextBox.Position = UDim2.new(0,0,0,0) return end
					if cursorPos == -1 then return end

					local cursorText = text:sub(1,cursorPos-1)
					local pos = nil
					local leftEnd = -self.TextBox.Position.X.Offset
					local rightEnd = leftEnd + self.View.AbsoluteSize.X

					local totalTextSize = textService:GetTextSize(text,self.TextBox.TextSize,self.TextBox.Font,Vector2.new(999999999,100)).X
					local cursorTextSize = textService:GetTextSize(cursorText,self.TextBox.TextSize,self.TextBox.Font,Vector2.new(999999999,100)).X

					if cursorTextSize > rightEnd then
						pos = math.max(-1,cursorTextSize - self.View.AbsoluteSize.X + 2)
					elseif cursorTextSize < leftEnd then
						pos = math.max(-1,cursorTextSize-2)
					elseif totalTextSize < rightEnd then
						pos = math.max(-1,totalTextSize - self.View.AbsoluteSize.X + 2)
					end

					if pos then
						self.TextBox.Position = UDim2.new(0,-pos,0,0)
						self.TextBox.Size = UDim2.new(1,pos,1,0)
					end
				end

				funcs.GetText = function(self)
					return self.TextBox.Text
				end

				funcs.SetText = function(self,text)
					self.TextBox.Text = text
				end

				local mt = getGuiMT(props,funcs)

				local function convert(textbox)
					local obj = initObj(props,mt)

					local view = Instance.new("Frame")
					view.BackgroundTransparency = textbox.BackgroundTransparency
					view.BackgroundColor3 = textbox.BackgroundColor3
					view.BorderSizePixel = textbox.BorderSizePixel
					view.BorderColor3 = textbox.BorderColor3
					view.Position = textbox.Position
					view.Size = textbox.Size
					view.ClipsDescendants = true
					view.Name = textbox.Name
					textbox.BackgroundTransparency = 1
					textbox.Position = UDim2.new(0,0,0,0)
					textbox.Size = UDim2.new(1,0,1,0)
					textbox.TextXAlignment = Enum.TextXAlignment.Left
					textbox.Name = "Input"

					obj.TextBox = textbox
					obj.View = view
					obj.Gui = view

					FrostznLife.Connect(textbox.Changed,function(prop)
						if prop == "Text" or prop == "CursorPosition" or prop == "AbsoluteSize" then
							local cursorPos = obj.TextBox.CursorPosition
							if cursorPos ~= -1 then obj.CursorPos = cursorPos end
							obj:Update()
						end
					end)

					obj:Update()

					view.Parent = textbox.Parent
					textbox.Parent = view

					return obj
				end

				local function new()
					local textBox = Instance.new("TextBox")
					textBox.Size = UDim2.new(0,100,0,20)
					textBox.BackgroundColor3 = Settings.Theme.TextBox
					textBox.BorderColor3 = Settings.Theme.Outline3
					textBox.ClearTextOnFocus = false
					textBox.TextColor3 = Settings.Theme.Text
					textBox.Font = Enum.Font.SourceSans
					textBox.TextSize = 14
					textBox.Text = ""
					return convert(textBox)
				end

				return {new = new, convert = convert}
			end)()

			Lib.Label = (function()
				local props,funcs = {},{}

				local mt = getGuiMT(props,funcs)

				local function new()
					local label = Instance.new("TextLabel")
					label.BackgroundTransparency = 1
					label.TextXAlignment = Enum.TextXAlignment.Left
					label.TextColor3 = Settings.Theme.Text
					label.TextTransparency = 0.1
					label.Size = UDim2.new(0,100,0,20)
					label.Font = Enum.Font.SourceSans
					label.TextSize = 14

					local obj = setmetatable({
						Gui = label
					},mt)
					return obj
				end

				return {new = new}
			end)()

			Lib.Frame = (function()
				local props,funcs = {},{}

				local mt = getGuiMT(props,funcs)

				local function new()
					local fr = Instance.new("Frame")
					fr.BackgroundColor3 = Settings.Theme.Main1
					fr.BorderColor3 = Settings.Theme.Outline1
					fr.Size = UDim2.new(0,50,0,50)

					local obj = setmetatable({
						Gui = fr
					},mt)
					return obj
				end

				return {new = new}
			end)()

			Lib.Button = (function()
				local props = {
					Gui = PH,
					Anim = PH,
					Disabled = false,
					OnClick = SIGNAL,
					OnDown = SIGNAL,
					OnUp = SIGNAL,
					AllowedButtons = {1}
				}
				local funcs = {}
				local tableFind = table.find

				funcs.Trigger = function(self,event,button)
					if not self.Disabled and tableFind(self.AllowedButtons,button) then
						self["On"..event]:Fire(button)
					end
				end

				funcs.SetDisabled = function(self,dis)
					self.Disabled = dis

					if dis then
						self.Anim:Disable()
						self.Gui.TextTransparency = 0.5
					else
						self.Anim.Enable()
						self.Gui.TextTransparency = 0
					end
				end

				local mt = getGuiMT(props,funcs)

				local function new()
					local b = Instance.new("TextButton")
					b.AutoButtonColor = false
					b.TextColor3 = Settings.Theme.Text
					b.TextTransparency = 0.1
					b.Size = UDim2.new(0,100,0,20)
					b.Font = Enum.Font.SourceSans
					b.TextSize = 14
					b.BackgroundColor3 = Settings.Theme.Button
					b.BorderColor3 = Settings.Theme.Outline2

					local obj = initObj(props,mt)
					obj.Gui = b
					obj.Anim = Lib.ButtonAnim(b,{Mode = 2, StartColor = Settings.Theme.Button, HoverColor = Settings.Theme.ButtonHover, PressColor = Settings.Theme.ButtonPress, OutlineColor = Settings.Theme.Outline2})

					FrostznLife.Connect(b.MouseButton1Click,function() obj:Trigger("Click",1) end)
					FrostznLife.Connect(b.MouseButton1Down,function() obj:Trigger("Down",1) end)
					FrostznLife.Connect(b.MouseButton1Up,function() obj:Trigger("Up",1) end)

					FrostznLife.Connect(b.MouseButton2Click,function() obj:Trigger("Click",2) end)
					FrostznLife.Connect(b.MouseButton2Down,function() obj:Trigger("Down",2) end)
					FrostznLife.Connect(b.MouseButton2Up,function() obj:Trigger("Up",2) end)

					return obj
				end

				return {new = new}
			end)()

			Lib.DropDown = (function()
				local props = {
					Gui = PH,
					Anim = PH,
					Context = PH,
					Selected = PH,
					Disabled = false,
					CanBeEmpty = true,
					Options = {},
					GuiElems = {},
					OnSelect = SIGNAL
				}
				local funcs = {}

				funcs.Update = function(self)
					local options = self.Options

					if #options > 0 then
						if not self.Selected then
							if not self.CanBeEmpty then
								self.Selected = options[1]
								self.GuiElems.Label.Text = options[1]
							else
								self.GuiElems.Label.Text = "- Select -"
							end
						else
							self.GuiElems.Label.Text = self.Selected
						end
					else
						self.GuiElems.Label.Text = "- Select -"
					end
				end

				funcs.ShowOptions = function(self)
					local context = self.Context

					context.Width = self.Gui.AbsoluteSize.X
					context.ReverseYOffset = self.Gui.AbsoluteSize.Y
					context:Show(self.Gui.AbsolutePosition.X, self.Gui.AbsolutePosition.Y + context.ReverseYOffset)
				end

				funcs.SetOptions = function(self,opts)
					self.Options = opts

					local context = self.Context
					local options = self.Options
					context:Clear()

					local onClick = function(option) self.Selected = option self.OnSelect:Fire(option) self:Update() end

					if self.CanBeEmpty then
						context:Add({Name = "- Select -", function() self.Selected = nil self.OnSelect:Fire(nil) self:Update() end})
					end

					for i = 1,#options do
						context:Add({Name = options[i], OnClick = onClick})
					end

					self:Update()
				end

				funcs.SetSelected = function(self,opt)
					self.Selected = type(opt) == "number" and self.Options[opt] or opt
					self:Update()
				end

				local mt = getGuiMT(props,funcs)

				local function new()
					local f = Instance.new("TextButton")
					f.AutoButtonColor = false
					f.Text = ""
					f.Size = UDim2.new(0,100,0,20)
					f.BackgroundColor3 = Settings.Theme.TextBox
					f.BorderColor3 = Settings.Theme.Outline3

					local label = Lib.Label.new()
					label.Position = UDim2.new(0,2,0,0)
					label.Size = UDim2.new(1,-22,1,0)
					label.TextTruncate = Enum.TextTruncate.AtEnd
					label.Parent = f
					local arrow = create({
						{1,"Frame",{BackgroundTransparency=1,Name="EnumArrow",Position=UDim2.new(1,-16,0,2),Size=UDim2.new(0,16,0,16),}},
						{2,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={1},Position=UDim2.new(0,8,0,9),Size=UDim2.new(0,1,0,1),}},
						{3,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={1},Position=UDim2.new(0,7,0,8),Size=UDim2.new(0,3,0,1),}},
						{4,"Frame",{BackgroundColor3=Color3.new(0.86274510622025,0.86274510622025,0.86274510622025),BorderSizePixel=0,Parent={1},Position=UDim2.new(0,6,0,7),Size=UDim2.new(0,5,0,1),}},
					})
					arrow.Parent = f

					local obj = initObj(props,mt)
					obj.Gui = f
					obj.Anim = Lib.ButtonAnim(f,{Mode = 2, StartColor = Settings.Theme.TextBox, LerpTo = Settings.Theme.Button, LerpDelta = 0.15})
					obj.Context = Lib.ContextMenu.new()
					obj.Context.Iconless = true
					obj.Context.MaxHeight = 200
					obj.Selected = nil
					obj.GuiElems = {Label = label}
					FrostznLife.Connect(f.MouseButton1Down,function() obj:ShowOptions() end)
					obj:Update()
					return obj
				end

				return {new = new}
			end)()

			Lib.ClickSystem = (function()
				local props = {
					LastItem = PH,
					OnDown = SIGNAL,
					OnRelease = SIGNAL,
					AllowedButtons = {1},
					Combo = 0,
					MaxCombo = 2,
					ComboTime = 0.5,
					Items = {},
					ItemCons = {},
					ClickId = -1,
					LastButton = ""
				}
				local funcs = {}
				local tostring = tostring

				local disconnect = function(con)
					local pos = table.find(con.Signal.Connections,con)
					if pos then table.remove(con.Signal.Connections,pos) end
				end

				funcs.Trigger = function(self, item, button, X, Y)
					if table.find(self.AllowedButtons, button) then
						if self.LastButton ~= button or self.LastItem ~= item or self.Combo == self.MaxCombo or tick() - self.ClickId > self.ComboTime then
							self.Combo = 0
							self.LastButton = button
							self.LastItem = item
						end

						self.Combo = self.Combo + 1
						self.ClickId = tick()

						FrostznLife.Spawn(function()
							if self.InputDown then
								self.InputDown = false
							else
								self.InputDown = tick()

								local Connection = item.MouseButton1Up:Once(function()
									self.InputDown = false
								end)

								while self.InputDown and not Explorer.Dragging do
									if (tick() - self.InputDown) >= 0.4 then
										self.InputDown = false
										self["OnRelease"]:Fire(item, self.Combo, 2, Vector2.new(X, Y))
										break
									end;task.wait()
								end
							end
						end)

						local release
						release = FrostznLife.Connect(service.UserInputService.InputEnded,function(input)
							if input.UserInputType == Enum.UserInputType["MouseButton" .. button] then
								release:Disconnect()
								if Lib.CheckMouseInGui(item) and self.LastButton == button and self.LastItem == item then
									self["OnRelease"]:Fire(item,self.Combo,button)
								end
							end
						end)

						self["OnDown"]:Fire(item,self.Combo,button)
					end
				end

				funcs.Add = function(self,item)
					if table.find(self.Items,item) then return end

					local cons = {}
					cons[1] = FrostznLife.Connect(item.MouseButton1Down,function(X, Y) self:Trigger(item, 1, X, Y) end)
					cons[2] = FrostznLife.Connect(item.MouseButton2Down,function(X, Y) self:Trigger(item, 2, X, Y) end)

					self.ItemCons[item] = cons
					self.Items[#self.Items+1] = item
				end

				funcs.Remove = function(self,item)
					local ind = table.find(self.Items,item)
					if not ind then return end

					for i,v in pairs(self.ItemCons[item]) do
						v:Disconnect()
					end
					self.ItemCons[item] = nil
					table.remove(self.Items,ind)
				end

				local mt = {__index = funcs}

				local function new()
					local obj = initObj(props,mt)

					return obj
				end

				return {new = new}
			end)()

			return Lib
		end

		return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
	end,
	Console = function()
--[[
	Console Module
]]
		-- Common Locals
		local Main,Lib,Apps,Settings -- Main Containers
		local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
		local API,RMD,env,service,plr,create,createSimple -- Main Locals

		local function initDeps(data)
			Main = data.Main
			Lib = data.Lib
			Apps = data.Apps
			Settings = data.Settings

			API = data.API
			RMD = data.RMD
			env = data.env
			service = data.service
			plr = data.plr
			create = data.create
			createSimple = data.createSimple
		end

		local function initAfterMain()
			Explorer = Apps.Explorer
			Properties = Apps.Properties
			ScriptViewer = Apps.ScriptViewer
			Notebook = Apps.Notebook
		end

		local function main()
			local Console = {}

			local window,ConsoleFrame

			local OutputLimit = 500 -- Same as Roblox Console.


			-- Instances: 29 | Scripts: 1 | Modules: 1 | Tags: 0
			local G2L = {};

			-- StarterGui.ScreenGui
			window = Lib.Window.new()
			window:SetTitle("Console")
			window:Resize(500,400)
			Console.Window = window

			-- StarterGui.ScreenGui.Console
			ConsoleFrame = Instance.new("ImageButton", window.GuiElems.Content);
			ConsoleFrame["BorderSizePixel"] = 0;
			ConsoleFrame["AutoButtonColor"] = false;
			ConsoleFrame["BackgroundTransparency"] = 1;
			ConsoleFrame["BackgroundColor3"] = Color3.fromRGB(47, 47, 47);
			ConsoleFrame["Selectable"] = false;
			ConsoleFrame["Size"] = UDim2.new(1,0,1,0);
			ConsoleFrame["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			ConsoleFrame["Name"] = [[Console]];
			ConsoleFrame["Position"] = UDim2.new(0,0,0,0);


			-- StarterGui.ScreenGui.Console.CommandLine
			G2L["3"] = Lib.Frame.new().Gui--Instance.new("Frame", ConsoleFrame);
			G2L["3"].Parent = ConsoleFrame
			G2L["3"]["BorderSizePixel"] = 0;
			G2L["3"]["BackgroundColor3"] = Color3.fromRGB(37, 37, 37);
			G2L["3"]["AnchorPoint"] = Vector2.new(0.5, 1);
			G2L["3"]["ClipsDescendants"] = true;
			G2L["3"]["Size"] = UDim2.new(1, -8, 0, 22);
			G2L["3"]["Position"] = UDim2.new(0.5, 0, 1, -5);
			G2L["3"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["3"]["Name"] = [[CommandLine]];


			-- StarterGui.ScreenGui.Console.CommandLine.UIStroke
			G2L["4"] = Instance.new("UIStroke", G2L["3"]);
			G2L["4"]["Transparency"] = 0.65;
			G2L["4"]["Thickness"] = 1.25;


			-- StarterGui.ScreenGui.Console.CommandLine.ScrollingFrame
			G2L["5"] = Instance.new("ScrollingFrame", G2L["3"]);
			G2L["5"]["Active"] = true;
			G2L["5"]["ScrollingDirection"] = Enum.ScrollingDirection.X;
			G2L["5"]["BorderSizePixel"] = 0;
			G2L["5"]["CanvasSize"] = UDim2.new(0, 0, 0, 0);
			G2L["5"]["ElasticBehavior"] = Enum.ElasticBehavior.Never;
			G2L["5"]["TopImage"] = [[rbxasset://textures/ui/Scroll/scroll-middle.png]];
			G2L["5"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["5"]["HorizontalScrollBarInset"] = Enum.ScrollBarInset.Always;
			G2L["5"]["BottomImage"] = [[rbxasset://textures/ui/Scroll/scroll-middle.png]];
			G2L["5"]["AutomaticCanvasSize"] = Enum.AutomaticSize.X;
			G2L["5"]["Size"] = UDim2.new(1, 0, 1, 0);
			G2L["5"]["ScrollBarImageColor3"] = Color3.fromRGB(57, 57, 57);
			G2L["5"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["5"]["ScrollBarThickness"] = 2;
			G2L["5"]["BackgroundTransparency"] = 1;

			-- StarterGui.ScreenGui.Console.CommandLine.ScrollingFrame.TextBox
			G2L["6"] = Instance.new("TextBox", G2L["5"]);
			G2L["6"]["CursorPosition"] = -1;
			G2L["6"]["TextXAlignment"] = Enum.TextXAlignment.Left;
			G2L["6"]["PlaceholderColor3"] = Color3.fromRGB(211, 211, 211);
			G2L["6"]["BorderSizePixel"] = 0;
			G2L["6"]["TextSize"] = 13;
			G2L["6"]["TextColor3"] = Color3.fromRGB(211, 211, 211);
			G2L["6"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["6"]["FontFace"] = Font.new([[rbxasset://fonts/families/Inconsolata.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
			G2L["6"]["AutomaticSize"] = Enum.AutomaticSize.X;
			G2L["6"]["ClearTextOnFocus"] = false;
			G2L["6"]["PlaceholderText"] = [[Run a command]];
			G2L["6"]["Size"] = UDim2.new(0, 246, 0, 22);
			G2L["6"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["6"]["Text"] = [[]];
			G2L["6"]["BackgroundTransparency"] = 1;


			-- StarterGui.ScreenGui.Console.CommandLine.ScrollingFrame.TextBox.UIPadding
			G2L["7"] = Instance.new("UIPadding", G2L["6"]);
			G2L["7"]["PaddingLeft"] = UDim.new(0, 7);


			-- StarterGui.ScreenGui.Console.CommandLine.ScrollingFrame.Highlight
			G2L["8"] = Instance.new("TextLabel", G2L["5"]);
			G2L["8"]["Interactable"] = false;
			G2L["8"]["ZIndex"] = 2;
			G2L["8"]["BorderSizePixel"] = 0;
			G2L["8"]["TextSize"] = 13;
			G2L["8"]["TextXAlignment"] = Enum.TextXAlignment.Left;
			G2L["8"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["8"]["FontFace"] = Font.new([[rbxasset://fonts/families/Inconsolata.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
			G2L["8"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["8"]["BackgroundTransparency"] = 1;
			G2L["8"]["RichText"] = true;
			G2L["8"]["Size"] = UDim2.new(0, 246, 0, 22);
			G2L["8"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["8"]["Text"] = [[]];
			G2L["8"]["Selectable"] = true;
			G2L["8"]["AutomaticSize"] = Enum.AutomaticSize.X;
			G2L["8"]["Name"] = [[Highlight]];


			-- StarterGui.ScreenGui.Console.CommandLine.ScrollingFrame.Highlight.UIPadding
			G2L["9"] = Instance.new("UIPadding", G2L["8"]);
			G2L["9"]["PaddingLeft"] = UDim.new(0, 7);

			G2L["backgroundOutput"] = Instance.new("Frame", ConsoleFrame);
			G2L["backgroundOutput"]["BorderSizePixel"] = 0;
			G2L["backgroundOutput"]["BackgroundColor3"] = Color3.fromRGB(36, 36, 36);
			G2L["backgroundOutput"]["Name"] = [[BackgroundOutput]];
			G2L["backgroundOutput"]["AnchorPoint"] = Vector2.new(0, 0);
			G2L["backgroundOutput"]["Size"] = UDim2.new(1, -8, 1, -55);
			G2L["backgroundOutput"]["Position"] = UDim2.new(0, 4, 0, 23);
			G2L["backgroundOutput"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["backgroundOutput"]["ZIndex"] = 1;

			local scrollbar = Lib.ScrollBar.new()
			scrollbar.Gui.Parent = ConsoleFrame
			scrollbar.Gui.Size = UDim2.new(0, 16, 1, -55);
			scrollbar.Gui.Position = UDim2.new(1, -20,0, 23);
			scrollbar.Gui.Up.ZIndex = 3
			scrollbar.Gui.Down.ZIndex = 3

			-- StarterGui.ScreenGui.Console.Output
			G2L["a"] = Instance.new("ScrollingFrame", ConsoleFrame);
			G2L["a"]["Active"] = true;
			G2L["a"]["BorderSizePixel"] = 0;
			G2L["a"]["CanvasSize"] = UDim2.new(0, 0, 0, 0);
			G2L["a"]["TopImage"] = '';
			G2L["a"]["BackgroundColor3"] = Color3.fromRGB(36, 36, 36);
			G2L["a"].BackgroundTransparency = 1
			G2L["a"]["Name"] = [[Output]];
			G2L["a"]["ScrollBarImageTransparency"] = 0;
			G2L["a"]["BottomImage"] = '';
			G2L["a"]["AnchorPoint"] = Vector2.new(0, 0);
			G2L["a"]["AutomaticCanvasSize"] = Enum.AutomaticSize.Y;
			G2L["a"]["Size"] = UDim2.new(1, -8, 1, -55);
			G2L["a"]["Position"] = UDim2.new(0, 4, 0, 23);
			G2L["a"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["a"].ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
			G2L["a"]["ScrollBarThickness"] = 16;
			G2L["a"]["ZIndex"] = 1;

			FrostznLife.Connect(G2L["a"]:GetPropertyChangedSignal("AbsoluteWindowSize"),function()
				if G2L["a"].AbsoluteCanvasSize ~= G2L["a"].AbsoluteWindowSize then
					scrollbar.Gui.Visible = true
				else
					scrollbar.Gui.Visible = false
				end
			end)

			-- StarterGui.ScreenGui.Console.Output.UIListLayout
			G2L["b"] = Instance.new("UIListLayout", G2L["a"]);
			G2L["b"]["SortOrder"] = Enum.SortOrder.LayoutOrder;


			-- StarterGui.ScreenGui.Console.Output.UIStroke
			G2L["c"] = Instance.new("UIStroke", G2L["a"]);
			G2L["c"]["Transparency"] = 0.7;
			G2L["c"]["Thickness"] = 1.25;
			G2L["c"]["Color"] = Color3.fromRGB(12, 12, 12);


			-- StarterGui.ScreenGui.Console.Output.OutputTextSize
			G2L["d"] = Instance.new("NumberValue", G2L["a"]);
			G2L["d"]["Name"] = [[OutputTextSize]];
			G2L["d"]["Value"] = 15;


			-- StarterGui.ScreenGui.Console.Output.OutputLimit
			G2L["e"] = Instance.new("NumberValue", G2L["a"]);
			G2L["e"]["Name"] = [[OutputLimit]];
			G2L["e"]["Value"] = OutputLimit;


			-- StarterGui.ScreenGui.Console.Output.UIPadding
			G2L["f"] = Instance.new("UIPadding", G2L["a"]);
			G2L["f"]["PaddingTop"] = UDim.new(0, 2);


			-- StarterGui.ScreenGui.Console.TextSizeBox
			G2L["10"] = Instance.new("Frame", ConsoleFrame);
			G2L["10"]["BorderSizePixel"] = 0;
			G2L["10"]["BackgroundColor3"] = Color3.fromRGB(37, 37, 37);
			G2L["10"]["ClipsDescendants"] = true;
			G2L["10"]["Size"] = UDim2.new(0, 37, 0, 15);
			G2L["10"]["Position"] = UDim2.new(0, 4, 0, 4);
			G2L["10"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["10"]["Name"] = [[TextSizeBox]];


			-- StarterGui.ScreenGui.Console.TextSizeBox.TextBox
			G2L["11"] = Instance.new("TextBox", G2L["10"]);
			G2L["11"]["PlaceholderColor3"] = Color3.fromRGB(108, 108, 108);
			G2L["11"]["BorderSizePixel"] = 0;
			G2L["11"]["TextWrapped"] = true;
			G2L["11"]["TextSize"] = 15;
			G2L["11"]["TextColor3"] = Color3.fromRGB(211, 211, 211);
			G2L["11"]["TextScaled"] = true;
			G2L["11"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["11"]["FontFace"] = Font.new([[rbxasset://fonts/families/Inconsolata.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
			G2L["11"]["PlaceholderText"] = [[Size]];
			G2L["11"]["Size"] = UDim2.new(1, 0, 1, 0);
			G2L["11"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["11"]["Text"] = [[]];
			G2L["11"]["BackgroundTransparency"] = 1;


			-- StarterGui.ScreenGui.Console.TextSizeBox.TextBox.UIPadding
			G2L["12"] = Instance.new("UIPadding", G2L["11"]);
			G2L["12"]["PaddingTop"] = UDim.new(0, 2);
			G2L["12"]["PaddingRight"] = UDim.new(0, 5);
			G2L["12"]["PaddingLeft"] = UDim.new(0, 5);
			G2L["12"]["PaddingBottom"] = UDim.new(0, 2);


			-- StarterGui.ScreenGui.Console.TextSizeBox.UIStroke
			G2L["13"] = Instance.new("UIStroke", G2L["10"]);
			G2L["13"]["Transparency"] = 0.65;
			G2L["13"]["Thickness"] = 1.25;


			-- StarterGui.ScreenGui.Console.Clear
			G2L["14"] = Instance.new("ImageButton", ConsoleFrame);
			G2L["14"]["BorderSizePixel"] = 0;
			G2L["14"]["BackgroundColor3"] = Color3.fromRGB(57, 57, 57);
			G2L["14"]["Size"] = UDim2.new(0, 37, 0, 15);
			G2L["14"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["14"]["Name"] = [[Clear]];
			G2L["14"]["Position"] = UDim2.new(1, -42, 0, 4);


			-- StarterGui.ScreenGui.Console.Clear.TextLabel
			G2L["15"] = Instance.new("TextLabel", G2L["14"]);
			G2L["15"]["TextWrapped"] = true;
			G2L["15"]["Interactable"] = false;
			G2L["15"]["BorderSizePixel"] = 0;
			G2L["15"]["TextSize"] = 20;
			G2L["15"]["TextScaled"] = true;
			G2L["15"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["15"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
			G2L["15"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["15"]["BackgroundTransparency"] = 1;
			G2L["15"]["Size"] = UDim2.new(1, 0, 1, 0);
			G2L["15"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["15"]["Text"] = [[Clear]];


			-- StarterGui.ScreenGui.Console.Clear.UIPadding
			G2L["16"] = Instance.new("UIPadding", G2L["14"]);
			G2L["16"]["PaddingTop"] = UDim.new(0, 1);
			G2L["16"]["PaddingBottom"] = UDim.new(0, 1);


			-- StarterGui.ScreenGui.Console.OutputTemplate
			G2L["17"] = Instance.new("TextBox", ConsoleFrame);
			G2L["17"]["Visible"] = false;
			G2L["17"]["Active"] = false;
			G2L["17"]["Name"] = [[OutputTemplate]];
			G2L["17"]["TextXAlignment"] = Enum.TextXAlignment.Left;
			G2L["17"]["BorderSizePixel"] = 0;
			G2L["17"]["TextEditable"] = false;
			G2L["17"]["TextWrapped"] = true;
			G2L["17"]["TextSize"] = 15;
			G2L["17"]["TextColor3"] = Color3.fromRGB(171, 171, 171);
			G2L["17"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["17"]["RichText"] = true;
			G2L["17"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
			G2L["17"]["AutomaticSize"] = Enum.AutomaticSize.Y;
			G2L["17"]["Selectable"] = false;
			G2L["17"]["ClearTextOnFocus"] = false;
			G2L["17"]["Size"] = UDim2.new(1, 0, 0, 1);
			G2L["17"]["Position"] = UDim2.new(0, 20, 0, 0);
			G2L["17"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["17"]["Text"] = [[(timestamp) <font color="rgb(255, 255, 255)">Output</font>]];
			G2L["17"]["BackgroundTransparency"] = 1;


			-- StarterGui.ScreenGui.Console.OutputTemplate.UIPadding
			G2L["18"] = Instance.new("UIPadding", G2L["17"]);
			G2L["18"]["PaddingRight"] = UDim.new(0, 6);
			G2L["18"]["PaddingLeft"] = UDim.new(0, 6);


			-- StarterGui.ScreenGui.Console.CtrlScroll
			G2L["19"] = Instance.new("ImageButton", ConsoleFrame);
			G2L["19"]["BorderSizePixel"] = 0;
			G2L["19"]["BackgroundColor3"] = Color3.fromRGB(57, 57, 57);
			G2L["19"]["Size"] = UDim2.new(0, 60, 0, 15);
			G2L["19"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["19"]["Name"] = [[CtrlScroll]];
			G2L["19"]["Position"] = UDim2.new(0, 46, 0, 4);


			-- StarterGui.ScreenGui.Console.CtrlScroll.TextLabel
			G2L["1a"] = Instance.new("TextLabel", G2L["19"]);
			G2L["1a"]["TextWrapped"] = true;
			G2L["1a"]["Interactable"] = false;
			G2L["1a"]["BorderSizePixel"] = 0;
			G2L["1a"]["TextSize"] = 20;
			G2L["1a"]["TextScaled"] = true;
			G2L["1a"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["1a"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
			G2L["1a"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["1a"]["BackgroundTransparency"] = 1;
			G2L["1a"]["Size"] = UDim2.new(1, 0, 1, 0);
			G2L["1a"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["1a"]["Text"] = [[Ctrl Scroll]];


			-- StarterGui.ScreenGui.Console.CtrlScroll.UIPadding
			G2L["1b"] = Instance.new("UIPadding", G2L["19"]);
			G2L["1b"]["PaddingTop"] = UDim.new(0, 1);
			G2L["1b"]["PaddingBottom"] = UDim.new(0, 1);

			-- StarterGui.ScreenGui.Console.AutoScroll
			G2L["20"] = Instance.new("ImageButton", ConsoleFrame);
			G2L["20"]["BorderSizePixel"] = 0;
			G2L["20"]["BackgroundColor3"] = Color3.fromRGB(57, 57, 57);
			G2L["20"]["Size"] = UDim2.new(0, 60, 0, 15);
			G2L["20"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["20"]["Name"] = [[AutoScroll]];
			G2L["20"]["Position"] = UDim2.new(0, 110, 0, 4);


			-- StarterGui.ScreenGui.Console.AutoScroll.TextLabel
			G2L["1e"] = Instance.new("TextLabel", G2L["20"]);
			G2L["1e"]["TextWrapped"] = true;
			G2L["1e"]["Interactable"] = false;
			G2L["1e"]["BorderSizePixel"] = 0;
			G2L["1e"]["TextSize"] = 20;
			G2L["1e"]["TextScaled"] = true;
			G2L["1e"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["1e"]["FontFace"] = Font.new([[rbxasset://fonts/families/SourceSansPro.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
			G2L["1e"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
			G2L["1e"]["BackgroundTransparency"] = 1;
			G2L["1e"]["Size"] = UDim2.new(1, 0, 1, 0);
			G2L["1e"]["BorderColor3"] = Color3.fromRGB(0, 0, 0);
			G2L["1e"]["Text"] = [[Auto Scroll]];


			-- StarterGui.ScreenGui.Console.AutoScroll.UIPadding
			G2L["1f"] = Instance.new("UIPadding", G2L["20"]);
			G2L["1f"]["PaddingTop"] = UDim.new(0, 1);
			G2L["1f"]["PaddingBottom"] = UDim.new(0, 1);


			-- StarterGui.ScreenGui.ConsoleHandler
			G2L["1c"] = Instance.new("LocalScript", G2L["1"]);
			G2L["1c"]["Name"] = [[ConsoleHandler]];


			-- StarterGui.ScreenGui.ConsoleHandler.SyntaxHighlighter
			G2L["1d"] = Instance.new("ModuleScript", G2L["1c"]);
			G2L["1d"]["Name"] = [[SyntaxHighlighter]];


			-- Require G2L wrapper
			local G2L_REQUIRE = require;
			local G2L_MODULES = {};
			local function require(Module)
				local ModuleState = G2L_MODULES[Module];
				if ModuleState then
					if not ModuleState.Required then
						ModuleState.Required = true;
						ModuleState.Value = ModuleState.Closure();
					end
					return ModuleState.Value;
				end;
				return G2L_REQUIRE(Module);
			end

			G2L_MODULES[G2L["1d"]] = {
				Closure = function()
					local script = G2L["1d"];local highlighter = {}
					local keywords = {
						lua = {
							"and", "break", "or", "else", "elseif", "if", "then", "until", "repeat", "while", "do", "for", "in", "end",
							"local", "return", "function", "export"
						},
						rbx = {
							"game", "workspace", "script", "math", "string", "table", "task", "wait", "select", "next", "Enum",
							"error", "warn", "tick", "assert", "shared", "loadstring", "tonumber", "tostring", "type",
							"typeof", "unpack", "print", "Instance", "CFrame", "Vector3", "Vector2", "Color3", "UDim", "UDim2", "Ray", "BrickColor",
							"OverlapParams", "RaycastParams", "Axes", "Random", "Region3", "Rect", "TweenInfo",
							"collectgarbage", "not", "utf8", "pcall", "xpcall", "_G", "setmetatable", "getmetatable", "os", "pairs", "ipairs"
						},
						exploit = {
							"hookmetamethod", "hookfunction", "getgc", "filtergc", "Drawing", "getgenv", "getsenv", "getrenv", "getfenv", "setfenv",
							"decompile", "saveinstance", "getrawmetatable", "setrawmetatable", "checkcaller", "cloneref", "clonefunction",
							"iscclosure", "islclosure", "isexecutorclosure", "newcclosure", "getfunctionhash", "crypt", "writefile", "appendfile", "loadfile", "readfile", "listfiles",
							"makefolder", "isfolder", "isfile", "delfile", "delfolder", "getcustomasset", "fireclickdetector", "firetouchinterest", "fireproximityprompt"
						},
						operators = {
							"#", "+", "-", "*", "%", "/", "^", "=", "~", "=", "<", ">", ",", ".", "(", ")", "{", "}", "[", "]", ";", ":"
						}
					}

					local colors = {
						numbers = Color3.fromRGB(255, 198, 0),
						boolean = Color3.fromRGB(255, 198, 0),
						operator = Color3.fromRGB(204, 204, 204),
						lua = Color3.fromRGB(132, 214, 247),
						exploit = Color3.fromRGB(171, 84, 247),
						rbx = Color3.fromRGB(248, 109, 124),
						str = Color3.fromRGB(173, 241, 132),
						comment = Color3.fromRGB(102, 102, 102),
						null = Color3.fromRGB(255, 198, 0),
						call = Color3.fromRGB(253, 251, 172),
						self_call = Color3.fromRGB(253, 251, 172),
						local_color = Color3.fromRGB(248, 109, 115),
						function_color = Color3.fromRGB(248, 109, 115),
						self_color = Color3.fromRGB(248, 109, 115),
						local_property = Color3.fromRGB(97, 161, 241),
					}

					local function createKeywordSet(keywords)
						local keywordSet = {}
						for _, keyword in ipairs(keywords) do
							keywordSet[keyword] = true
						end
						return keywordSet
					end

					local luaSet = createKeywordSet(keywords.lua)
					local exploitSet = createKeywordSet(keywords.exploit)
					local rbxSet = createKeywordSet(keywords.rbx)
					local operatorsSet = createKeywordSet(keywords.operators)

					local function getHighlight(tokens, index)
						local token = tokens[index]

						if colors[token .. "_color"] then
							return colors[token .. "_color"]
						end

						if tonumber(token) then
							return colors.numbers
						elseif token == "nil" then
							return colors.null
						elseif token:sub(1, 2) == "--" then
							return colors.comment
						elseif operatorsSet[token] then
							return colors.operator
						elseif luaSet[token] then
							return colors.rbx
						elseif rbxSet[token] then
							return colors.lua
						elseif exploitSet[token] then
							return colors.exploit
						elseif token:sub(1, 1) == "\"" or token:sub(1, 1) == "\'" then
							return colors.str
						elseif token == "true" or token == "false" then
							return colors.boolean
						end

						if tokens[index + 1] == "(" then
							if tokens[index - 1] == ":" then
								return colors.self_call
							end

							return colors.call
						end

						if tokens[index - 1] == "." then
							if tokens[index - 2] == "Enum" then
								return colors.rbx
							end

							return colors.local_property
						end
					end

					function highlighter.run(source)
						local tokens = {}
						local currentToken = ""

						local inString = false
						local inComment = false
						local commentPersist = false

						for i = 1, #source do
							local character = source:sub(i, i)

							if inComment then
								if character == "\n" and not commentPersist then
									table.insert(tokens, currentToken)
									table.insert(tokens, character)
									currentToken = ""

									inComment = false
								elseif source:sub(i - 1, i) == "]]" and commentPersist then
									currentToken ..= "]"

									table.insert(tokens, currentToken)
									currentToken = ""

									inComment = false
									commentPersist = false
								else
									currentToken = currentToken .. character
								end
							elseif inString then
								if character == inString and source:sub(i-1, i-1) ~= "\\" or character == "\n" then
									currentToken = currentToken .. character
									inString = false
								else
									currentToken = currentToken .. character
								end
							else
								if source:sub(i, i + 1) == "--" then
									table.insert(tokens, currentToken)
									currentToken = "-"
									inComment = true
									commentPersist = source:sub(i + 2, i + 3) == "[["
								elseif character == "\"" or character == "\'" then
									table.insert(tokens, currentToken)
									currentToken = character
									inString = character
								elseif operatorsSet[character] then
									table.insert(tokens, currentToken)
									table.insert(tokens, character)
									currentToken = ""
								elseif character:match("[%w_]") then
									currentToken = currentToken .. character
								else
									table.insert(tokens, currentToken)
									table.insert(tokens, character)
									currentToken = ""
								end
							end
						end

						table.insert(tokens, currentToken)

						local highlighted = {}

						for i, token in ipairs(tokens) do
							local highlight = getHighlight(tokens, i)

							if highlight then
								local syntax = string.format("<font color = \"#%s\">%s</font>", highlight:ToHex(), token:gsub("<", "&lt;"):gsub(">", "&gt;"))

								table.insert(highlighted, syntax)
							else
								table.insert(highlighted, token)
							end
						end

						return table.concat(highlighted)
					end

					return highlighter
				end;
			};

			Console.Init = function()
				-- StarterGui.ScreenGui.ConsoleHandler

				local CtrlScroll = false
				local AutoScroll = false

				local LogService = game:GetService("LogService")
				local Players = game:GetService("Players")
				local LocalPlayer = Players.LocalPlayer
				local Mouse = LocalPlayer:GetMouse()
				local UserInputService = game:GetService("UserInputService")
				local RunService = game:GetService("RunService")

				local Console = ConsoleFrame
				local SyntaxHighlightingModule = require(G2L["1c"].SyntaxHighlighter)
				local OutputTextSize = Console.Output.OutputTextSize

				local function Tween(obj, info, prop)
					local tween = game:GetService("TweenService"):Create(obj, info, prop)
					tween:Play()
					return tween
				end



				-- MOUSE STUFFS

				if CtrlScroll == true then
					Console.CtrlScroll.BackgroundColor3 = Color3.fromRGB(11, 90, 175)
				elseif CtrlScroll == false then
					Console.CtrlScroll.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
				end
				FrostznLife.Connect(Console.CtrlScroll.MouseButton1Click,function()
					CtrlScroll = not CtrlScroll
					if CtrlScroll == true then
						Console.CtrlScroll.BackgroundColor3 = Color3.fromRGB(11, 90, 175)
					elseif CtrlScroll == false then
						Console.CtrlScroll.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
					end
				end)

				local IsHoldingCTRL = false
				FrostznLife.Connect(UserInputService.InputBegan,function(input, gameproc)
					if not gameproc then
						if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
							IsHoldingCTRL = true
						end
					end
				end)
				FrostznLife.Connect(UserInputService.InputEnded,function(input, gameproc)
					if not gameproc then
						if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
							IsHoldingCTRL = false
						end
					end
				end)

				if AutoScroll == true then
					Console.AutoScroll.BackgroundColor3 = Color3.fromRGB(11, 90, 175)
				elseif AutoScroll == false then
					Console.AutoScroll.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
				end
				FrostznLife.Connect(Console.AutoScroll.MouseButton1Click,function()
					AutoScroll = not AutoScroll
					if AutoScroll == true then
						Console.AutoScroll.BackgroundColor3 = Color3.fromRGB(11, 90, 175)
						Console.Output.CanvasPosition = Vector2.new(0, 9e9)
					elseif AutoScroll == false then
						Console.AutoScroll.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
					end
				end)

				-- Console part
				local displayedOutput = {}
				local OutputLimit = Console.Output.OutputLimit

				Console.TextSizeBox.TextBox.Text = tostring(OutputTextSize.Value)

				FrostznLife.Connect(Console.TextSizeBox.TextBox:GetPropertyChangedSignal("Text"),function()
					local tonum = tonumber(Console.TextSizeBox.TextBox.Text)
					if tonum then
						OutputTextSize.Value = tonum
					end
				end)
				FrostznLife.Connect(OutputTextSize:GetPropertyChangedSignal("Value"),function()
					Console.TextSizeBox.TextBox.Text = tostring(OutputTextSize.Value)
				end)

				local scrollConsoleInput
				FrostznLife.Connect(Console.Output.MouseEnter,function()
					scrollConsoleInput = FrostznLife.Connect(UserInputService.InputChanged,function(input)
						if CtrlScroll and input.UserInputType == Enum.UserInputType.MouseWheel and IsHoldingCTRL == true then
							Console.Output.ScrollingEnabled = false
							local newTextSize = OutputTextSize.Value + input.Position.Z
							if newTextSize >= 1 then
								OutputTextSize.Value = newTextSize
							end
						else
							Console.Output.ScrollingEnabled = true
						end
					end)
				end)
				FrostznLife.Connect(Console.Output.MouseLeave,function()
					if scrollConsoleInput then
						scrollConsoleInput:Disconnect()
						scrollConsoleInput = nil
					end
				end)


				FrostznLife.Connect(Console.Clear.MouseButton1Click,function()
					for _, log in pairs(Console.Output:GetChildren()) do
						if log:IsA("TextBox") then
							log:Destroy()
						end
					end
				end)

				local focussedOutput

				FrostznLife.Connect(LogService.MessageOut,function(msg, msgtype)
					local formattedText = ""
					local unformattedText = ""
					local newOutputText = Console.OutputTemplate:Clone()
					table.insert(displayedOutput, newOutputText)

					if #displayedOutput > OutputLimit.Value then
						local oldest = table.remove(displayedOutput, 1)
						if oldest and typeof(oldest) == "Instance" then
							oldest:Destroy()
						end
					end

					unformattedText = os.date("%H:%M:%S")..'   '..msg
					if msgtype == Enum.MessageType.MessageOutput then
						formattedText = os.date("%H:%M:%S")..'   <font color="rgb(204, 204, 204)">'..msg..'</font>'
						newOutputText.Text = formattedText
					elseif msgtype == Enum.MessageType.MessageWarning then
						formattedText = os.date("%H:%M:%S")..'   <b><font color="rgb(255, 142, 60)">'..msg..'</font></b>'
						newOutputText.Text = formattedText
					elseif msgtype == Enum.MessageType.MessageError then
						formattedText = os.date("%H:%M:%S")..'   <b><font color="rgb(255, 68, 68)">'..msg..'</font></b>'
						newOutputText.Text = formattedText
					elseif msgtype == Enum.MessageType.MessageInfo then
						formattedText = os.date("%H:%M:%S")..'   <font color="rgb(128, 215, 255)">'..msg..'</font>'
						newOutputText.Text = formattedText
					end

					newOutputText.TextSize = OutputTextSize.Value
					FrostznLife.Connect(OutputTextSize:GetPropertyChangedSignal("Value"),function()
						newOutputText.TextSize = OutputTextSize.Value
					end)

					FrostznLife.Connect(newOutputText.Focused,function()
						focussedOutput = newOutputText
						newOutputText.Text = unformattedText
					end)
					FrostznLife.Connect(newOutputText.FocusLost,function()
						focussedOutput = nil
						newOutputText.Text = formattedText
					end)

					newOutputText.Parent = Console.Output
					newOutputText.Visible = true

					if AutoScroll then
						Console.Output.CanvasPosition = Vector2.new(0, 9e9)
					end
				end)

				FrostznLife.Connect(Console.Output.MouseLeave,function()
					if focussedOutput then
						focussedOutput:ReleaseFocus()
					end
				end)

				FrostznLife.Connect(Console.CommandLine.ScrollingFrame.TextBox:GetPropertyChangedSignal("Text"),function()

					local oneliner = string.gsub(Console.CommandLine.ScrollingFrame.TextBox.Text, "\n", "    ")
					Console.CommandLine.ScrollingFrame.TextBox.Text = oneliner

					Console.CommandLine.ScrollingFrame.Highlight.Text = SyntaxHighlightingModule.run(Console.CommandLine.ScrollingFrame.TextBox.Text)
				end)



				FrostznLife.Connect(Console.CommandLine.ScrollingFrame.TextBox.FocusLost,function(enterPressed)
					if enterPressed and Console.CommandLine.ScrollingFrame.TextBox.Text ~= "" then
						print("> "..Console.CommandLine.ScrollingFrame.TextBox.Text)
						loadstring(Console.CommandLine.ScrollingFrame.TextBox.Text)()
					end
				end)
			end

			return Console
		end

		return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
	end,
    SaveInstance=function()
        local deps
        local function main()
            local app={};local selection,info,button;local targets={}
            function app.SetTargets(items)
                targets={};local chosen={}
                for _,object in ipairs(items) do chosen[object]=true end
                for _,object in ipairs(items) do
                    local ancestor=object.Parent;local nested=false
                    while ancestor do if chosen[ancestor] then nested=true;break end;ancestor=ancestor.Parent end
                    if not nested then targets[#targets+1]=object end
                end
                local names={};for i,o in ipairs(targets) do if i<=4 then names[#names+1]=o.Name.." • "..o.ClassName end end
                info.Text=#targets==0 and "Selecione um item no Explorer e clique em Usar seleção." or table.concat(names,"\n")..(#targets>4 and "\n+ outros itens" or "")
            end
            function app.UseSelection()
                local objects={};for _,node in ipairs(FrostznLife.Public.Selection.List) do objects[#objects+1]=node.Obj end
                app.SetTargets(objects)
            end
            function app.Init()
                local Lib,createSimple,theme=deps.Lib,deps.createSimple,deps.Settings.Theme
                local w=Lib.Window.new();w:SetTitle("Frostzn • Baixar itens");w:Resize(480,325);app.Window=w
                w.MinX=360;w.MinY=325
                local c=w.GuiElems.Content
                local function label(text,y,h)
                    return createSimple("TextLabel",{Text=text,Font=Enum.Font.SourceSans,TextSize=14,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
                        TextColor3=theme.Text,BackgroundTransparency=1,Position=UDim2.fromOffset(14,y),Size=UDim2.new(1,-28,0,h),Parent=c})
                end
                label("BAIXAR SELEÇÃO",12,22).TextColor3=Color3.fromRGB(190,164,255)
                info=label("Selecione um item no Explorer.",43,83)
                label("Modelos, pastas e interfaces: .rbxmx. Fonte legível: .lua. A exportação inclui descendentes acessíveis e relatório de limitações.",135,55)
                label("Destino: Xeno/workspace/FrostznDex/saved",196,24).TextColor3=theme.PlaceholderText
                local function action(text,x,width,callback)
                    local b=createSimple("TextButton",{Text=text,Font=Enum.Font.SourceSans,TextSize=14,TextColor3=theme.Text,BackgroundColor3=theme.Button,BorderSizePixel=0,
                        Position=UDim2.new(x,14,1,-45),Size=UDim2.new(width,-21,0,31),Parent=c})
                    FrostznLife.Connect(b.MouseButton1Click,callback);return b
                end
                action("Usar seleção",0,.5,app.UseSelection)
                button=action("Baixar",.5,.5,function()
                    if app.Busy then return end
                    if #targets==0 then info.Text="Nenhum item selecionado.";return end
                    if #targets>20 then info.Text="Selecione até 20 raízes por exportação.";return end
                    local snapshot=table.clone(targets);app.Busy=true;button.Text="Salvando..."
                    FrostznLife.Spawn(function()
                        local saved,errors=0,{}
                        for _,object in ipairs(snapshot) do
                            local path,detail=FrostznLife.Export(object)
                            if path then saved+=1 else errors[#errors+1]=tostring(detail):sub(1,110) end
                        end
                        info.Text=string.format("%d arquivo(s) salvo(s) em FrostznDex/saved",saved)..(#errors>0 and "\n"..table.concat(errors,"\n") or "\nRelatórios .report.json acompanham os modelos.")
                        button.Text="Baixar";app.Busy=false
                    end)
                end)
                FrostznLife.OpenExport=function()
                    app.UseSelection();w:Show()
                end
            end
            return app
        end
        return {InitDeps=function(d)deps=d end,InitAfterMain=function()end,Main=main}
    end,

}

-- Main vars
local Main, Explorer, Properties, ScriptViewer, DefaultSettings, Notebook, Serializer, Lib, Console, SaveInstance
local API, RM

-- Default Settings
DefaultSettings = (function()
	local rgb = Color3.fromRGB
	return {
		Explorer = {
			_Recurse = true,
			Sorting = true,
			TeleportToOffset = Vector3.new(0,0,0),
			ClickToRename = true,
			AutoUpdateSearch = false,
			AutoUpdateMode = 0, -- 0 Default, 1 no tree update, 2 no descendant events, 3 frozen
			PartSelectionBox = true,
			GuiSelectionBox = true,
			CopyPathUseGetChildren = true
		},
		Properties = {
			_Recurse = true,
			MaxConflictCheck = 50,
			ShowDeprecated = false,
			ShowHidden = false,
			ClearOnFocus = false,
			LoadstringInput = false,
			NumberRounding = 3,
			ShowAttributes = false,
			MaxAttributes = 50,
			ScaleType = 1 -- 0 Full Name Shown, 1 Equal Halves
		},
		Theme = {
			_Recurse = true,
			Main1 = rgb(29,31,47),
			Main2 = rgb(19,21,34),
			Outline1 = rgb(10,12,23), -- Mainly frames
			Outline2 = rgb(54,58,84), -- Mainly button
			Outline3 = rgb(71,64,110), -- Mainly textbox
			TextBox = rgb(15,18,30),
			Menu = rgb(22,25,40),
			ListSelection = rgb(85,62,145),
			Button = rgb(39,43,64),
			ButtonHover = rgb(59,56,91),
			ButtonPress = rgb(73,56,121),
			Highlight = rgb(55,59,86),
			Text = rgb(231,235,248),
			PlaceholderText = rgb(151,160,188),
			Important = rgb(248,136,155),
			ExplorerIconMap = "",
			MiscIconMap = "",
			Syntax = {
				Text = rgb(204,204,204),
				Background = rgb(15,18,29),
				Selection = rgb(255,255,255),
				SelectionBack = rgb(11,90,175),
				Operator = rgb(204,204,204),
				Number = rgb(255,198,0),
				String = rgb(173,241,149),
				Comment = rgb(126,148,137),
				Keyword = rgb(248,109,124),
				Error = rgb(255,0,0),
				FindBackground = rgb(141,118,0),
				MatchingWord = rgb(85,85,85),
				BuiltIn = rgb(132,214,247),
				CurrentLine = rgb(45,50,65),
				LocalMethod = rgb(253,251,172),
				LocalProperty = rgb(97,161,241),
				Nil = rgb(255,198,0),
				Bool = rgb(255,198,0),
				Function = rgb(248,109,124),
				Local = rgb(248,109,124),
				Self = rgb(248,109,124),
				FunctionName = rgb(253,251,172),
				Bracket = rgb(204,204,204)
			},
		}
	}
end)()

-- Vars
local Settings = {}
local Apps = {}
local env = {}

local plr = service.Players.LocalPlayer or service.Players.PlayerAdded:wait()

local create = function(data)
	local insts = {}
	for i,v in pairs(data) do insts[v[1]] = Instance.new(v[2]) end

	for _,v in pairs(data) do
		for prop,val in pairs(v[3]) do
			if type(val) == "table" then
				insts[v[1]][prop] = insts[val[1]]
			else
				insts[v[1]][prop] = val
			end
		end
	end

	return insts[1]
end

local createSimple = function(class,props)
	local inst = Instance.new(class)
	for i,v in next,props do
		inst[i] = v
	end
	return inst
end

Main = (function()
	local Main = {}

	Main.ModuleList = {"Explorer", "Properties", "ScriptViewer", "Console", "SaveInstance"}
	Main.Elevated = false
	Main.MissingEnv = {}
	Main.Version = "Frostzn 2.0" -- Base Dex preservada
	Main.Mouse = plr:GetMouse()
	Main.AppControls = {}
	Main.Apps = Apps
	Main.MenuApps = {}

	Main.DisplayOrders = {
		SideWindow = 1100008,
		Window = 1100010,
		Menu = 1200000,
		Core = 1300000
	}

	Main.GetInitDeps = function()
		return {
			Main = Main,
			Lib = Lib,
			Apps = Apps,
			Settings = Settings,

			API = API,
			RMD = RMD,
			env = env,
			service = service,
			plr = plr,
			create = create,
			createSimple = createSimple
		}
	end

	Main.Error=function(str) error("[Frostzn Dex] "..tostring(str),0) end

	Main.LoadModule = function(name)
		--[[if Main.Elevated then -- If you don't have filesystem api then ur outta luck tbh
			local control

			if EmbeddedModules then -- Offline Modules
				control = EmbeddedModules[name]()

				if not control then Main.Error("Missing Embedded Module: "..name) end
			end

			Main.AppControls[name] = control
			control.InitDeps(Main.GetInitDeps())

			local moduleData = control.Main()
			Apps[name] = moduleData
			return moduleData
		else
			local module = script:WaitForChild("Modules"):WaitForChild(name, 2)
			if not module then Main.Error("CANNOT FIND MODULE " .. name) end

			local control = require(module)
			Main.AppControls[name] = control
			control.InitDeps(Main.GetInitDeps())

			local moduleData = control.Main()
			Apps[name] = moduleData
			return moduleData
		end]]
		local control

		if EmbeddedModules then -- Offline Modules
			control = EmbeddedModules[name]()

			if not control then Main.Error("Missing Embedded Module: "..name) end
		end

		Main.AppControls[name] = control
		control.InitDeps(Main.GetInitDeps())

		local moduleData = control.Main()
		Apps[name] = moduleData
		return moduleData
	end

	Main.LoadModules = function()
		for i,v in pairs(Main.ModuleList) do
			local s,e = pcall(Main.LoadModule,v)
			if not s then
				Main.Error(("FAILED LOADING %s CAUSE %s"):format(v, e))
			end
		end

		-- Init Major Apps and define them in modules
		Explorer = Apps.Explorer
		Properties = Apps.Properties
		ScriptViewer = Apps.ScriptViewer
		Console = Apps.Console
		SaveInstance = Apps.SaveInstance
		Notebook = Apps.Notebook
		local appTable = {
			Explorer = Explorer,
			Properties = Properties,
			ScriptViewer = ScriptViewer,
			Console = Console,
			SaveInstance = SaveInstance,
			Notebook = Notebook
		}

		Main.AppControls.Lib.InitAfterMain(appTable)
		for i,v in pairs(Main.ModuleList) do
			local control = Main.AppControls[v]
			if control then
				control.InitAfterMain(appTable)
			end
		end
	end

	Main.InitEnv = function()
		setmetatable(env, {__newindex = function(self, name, func)
			if not func then Main.MissingEnv[#Main.MissingEnv + 1] = name return end
			rawset(self, name, func)
		end})

		-- file
		env.readfile = missing("function", readfile)
		env.writefile = missing("function", writefile)
		env.appendfile = missing("function", appendfile)
		env.makefolder = missing("function", makefolder)
		env.listfiles = missing("function", listfiles)
		env.loadfile = missing("function", loadfile)
		env.movefileas = missing("function", movefileas)
		env.saveinstance = missing("function", saveinstance)
		env.parsefile = function(name)
			return tostring(name):gsub("[*\\?:<>|]+", ""):sub(1, 175)
		end

		-- debug
		env.getupvalues = missing("function", (debug and debug.getupvalues) or getupvalues or getupvals)
		env.getconstants = missing("function", (debug and debug.getconstants) or getconstants or getconsts)
		env.getinfo = missing("function", (debug and (debug.getinfo or debug.info)) or getinfo)
		env.islclosure = missing("function", islclosure or is_l_closure or is_lclosure)
		env.checkcaller = missing("function", checkcaller)
		--env.getreg = missing("function", getreg)
		env.getgc = missing("function", getgc or get_gc_objects)
		--env.base64encode = missing("function", crypt and crypt.base64 and crypt.base64.encode)
		env.getscriptbytecode = missing("function", getscriptbytecode)

		-- other
		--env.setfflag = missing("function", setfflag)
		env.request = missing("function", request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request))
		env.decompile = missing("function", decompile)
		env.isViableDecompileScript = function(obj)
			if obj:IsA("ModuleScript") then
				return true
			elseif obj:IsA("LocalScript") and (obj.RunContext == Enum.RunContext.Client or obj.RunContext == Enum.RunContext.Legacy) then
				return true
			elseif obj:IsA("Script") and obj.RunContext == Enum.RunContext.Client then
				return true
			end
			return false
		end
		env.protectgui = missing("function", protect_gui or (syn and syn.protect_gui))
		env.gethui = missing("function", gethui or get_hidden_gui)
        env.getcustomasset=missing("function",getcustomasset or getsynasset)
		env.setclipboard = missing("function", setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set))
		env.getnilinstances = missing("function", getnilinstances or get_nil_instances)
		env.getloadedmodules = missing("function", getloadedmodules)

		env.executor = (function()
			local identifyexec = identifyexecutor or getexecutorname or whatexecutor
			local success, name = pcall(function()
				return tostring(identifyexec())
			end)
			return success and name or "Your executor"
		end)()

		Main.GuiHolder = Main.Elevated and service.CoreGui or plr:FindFirstChildWhichIsA("PlayerGui")

		setmetatable(env, nil)
	end

    Main.LoadSettings=function()
        Main.ResetSettings()
        if not env.readfile then return end
        local ok,raw=pcall(env.readfile,"FrostznDex/settings.json")
        if not ok then return end
        local decoded,data=pcall(service.HttpService.JSONDecode,service.HttpService,raw)
        if not decoded or type(data)~="table" then return end
        if type(data.BudgetMs)=="number" then FrostznLife.Budget=math.clamp(data.BudgetMs,1,5)/1000 end
        if type(data.SelectionBoxes)=="boolean" then Settings.Explorer.PartSelectionBox=data.SelectionBoxes;Settings.Explorer.GuiSelectionBox=data.SelectionBoxes end
    end

	Main.ResetSettings = function()
		local function recur(t,res)
			for set,val in pairs(t) do
				if type(val) == "table" and val._Recurse then
					if type(res[set]) ~= "table" then
						res[set] = {}
					end
					recur(val,res[set])
				else
					res[set] = val
				end
			end
			return res
		end
		recur(DefaultSettings,Settings)
	end

	local function jsonDecode(str)
		local suc, res = pcall(service.HttpService.JSONDecode, service.HttpService, str)
		return suc and res or suc
	end

	Main.FetchAPI = function()
        local rawAPI=assert(Lib.ReadFile("FrostznDex/deps/API.compact.json"),"API local ausente; instale o pacote FrostznDex")
        local api=assert(jsonDecode(rawAPI),"API local invalida")
        Main.RawAPI=nil

		local classes,enums = {},{}
		local categoryOrder,seenCategories = {},{}

		local function insertAbove(t,item,aboveItem)
			local findPos = table.find(t,item)
			if not findPos then return end
			table.remove(t,findPos)

			local pos = table.find(t,aboveItem)
			if not pos then return end
			table.insert(t,pos,item)
		end

		for _,class in pairs(api.Classes) do
            FrostznLife.Yield()
			local newClass = {}
			newClass.Name = class.Name
			newClass.Superclass = class.Superclass
			newClass.Properties = {}
			newClass.Functions = {}
			newClass.Events = {}
			newClass.Callbacks = {}
			newClass.Tags = {}

			if class.Tags then for c,tag in pairs(class.Tags) do newClass.Tags[tag] = true end end
			for __,member in pairs(class.Members) do
                FrostznLife.Yield()
				local newMember = {}
				newMember.Name = member.Name
				newMember.Class = class.Name
				newMember.Security = member.Security
				newMember.Tags ={}
				if member.Tags then for c,tag in pairs(member.Tags) do newMember.Tags[tag] = true end end

				local mType = member.MemberType
				if mType == "Property" then
					local propCategory = member.Category or "Other"
					propCategory = propCategory:match("^%s*(.-)%s*$")
					if not seenCategories[propCategory] then
						categoryOrder[#categoryOrder+1] = propCategory
						seenCategories[propCategory] = true
					end
					newMember.ValueType = member.ValueType
					newMember.Category = propCategory
					newMember.Serialization = member.Serialization
					table.insert(newClass.Properties,newMember)
				elseif mType == "Function" then
					newMember.Parameters = {}
					newMember.ReturnType = member.ReturnType.Name or "Tuple"
					for c,param in pairs(member.Parameters) do
						table.insert(newMember.Parameters,{Name = param.Name, Type = param.Type.Name})
					end
					table.insert(newClass.Functions,newMember)
				elseif mType == "Event" then
					newMember.Parameters = {}
					for c,param in pairs(member.Parameters) do
						table.insert(newMember.Parameters,{Name = param.Name, Type = param.Type.Name})
					end
					table.insert(newClass.Events,newMember)
				end
			end

			classes[class.Name] = newClass
		end

		for _,class in pairs(classes) do
			class.Superclass = classes[class.Superclass]
		end

		for _,enum in pairs(api.Enums) do
			local newEnum = {}
			newEnum.Name = enum.Name
			newEnum.Items = {}
			newEnum.Tags = {}

			if enum.Tags then for c,tag in pairs(enum.Tags) do newEnum.Tags[tag] = true end end
			for __,item in pairs(enum.Items) do
				local newItem = {}
				newItem.Name = item.Name
				newItem.Value = item.Value
				table.insert(newEnum.Items,newItem)
			end

			enums[enum.Name] = newEnum
		end

		local function getMember(class,member)
			if not classes[class] or not classes[class][member] then return end
			local result = {}

			local currentClass = classes[class]
			while currentClass do
				for _,entry in pairs(currentClass[member]) do
					result[#result+1] = entry
				end
				currentClass = currentClass.Superclass
			end

			table.sort(result,function(a,b) return a.Name < b.Name end)
			return result
		end

		insertAbove(categoryOrder,"Behavior","Tuning")
		insertAbove(categoryOrder,"Appearance","Data")
		insertAbove(categoryOrder,"Attachments","Axes")
		insertAbove(categoryOrder,"Cylinder","Slider")
		insertAbove(categoryOrder,"Localization","Jump Settings")
		insertAbove(categoryOrder,"Surface","Motion")
		insertAbove(categoryOrder,"Surface Inputs","Surface")
		insertAbove(categoryOrder,"Part","Surface Inputs")
		insertAbove(categoryOrder,"Assembly","Surface Inputs")
		insertAbove(categoryOrder,"Character","Controls")
		categoryOrder[#categoryOrder+1] = "Unscriptable"
		categoryOrder[#categoryOrder+1] = "Attributes"

		local categoryOrderMap = {}
		for i = 1,#categoryOrder do
			categoryOrderMap[categoryOrder[i]] = i
		end

		return {
			Classes = classes,
			Enums = enums,
			CategoryOrder = categoryOrderMap,
			GetMember = getMember
		}
	end

    Main.FetchRMD=function()
        local raw=assert(Lib.ReadFile("FrostznDex/deps/RMD.prepared.json"),"RMD local ausente")
        return assert(jsonDecode(raw),"RMD local invalido")
    end

	Main.ShowGui = function(gui)
        FrostznLife.TrackGui(gui)
		if env.gethui then
			gui.Parent = env.gethui()
		elseif env.protectgui then
			env.protectgui(gui)
			gui.Parent = Main.GuiHolder
		else
			gui.Parent = Main.GuiHolder
		end
	end

	Main.CreateIntro = function(initStatus) -- TODO: Must theme and show errors
		local gui = create({
			{1,"ScreenGui",{Name="Intro",}},
			{2,"Frame",{Active=true,BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="Main",Parent={1},Position=UDim2.new(0.5,-175,0.5,-100),Size=UDim2.new(0,350,0,200),}},
			{3,"Frame",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderSizePixel=0,ClipsDescendants=true,Name="Holder",Parent={2},Size=UDim2.new(1,0,1,0),}},
			{4,"UIGradient",{Parent={3},Rotation=30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{5,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=4,Name="Title",Parent={3},Position=UDim2.new(0,-190,0,15),Size=UDim2.new(0,100,0,50),Text="Dex",TextColor3=Color3.new(1,1,1),TextSize=50,TextTransparency=1,}},
			{6,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Desc",Parent={3},Position=UDim2.new(0,-230,0,60),Size=UDim2.new(0,180,0,25),Text="Ultimate Debugging Suite",TextColor3=Color3.new(1,1,1),TextSize=18,TextTransparency=1,}},
			{7,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="StatusText",Parent={3},Position=UDim2.new(0,20,0,110),Size=UDim2.new(0,180,0,25),Text="Fetching API",TextColor3=Color3.new(1,1,1),TextSize=14,TextTransparency=1,}},
			{8,"Frame",{BackgroundColor3=Color3.new(0.20392157137394,0.20392157137394,0.20392157137394),BorderSizePixel=0,Name="ProgressBar",Parent={3},Position=UDim2.new(0,110,0,145),Size=UDim2.new(0,0,0,4),}},
			{9,"Frame",{BackgroundColor3=Color3.new(0.2392156869173,0.56078433990479,0.86274510622025),BorderSizePixel=0,Name="Bar",Parent={8},Size=UDim2.new(0,0,1,0),}},
			{10,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Image="rbxassetid://2764171053",ImageColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),Parent={8},ScaleType=1,Size=UDim2.new(1,0,1,0),SliceCenter=Rect.new(2,2,254,254),}},
			{11,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Creator",Parent={2},Position=UDim2.new(1,-110,1,-20),Size=UDim2.new(0,105,0,20),Text="Developed by Moon",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=1,}},
			{12,"UIGradient",{Parent={11},Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{13,"TextLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=3,Name="Version",Parent={2},Position=UDim2.new(1,-110,1,-35),Size=UDim2.new(0,105,0,20),Text=Main.Version,TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=1,}},
			{14,"UIGradient",{Parent={13},Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{15,"ImageLabel",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,Image="rbxassetid://1427967925",Name="Outlines",Parent={2},Position=UDim2.new(0,-5,0,-5),ScaleType=1,Size=UDim2.new(1,10,1,10),SliceCenter=Rect.new(6,6,25,25),TileSize=UDim2.new(0,20,0,20),}},
			{16,"UIGradient",{Parent={15},Rotation=-30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
			{17,"UIGradient",{Parent={2},Rotation=-30,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0),}),}},
		})
		Main.ShowGui(gui)
		local backGradient = gui.Main.UIGradient
		local outlinesGradient = gui.Main.Outlines.UIGradient
		local holderGradient = gui.Main.Holder.UIGradient
		local titleText = gui.Main.Holder.Title
		local descText = gui.Main.Holder.Desc
		local versionText = gui.Main.Version
		local versionGradient = versionText.UIGradient
		local creatorText = gui.Main.Creator
		local creatorGradient = creatorText.UIGradient
		local statusText = gui.Main.Holder.StatusText
		local progressBar = gui.Main.Holder.ProgressBar
		local tweenS = service.TweenService

		local renderStepped = service.RunService.RenderStepped
		local signalWait = renderStepped.wait
		local fastwait = function(s)
			if not s then return signalWait(renderStepped) end
			local start = tick()
			while tick() - start < s do signalWait(renderStepped) end
		end

		statusText.Text = initStatus

		local function tweenNumber(n,ti,func)
			local tweenVal = Instance.new("IntValue")
			tweenVal.Value = 0
			FrostznLife.Connect(tweenVal.Changed,func)
			local tween = tweenS:Create(tweenVal,ti,{Value = n})
			tween:Play()
			FrostznLife.Connect(tween.Completed,function()
				tweenVal:Destroy()
			end)
		end

		local ti = TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
		tweenNumber(100,ti,function(val)
			val = val/200
			local start = NumberSequenceKeypoint.new(0,0)
			local a1 = NumberSequenceKeypoint.new(val,0)
			local a2 = NumberSequenceKeypoint.new(math.min(0.5,val+math.min(0.05,val)),1)
			if a1.Time == a2.Time then a2 = a1 end
			local b1 = NumberSequenceKeypoint.new(1-val,0)
			local b2 = NumberSequenceKeypoint.new(math.max(0.5,1-val-math.min(0.05,val)),1)
			if b1.Time == b2.Time then b2 = b1 end
			local goal = NumberSequenceKeypoint.new(1,0)
			backGradient.Transparency = NumberSequence.new({start,a1,a2,b2,b1,goal})
			outlinesGradient.Transparency = NumberSequence.new({start,a1,a2,b2,b1,goal})
		end)

		fastwait(0.4)

		tweenNumber(100,ti,function(val)
			val = val/166.66
			local start = NumberSequenceKeypoint.new(0,0)
			local a1 = NumberSequenceKeypoint.new(val,0)
			local a2 = NumberSequenceKeypoint.new(val+0.01,1)
			local goal = NumberSequenceKeypoint.new(1,1)
			holderGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
		end)

		tweenS:Create(titleText,ti,{Position = UDim2.new(0,60,0,15), TextTransparency = 0}):Play()
		tweenS:Create(descText,ti,{Position = UDim2.new(0,20,0,60), TextTransparency = 0}):Play()

		local function rightTextTransparency(obj)
			tweenNumber(100,ti,function(val)
				val = val/100
				local a1 = NumberSequenceKeypoint.new(1-val,0)
				local a2 = NumberSequenceKeypoint.new(math.max(0,1-val-0.01),1)
				if a1.Time == a2.Time then a2 = a1 end
				local start = NumberSequenceKeypoint.new(0,a1 == a2 and 0 or 1)
				local goal = NumberSequenceKeypoint.new(1,0)
				obj.Transparency = NumberSequence.new({start,a2,a1,goal})
			end)
		end
		rightTextTransparency(versionGradient)
		rightTextTransparency(creatorGradient)

		fastwait(0.9)

		local progressTI = TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)

		tweenS:Create(statusText,progressTI,{Position = UDim2.new(0,20,0,120), TextTransparency = 0}):Play()
		tweenS:Create(progressBar,progressTI,{Position = UDim2.new(0,60,0,145), Size = UDim2.new(0,100,0,4)}):Play()

		fastwait(0.25)

		local function setProgress(text,n)
			statusText.Text = text
			tweenS:Create(progressBar.Bar,progressTI,{Size = UDim2.new(n,0,1,0)}):Play()
		end

		local function close()
			tweenS:Create(titleText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(descText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(versionText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(creatorText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(statusText,progressTI,{TextTransparency = 1}):Play()
			tweenS:Create(progressBar,progressTI,{BackgroundTransparency = 1}):Play()
			tweenS:Create(progressBar.Bar,progressTI,{BackgroundTransparency = 1}):Play()
			tweenS:Create(progressBar.ImageLabel,progressTI,{ImageTransparency = 1}):Play()

			tweenNumber(100,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.In),function(val)
				val = val/250
				local start = NumberSequenceKeypoint.new(0,0)
				local a1 = NumberSequenceKeypoint.new(0.6+val,0)
				local a2 = NumberSequenceKeypoint.new(math.min(1,0.601+val),1)
				if a1.Time == a2.Time then a2 = a1 end
				local goal = NumberSequenceKeypoint.new(1,a1 == a2 and 0 or 1)
				holderGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
			end)

			fastwait(0.5)
			gui.Main.BackgroundTransparency = 1
			outlinesGradient.Rotation = 30

			tweenNumber(100,ti,function(val)
				val = val/100
				local start = NumberSequenceKeypoint.new(0,1)
				local a1 = NumberSequenceKeypoint.new(val,1)
				local a2 = NumberSequenceKeypoint.new(math.min(1,val+math.min(0.05,val)),0)
				if a1.Time == a2.Time then a2 = a1 end
				local goal = NumberSequenceKeypoint.new(1,a1 == a2 and 1 or 0)
				outlinesGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
				holderGradient.Transparency = NumberSequence.new({start,a1,a2,goal})
			end)

			fastwait(0.45)
			gui:Destroy()
		end

		return {SetProgress = setProgress, Close = close}
	end

	Main.CreateApp = function(data)
		if Main.MenuApps[data.Name] then return end -- TODO: Handle conflict
		local control = {}

		local app = Main.AppTemplate:Clone()

		local iconIndex = data.Icon
		if data.IconMap and iconIndex then
			if type(iconIndex) == "number" then
				data.IconMap:Display(app.Main.Icon,iconIndex)
			elseif type(iconIndex) == "string" then
				data.IconMap:DisplayByKey(app.Main.Icon,iconIndex)
			end
		elseif type(iconIndex) == "string" then
			app.Main.Icon.Image = iconIndex
		else
			app.Main.Icon.Image = ""
		end

		local function updateState()
			app.Main.BackgroundTransparency = data.Open and 0 or (Lib.CheckMouseInGui(app.Main) and 0 or 1)
			app.Main.Highlight.Visible = data.Open
		end

		local function enable(silent)
			if data.Open then return end
			data.Open = true
			updateState()
			if not silent then
				if data.Window then data.Window:Show() end
				if data.OnClick then data.OnClick(data.Open) end
			end
		end

		local function disable(silent)
			if not data.Open then return end
			data.Open = false
			updateState()
			if not silent then
				if data.Window then data.Window:Hide() end
				if data.OnClick then data.OnClick(data.Open) end
			end
		end

		updateState()

		local ySize = service.TextService:GetTextSize(data.Name,14,Enum.Font.SourceSans,Vector2.new(62,999999)).Y
		app.Main.Size = UDim2.new(1,0,0,math.clamp(46+ySize,60,74))
		app.Main.AppName.Text = data.Name

		FrostznLife.Connect(app.Main.InputBegan,function(input)
			if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				app.Main.BackgroundTransparency = 0
				app.Main.BackgroundColor3 = Settings.Theme.ButtonHover
			end
		end)

		FrostznLife.Connect(app.Main.InputEnded,function(input)
			if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				app.Main.BackgroundTransparency = data.Open and 0 or 1
				app.Main.BackgroundColor3 = Settings.Theme.Button
			end
		end)

		FrostznLife.Connect(app.Main.MouseButton1Click,function()
			if data.Open then disable() else enable() end
		end)

		local window = data.Window
		if window then
			FrostznLife.Connect(window.OnActivate,function() enable(true) end)
			FrostznLife.Connect(window.OnDeactivate,function() disable(true) end)
		end

		app.Visible = true
		app.Parent = Main.AppsContainer
		Main.AppsFrame.CanvasSize = UDim2.new(0,0,0,Main.AppsContainerGrid.AbsoluteCellCount.Y*82 + 8)

		control.Enable = enable
		control.Disable = disable
		Main.MenuApps[data.Name] = control
		return control
	end

	Main.SetMainGuiOpen = function(val)
		Main.MainGuiOpen = val

		Main.MainGui.OpenButton.Text = val and "X" or "Dex"
		if val then Main.MainGui.OpenButton.MainFrame.Visible = true end
		Main.MainGui.OpenButton.MainFrame:TweenSize(val and UDim2.new(0,224,0,200) or UDim2.new(0,0,0,0),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.2,true)
		--Main.MainGui.OpenButton.BackgroundTransparency = val and 0 or (Lib.CheckMouseInGui(Main.MainGui.OpenButton) and 0 or 0.2)
		service.TweenService:Create(Main.MainGui.OpenButton,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency = val and 0 or (Lib.CheckMouseInGui(Main.MainGui.OpenButton) and 0 or 0.2)}):Play()

		if Main.MainGuiMouseEvent then Main.MainGuiMouseEvent:Disconnect() end

		if not val then
			local startTime = tick()
			Main.MainGuiCloseTime = startTime
			FrostznLife.Wrap(function()
				Lib.FastWait(0.2)
				if not Main.MainGuiOpen and startTime == Main.MainGuiCloseTime then Main.MainGui.OpenButton.MainFrame.Visible = false end
			end)()
		else
			Main.MainGuiMouseEvent = FrostznLife.Connect(service.UserInputService.InputBegan,function(input)
				if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not Lib.CheckMouseInGui(Main.MainGui.OpenButton) and not Lib.CheckMouseInGui(Main.MainGui.OpenButton.MainFrame) then

					Main.SetMainGuiOpen(false)
				end
			end)
		end
	end

    Main.CreateMainGui=function()
        local theme=Settings.Theme
        local atlas
        if env.getcustomasset then
            local ok,result=pcall(env.getcustomasset,"FrostznDex/assets/LauncherAtlas.png")
            if ok and type(result)=="string" then atlas=result end
        end
        local gui=createSimple("ScreenGui",{Name="FrostznDexLauncher",IgnoreGuiInset=true,DisplayOrder=Main.DisplayOrders.Core,ResetOnSpawn=false})
        FrostznLife.TrackGui(gui)
        local dock=createSimple("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-16,.5,0),Size=UDim2.fromOffset(54,330),
            BackgroundColor3=theme.Main2,BorderSizePixel=0,Parent=gui})
        createSimple("UICorner",{CornerRadius=UDim.new(0,10),Parent=dock})
        createSimple("UIStroke",{Color=Color3.fromRGB(105,87,164),Thickness=1,Parent=dock})
        local brand=createSimple("TextLabel",{Text="F",TextSize=24,Font=Enum.Font.GothamBold,TextColor3=Color3.fromRGB(178,153,255),
            BackgroundTransparency=1,Position=UDim2.fromOffset(6,4),Size=UDim2.fromOffset(42,32),Parent=dock})
        local tooltip=createSimple("TextLabel",{Text="",Visible=false,TextSize=13,Font=Enum.Font.Gotham,TextColor3=theme.Text,
            BackgroundColor3=theme.Menu,BorderSizePixel=0,AnchorPoint=Vector2.new(1,0),Size=UDim2.fromOffset(195,30),Parent=gui})
        createSimple("UICorner",{CornerRadius=UDim.new(0,6),Parent=tooltip})
        local settingsWindow,infoWindow
        local function panel(title,width,height)
            local window=Lib.Window.new();window:SetTitle(title);window:Resize(width,height)
            window.MinX=width;window.MinY=height
            return window,window.GuiElems.Content
        end
        local function text(parent,value,y,height)
            return createSimple("TextLabel",{Text=value,TextSize=14,Font=Enum.Font.SourceSans,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
                TextYAlignment=Enum.TextYAlignment.Top,TextColor3=theme.Text,BackgroundTransparency=1,Position=UDim2.fromOffset(14,y),Size=UDim2.new(1,-28,0,height),Parent=parent})
        end
        local function saveSettings()
            if env.writefile then pcall(env.writefile,"FrostznDex/settings.json",service.HttpService:JSONEncode({BudgetMs=FrostznLife.Budget*1000,SelectionBoxes=Settings.Explorer.PartSelectionBox})) end
        end
        local function showInfo()
            if not infoWindow then
                local c;infoWindow,c=panel("Frostzn Dex • Sobre e limites",480,370)
                text(c,"FROSTZN DEX",15,25).TextColor3=Color3.fromRGB(185,158,255)
                text(c,"Base original: Dex por Moon / LorekeeperZinnia, modificado para Infinite Yield. Personalização e manutenção: Frostzn.",49,53)
                text(c,"O Explorer mostra objetos reais acessíveis no cliente. Scripts exclusivos do servidor não são enviados ao Roblox Player. Serviços vazios no cliente não comprovam ausência de conteúdo no servidor.",113,86)
                text(c,"Código original protegido aparece como indisponível. Decompilar cliente depende da função já fornecida pelo executor e pode produzir uma reconstrução diferente do original.",207,76)
                text(c,"F4: Explorer e Propriedades. Janelas podem ser arrastadas, redimensionadas e encaixadas nas laterais. Edições são locais.",290,58)
            end
            infoWindow:Show()
        end
        local function showSettings()
            if not settingsWindow then
                local c;settingsWindow,c=panel("Frostzn Dex • Configurações",460,365)
                text(c,"PROCESSAMENTO POR QUADRO",15,24).TextColor3=Color3.fromRGB(185,158,255)
                local state=text(c,"",82,52)
                local function update()state.Text=string.format("Orçamento de indexação/busca: %.0f ms.\nObjetos indexados na abertura: %d.",FrostznLife.Budget*1000,FrostznLife.Scanned)end
                for i,data in ipairs({{"Leve",2},{"Equilibrado",3},{"Rápido",5}}) do
                    local b=createSimple("TextButton",{Text=data[1],Font=Enum.Font.SourceSans,TextSize=14,TextColor3=theme.Text,BackgroundColor3=theme.Button,
                        BorderSizePixel=0,Position=UDim2.fromOffset(14+(i-1)*143,44),Size=UDim2.fromOffset(136,28),Parent=c})
                    FrostznLife.Connect(b.MouseButton1Click,function()FrostznLife.Budget=data[2]/1000;update();saveSettings()end)
                end
                local toggle=createSimple("TextButton",{Text="",Font=Enum.Font.SourceSans,TextSize=14,TextColor3=theme.Text,BackgroundColor3=theme.Button,
                    BorderSizePixel=0,Position=UDim2.fromOffset(14,145),Size=UDim2.new(1,-28,0,31),Parent=c})
                local function paint()toggle.Text="Contornos de seleção: "..(Settings.Explorer.PartSelectionBox and "Ligados" or "Desligados")end
                FrostznLife.Connect(toggle.MouseButton1Click,function()Settings.Explorer.PartSelectionBox=not Settings.Explorer.PartSelectionBox;Settings.Explorer.GuiSelectionBox=Settings.Explorer.PartSelectionBox;paint();Explorer.UpdateSelectionVisuals();saveSettings()end)
                text(c,'Busca: class:Script, isa:BasePart, path:Workspace, "frase exata", -excluir. Espaços combinam condições; vírgula combina alternativas.',191,61)
                local reflow=createSimple("TextButton",{Text="Restaurar encaixes",Font=Enum.Font.SourceSans,TextSize=14,TextColor3=theme.Text,BackgroundColor3=theme.Button,
                    BorderSizePixel=0,Position=UDim2.fromOffset(14,256),Size=UDim2.new(1,-28,0,29),Parent=c})
                FrostznLife.Connect(reflow.MouseButton1Click,function()
                    Explorer.Window:Close();Properties.Window:Close()
                    Explorer.Window:Show({Align="right",Pos=1,Size=.5,Silent=true})
                    Properties.Window:Show({Align="right",Pos=2,Size=.5,Silent=true})
                    Lib.Window.SetSideVisible("right",true);Lib.Window.Reflow()
                end)
                local close=createSimple("TextButton",{Text="Encerrar Frostzn Dex",Font=Enum.Font.SourceSans,TextSize=14,TextColor3=Color3.fromRGB(255,162,175),BackgroundColor3=theme.Button,
                    BorderSizePixel=0,Position=UDim2.fromOffset(14,300),Size=UDim2.new(1,-28,0,29),Parent=c})
                FrostznLife.Connect(close.MouseButton1Click,function()saveSettings();FrostznLife.Shutdown()end)
                paint();update()
            end
            settingsWindow:Show()
        end
        local apps={
            {"Explorer",0,function()Explorer.Window:Show();FrostznLife.Status("Explorer • conteúdo replicado do cliente")end},
            {"Propriedades",1,function()Properties.Window:Show()end},
            {"Editor de scripts",2,function()ScriptViewer.Window:Show()end},
            {"Console",4,function()Console.Window:Show()end},
            {"Baixar seleção",3,function()FrostznLife.OpenExport()end},
            {"Configurações",nil,showSettings,"≡"},
            {"Sobre / limites",nil,showInfo,"?"},
        }
        local fallback={19,23,54,51,19,23,21}
        for i,data in ipairs(apps) do
            local b=createSimple("TextButton",{Name="LauncherButton"..i,Text="",TextColor3=theme.Text,TextSize=19,Font=Enum.Font.SourceSansSemibold,AutoButtonColor=false,
                BackgroundColor3=theme.Button,BorderSizePixel=0,Position=UDim2.fromOffset(7,38+(i-1)*40),Size=UDim2.fromOffset(40,35),Parent=dock})
            createSimple("UICorner",{CornerRadius=UDim.new(0,6),Parent=b})
            local icon=createSimple("ImageLabel",{Name="Icon",BackgroundTransparency=1,Size=UDim2.fromOffset(26,26),Position=UDim2.fromOffset(7,4),
                Image=atlas or "rbxasset://textures/ClassImages.PNG",ImageRectSize=atlas and Vector2.new(64,64) or Vector2.new(16,16),
                ImageRectOffset=atlas and Vector2.new((i-1)*64,0) or Vector2.new((fallback[i]%16)*16,math.floor(fallback[i]/16)*16),Parent=b})
            FrostznLife.Connect(b.MouseButton1Click,data[3])
            FrostznLife.Connect(b.MouseEnter,function()
                tooltip.Text=data[1];tooltip.Visible=true
                tooltip.Position=UDim2.new(1,-78,0,b.AbsolutePosition.Y)
                service.TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=theme.ButtonHover}):Play()
            end)
            FrostznLife.Connect(b.MouseLeave,function()tooltip.Visible=false;service.TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=theme.Button}):Play()end)
        end
        local status=createSimple("TextLabel",{Text="Pronto • cliente",TextSize=12,Font=Enum.Font.SourceSans,TextColor3=theme.PlaceholderText,
            TextXAlignment=Enum.TextXAlignment.Left,BackgroundColor3=theme.Main2,BorderSizePixel=0,Position=UDim2.new(0,12,1,-28),Size=UDim2.fromOffset(420,22),Parent=gui})
        FrostznLife.StatusLabel=status
        local exit=createSimple("TextButton",{Name="ExitView",Text="Sair da observação  •  F7",Visible=false,TextSize=14,Font=Enum.Font.SourceSansSemibold,
            TextColor3=theme.Text,BackgroundColor3=theme.ListSelection,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,50),Size=UDim2.fromOffset(220,34),Parent=gui})
        createSimple("UICorner",{CornerRadius=UDim.new(0,8),Parent=exit})
        FrostznLife.Connect(exit.MouseButton1Click,function()FrostznLife.RestoreCamera()end)
        FrostznLife.CameraExit=exit
        Main.MainGui=gui;Lib.ShowGui(gui)
        FrostznLife.Open=function(name)
            if name=="ScriptViewer" then ScriptViewer.Window:Show()
            elseif name=="Properties" then Properties.Window:Show()
            else Explorer.Window:Show() end
        end
        FrostznLife.Connect(service.UserInputService.InputBegan,function(input,processed)
            if processed or service.UserInputService:GetFocusedTextBox() then return end
            if input.KeyCode==Enum.KeyCode.F4 then Lib.Window.ToggleSide("right") end
            if input.KeyCode==Enum.KeyCode.F7 then FrostznLife.RestoreCamera() end
        end)
    end

    Main.SetupFilesystem=function()
        if not env.makefolder then return end
        for _,path in ipairs({"FrostznDex","FrostznDex/assets","FrostznDex/saved","FrostznDex/plugins","FrostznDex/ModuleCache"}) do
            pcall(env.makefolder,path)
        end
    end

	Main.LocalDepsUpToDate = function()
		return Main.DepsVersionData and Main.ClientVersion == Main.DepsVersionData[1]
	end

	Main.Init = function()
		Main.Elevated = pcall(function() local a = service.CoreGui:GetFullName() end)
		Main.InitEnv()
		Main.LoadSettings()
		Main.SetupFilesystem()

		-- Load Lib
		local intro = Main.CreateIntro("Initializing Library")
		Lib = Main.LoadModule("Lib")
		Lib.FastWait()

		-- Init other stuff
		--Main.IncompatibleTest()

		-- Init icons
		Main.MiscIcons = Lib.IconMap.new("http://www.roblox.com/asset/?id=6511490623",256,256,16,16) -- 6579106223

		Main.MiscIcons:SetDict({
			["Reference"] = 0;
			["Cut"] = 1;
			["Cut_Disabled"] = 2;
			["Copy"] = 3;
			["Copy_Disabled"] = 4;
			["Paste"] = 5;
			["Paste_Disabled"] = 6;
			["Delete"] = 7;
			["Delete_Disabled"] = 8;
			["Group"] = 9;
			["Group_Disabled"] = 10;
			["Ungroup"] = 11;
			["Ungroup_Disabled"] = 12;
			["TeleportTo"] = 13;
			["Rename"] = 14;
			["JumpToParent"] = 15;
			["ExploreData"] = 16;
			["Save"] = 17;
			["CallFunction"] = 18;
			["CallRemote"] = 19;
			["Undo"] = 20,
			["Undo_Disabled"] = 21;
			["Redo"] = 22;
			["Redo_Disabled"] = 23;
			["Expand_Over"] = 24;
			["Expand"] = 25;
			["Collapse_Over"] = 26;
			["Collapse"] = 27;
			["SelectChildren"] = 28;
			["SelectChildren_Disabled"] = 29;
			["InsertObject"] = 30;
			["ViewScript"] = 31;
			["AddStar"] = 32;
			["RemoveStar"] = 33;
			["Script_Disabled"] = 34;
			["LocalScript_Disabled"] = 35;
			["Play"] = 36;
			["Pause"] = 37;
			["Rename_Disabled"] = 38;
		})
		Main.LargeIcons = Lib.IconMap.new("rbxassetid://6579106223",256,256,32,32)
		Main.LargeIcons:SetDict({
			Explorer = 0, Properties = 1, Script_Viewer = 2, Watcher = 3, Output = 4
		})

		Main.RobloxVersion="offline-metadata-20261016"
		-- Fetch external deps
		intro.SetProgress("Fetching API",0.35)
		API = Main.FetchAPI()
		Lib.FastWait()
		intro.SetProgress("Fetching RMD",0.5)
		RMD = Main.FetchRMD()
		Lib.FastWait()

		-- Load other modules
		intro.SetProgress("Loading Modules",0.75)
		Main.AppControls.Lib.InitDeps(Main.GetInitDeps()) -- Missing deps now available
		Main.LoadModules()
		Lib.FastWait()

		-- Init other modules
		intro.SetProgress("Initializing Modules",0.9)
		Explorer.Init()
		Properties.Init()
		ScriptViewer.Init()
		Console.Init()
		SaveInstance.Init()
		Lib.FastWait()

		-- Done
		intro.SetProgress("Complete",1)
		FrostznLife.Wrap(function()
			Lib.FastWait(1.25)
			intro.Close()
		end)()

		-- Init window system, create main menu, show explorer and properties
		Lib.Window.Init()
        Main.CreateMainGui()
        FrostznLife.Public={Main=Main,Apps=Apps,Settings=Settings,Nodes=nodes,Selection=selection}
        FrostznLife.Connect(selection.Changed,function()
            local node=selection.List[1]
            if node and (node.Obj:IsA("ServerStorage") or node.Obj:IsA("ServerScriptService")) then
                FrostznLife.Status("Servidor • conteúdo não replicado ao cliente")
            end
        end)
        FrostznLife.Ready=true
        FrostznLife.Status("Pronto • cliente · servidor não replicado")
        local oldPanel=plr.PlayerGui:FindFirstChild("FrostznClientStudio")
        if oldPanel and oldPanel:FindFirstChild("Control") then pcall(function()oldPanel.Control:Invoke("close")end) end
		Explorer.Window:Show({Align = "right", Pos = 1, Size = 0.5, Silent = true})
		Properties.Window:Show({Align = "right", Pos = 2, Size = 0.5, Silent = true})
		Lib.DeferFunc(function() Lib.Window.ToggleSide("right") end)
	end

	return Main
end)()

-- Start
Main.Init()
