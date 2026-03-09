// =========================================================================
// PARAMETRIC ONE-TIME MOUTHPIECE ARRAY
// Designed for fast printing, custom PEZAZ, and anti-sharp edges
// =========================================================================

/* [Print & Slicer Geometry] */
// Your nozzle size. Used to calculate optimal wall thickness and chamfers.
nozzle_diameter = 0.4;       // [0.2:0.1:1.0]

// Layer height for the base sheet and general printing
layer_height = 0.2;          // [0.1:0.04:0.6]

// How many perimeters thick is the mouthpiece wall?
wall_perimeters = 2;         // [1:1:5]

// How many layers thick is the break-away base sheet?
base_sheet_layers = 1;       // [1:1:5]

/* [Mouthpiece Dimensions] */
// Total height of the mouthpiece
height = 42;                 // [20:1:60]

// The diameter of the wider side
wide_diameter = 14;          // [8:0.5:25]

// The diameter of the thinner side
thin_diameter = 8;           // [5:0.5:20]

// Which end sits on the base sheet?
orientation = "wide_bottom"; // ["wide_bottom", "thin_bottom"]

/* [Hose Sealing] */
// Which end goes into or over the hose? This portion will be perfectly round for a good seal!
hose_end = "wide";           // ["wide", "thin"]

// How long should the perfectly round sealing portion be?
hose_grip_length = 12;       // [5:1:30]

/* [Grid & Array Layout] */
columns = 4;                 // [1:1:12]
rows = 4;                    // [1:1:12]
// Spacing between centers
spacing_x = 18;              // [10:1:35]
spacing_y = 18;              // [10:1:35]

/* [PEZAZ & Enhancements] */
// Choose the aesthetic style of your mouthpiece!
style = "Ergonomic_Flare";   // ["Classic", "Twisted_Hex", "Ribbed", "Ergonomic_Flare", "Whistle_Flat"]

// For Twisted_Hex, how much should it twist?
twist_angle = 90;            // [0:15:360]

// Tuck the sharp edge inward so when snapped off the sheet, the lip is safe and smooth.
anti_sharp_edge = true;

/* [Performance] */
// Curve detail. 'Draft' drastically improves F6 Render speeds on large grids!
resolution = 36;             // [24:Draft (Fastest), 36:Standard, 72:High, 120:Ultra (Slow)]

/* [Hidden] */
$fn = max(min(resolution, 120), 24);
wall_thickness = nozzle_diameter * wall_perimeters;
sheet_thickness = layer_height * base_sheet_layers;

// Derived bottom and top diameters based on orientation
d_bottom_out = (orientation == "wide_bottom") ? wide_diameter : thin_diameter;
d_top_out    = (orientation == "wide_bottom") ? thin_diameter : wide_diameter;

d_bottom_in  = d_bottom_out - (2 * wall_thickness);
d_top_in     = d_top_out - (2 * wall_thickness);


// --------------------------------------------------------------------------
// MAIN ASSEMBLY
// --------------------------------------------------------------------------
union() {
    grid_sheet();
    mouthpiece_array();
}


// --------------------------------------------------------------------------
// MODULE: BASE SHEET
// The thin single-layer (or multi-layer) brim sheet holding them all
// --------------------------------------------------------------------------
module grid_sheet() {
    difference() {
        // Center the entire sheet
        translate([-spacing_x/2, -spacing_y/2, 0])
            cube([spacing_x * columns, spacing_y * rows, sheet_thickness]);
            
        // Cut out the inner holes for breathability/cleaning while in the sheet
        for (x = [0 : columns - 1]) {
            for (y = [0 : rows - 1]) {
                translate([x * spacing_x, y * spacing_y, -0.1])
                    linear_extrude(height=sheet_thickness + 0.2)
                        base_shape_2d(is_inner=true);
            }
        }
    }
}

// --------------------------------------------------------------------------
// MODULE: EXACT BASE SHAPE 2D
// Calculates the math for the exact 2D outline at z=0 (used for sheet cuts & chamfers)
// --------------------------------------------------------------------------
module base_shape_2d(is_inner) {
    is_hose_bottom = (hose_end == "wide" && orientation == "wide_bottom") || 
                     (hose_end == "thin" && orientation == "thin_bottom");
                     
    D = is_inner ? d_bottom_in : d_bottom_out;
    t_pezaz_raw = is_hose_bottom ? 
                  (0 - hose_grip_length) / max(0.1, height - hose_grip_length) :
                  (height - 0 - hose_grip_length) / max(0.1, height - hose_grip_length);
                  
