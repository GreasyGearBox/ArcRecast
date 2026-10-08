addon.name='arcrecast'
addon.author='Mr.Bear'
addon.version='1.0.3'
addon.desc='ArcRecast: standalone ability cooldowns and ready notifications for Ashita v4.'
require('common')
local imgui=require('imgui')
local settings=require('settings')
local drag=require('drag')
local cooldowns=require('cooldowns')
local cooldownState=cooldowns.new()
local cooldownRows={}
local cooldownLayoutWidth=0
local cooldownJob=nil
local readyNotices={}
local readyBoxWidth=380
local readyBoxHeight=64
local defaults=T{enabled=true,showReadyBox=true,readyBoxX=.5,readyBoxY=.58,readyBoxTextSize=36,readyBoxLinger=1.5,readyBoxFade=.5,readyBoxStrength=.5,cooldownBuffer=25,showCooldowns=true,cooldownX=.96,cooldownY=.08,cooldownScale=1.5,cooldownWidth=150,cooldownTextSize=24,cooldownBarThickness=5,cooldownRowGap=12,cooldownFade=.5,cooldownReadyLinger=1.5,cooldownPulseStrength=.25,cooldownRed=T{.94,.25,.29,1},cooldownYellow=T{.91,.78,.42,1},cooldownGreen=T{.40,.82,.55,1}}
local cfg=settings.load(defaults)
cfg.cooldownWidth=math.max(40,math.min(300,tonumber(cfg.cooldownWidth) or 150))
settings.register('settings','arcrecast_settings',function(s)
    cfg=s
    cfg.cooldownWidth=math.max(40,math.min(300,tonumber(cfg.cooldownWidth) or 150))
end)
local configOpen=false
local dragActive=false
local preview=false
local lastError=nil
local font=nil
local fontAttempted=false
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function closeConfig() configOpen=false;dragActive=false;settings.save() end
local function color(v,alpha)
    return imgui.GetColorU32({v[1],v[2],v[3],alpha or v[4] or 1})
end
local function text(dl,value,x,y,size,rgba)
    value=tostring(value)
    local black=color({0,0,0,0.85})
    local white=color(rgba or {0.94,0.96,1,1})
    if font then
        dl:AddText(font,size,{x+1,y+1},black,value)
        dl:AddText(font,size,{x,y},white,value)
    else
        dl:AddText({x+1,y+1},black,value); dl:AddText({x,y},white,value)
    end
end
local function measure(value,size)
    value=tostring(value)
    local pushed=false
    if font then pushed=pcall(imgui.PushFont,font) end
    local width=imgui.CalcTextSize(value)
    local line=imgui.GetTextLineHeight()
    if pushed then imgui.PopFont() end
    return width*(font and size/math.max(line,1) or 1)
end
local function alignedText(dl,value,x,y,size,rgba)
    text(dl,value,x-measure(value,size),y,size,rgba)
end
local function setupFont()
    if fontAttempted then return end
    fontAttempted=true
    local base=addon.path or (AshitaCore:GetInstallPath()..'\\addons\\arcrecast\\')
    local ok,f=pcall(imgui.AddFontFromFileTTF,base..'assets/Rajdhani-Bold.ttf',48)
    if not ok or not f then ok,f=pcall(imgui.AddFontFromFileTTF,'C:\\Windows\\Fonts\\arialbd.ttf',48) end
    if ok and f then font=f end
