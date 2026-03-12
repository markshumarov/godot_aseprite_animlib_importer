@tool
extends EditorImportPlugin

func _get_importer_name() -> String: return "tactics.aseprite.animlib"
func _get_visible_name() -> String: return "Aseprite to AnimationLibrary"
func _get_recognized_extensions() -> PackedStringArray: return PackedStringArray(["ase", "aseprite"])
func _get_save_extension() -> String: return "res"
func _get_resource_type() -> String: return "AnimationLibrary"
func _get_preset_count() -> int: return 1
func _get_preset_name(preset_index: int) -> String: return "Default"
func _get_priority() -> float: return 2.0 
func _get_import_order() -> int: return 0

# Universal import settings available in the Inspector
func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{"name": "aseprite_executable", "default_value": "aseprite"},
		{"name": "sprite_node_path", "default_value": "Sprite2D"},
		{"name": "trigger_method", "default_value": "trigger_animation_phase"},
		{"name": "loop_animations", "default_value": "idle, run, walk"},
		{"name": "speed_modifiers", "default_value": "idle:1.5"},
		{"name": "fallback_triggers", "default_value": "charge"}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool: return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var ase_cmd = options["aseprite_executable"]
	var sprite_path = options["sprite_node_path"]
	var trigger_method = options["trigger_method"]
	
	# Parse user settings
	var loop_anims = _parse_csv(options["loop_animations"])
	var fallbacks = _parse_csv(options["fallback_triggers"])
	var speed_mods = _parse_dict(options["speed_modifiers"])
	
	var global_source = ProjectSettings.globalize_path(source_file)
	var temp_dir = OS.get_user_data_dir()
	
	var uid = str(Time.get_ticks_usec())
	var temp_lua = temp_dir.path_join("export_%s.lua" % uid)
	var temp_png = temp_dir.path_join("sheet_%s.png" % uid)
	var temp_json = temp_dir.path_join("data_%s.json" % uid)

	var lua_code = """
	local spr = app.activeSprite
	if not spr then return end
	app.command.ExportSpriteSheet{ui=false, type=SpriteSheetType.HORIZONTAL, textureFilename=app.params["png_path"]}
	local f = io.open(app.params["json_path"], "w")
	f:write('{"w":'..spr.width..',"h":'..spr.height..',"tags":[')
	for i, t in ipairs(spr.tags) do
		f:write('{"name":"'..t.name..'","from":'..(t.fromFrame.frameNumber-1)..',"to":'..(t.toFrame.frameNumber-1)..'}')
		if i < #spr.tags then f:write(',') end
	end
	f:write('],"frames":[')
	for i, fr in ipairs(spr.frames) do
		local ud = ""
		for j, lay in ipairs(spr.layers) do
			local cel = lay:cel(fr.frameNumber)
			if cel and cel.data and cel.data ~= "" then ud = cel.data break end
		end
		f:write('{"duration":'..fr.duration..',"userdata":"'..ud..'"}')
		if i < #spr.frames then f:write(',') end
	end
	f:write(']}')
	f:close()
	"""
	var f = FileAccess.open(temp_lua, FileAccess.WRITE)
	f.store_string(lua_code)
	f.close()

	var args = ["-b", global_source, "--script-param", "png_path=" + temp_png, "--script-param", "json_path=" + temp_json, "--script", temp_lua]
	
	var output = []
	var exit_code = OS.execute(ase_cmd, args, output, true)
	if exit_code != 0:
		printerr("Aseprite CLI Error: ", output)
		return ERR_CANT_CREATE

	var json_str = FileAccess.get_file_as_string(temp_json)
	var data = JSON.parse_string(json_str)
	var image = Image.load_from_file(temp_png)
	
	var texture = PortableCompressedTexture2D.new()
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)

	var anim_lib = AnimationLibrary.new()
	var hframes = image.get_width() / data["w"]
	var vframes = 1 

	for tag in data["tags"]:
		var anim_name = tag["name"]
		var anim = Animation.new()
		anim.step = 0.05
		
		var tex_track = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(tex_track, sprite_path + ":texture")
		anim.track_insert_key(tex_track, 0.0, texture)
		
		var h_track = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(h_track, sprite_path + ":hframes")
		anim.track_insert_key(h_track, 0.0, hframes)
		
		var v_track = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(v_track, sprite_path + ":vframes")
		anim.track_insert_key(v_track, 0.0, vframes)

		var frame_track = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(frame_track, sprite_path + ":frame")
		anim.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
		
		var method_track = anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(method_track, ".")

		# 1. Apply speed modifier if the animation name matches
		var speed_mult = 1.0
		for key in speed_mods.keys():
			if anim_name.contains(key):
				speed_mult = speed_mods[key]

		var current_time = 0.0
		var found_fallbacks = {}
		for fb in fallbacks:
			found_fallbacks[fb] = false
		
		for i in range(tag["from"], tag["to"] + 1):
			var frame_data = data["frames"][i]
			var duration = float(frame_data["duration"]) * speed_mult
			
			anim.track_insert_key(frame_track, current_time, i)
			
			var user_data = frame_data["userdata"].strip_edges()
			if user_data != "":
				if found_fallbacks.has(user_data):
					found_fallbacks[user_data] = true
					
				var method_key = {"method": trigger_method, "args": [tag["name"],user_data]}
				anim.track_insert_key(method_track, current_time, method_key)
				
			current_time += duration
			
		anim.length = current_time
		
		# 2. Inject missing triggers at frame 0
		for fb in fallbacks:
			if not found_fallbacks[fb]:
				var default_key = {"method": trigger_method, "args": [tag["name"],fb]}
				anim.track_insert_key(method_track, 0.0, default_key)
			
		# 3. Auto-looping based on name mask
		var should_loop = false
		for loop_name in loop_anims:
			if anim_name.contains(loop_name):
				should_loop = true
				break
				
		anim.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE
			
		anim_lib.add_animation(anim_name, anim)

	DirAccess.remove_absolute(temp_lua)
	DirAccess.remove_absolute(temp_png)
	DirAccess.remove_absolute(temp_json)

	return ResourceSaver.save(anim_lib, "%s.%s" % [save_path, _get_save_extension()])

# Utility functions for setting parsing
func _parse_csv(raw_str: String) -> Array:
	var result = []
	if raw_str.strip_edges() == "": return result
	for item in raw_str.split(","):
		result.append(item.strip_edges())
	return result

func _parse_dict(raw_str: String) -> Dictionary:
	var result = {}
	if raw_str.strip_edges() == "": return result
	for pair in raw_str.split(","):
		var parts = pair.split(":")
		if parts.size() == 2:
			result[parts[0].strip_edges()] = parts[1].to_float()
	return result
