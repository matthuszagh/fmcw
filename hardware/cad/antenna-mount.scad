// plane
plane_x = 310;
plane_y = 210;
plane_z = 6.35;

diff_pad = 0.5;

// support
sup_x = plane_z;
sup_y = 50;
sup_z = 150;
wave_sup_ysep = 30;

// support joint
sup_jt_x = 5 * sup_x;
sup_jt_y = sup_y;
sup_jt_z = sup_z / 5;

// waveguide base
wave_base_x = 81;
wave_base_y = 62;

// waveguide
wave_x = 45;
wave_y = 25;
wave_insert_y = wave_y + 10;
wave_z = plane_z + 2 * diff_pad;
wave_sep = 190;
wave_offx = 60;
wave_offy = sup_y + wave_sup_ysep + (wave_base_y / 2);

// antenna screw holes
hole_diam = 6.5;
right_hole_offy = 19.1 / 2;
right_hole_offx = 64.7 / 2;
top_hole_offx = 25.4 / 2;
top_hole_offy = 44.5 / 2;

// pcb screw holes
pcb_hole_diam = 3.7;
pcb_xsep = 51;
pcb_small_ysep = 2.5;
pcb_large_ysep = 110.5;
pcb_xtra_yoff = 35;

function pt_from_mid(mid, dim) = mid - (dim / 2);

union()
{
	translate([ pt_from_mid(wave_offx / 2, sup_x), 0, 0 ]) { cube([ sup_x, sup_y, sup_z ]); }
	translate([ pt_from_mid(wave_offx / 2, sup_jt_x), 0, 0 ])
	{
		cube([ sup_jt_x, sup_jt_y, sup_jt_z ]);
	}
	translate([ pt_from_mid(plane_x - (wave_offx / 2), sup_x), 0, 0 ])
	{
		cube([ sup_x, sup_y, sup_z ]);
	}
	translate([ pt_from_mid(plane_x - (wave_offx / 2), sup_jt_x), 0, 0 ])
	{
		cube([ sup_jt_x, sup_jt_y, sup_jt_z ]);
	}
	difference()
	{
		// plane
		translate([ 0, 0, 0 ]) { cube([ plane_x, plane_y, plane_z ]); }
		// left waveguide slot
		translate([
			pt_from_mid(wave_offx, wave_x), pt_from_mid(wave_offy, wave_y), -diff_pad
		])
		{
			cube([ wave_x, wave_y, wave_z ]);
		}
		translate([ 0, pt_from_mid(wave_offy, wave_insert_y), -diff_pad ])
		{
			cube([ wave_offx - (wave_x / 2), wave_insert_y, wave_z ]);
		}
		// right waveguide slot
		translate([
			pt_from_mid(plane_x - wave_offx, wave_x), pt_from_mid(wave_offy, wave_y), -
			diff_pad
		])
		{
			cube([ wave_x, wave_y, wave_z ]);
		}
		translate([
			plane_x - (wave_offx - (wave_x / 2)), pt_from_mid(wave_offy, wave_insert_y),
			-diff_pad
		])
		{
			cube([ wave_offx - (wave_x / 2), wave_insert_y, wave_z ]);
		}
		// antenna mount screw holes
		// left side
		translate([ wave_offx - top_hole_offx, wave_offy + top_hole_offy, -diff_pad ])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([ wave_offx + top_hole_offx, wave_offy + top_hole_offy, -diff_pad ])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([ wave_offx - top_hole_offx, wave_offy - top_hole_offy, -diff_pad ])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([ wave_offx + top_hole_offx, wave_offy - top_hole_offy, -diff_pad ])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([ wave_offx + right_hole_offx, wave_offy + right_hole_offy, -diff_pad ])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([ wave_offx + right_hole_offx, wave_offy - right_hole_offy, -diff_pad ])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		// right side
		translate([
			plane_x - (wave_offx - top_hole_offx), wave_offy + top_hole_offy, -diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([
			plane_x - (wave_offx + top_hole_offx), wave_offy + top_hole_offy, -diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([
			plane_x - (wave_offx - top_hole_offx), wave_offy - top_hole_offy, -diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([
			plane_x - (wave_offx + top_hole_offx), wave_offy - top_hole_offy, -diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([
			plane_x - (wave_offx + right_hole_offx), wave_offy + right_hole_offy, -
			diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		translate([
			plane_x - (wave_offx + right_hole_offx), wave_offy - right_hole_offy, -
			diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = hole_diam, $fn = 100);
		}
		// pcb screw holes
		translate([
			(plane_x / 2) - (pcb_xsep / 2),
			pcb_xtra_yoff + (plane_y / 2) - (pcb_large_ysep / 2), -diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = pcb_hole_diam, $fn = 100);
		}
		translate([
			(plane_x / 2) - (pcb_xsep / 2),
			pcb_xtra_yoff + (plane_y / 2) + (pcb_large_ysep / 2), -diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = pcb_hole_diam, $fn = 100);
		}
		translate([
			(plane_x / 2) + (pcb_xsep / 2),
			pcb_xtra_yoff + (plane_y / 2) + (pcb_large_ysep / 2) - pcb_small_ysep, -
			diff_pad
		])
		{
			cylinder(h = plane_z + 2 * diff_pad, d = pcb_hole_diam, $fn = 100);
		}
	}
}
