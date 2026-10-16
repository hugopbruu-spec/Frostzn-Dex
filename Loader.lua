-- Frostzn Dex 2.0.0 | https://github.com/hugopbruu-spec/Frostzn-Dex
-- Dex: Moon / LorekeeperZinnia / Infinite Yield. Customization: Frostzn.
-- Installs this repository's runtime and metadata; does not fetch other code.
local VERSION="2.0.0"
local BASE="https://raw.githubusercontent.com/hugopbruu-spec/Frostzn-Dex/main/"
local scope=(type(getgenv)=="function" and getgenv()) or _G
local active=scope.FrostznDex
if active and active.Alive and active.Ready then
    if active.Open then active.Open("Explorer") end
    return
end
assert(type(readfile)=="function" and type(writefile)=="function" and type(makefolder)=="function" and type(loadstring)=="function",
    "[Frostzn Dex] O ambiente precisa oferecer readfile, writefile, makefolder e loadstring.")
local http=game:GetService("HttpService")
local root="FrostznDex/"
local files={
    {remote="API.compact.json",path="deps/API.compact.json",bytes=2086538},
    {remote="RMD.prepared.json",path="deps/RMD.prepared.json",bytes=140205},
    {remote="LauncherAtlas.png",path="assets/LauncherAtlas.png",bytes=12418},
    {remote="Frostzn_Dex.lua",path="Frostzn_Dex.lua",bytes=500629},
}
local function validate(file,data)
    if type(data)~="string" or #data~=file.bytes then return false end
    if file.remote:sub(-5)==".json" then
        local ok,value=pcall(http.JSONDecode,http,data)
        return ok and type(value)=="table"
    elseif file.remote:sub(-4)==".png" then
        return data:sub(1,8)=="\137PNG\r\n\26\n"
    else
        local program=loadstring(data,"Frostzn Dex validation")
        return type(program)=="function"
    end
end
local function install()
    for _,folder in ipairs({"FrostznDex","FrostznDex/deps","FrostznDex/assets","FrostznDex/saved","FrostznDex/plugins","FrostznDex/ModuleCache"}) do
        local ok,err=pcall(makefolder,folder)
        if not ok then
            -- Existing folders may be reported as errors by some executors.
            if type(isfolder)=="function" then assert(isfolder(folder),"[Frostzn Dex] Falha na pasta: "..folder.." • "..tostring(err)) end
        end
    end
    local payloads={}
    -- Validate all requested files before changing the installed runtime.
    for _,file in ipairs(files) do
        local ok,cached=pcall(readfile,root..file.path)
        if ok and validate(file,cached) then
            payloads[file.path]=cached
        else
            local downloaded,data=pcall(function()return game:HttpGet(BASE..file.remote)end)
            assert(downloaded,"[Frostzn Dex] Download falhou: "..file.remote..". Tente novamente. "..tostring(data))
            assert(validate(file,data),"[Frostzn Dex] Arquivo incompleto ou versão incompatível: "..file.remote)
            payloads[file.path]=data
        end
    end
    for _,file in ipairs(files) do
        local path=root..file.path
        local ok,cached=pcall(readfile,path)
        if not ok or cached~=payloads[file.path] then
            writefile(path,payloads[file.path])
            assert(readfile(path)==payloads[file.path],"[Frostzn Dex] Gravação não confirmada: "..file.path)
        end
    end
    local program,err=loadstring(payloads["Frostzn_Dex.lua"],"Frostzn Dex "..VERSION)
    assert(program,err)
    return program
end
local ok,program=xpcall(install,debug.traceback)
assert(ok,program)
-- Preserve the normal runtime error handling and clean up only this panel.
local started,err=xpcall(program,debug.traceback)
if not started then
    local instance=scope.FrostznDex
    if instance and instance.Shutdown then pcall(instance.Shutdown) end
    error("[Frostzn Dex] "..tostring(err),0)
end