    t_pezaz = max(0, min(1, t_pezaz_raw));
    t_ease = t_pezaz * t_pezaz * (3 - 2 * t_pezaz);
    radial_pts = max(12, round($fn / 12) * 12);
    
    if (style == "Classic" || style == "Ergonomic_Flare") {
        circle(d=D, $fn=$fn);
    } else {
        polygon([
            for (j = [0 : radial_pts - 1])
                let (
                    ang = j * (360 / radial_pts),
                    r = (style == "Twisted_Hex") ? 
                        let (
                            theta_mod = ((ang + 360000) + 30) % 60 - 30,
                            r_hex = (D/2) / cos(theta_mod)
                        )
                        (D/2) * (1 - t_ease) + r_hex * t_ease
                    : (style == "Ribbed") ?
                        let (
                            wave_depth = wall_thickness * 0.7,
                            eff_wave_depth = wave_depth * t_ease
                        )
                        (D/2) + (eff_wave_depth/2) * sin(ang * 12)
                    : (style == "Whistle_Flat") ?
                        let (
                            a = (D/2) * (1 + 0.8 * t_ease), 
                            b = (D/2) * (1 - 0.5 * t_ease)
                        )
                        (a * b) / sqrt( (b * cos(ang))^2 + (a * sin(ang))^2 )
                    : D/2
                )
                [r * cos(ang), r * sin(ang)]
        ]);
    }
}

// --------------------------------------------------------------------------
// MODULE: ARRAY GENERATOR
// Instances the selected core shape across the grid
// --------------------------------------------------------------------------
module mouthpiece_array() {
    for (x = [0 : columns - 1]) {
        for (y = [0 : rows - 1]) {
            translate([x * spacing_x, y * spacing_y, 0])
                render_piece();
        }
    }
}

// --------------------------------------------------------------------------
// MODULE: SINGLE PIECE LOGIC
// Adds the anti-sharp chamfer to the selected shape
// --------------------------------------------------------------------------
module render_piece() {
    difference() {
        // Build the outer shell minus the inner hole
        core_shape();
        
        // Anti-sharp bottom chamfer (Elephant Foot & Burr Compensation)
        // We cut away an inverted wedge at the bottom external perimeter
        // so that the fracture point is shielded safely inward, avoiding lip scrapes.
        if (anti_sharp_edge) {
            chamfer_depth = min(nozzle_diameter * 1.5, wall_thickness * 0.7);
            chamfer_h = min(layer_height * 3, 1.0);
            
            // By making the cutter an extremely wide shape, it safely trims off Hex corners
            // and Ribs without leaving any horizontal steps, gracefully surfacing out of the walls.
            difference() {
                translate([0,0,-0.1]) 
                    cylinder(d=d_bottom_out * 4, h=chamfer_h + 0.1, $fn=$fn);
                    
                // The scaled 2D outline cutter (acts like a tapered cone that matches the base shape!)
                translate([0,0,-0.2]) 
                    linear_extrude(height=chamfer_h + 0.2, scale=(d_bottom_out * 2) / (d_bottom_out - 2*chamfer_depth))
                        scale((d_bottom_out - 2*chamfer_depth) / d_bottom_out)
                        base_shape_2d(is_inner=false);
            }
        }
    }
}

// --------------------------------------------------------------------------
// MODULE: CORE SHAPES (PEZAZ LIBRARY)
// --------------------------------------------------------------------------
module core_shape() {

    if (style == "Classic") {
        difference() {
            cylinder(d1=d_bottom_out, d2=d_top_out, h=height, $fn=$fn);
            
            translate([0,0,-0.1]) 
                cylinder(d1=d_bottom_in, d2=d_top_in, h=height+0.2, $fn=$fn);
        }
    }
    
    else if (style == "Twisted_Hex" || style == "Ribbed" || style == "Whistle_Flat") {
        difference() {
            pezaz_polyhedron(is_inner=false);
            pezaz_polyhedron(is_inner=true);
        }
    }
    
    else if (style == "Ergonomic_Flare") {
        // Build an elegant curved profile using rotate_extrude and a stitched procedural polygon!
        // This ensures constant scaled wall transitions without hard cone angles.
        outer_curve = [ 
            for (z=[0 : 0.5 : height]) 
                let (
                    t = z/height,
                    // Ease-in-out cubic smoothing function
                    t_flare = t * t * (3 - 2 * t), 
                    r = (d_bottom_out/2) * (1 - t_flare) + (d_top_out/2) * t_flare
                ) [r, z] 
        ];
        
        inner_curve = [ 
            for (z=[height : -0.5 : 0]) 
                let (
                    t = z/height,
                    t_flare = t * t * (3 - 2 * t), 
                    r = (d_bottom_in/2) * (1 - t_flare) + (d_top_in/2) * t_flare
                ) [r, z] 
        ];
        
        rotate_extrude($fn=$fn)
            polygon(concat(outer_curve, inner_curve));
    }
}

