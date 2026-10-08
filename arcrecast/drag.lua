-- Small transparent ImGui windows capture mouse input only in edit mode.
local M={wasActive=false}
local function flag(name) return _G[name] or 0 end
function M.handle(imgui,id,label,left,top,width,height,cfg,xkey,ykey,screenW,screenH,drawLabel)
    local flags=flag('ImGuiWindowFlags_NoDecoration')+flag('ImGuiWindowFlags_NoMove')
        +flag('ImGuiWindowFlags_NoSavedSettings')+flag('ImGuiWindowFlags_NoBackground')
        +flag('ImGuiWindowFlags_NoNav')+flag('ImGuiWindowFlags_NoFocusOnAppearing')
        +flag('ImGuiWindowFlags_NoBringToFrontOnFocus')
    imgui.SetNextWindowPos({left,top},_G.ImGuiCond_Always or 1)
    imgui.SetNextWindowSize({width,height},_G.ImGuiCond_Always or 1)
    local active=false
    if imgui.Begin('##arcrecast_drag_'..id,true,flags) then
        imgui.SetCursorScreenPos({left,top})
        imgui.InvisibleButton('##move_'..id,{width,height})
        active=imgui.IsItemActive()
        if active then
            local delta=imgui.GetIO().MouseDelta
            cfg[xkey]=math.max(0.02,math.min(0.98,cfg[xkey]+delta.x/screenW))
            local minY,maxY=0.02,0.98
            cfg[ykey]=math.max(minY,math.min(maxY,cfg[ykey]+delta.y/screenH))
        end
        local dl=imgui.GetWindowDrawList()
        dl:AddRectFilled({left,top},{left+width,top+height},imgui.GetColorU32({0.47,0.77,0.93,active and 0.32 or 0.10}),4)
        dl:AddRect({left,top},{left+width,top+height},imgui.GetColorU32({0.47,0.77,0.93,active and 0.85 or 0.35}),4)
        drawLabel(dl,active and ('MOVING: '..label) or label,left+8,top+6)
    end
    imgui.End()
    return active
end
return M
