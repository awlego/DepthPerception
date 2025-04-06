shader_type canvas_item;

// Depth and color parameters
uniform float distance : hint_range(0.0, 1000.0) = 0.0;   // How many meters away from the camera

// Movement parameters
uniform float wave_strength : hint_range(0.0, 0.1) = 0.003;  // How much the coral sways
uniform float wave_speed : hint_range(0.1, 2.0) = 0.5;      // How fast the coral sways
uniform float wave_offset = 0.0;                            // Phase offset for varied movement

// Flashlight parameters - now using global screen coordinates
uniform vec2 light_position = vec2(0.5, 0.5);  // Center position in UV coordinates (0-1)
uniform float light_radius : hint_range(0.0, 0.5) = 0.17;  // Size of the light circle
uniform float light_intensity : hint_range(0.0, 1.0) = 1.0;  // Brightness of the light
uniform float light_falloff : hint_range(1.0, 5.0) = 1.5;  // How soft/hard the light edge is
uniform bool flashlight_on = false;

// Additional parameters for proper global positioning
uniform vec2 sprite_world_position; // Sprite's position in world space
uniform vec2 sprite_size;          // Sprite's size in pixels
uniform vec2 screen_size;          // Screen size in pixels

void fragment() {
    // Apply wave distortion to UV coordinates
    vec2 wave_uv = UV;
    wave_uv.x += sin(wave_uv.y * 10.0 + TIME * wave_speed + wave_offset) * wave_strength;
    wave_uv.y += cos(wave_uv.x * 10.0 + TIME * wave_speed + wave_offset) * wave_strength;
    
    // Get the sprite's texture with the distorted UVs
    vec4 sprite_color = texture(TEXTURE, wave_uv);
    vec4 distance_filtered_color = sprite_color;

    // Apply distance-based color filtering
    // Red disappears by ~30m
    distance_filtered_color.r = sprite_color.r * max(0.0, 1.0 - (distance / 30.0));
    // Green disappears by ~150m
    distance_filtered_color.g = sprite_color.g * max(0.0, 1.0 - (distance / 150.0));
    // Blue disappears by ~200m
    distance_filtered_color.b = sprite_color.b * max(0.0, 1.0 - (distance / 200.0));

    // Final color starts as adjusted color (without flashlight effect)
    vec4 final_color = distance_filtered_color;
    
    // Only apply flashlight effect if it's turned on
    if (flashlight_on) {
        // Calculate the current fragment's position in screen space
        // Convert UV (0-1) to local pixel coordinates
        vec2 local_pixel_pos = UV * sprite_size;
        
        // Convert to world pixel coordinates by adding sprite position
        vec2 world_pixel_pos = sprite_world_position + local_pixel_pos;
        
        // Convert world position to screen UV space (0-1)
        vec2 screen_uv_pos = world_pixel_pos / screen_size;
        
        // Now calculate distance using screen coordinates
        float dist_x = (screen_uv_pos.x - light_position.x);
        float dist_y = (screen_uv_pos.y - light_position.y);
        float distance_from_light = sqrt(dist_x * dist_x + dist_y * dist_y);
        
        // Calculate spotlight effect
        float spotlight = 1.0 - smoothstep(light_radius - (light_radius / light_falloff),
                                          light_radius,
                                          distance_from_light);
        
        // Apply flashlight effect only where light hits
        float light_effect = spotlight * min(1.0, light_intensity);
        
        if (light_effect > 0.0) {
            // to debug, instead of mixing, let's just get full color if the flashlight is on
            // final_color = sprite_color;
            // Mix between distance-filtered color and original sprite color only where light hits
            final_color = mix(distance_filtered_color, sprite_color, light_effect);
        }
    }

    COLOR = final_color;
}