// =========================================================================
// HIGH-CAPACITY INJECTION MOLD (20G+ MACHINES)
// Multi-Cavity Hookah / Shisha Mouthpiece Tooling layout
// Built with Industrial Best Practices (3-Plate Foolproof Venting & Ejection)
// =========================================================================

/* [Mold Configuration] */
// Select which part to view or export for milling
part = "assembly"; // ["assembly", "cavity_plate_A", "core_plate_B", "cap_plate_C", "plastic_shot"]

// How many columns of mouthpieces? (Max out your machine capacity!)
columns = 5; // [1:1:10]

// How many rows of mouthpieces?
rows = 4; // [1:1:10]

// Inject structural plastic from BOTH sides of the cavity for faster fill rates
dual_gates = true;

// Shrinkage compensation (1.0 = 0%. PP is typically ~1.015, PLA ~1.002)
shrinkage = 1.015;

/* [Mouthpiece Re-created Settings] */
// Basic geometry (matched from the 3D print version)
height = 42;
wide_diameter = 14;
thin_diameter = 8;
wall_thickness = 1.2; // Optimized for Injection Molding

// --------------------------------------------------------------------------
// DERIVED MATH
// --------------------------------------------------------------------------
$fn = 60;
d_bottom_out = wide_diameter;
d_top_out = thin_diameter;
d_bottom_in = wide_diameter - (2 * wall_thickness);
d_top_in = thin_diameter - (2 * wall_thickness);

/* [Mold Block Dimensions & Best Practices] */
spacing_x = 22; // Increased slightly for runner & gate clearance
spacing_y = 22;

// Automatically calculate mold block dimensions based on your grid
mold_width = max(50, (columns - 1) * spacing_x + 45);
mold_depth = max(50, (rows - 1) * spacing_y + 35);

mold_height_A = height;      // Cavity side (Exact height of part for Through-Holes!)
mold_height_B = 25;          // Core side base (Bottom)
mold_height_C = 12;          // Cap Plate (The foolproof venting roof!)

// Industrial Interlock settings (Prevents Flash & Lateral Shift)
interlock_margin = 10;
interlock_depth = 6;
interlock_draft = 3; // Degrees

// --------------------------------------------------------------------------
// MAIN DISPATCHER
// --------------------------------------------------------------------------
scale([shrinkage, shrinkage, shrinkage]) {
    if (part == "assembly") {
        render_assembly();
    } else if (part == "cavity_plate_A") {
        // Rotated upside down so it lays flat on the bed
        translate([0, 0, mold_height_A]) rotate([180, 0, 0]) cavity_plate_A();
    } else if (part == "core_plate_B") {
        core_plate_B();
    } else if (part == "cap_plate_C") {
        // Flat on bed
        translate([0, 0, mold_height_C]) rotate([180, 0, 0]) cap_plate_C();
    } else if (part == "plastic_shot") {
        full_plastic_shot();
    }
}

// --------------------------------------------------------------------------
// MODULE: TOTAL ASSEMBLY VISUALIZATION
// --------------------------------------------------------------------------
module render_assembly() {
    // Top Plate C (Cap Plate) - Lifted high
    translate([0, 0, height + 40]) 
        color("DimGray", 1.0) cap_plate_C();

    // Middle Plate A (Cavity) - Raised up to view inside
    translate([0, 0, 20]) 
        color("LightSteelBlue", 0.4) cavity_plate_A();
        
    // Bottom Plate B (Core)
    translate([0, 0, -5])
        color("Silver", 1.0) core_plate_B();
        
    // The Injection Shot (The actual plastic you get out!)
    color("Red", 0.9) full_plastic_shot();
}

// --------------------------------------------------------------------------
// MODULE: PLATES
// --------------------------------------------------------------------------
module cavity_plate_A() {
    difference() {
        // The solid block
        translate([-mold_width/2, -mold_depth/2, 0])
            cube([mold_width, mold_depth, mold_height_A]);
            
        // 1. The Interlocking Pocket
        translate([-(mold_width-interlock_margin)/2, -(mold_depth-interlock_margin)/2, -0.1])
            linear_extrude(height=interlock_depth+0.1, scale=((mold_width-interlock_margin)-2*interlock_depth*tan(interlock_draft))/(mold_width-interlock_margin))
                square([mold_width-interlock_margin, mold_depth-interlock_margin]);
                
        // 2. Cavities (Machined ALL THE WAY THROUGH!)
        // Because mold_height_A == height, this naturally breaches the top of the block.
        array_loop() {
            translate([0,0,-0.1]) cylinder(d1=d_bottom_out, d2=d_top_out, h=mold_height_A+0.2, $fn=$fn);
        }
        
        // 2.5 Foolproof Venting (Scratches on the top roof surface)
        // Just scrape a line across the top of the block so air escapes underneath the Cap Plate!
        for(y = [0 : rows-1]) {
            translate([0, -(rows-1)*spacing_y/2 + y*spacing_y, mold_height_A])
                cube([mold_width+2, 2, 0.4], center=true); 
        }
        
        // 3. Parting Line Vents (Base air escape paths)
        parting_line_vents();
        
        // 4. Main Sprue Hole (From top nozzle directly down to the runner)
        translate([0, 0, -0.1])
            cylinder(d1=4, d2=8, h=mold_height_A+0.2, $fn=50);
            
        // 5. Alignment Pin holes
        alignment_pins(is_hole=true, block="A");
    }
}

