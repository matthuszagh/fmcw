#!/bin/sh

ffmpeg -framerate 100 \
       -i img/range_%04d.png \
       -c:v libx264 \
       -profile:v high \
       -crf 20 \
       -pix_fmt yuv420p mov.mp4
