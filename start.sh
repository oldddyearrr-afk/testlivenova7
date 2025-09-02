#!/bin/bash

export SOURCE_URL="http://188.241.219.157/ulke.bordo1453.befhjjjj/Orhantelegrammmm30conextionefbn/274122?token=..."

echo "🚀 Quick start enabled..."

mkdir -p /app/hls
rm -f /app/hls/*.ts /app/hls/*.m3u8

nginx -c /etc/nginx/nginx.conf -g "daemon off;" &
NGINX_PID=$!

ffmpeg -hide_banner -loglevel error \
    -fflags +genpts+flush_packets \
    -avoid_negative_ts make_zero \
    -user_agent "VLC/3.0.16 LibVLC/3.0.16" \
    -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 2 \
    -rw_timeout 5000000 \
    -analyzeduration 500000 \
    -probesize 500000 \
    -thread_queue_size 512 \
    -i "$SOURCE_URL" \
    -c:v copy -c:a copy \
    -f hls \
    -hls_time 3 -hls_list_size 3 \
    -hls_flags delete_segments+independent_segments+omit_endlist \
    -hls_allow_cache 0 \
    -hls_segment_filename "/app/hls/segment%03d.ts" \
    "/app/hls/playlist.m3u8" &

FFMPEG_PID=$!

monitor_ffmpeg() {
    while true; do
        if ! kill -0 $FFMPEG_PID 2>/dev/null; then
            echo "⚠️ FFmpeg stopped, restarting..."
            rm -f /app/hls/*.ts /app/hls/*.m3u8
            ffmpeg -hide_banner -loglevel info -i "$SOURCE_URL" -c:v copy -c:a copy -f hls \
                -hls_time 6 -hls_list_size 5 -hls_flags delete_segments+independent_segments \
                -hls_allow_cache 0 -hls_segment_filename "/app/hls/segment%03d.ts" \
                "/app/hls/playlist.m3u8" &
            FFMPEG_PID=$!
            echo "🔄 FFmpeg restarted with PID: $FFMPEG_PID"
        fi
        sleep 15
    done
}

monitor_ffmpeg &

cleanup() {
    kill $FFMPEG_PID 2>/dev/null || true
    kill $NGINX_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

while true; do sleep 5; done
