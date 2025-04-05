shader_type canvas_item;

uniform float depth : hint_range(0.0, 200.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec2 light_position = vec2(0.5, 0.5);  // Center position in UV coordinates (0-1)
uniform float light_radius : hint_range(0.0, 0.5) = 0.17;  // Size of the light circle
uniform float light_intensity : hint_range(0.0, 1.0) = 1.0;  // Brightness of the light
uniform float light_falloff : hint_range(1.0, 5.0) = 1.5;  // How soft/hard the light edge is
uniform bool flashlight_on = false;


void fragment() {
    // Get screen texture using SCREEN_TEXTURE
    vec4 screen_texture = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    // Calculate color filtered by depth
    vec4 depth_filtered_color = screen_texture;
    
    // Apply depth-based color filtering
    // Red disappears by ~30m
    depth_filtered_color.r = screen_texture.r * max(0.0, 1.0 - (depth / 30.0));
    // Green disappears by ~150m
    depth_filtered_color.g = screen_texture.g * max(0.0, 1.0 - (depth / 150.0));
    // Blue disappears by ~200m
    depth_filtered_color.b = screen_texture.b * max(0.0, 1.0 - (depth / 200.0));
    
    vec4 final_color = depth_filtered_color;
    
    // Only apply flashlight effect if it's turned on
    if (flashlight_on) {
        // Calculate proper aspect ratio for perfect circle
        float aspect_ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y; // width / height
        
        // Calculate distance with proper aspect ratio correction
        float dist_x = (SCREEN_UV.x - light_position.x) * 1.0;
        float dist_y = (SCREEN_UV.y - light_position.y) * aspect_ratio;
        float distance_from_light = sqrt(dist_x * dist_x + dist_y * dist_y);
        
        // Calculate spotlight effect (1.0 at center, fading to 0.0 outside the radius)
        float spotlight = 1.0 - smoothstep(light_radius - (light_radius / light_falloff), 
                                          light_radius, 
                                          distance_from_light);
        
        // Calculate true colors with brightness boost from flashlight
        vec4 true_color = screen_texture;
        
        // Mix between true colors and depth-filtered colors based on spotlight
        // Spotlight center = true colors
        // Outside spotlight = depth-filtered colors
        final_color = mix(depth_filtered_color, true_color, spotlight * min(1.0, light_intensity));
    }
    
    COLOR = final_color;
}