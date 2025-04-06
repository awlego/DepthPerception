shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
    // Get screen texture using SCREEN_TEXTURE
    vec4 screen_texture = texture(SCREEN_TEXTURE, SCREEN_UV);
// Depth and color parameters
uniform float distance: hint_range(0.0, 1000) = 0.0;   // how many meters away from the camera the shader is

// Movement parameters
uniform float wave_strength : hint_range(0.0, 0.1) = 0.003;  // How much the coral sways
uniform float wave_speed : hint_range(0.1, 2.0) = 0.5;      // How fast the coral sways
uniform float wave_offset = 0.0;                            // Phase offset for varied movement

// Detail parameters
uniform float brightness : hint_range(0.5, 1.5) = 1.0;   // Overall brightness multiplier
uniform float contrast : hint_range(0.5, 1.5) = 1.0;     // Contrast adjustment

void fragment() {
    // Get screen texture using SCREEN_TEXTURE
    vec4 screen_texture = texture(SCREEN_TEXTURE, SCREEN_UV);

    // Calculate color filtered by distance
    vec4 distance_filtered_color = screen_texture;

    // Apply distance-based color filtering
    // Red disappears by ~30m
    distance_filtered_color.r = screen_texture.r * max(0.0, 1.0 - (distance / 30.0));
    // Green disappears by ~150m
    distance_filtered_color.g = screen_texture.g * max(0.0, 1.0 - (distance / 150.0));
    // Blue disappears by ~200m
    distance_filtered_color.b = screen_texture.b * max(0.0, 1.0 - (distance / 200.0));

    vec4 final_color = distance_filtered_color;
    
    // Output final color
    COLOR = final_color