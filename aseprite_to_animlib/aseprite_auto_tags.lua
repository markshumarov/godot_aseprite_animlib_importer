local sprite = app.activeSprite
if not sprite then
    return app.alert("No active sprite found!")
end

local dlg = Dialog("Tagging and Cleanup")
dlg:number{ id="columns", label="Frames per row (columns):", text="8", decimals=0 }
dlg:button{ id="ok", text="Split and Clean", focus=true }
dlg:button{ id="cancel", text="Cancel" }
dlg:show()

if not dlg.data.ok then return end

local cols = dlg.data.columns
if cols <= 0 then
    return app.alert("The number of frames must be greater than zero!")
end

-- Helper function: checks if a frame is empty (transparent) across all layers
local function isFrameEmpty(spr, frameNum)
    for _, layer in ipairs(spr.layers) do
        local cel = layer:cel(frameNum)
        -- If the cel exists and contains opaque pixels, the frame is not empty
        if cel and not cel.image:isEmpty() then
            return false
        end
    end
    return true
end

app.transaction(function()
    local total_frames_initial = #sprite.frames
    local total_rows = math.ceil(total_frames_initial / cols)

    local current_start = 1
    local created_tags = {} -- Storage for created tags

    for i = 1, total_rows do
        -- Determine the last frame for the current row with out-of-bounds protection
        local end_frame = current_start + cols - 1
        if end_frame > #sprite.frames then
            end_frame = #sprite.frames
        end
        
        local valid_frames = end_frame - current_start + 1

        -- Iterate through the row's frames strictly backwards
        for f = end_frame, current_start, -1 do
            if isFrameEmpty(sprite, f) then
                sprite:deleteFrame(f)
                valid_frames = valid_frames - 1
            else
                -- Stop deleting once a frame with pixels is encountered
                break
            end
        end

        -- Create a tag if frames remain after trimming
        if valid_frames > 0 then
            local tag = sprite:newTag(current_start, current_start + valid_frames - 1)
            -- Temporary name
            tag.name = "Anim_" .. tostring(#created_tags + 1)
            
            if #created_tags % 2 == 0 then
                tag.color = Color{r=100, g=150, b=255}
            else
                tag.color = Color{r=255, g=150, b=100}
            end
            
            table.insert(created_tags, tag)
            -- Shift the start position for the next row
            current_start = current_start + valid_frames
        end
    end

    -- Renaming by position (Data-Driven logic)
    local num_tags = #created_tags
    if num_tags > 0 then
        created_tags[1].name = "idle"
    end
    if num_tags > 1 then
        created_tags[num_tags].name = "death"
    end
    if num_tags > 2 then
        created_tags[num_tags - 1].name = "hurt"
    end
end)