end
local function drawReadyBox(dl,w,h,now)
    if not cfg.showReadyBox then readyNotices={};return end
    for i=#readyNotices,1,-1 do
        if now-readyNotices[i].at>=cfg.readyBoxLinger+cfg.readyBoxFade then table.remove(readyNotices,i) end
    end
    local rows=readyNotices
    if preview then rows={{name='Meditate',at=now},{name='Third Eye',at=now}} end
    local size=cfg.readyBoxTextSize*h/1600
    local padding=12*h/1600
    local width=math.max(160*h/1600,measure('+Meditate',size)+padding*2)
    for _,e in ipairs(rows) do width=math.max(width,measure('+'..e.name,size)+padding*2) end
    readyBoxWidth=width;readyBoxHeight=math.max(1,#rows)*(size+6*h/1600)+padding*2
    if #rows==0 then return end
    local x,y=cfg.readyBoxX*w,cfg.readyBoxY*h
    local boxAlpha=0
    for _,e in ipairs(rows) do
        local age=math.max(0,now-e.at)
        local a=age<cfg.readyBoxLinger and 1 or (cfg.readyBoxFade>0 and math.max(0,1-(age-cfg.readyBoxLinger)/cfg.readyBoxFade) or 0)
        boxAlpha=math.max(boxAlpha,a)
    end
    dl:AddRectFilled({x-width/2,y},{x+width/2,y+readyBoxHeight},color({.06,.08,.09,.55*boxAlpha}),5)
    for i,e in ipairs(rows) do
        local age=math.max(0,now-e.at)
        local alpha=age<cfg.readyBoxLinger and 1 or (cfg.readyBoxFade>0 and math.max(0,1-(age-cfg.readyBoxLinger)/cfg.readyBoxFade) or 0)
        local pulse=age<.6 and math.sin(math.pi*age/.6)*cfg.readyBoxStrength or 0
        local c=cfg.cooldownGreen
        local label='+'..e.name
        text(dl,label,x-measure(label,size)/2,y+padding+(i-1)*(size+6*h/1600),size,
            {c[1]+(1-c[1])*pulse,c[2]+(1-c[2])*pulse,c[3]+(1-c[3])*pulse,alpha})
    end
end
local function drawCooldowns(dl,w,h,manager,player)
    if not cfg.showCooldowns and not cfg.showReadyBox then cooldownState=cooldowns.new();cooldownRows={};readyNotices={};return end
    local job=player:GetMainJob()
    if cooldownJob~=job then readyNotices={};cooldownState=cooldowns.new();cooldownJob=job end
    local active={}
    if preview then
        local examples={{'Meditate',135},{'Third Eye',42},{'Hasso',18},{'Seigan',6}}
        for i,e in ipairs(examples) do
            local ok,a=pcall(function() return AshitaCore:GetResourceManager():GetAbilityByName(e[1],2) end)
            active[i]={timer=i,id=ok and a and a.Id or 0,name=e[1],remaining=e[2]}
        end
    else
        if manager.GetRecast then
            local recast=manager:GetRecast()
            if recast then active=cooldowns.read(recast,AshitaCore:GetResourceManager(),player) end
        end
    end
    cooldownRows=cooldowns.update(cooldownState,active,os.clock(),cfg.cooldownFade,cfg.cooldownReadyLinger,cfg.cooldownBuffer/100)
    local now=os.clock()
    if not preview and cfg.showReadyBox then
        for _,e in ipairs(cooldownRows) do
            if e.justReady then
                for i=#readyNotices,1,-1 do if readyNotices[i].id==e.id then table.remove(readyNotices,i) end end
                readyNotices[#readyNotices+1]={id=e.id,name=e.name,at=now}
                if #readyNotices>6 then table.remove(readyNotices,1) end
            end
        end
    end
    drawReadyBox(dl,w,h,now)
    if not cfg.showCooldowns then return end
    local s=cfg.cooldownScale*h/1600
    local right,y=cfg.cooldownX*w,cfg.cooldownY*h
    local width,size=clamp(cfg.cooldownWidth,40,300)*s,cfg.cooldownTextSize*s
    local timerWidth=math.max(measure('00:00',size),measure('READY',size))
    local layoutWidth=width
    for _,e in ipairs(cooldownRows) do
        timerWidth=math.max(timerWidth,measure(cooldowns.format(e.remaining),size))
    end
    for _,e in ipairs(cooldownRows) do
        layoutWidth=math.max(layoutWidth,measure(e.name,size)+timerWidth+12*s)
    end
    cooldownLayoutWidth=layoutWidth
    local line=size
    local step=line+cfg.cooldownBarThickness*s+cfg.cooldownRowGap*s+5*s
    for i,e in ipairs(cooldownRows) do
        local top=y+(i-1)*step;local alpha=e.alpha
        local left=right-layoutWidth
        local timer=e.ready and 'READY' or cooldowns.format(e.remaining)
        local tint={.94,.96,1,alpha}
        if e.ready then
            local green=cfg.cooldownGreen
            local pulse=(e.pulse or 0)*cfg.cooldownPulseStrength
            tint={green[1]+(1-green[1])*pulse,green[2]+(1-green[2])*pulse,green[3]+(1-green[3])*pulse,alpha}
        end
        alignedText(dl,timer,right,top+(line-size)/2,size,tint)
        local nameRight=right-timerWidth-12*s
        local name=e.name
        alignedText(dl,name,nameRight,top+(line-size)/2,size,tint)
        local barLeft=right-width;local barY=top+line+5*s;local thickness=cfg.cooldownBarThickness*s
        if e.fraction>0 then
            local phase=cooldowns.phase(e.remaining)
            local c=phase=='green' and cfg.cooldownGreen or phase=='yellow' and cfg.cooldownYellow or cfg.cooldownRed
            if e.ready then
                -- A single bright flash across the completed bar; no empty track.
                local pulse=clamp((e.pulse or 0)*cfg.cooldownPulseStrength*3,0,1)
                c={c[1]+(1-c[1])*pulse,c[2]+(1-c[2])*pulse,c[3]+(1-c[3])*pulse,1}
            end
            dl:AddRectFilled({right-(right-barLeft)*e.fraction,barY},{right,barY+thickness},color({c[1],c[2],c[3],alpha}),thickness/2)
        end
    end
end
local centeredSliders={cooldownScale=true,cooldownWidth=true,cooldownTextSize=true,cooldownBarThickness=true,cooldownRowGap=true,cooldownFade=true,readyBoxTextSize=true,readyBoxLinger=true,readyBoxFade=true,readyBoxStrength=true,cooldownBuffer=true,cooldownReadyLinger=true,cooldownPulseStrength=true}
local function slider(label,key,lo,hi,format)
    imgui.Text(label)
    if imgui.SetNextItemWidth then imgui.SetNextItemWidth(-1) end
    local widget='##'..key
    local center=defaults[key]
    if centeredSliders[key] and center>lo and center<hi then
        local current=cfg[key]
        local normalized=current<=center and .5*(current-lo)/(center-lo) or .5+.5*(current-center)/(hi-center)
        local value={clamp(normalized,0,1)}
        local display=string.format(format or '%.2f',current)
        if imgui.SliderFloat(widget,value,0,1,display) then
            cfg[key]=value[1]<=.5 and lo+(center-lo)*value[1]*2 or center+(hi-center)*(value[1]-.5)*2
        end
    else
        local value={cfg[key]}
        if imgui.SliderFloat(widget,value,lo,hi,format or '%.2f') then cfg[key]=value[1] end
    end
end
local function checkbox(label,key)
    local value={cfg[key]}; if imgui.Checkbox(label,value) then cfg[key]=value[1] end
end
local function section(label)
    if imgui.CollapsingHeader then return imgui.CollapsingHeader(label) end
    imgui.Text(label);return true
end
local function configWindow()
    if not configOpen then return end
    local display=imgui.GetIO().DisplaySize
    imgui.SetNextWindowSize({math.min(720,display.x-40),math.min(700,display.y-80)},ImGuiCond_FirstUseEver)
    local open={true}
    if imgui.Begin('ArcRecast settings###arcrecast_settings',open) then
        checkbox('Show ArcRecast','enabled')
        imgui.SameLine()
        local p={preview}
        if imgui.Checkbox('Preview',p) then preview=p[1];readyNotices={};cooldownState=cooldowns.new() end
        if imgui.BeginTabBar('ArcRecastTabs') then
            if imgui.BeginTabItem('Cooldowns') then
                checkbox('Show cooldown list','showCooldowns')
                if cfg.showCooldowns then
                    slider('Overall size','cooldownScale',.1,4)
                    slider('Text size','cooldownTextSize',6,60,'%.0f')
                    slider('Bar width','cooldownWidth',40,300,'%.0f')
                    slider('Bar thickness','cooldownBarThickness',1,20,'%.0f')
                    slider('Space between abilities','cooldownRowGap',0,40,'%.0f')
                    slider('Bar remaining at 20s','cooldownBuffer',0,75,'%.0f%%')
                    imgui.TextWrapped('Longest cooldowns first. The bar reverses and fills over the final 20 seconds.')
                    if section('Completion') then
                        slider('Ready linger (seconds)','cooldownReadyLinger',0,5)
                        slider('Fade out (seconds)','cooldownFade',0,2)
                    end
                    if section('Position') then slider('Right edge X','cooldownX',0,1);slider('Top edge Y','cooldownY',0,1) end
                    if section('Countdown colors') then
                        imgui.ColorEdit4('1 minute or more',cfg.cooldownRed)
                        imgui.ColorEdit4('More than 20, under 60 seconds',cfg.cooldownYellow)
                        imgui.ColorEdit4('20 seconds or less',cfg.cooldownGreen)
                    end
                end
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem('Ready') then
                checkbox('Show ready notices','showReadyBox')
                if cfg.showReadyBox then
                    slider('Notice text size','readyBoxTextSize',12,100,'%.0f')
                    slider('Linger (seconds)','readyBoxLinger',0,5)
                    slider('Fade out (seconds)','readyBoxFade',0,2)
                    imgui.TextWrapped('Shows +AbilityName when a cooldown finishes. Multiple notices stack. The box hides when empty and works with the cooldown list hidden.')
                    if section('Position') then slider('Notice position X','readyBoxX',0,1);slider('Notice position Y','readyBoxY',0,1) end
                end
                imgui.EndTabItem()
            end
            if imgui.BeginTabItem('Alerts') then
                if cfg.showCooldowns then slider('Cooldown bar flash strength','cooldownPulseStrength',0,1) end
                if cfg.showReadyBox then slider('Ready notice flash strength','readyBoxStrength',0,1) end
                imgui.EndTabItem()
            end
            imgui.EndTabBar()
        end
        if imgui.Button('Close') then closeConfig() end
        if lastError and section('Diagnostics') then imgui.TextWrapped(lastError) end
    end
    imgui.End()
    if not open[1] then closeConfig() end
end
local function dragLayout(w,h)
    if not configOpen or not cfg.enabled then dragActive=false;return end
    local any=false
    local function label(dl,value,x,y) text(dl,value,x,y,18,{0.65,0.83,1,1}) end
    local function handle(id,name,x,y,width,height,xkey,ykey)
        local active=drag.handle(imgui,id,name,x,y,width,height,cfg,xkey,ykey,w,h,label)
        any=active or any
    end
    if cfg.showCooldowns then
        local cs=cfg.cooldownScale*h/1600
        local line=cfg.cooldownTextSize
        local rows=math.max(1,#cooldownRows)
        local width=math.max(clamp(cfg.cooldownWidth,40,300)*cs,cooldownLayoutWidth)
        handle('cooldowns','ABILITY COOLDOWNS',cfg.cooldownX*w-width,cfg.cooldownY*h,
            width,rows*(line+cfg.cooldownBarThickness+cfg.cooldownRowGap+5)*cs,'cooldownX','cooldownY')
    end
    if cfg.showReadyBox then
        handle('ready_box','READY NOTICES',cfg.readyBoxX*w-readyBoxWidth/2,cfg.readyBoxY*h,
            readyBoxWidth,readyBoxHeight,'readyBoxX','readyBoxY')
    end
    if dragActive and not any then settings.save() end
    dragActive=any
end
ashita.events.register('load','arcrecast_load',function() setupFont() end)
ashita.events.register('d3d_present','arcrecast_present',function()
    local ok,err=pcall(function()
        if not cfg.enabled then if configOpen then configWindow() end;return end
        local manager=AshitaCore:GetMemoryManager()
        local player=manager:GetPlayer()
        if not preview and (not GetPlayerEntity() or player:GetMainJob()==0 or player.isZoning) then
            readyNotices={};cooldownState=cooldowns.new();cooldownRows={};cooldownJob=nil
            if configOpen then configWindow() end
            return
        end
        local display=imgui.GetIO().DisplaySize
        local w,h=display.x,display.y
        if not w or not h or w<=0 or h<=0 then return end
        drawCooldowns(imgui.GetBackgroundDrawList(),w,h,manager,player)
        dragLayout(w,h)
        configWindow()
    end)
    if not ok then
        if lastError~=tostring(err) then print('[ArcRecast] '..tostring(err)) end
        lastError=tostring(err)
    end
end)
ashita.events.register('packet_in','arcrecast_zone',function(e)
    if e.injected then return end
    if e.id==0x00A or e.id==0x00B then
        readyNotices={};cooldownState=cooldowns.new();cooldownRows={};cooldownJob=nil
    end
end)
local function showHelp()
    print('[ArcRecast] '..addon.version..' by Mr.Bear')
    print('[ArcRecast] /arcrecast or /arcrecast config - Open/close settings.')
    print('[ArcRecast] /arcrecast preview - Toggle sample cooldowns.')
    print('[ArcRecast] /arcrecast toggle - Show/hide addon.')
    print('[ArcRecast] /arcrecast clear - Clear cooldown display history.')
    print('[ArcRecast] /arcrecast status - Show addon status.')
end
ashita.events.register('command','arcrecast_commands',function(e)
    local args={}
    for word in e.command:gmatch('%S+') do args[#args+1]=word end
    if not args[1] or args[1]:lower()~='/arcrecast' then return end
    e.blocked=true
    local cmd=(args[2] or 'config'):lower()
    if cmd=='help' then showHelp()
    elseif cmd=='config' then if configOpen then closeConfig() else configOpen=true end
    elseif cmd=='preview' then preview=not preview;readyNotices={};cooldownState=cooldowns.new();cooldownRows={}
    elseif cmd=='clear' then readyNotices={};cooldownState=cooldowns.new();cooldownRows={}
    elseif cmd=='toggle' then cfg.enabled=not cfg.enabled;settings.save()
    elseif cmd=='status' then print(string.format('[ArcRecast] %s; preview=%s; enabled=%s; last error=%s',addon.version,tostring(preview),tostring(cfg.enabled),lastError or 'none'))
    else print('[ArcRecast] Unknown command: '..cmd);showHelp() end
end)
ashita.events.register('unload','arcrecast_unload',function() settings.save() end)