// --------------------------------------------------------------------------
// MODULE: PEZAZ POLYHEDRON (DYNAMIC LOFTING)
// Smoothly morphs from a perfect circle (for hose sealing) into the Pezaz shape
// --------------------------------------------------------------------------
module pezaz_polyhedron(is_inner) {
    // Vastly improved rendering speeds by scaling slices efficiently and reducing point loops
    slices = max(15, floor(height / 2)); // 1 vertical slice per ~2mm is plenty for smooth sweeps
    radial_pts = max(12, round($fn / 12) * 12); // Must divide evenly by 12 for Hex/Ribbed symmetry
    
    // Map diameters properly for boolean operations
    d_bottom = is_inner ? d_bottom_in : d_bottom_out;
    d_top    = is_inner ? d_top_in : d_top_out;
    
    h_total = is_inner ? height + 0.2 : height;
    z_shift = is_inner ? -0.1 : 0;
    
    points_array = [
        for (i = [0 : slices]) 
            for (j = [0 : radial_pts - 1])
                let (
                    // We map z to the true height so interpolations exactly match inner and outer geometry
                    local_z = i * (h_total / slices),
                    true_z = local_z + z_shift, 
                    t_z = true_z / height, 
                    
                    // Base circular radius interpolation
                    D = d_bottom * (1 - t_z) + d_top * t_z,
                    
                    // Determine where the hose connection is globally
                    is_hose_bottom = (hose_end == "wide" && orientation == "wide_bottom") || 
                                     (hose_end == "thin" && orientation == "thin_bottom"),
                    
                    // Transition formula: how much of the "Pezaz" effect is applied here? (0 to 1)
                    t_pezaz_raw = is_hose_bottom ? 
                                  (true_z - hose_grip_length) / max(0.1, height - hose_grip_length) :
                                  (height - true_z - hose_grip_length) / max(0.1, height - hose_grip_length),
                                  
                    t_pezaz = max(0, min(1, t_pezaz_raw)),
                    
                    // Smooth S-curve easing for the 3D transition so it doesn't just "snap" into the pattern
                    t_ease = t_pezaz * t_pezaz * (3 - 2 * t_pezaz),
                    
                    ang = j * (360 / radial_pts),
                    
                    // Morphing Mathematical Radius
                    r = (style == "Twisted_Hex") ? 
                        let (
                            twist_ang = twist_angle * t_z,
                            eff_ang = ang - twist_ang,
                            shifted_ang = eff_ang + 360000,
                            theta_mod = (shifted_ang + 30) % 60 - 30,
                            r_hex = (D/2) / cos(theta_mod),
                            r_round = D/2
                        )
                        r_round * (1 - t_ease) + r_hex * t_ease
                    : (style == "Ribbed") ?
                        let (
                            wave_depth = wall_thickness * 0.7,
                            eff_wave_depth = wave_depth * t_ease,
                            r_star = (D/2) + (eff_wave_depth/2) * sin(ang * 12)
                        )
                        r_star
                    : (style == "Whistle_Flat") ?
                        let (
                            // Flattens into a sleek oval whistle outline on the non-hose end
                            a = (D/2) * (1 + 0.8 * t_ease), // Increase width 
                            b = (D/2) * (1 - 0.5 * t_ease), // Decrease height
                            r_flat = (a * b) / sqrt( (b * cos(ang))^2 + (a * sin(ang))^2 )
                        )
                        r_flat
                    : D/2
                )
                [r * cos(ang), r * sin(ang), true_z]
    ];
    
    faces_array = [
        // Side walls
        for (i = [0 : slices - 1])
            for (j = [0 : radial_pts - 1])
                let (
                    p0 = i * radial_pts + j,
                    p1 = i * radial_pts + (j + 1) % radial_pts,
                    p2 = (i + 1) * radial_pts + (j + 1) % radial_pts,
                    p3 = (i + 1) * radial_pts + j
                )
                [p0, p3, p2, p1],

        // Bottom cap (oriented properly)
        [ for (j = [0 : radial_pts - 1]) j ],

        // Top cap (oriented properly)
        [ for (j = [radial_pts - 1 : -1 : 0]) slices * radial_pts + j ]
    ];
    
    polyhedron(points=points_array, faces=faces_array);
}
