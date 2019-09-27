base_width = 81.0;
base_height = 62.0;
base_thickness = 6.35;
hole_diam = 6.5;
right_hole_y_offset = 19.1 / 2;
right_hole_x_offset = 64.7 / 2;
top_hole_x_offset = 25.4 / 2;
top_hole_y_offset = 44.5 / 2;
flange_width = 40.39;
flange_height = 20.19;
thickness = 5;
sec1_length = 2 * base_thickness;
sec2_width = 110.0;
sec2_height = 80.0;
sec2_zmax = 203.2;

// base
difference()
{
	// base
	translate([ -base_width / 2, -base_height / 2, 0 ])
	{
		cube([ base_width, base_height, base_thickness ]);
	}
	// top and bottom screw holes
	translate([ -top_hole_x_offset, -top_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	translate([ -top_hole_x_offset, top_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	translate([ top_hole_x_offset, top_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	translate([ top_hole_x_offset, -top_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	// left and right screw holes
	translate([ right_hole_x_offset, right_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	translate([ -right_hole_x_offset, right_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	translate([ right_hole_x_offset, -right_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	translate([ -right_hole_x_offset, -right_hole_y_offset, -0.1 ])
	{
		cylinder(h = base_thickness + 0.2, d = hole_diam, $fn = 100);
	}
	// flange
	translate([ -flange_width / 2, -flange_height / 2, -0.1 ])
	{
		cube([ flange_width, flange_height, base_thickness + 0.2 ]);
	}
}

// section 1
difference()
{
	translate([ -flange_width / 2 - thickness, -flange_height / 2 - thickness, base_thickness ])
	{
		cube([ flange_width + 2 * thickness, flange_height + 2 * thickness, sec1_length ]);
	}
	translate([ -flange_width / 2, -flange_height / 2, base_thickness - 0.1 ])
	{
		cube([ flange_width, flange_height, sec1_length + 0.2 ]);
	}
}

// section 2
points_outer = [
	[
		-flange_width / 2 - thickness, -flange_height / 2 - thickness, base_thickness +
		sec1_length
	],
	[
		-flange_width / 2 - thickness, flange_height / 2 + thickness, base_thickness +
		sec1_length
	],
	[
		flange_width / 2 + thickness, flange_height / 2 + thickness, base_thickness +
		sec1_length
	],
	[
		flange_width / 2 + thickness, -flange_height / 2 - thickness, sec1_length +
		base_thickness
	],
	[ -sec2_width / 2 - thickness, -sec2_height / 2 - thickness, sec2_zmax ],
	[ -sec2_width / 2 - thickness, sec2_height / 2 + thickness, sec2_zmax ],
	[ sec2_width / 2 + thickness, sec2_height / 2 + thickness, sec2_zmax ],
	[ sec2_width / 2 + thickness, -sec2_height / 2 - thickness, sec2_zmax ]
];

points_inner = [
	[ -flange_width / 2, -flange_height / 2, base_thickness + sec1_length ],
	[ -flange_width / 2, flange_height / 2, base_thickness + sec1_length ],
	[ flange_width / 2, flange_height / 2, base_thickness + sec1_length ],
	[ flange_width / 2, -flange_height / 2, base_thickness + sec1_length ],
	[ -sec2_width / 2, -sec2_height / 2, sec2_zmax ],
	[ -sec2_width / 2, sec2_height / 2, sec2_zmax ],
	[ sec2_width / 2, sec2_height / 2, sec2_zmax ],
	[ sec2_width / 2, -sec2_height / 2, sec2_zmax ]
];

difference()
{
	polyhedron(points_outer, faces = [
		[ 0, 4, 7, 3 ], [ 1, 5, 4, 0 ], [ 2, 6, 5, 1 ], [ 3, 7, 6, 2 ], [ 3, 2, 1, 0 ],
		[ 4, 5, 6, 7 ]
	]);
	polyhedron(points_inner, faces = [
		[ 3, 7, 4, 0 ], [ 0, 4, 5, 1 ], [ 1, 5, 6, 2 ], [ 2, 6, 7, 3 ], [ 0, 1, 2, 3 ],
		[ 7, 6, 5, 4 ]
	]);
}
