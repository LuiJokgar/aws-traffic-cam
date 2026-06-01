#!/bin/bash

INGEST_URL="rtmps://"

ffmpeg \
  -f v4l2 \
  -input_format mjpeg \
  -video_size 1280x720 \
  -framerate 15 \
  -i /dev/video0 \
  -vcodec libx264 \
  -preset ultrafast \
  -tune zerolatency \
  -b:v 1500k \
  -maxrate 1500k \
  -bufsize 3000k \
  -pix_fmt yuv420p \
  -rtmp_live live \
  -f flv \
  "$INGEST_URL"