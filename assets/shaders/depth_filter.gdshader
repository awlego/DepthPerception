shader_type canvas_item;

uniform float depth : hint_range(0.0, 200.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec2 light_position = vec2(0.5, 0.5);  // Center position in UV coordinates (0-1)
uniform float light_radius : hint_range(0.0, 1.0) = 0.3;  // Size of the light circle
uniform float light_intensity : hint_range(0.0, 2.0) = 1.5;  // Brightness of the light
uniform float light_falloff : hint_range(1.0, 10.0) = 3.0;  // How soft/hard the light edge is

void fragment() {
    // Get screen texture using SCREEN_TEXTURE
    vec4 screen_texture = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    // Calculate proper aspect ratio for perfect circle
    float aspect_ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y; // width / height
    
    // Calculate distance with proper aspect ratio correction
    float dist_x = (SCREEN_UV.x - light_position.x) * aspect_ratio;
    float dist_y = SCREEN_UV.y - light_position.y;
    float distance_from_light = sqrt(dist_x * dist_x + dist_y * dist_y);
    
    // Calculate spotlight effect (1.0 at center, fading to 0.0 outside the radius)
    float spotlight = 1.0 - smoothstep(light_radius - (light_radius / light_falloff), 
                                      light_radius, 
                                      distance_from_light);
    
    // Calculate color filtered by depth
    vec4 depth_filtered_color = screen_texture;
    
    // Apply depth-based color filtering
    // Red disappears by ~30m
    depth_filtered_color.r = screen_texture.r * max(0.0, 1.0 - (depth / 30.0));
    // Green disappears by ~150m
    depth_filtered_color.g = screen_texture.g * max(0.0, 1.0 - (depth / 150.0));
    // Blue disappears by ~200m (lasts the longest)
    depth_filtered_color.b = screen_texture.b * max(0.0, 1.0 - (depth / 200.0));
    
    // Overall light attenuation from depth
    float overall_attenuation = max(0.2, 1.0 - (depth / 200.0));
    depth_filtered_color.rgb *= overall_attenuation;
    
    // Calculate true colors with brightness boost from flashlight
    vec4 true_color = screen_texture * min(1.0 + (spotlight * (light_intensity - 1.0)), 2.0);
    
    // Mix between true colors and depth-filtered colors based on spotlight
    // Spotlight center = true colors
    // Outside spotlight = depth-filtered colors
    vec4 final_color = mix(depth_filtered_color, true_color, spotlight * min(1.0, light_intensity));
    
    // Add slight ambient light outside spotlight area
    float ambient_light = max(0.5, 1.0 - (depth / 100.0));
    final_color.rgb = mix(final_color.rgb, depth_filtered_color.rgb * ambient_light, 1.0 - spotlight);
    
    COLOR = final_color;
}