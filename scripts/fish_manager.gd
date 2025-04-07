extends Node2D
class_name FishManager

# New function to get all unique fish textures
func get_all_fish_textures():
    var all_textures = []
    
    # Go through the fish database and collect all unique texture paths
    for fish_data in fish_database:
        if "texture_path" in fish_data and fish_data.texture_path not in all_textures:
            all_textures.append(fish_data.texture_path)
            
    return all_textures 