module core_plate_B() {
    union() {
        difference() {
            // The solid block base
            translate([-mold_width/2, -mold_depth/2, -mold_height_B])
                cube([mold_width, mold_depth, mold_height_B]);
                
            // Runner Channels
            runner_system();
            
            // Cold slug well
            translate([0, 0, -4]) cylinder(d=5, h=4.1, $fn=20);
        }
        
        // 1. The Interlocking Boss
        intersection() {
            translate([-(mold_width-interlock_margin)/2, -(mold_depth-interlock_margin)/2, 0])
                linear_extrude(height=interlock_depth, scale=((mold_width-interlock_margin)-2*interlock_depth*tan(interlock_draft))/(mold_width-interlock_margin))
                    square([mold_width-interlock_margin, mold_depth-interlock_margin]);
                    
            difference() {
                translate([-mold_width, -mold_depth, 0]) cube([mold_width*2, mold_depth*2, mold_height_B]);
                translate([0,0, interlock_depth]) runner_system(); 
            }
        }
        
        // 2. The Core Pins!
        // These exactly reach the top of Plate A, forming the mouthpiece hole perfectly against Plate C
        array_loop() {
            cylinder(d1=d_bottom_in, d2=d_top_in, h=height, $fn=$fn);
        }
        
        // 3. Alignment Pins protruding up (Through A and C)
        alignment_pins(is_hole=false, block="B");
    }
}

module cap_plate_C() {
    difference() {
        // Flat steel slab that caps the through-holes in Plate A
        translate([-mold_width/2, -mold_depth/2, 0])
            cube([mold_width, mold_depth, mold_height_C]);
            
        // Nozzle Seating & Sprue continuation
        translate([0, 0, -0.1])
            cylinder(d1=8, d2=12, h=mold_height_C+0.2, $fn=50);
            
        // Alignment Pin holes
        alignment_pins(is_hole=true, block="C");
    }
}

// --------------------------------------------------------------------------
// MODULE: THE PLASTIC PART ENGINE
// --------------------------------------------------------------------------
module full_plastic_shot() {
    array_loop() {
        difference() {
            cylinder(d1=d_bottom_out, d2=d_top_out, h=height, $fn=$fn);
            translate([0,0,-0.1]) cylinder(d1=d_bottom_in, d2=d_top_in, h=height+0.2, $fn=$fn);
        }
    }
    
    runner_system();
    
    // The full Sprue through A and C
    translate([0, 0, 0])
        cylinder(d1=4, d2=12, h=mold_height_A + mold_height_C, $fn=50);
        
    translate([0, 0, -4]) cylinder(d=5, h=4, $fn=20);
}

// --------------------------------------------------------------------------
// MODULE: UTILITIES
// --------------------------------------------------------------------------
module array_loop() {
    start_x = -(columns - 1) * spacing_x / 2;
    start_y = -(rows - 1) * spacing_y / 2;
    for(x = [0 : columns-1]) {
        for(y = [0 : rows-1]) {
            translate([start_x + x*spacing_x, start_y + y*spacing_y, 0])
                children();
        }
    }
}

module runner_system() {
    start_x = -(columns - 1) * spacing_x / 2;
    start_y = -(rows - 1) * spacing_y / 2;
    runner_offset_x = (wide_diameter/2) + 4;
    
    min_x = min(0, start_x + (dual_gates ? -runner_offset_x : runner_offset_x));
    max_x = max(0, start_x + (columns-1)*spacing_x + runner_offset_x);
    x_len = max_x - min_x;
    if (x_len > 0) {
        translate([min_x + x_len/2, 0, 0])
             rotate([0, 90, 0]) cylinder(d=6, h=x_len + 6, center=true, $fn=24);
    }
    
    for(x = [0 : columns-1]) {
        px = start_x + x*spacing_x;
        sides = dual_gates ? [1, -1] : [1];
        for (side = sides) {
            runner_x = px + (runner_offset_x * side);
            if (rows > 1) {
                translate([runner_x, 0, 0]) 
                    rotate([-90, 0, 0]) cylinder(d=4.5, h=(rows-1)*spacing_y, center=true, $fn=24);
            }
            for(y = [0 : rows-1]) {
                py = start_y + y*spacing_y;
                gate_len = runner_offset_x - (wide_diameter/2) + 0.5;
                gate_center_x = px + (wide_diameter/2 + gate_len/2 - 0.25) * side;
                translate([gate_center_x, py, 0]) cube([gate_len, 2, 1.5], center=true);
            }
        }
    }
}

module parting_line_vents() {
    start_y = -(rows - 1) * spacing_y / 2;
    for(y = [0 : rows-1]) {
        py = start_y + y*spacing_y;
        translate([0, py, 0]) cube([mold_width+2, 4, 0.2], center=true); 
    }
}

module alignment_pins(is_hole, block="A") {
    dia = is_hole ? 6.2 : 6.0; 
    len = mold_height_A + mold_height_C; 
    
    offsets_x = [-mold_width/2 + 6, mold_width/2 - 6];
    offsets_y = [-mold_depth/2 + 6, mold_depth/2 - 6];
    
    for (x = offsets_x) {
        for (y = offsets_y) {
            translate([x, y, 0]) {
                if(is_hole) {
                    if (block == "C") {
                        translate([0,0,-0.1]) cylinder(d=dia, h=mold_height_C+0.2, $fn=30);
                    } else {
                        translate([0,0,-0.1]) cylinder(d=dia, h=mold_height_A+0.2, $fn=30);
                    }
                } else {
                    translate([0,0,-10]) cylinder(d=dia, h=len+10, $fn=30);
                }
            }
        }
    }
}
