-- Start of Global Scope -------------------------------------------------------
local camera = nil
local cameraID = nil

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

local function startsWith(str, match)
    return str:sub(1, #match) == match
end

local function isRangerOrRuler(model)
    return startsWith(model, "Ranger") or startsWith(model, "Ruler")
end

local function connectToRangerOrRuler()
    -- Scan network and connect to the first available Ranger/Ruler camera.
    -- If reconnecting, find the previously connected camera.
    while camera == nil do
        print("Scanning for cameras..")
        local foundCameras = Image.Provider.GigEVision.Discovery.scanForCameras()
        if #foundCameras > 0 then
            for i = 1, 1, #foundCameras do
                print("Discovered camera: " .. foundCameras[i]:getID() .. " (" ..
                    foundCameras[i]:getAccessStatus() .. ")")
                if foundCameras[i]:getAccessStatus() == "AVAILABLE" then
                    if isRangerOrRuler(foundCameras[i]:getModel()) then
                        if cameraID == nil or cameraID == foundCameras[i]:getID() then
                            camera = Image.Provider.GigEVision.Ranger3.connectTo(foundCameras[i])
                            if camera == nil then
                                print("Failed to connect to " .. foundCameras[i]:getID())
                            else
                                break
                            end
                        end
                    end
                end
            end
        end
        if camera == nil then
            if cameraID == nil then
                print("Found no available Ranger/Ruler to connect to or failed to connect," ..
                    "re-scan in a few seconds..")
            else
                print("Could not find " .. cameraID .. " among discovered cameras or failed " ..
                    "to connect, re-scan in a few seconds..")
            end
            Script.sleep(5000)
        else
            if cameraID == nil then
                cameraID = camera:getID()
            end
            print("Connected to " .. cameraID)
        end
    end
end

local function registerEventHandler(event, handler)
    local ok = camera:register(event, handler)
    if ok == false then
        print("Error: failed to connect handler for event " .. event)
    end
    return ok
end

local function onNewFrame(frame)
    print("Frame received.")
    local image = frame:getRangeImage()
    -- Do something with image, then release frame buffer
    frame:release()

    camera:stop()
end

local function onLogMessage(cameraID, timestamp, level, msg)
    print("[" .. timestamp .. "] (" .. cameraID .. ") " .. level .. ": " .. msg)
end

local function onDisconnect(cameraID)
    print("Camera " .. cameraID .. " was disconnected")
    camera = nil
    main()
end

function main()
    -- Make sure we have a connected camera object
    connectToRangerOrRuler()

    -- Register event handlers
    local ok = true
    ok = ok and registerEventHandler("OnNewFrame", onNewFrame)
    ok = ok and registerEventHandler("OnLogMessage", onLogMessage)
    ok = ok and registerEventHandler("OnDisconnect", onDisconnect)

    if ok == true then
        -- Configure line scan in 3d mode
        local parameters = camera:getParameters()
        local ok = parameters:setEnum("DeviceScanType", "Linescan3D")
        if ok == false then
            print("Error: failed to set DeviceScanType")
        else
            -- Start image acqusition in 3D mode
            camera:start("PROFILE_3D_FRAME")
        end
    end
end

Script.register("Engine.OnStarted", main)

--End of Function and Event Scope-----------------------------------------------
