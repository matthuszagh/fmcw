import animate;
import graph;
import fontsize;

size(20cm, 6cm, keepAspect=false);

file fin = input(".data/tx_line.dat").line();
real[][] data;
int i = 0;
for (real[] arr : fin) {
  data[i] = arr;
  i += 1;
}

int num_lines = data.length;
int[] xvals;
for (int i=0; i<data[0].length - 2; ++i) {
  xvals[i] = i;
}

animation A;

real trace_len = data[0].length;
real[] xaxis_ticks = {trace_len/4, trace_len/2, 3*trace_len/4, trace_len};

string xaxis_label(real x) {
  if (x == trace_len/4) {
    return "$l/4$";
  }
  if (x == trace_len/2) {
    return "$l/2$";
  }
  if (x == 3*trace_len/4) {
    return "$3l/4$";
  }
  return "$l$";
}

real vp = 5;
real[] yaxis_ticks = {0, vp/8, vp/4, 3*vp/8, vp/2, 5*vp/8};

string yaxis_label(real x) {
  if (x == 0) {
    return "$0$";
  }
  if (x == vp/8) {
    return "$V_0/8$";
  }
  if (x == vp/4) {
    return "$V_0/4$";
  }
  if (x == 3*vp/8) {
    return "$3V_0/8$";
  }
  if (x == vp/2) {
    return "$V_0/2$";
  }
  return "$5V_0/8$";
}

axis FullTB() {
  return new void(picture pic, axisT axis) {
    axis.type=Both;
    axis.value=pic.scale.y.T(yaxis_ticks[0]);
    axis.value2=pic.scale.y.T(yaxis_ticks[yaxis_ticks.length-1]);
    axis.side=right;
    axis.align=S;
    axis.position=0.5;
    axis.extend=false;
  };
}

axis FullLR() {
  return new void(picture pic, axisT axis) {
    axis.type=Both;
    axis.value=pic.scale.x.T(0);
    axis.value2=pic.scale.x.T(xaxis_ticks[xaxis_ticks.length-1]);
    axis.side=left;
    axis.align=W;
    axis.position=0.5;
    axis.extend=false;
  };
}

fixedscaling(pic=currentpicture, min=(0, 0), max=(data[0].length, 5*vp/8));
defaultpen(linewidth(0.75bp));
pen ax_pen = fontsize(10pt)+linewidth(0.5bp);

for (int i=0; i<num_lines; ++i) {
  save();
  path f = graph(xvals, data[i][2:]);
  draw(f);
  xaxis(
    L="$x$",
    p=ax_pen,
    axis=FullTB(),
    LeftTicks(Ticks=xaxis_ticks, ticklabel=xaxis_label),
    xmin=0,
    xmax=xaxis_ticks[xaxis_ticks.length-1]
  );
  yaxis(
    L="$V$",
    p=ax_pen,
    axis=FullLR(),
    RightTicks(Ticks=yaxis_ticks, ticklabel=yaxis_label),
    ymin=yaxis_ticks[0],
    ymax=yaxis_ticks[yaxis_ticks.length-1]
  );
  A.add();
  restore();
}

A.movie(loops=0, delay=10, options="-density 300 -quality 95");
