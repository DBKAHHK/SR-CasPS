-- This Lua runs in the client Lua runtime (via ClientDownloadData).
-- Edit this file to experiment with UI inspection or text replacement.

local function setTextComponent(path, newText)
    local obj = CS.UnityEngine.GameObject.Find(path)
    if not obj then
        print("[CastoricePS Lua] not found: " .. tostring(path))
        return false
    end

    -- Game uses LocalizedText in many places; fall back to TextMeshPro / UI.Text if needed.
    local localized = obj:GetComponentInChildren(typeof(CS.RPG.Client.LocalizedText))
    if localized then
        localized.text = newText
        return true
    end

    local tmp = obj:GetComponentInChildren(typeof(CS.TMPro.TMP_Text))
    if tmp then
        tmp.text = newText
        return true
    end

    local utext = obj:GetComponentInChildren(typeof(CS.UnityEngine.UI.Text))
    if utext then
        utext.text = newText
        return true
    end

    print("[CastoricePS Lua] no text component under: " .. tostring(path))
    return false
end

local function getTransformPath(t)
    if not t then return "" end
    local parts = {}
    while t do
        table.insert(parts, 1, t.name)
        t = t.parent
    end
    return table.concat(parts, "/")
end

local function dumpHierarchy(rootPath, maxDepth)
    maxDepth = maxDepth or 6
    local rootObj = CS.UnityEngine.GameObject.Find(rootPath)
    if not rootObj then
        print("[CastoricePS Lua] dumpHierarchy root not found: " .. tostring(rootPath))
        return
    end

    local function rec(tr, depth)
        if depth > maxDepth then return end
        print(string.rep("  ", depth) .. tr.name)
        for i = 0, tr.childCount - 1 do
            rec(tr:GetChild(i), depth + 1)
        end
    end

    print("[CastoricePS Lua] dumpHierarchy: " .. tostring(rootPath) .. " depth=" .. tostring(maxDepth))
    rec(rootObj.transform, 0)
end

local function findTransformsByName(name, limit)
    limit = limit or 20
    local results = 0
    local arr = CS.UnityEngine.Resources.FindObjectsOfTypeAll(typeof(CS.UnityEngine.Transform))
    for i = 0, arr.Length - 1 do
        local t = arr[i]
        if t and t.name == name then
            print("[CastoricePS Lua] found: " .. getTransformPath(t))
            results = results + 1
            if results >= limit then
                print("[CastoricePS Lua] find limit reached: " .. tostring(limit))
                break
            end
        end
    end
    if results == 0 then
        print("[CastoricePS Lua] name not found: " .. tostring(name))
    end
end

-- Example: replace texts
setTextComponent(
    "UIRoot/AboveDialog/BetaHintDialog(Clone)",
    "<color=#FF7BEA>CastoricePS is a free and open source software.</color>"
)

setTextComponent(
    "VersionText",
    "<color=#A675FF>HyacineLover | Based on DahliaSR | Discord.gg/dyn9NjBwzZ</color>"
)

-- UI debugging helpers:
-- dumpHierarchy("UIRoot", 4)
-- findTransformsByName("VersionText", 30)

