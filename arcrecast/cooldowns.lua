-- Live recasts use Ashita's public IRecast API (ticks at 60 Hz).
local M={}
function M.new() return {entries={},sequence=0} end
function M.format(seconds)
    local n=math.max(0,math.ceil(seconds))
    if n>=60 then return string.format('%d:%02d',math.floor(n/60),n%60) end
    return string.format('%ds',n)
end
function M.update(state,active,now,fade,linger,buffer)
    linger=linger or 0
    for _,e in pairs(state.entries) do e.justReady=false end
    local seen={}
    for _,a in ipairs(active) do
        if a.remaining>0 and not seen[a.timer] then
            seen[a.timer]=true
            local e=state.entries[a.timer]
            if not e or e.finished then
                state.sequence=state.sequence+1
                e={order=state.sequence};state.entries[a.timer]=e
            end
            e.name=a.name;e.id=a.id;e.remaining=a.remaining
            e.finished=nil;e.ready=false;e.pulse=0;e.alpha=1
            e.fraction=M.fraction(a.remaining,buffer)
        end
    end
    local rows={}
    for timer,e in pairs(state.entries) do
        if not seen[timer] then
            e.justReady=e.finished==nil
            e.finished=e.finished or now;e.remaining=0;e.fraction=1
            local age=math.max(0,now-e.finished)
            e.ready=true
            e.pulse=age<.6 and math.sin(math.pi*age/.6) or 0
            e.alpha=age<linger and 1 or (fade>0 and math.max(0,1-(age-linger)/fade) or 0)
            if e.alpha<=0 then state.entries[timer]=nil end
        end
        if e.alpha>0 then rows[#rows+1]=e end
    end
    table.sort(rows,function(a,b)
        if a.remaining~=b.remaining then return a.remaining>b.remaining end
        return a.order<b.order
    end)
    return rows
end
function M.fraction(seconds,buffer)
    buffer=math.max(0,math.min(.95,buffer or .25))
    if seconds<=20 then return math.max(0,math.min(1,1-(seconds/20)*(1-buffer))) end
    return math.min(1,buffer+((seconds-20)/280)*(1-buffer))
end
function M.phase(seconds)
    if seconds<=20 then return 'green' end
    if seconds<60 then return 'yellow' end
    return 'red'
end
function M.read(recast,resources,player)
    local result={}
    for slot=0,31 do
        local timer=recast:GetAbilityTimerId(slot)
        local ticks=recast:GetAbilityTimer(slot)
        if (slot==0 or timer>0) and ticks>0 then
            local a=resources:GetAbilityByTimerId(timer)
            -- The shared two-hour slot must reflect the current main job.
            if slot==0 then
                local twohour={528,529,530,531,532,533,534,535,536,537,538,539,540,541,542,543,544,545,546,547}
                a=resources:GetAbilityById(twohour[player:GetMainJob()] or 0)
            end
            if a and a.Name and a.Name[1] and a.Name[1]~='' and a.Name[1]~='Unknown' then
                result[#result+1]={timer=timer,id=a.Id,name=a.Name[1],remaining=ticks/60}
            end
        end
    end
    return result
end
return M
