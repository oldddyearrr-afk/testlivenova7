#!/bin/bash

# دعم Koyeb PORT
PORT=${PORT:-80}

# إعداد متغيرات البيئة
export SOURCE_URL="http://188.241.219.157/ulke.bordo1453.befhjjjj/Orhantelegrammmm30conextionefbn/274122?token=ShJdY2ZmQQNHCmMZCDZXUh9GSHAWGFMD.ZDsGQVN.WGBFNX013GR9YV1QbGBp0QE9SWmpcXlQXXlUHWlcbRxFACmcDY1tXEVkbVAoAAQJUFxUbRFldAxdeUAdaVAFcUwcHAhwWQlpXQQMLTFhUG0FQQU1VQl4HWTsFVBQLVABGCVxEXFgeEVwNZgFcWVlZBxcDGwESHERcFxETWAxCCQgfEFNZQEBSRwYbX1dBVFtPF1pWRV5EFExGWxMmJxVJRlZKRVVaQVpcDRtfG0BLFU8XUEpvQlUVQRYEUA8HRUdeEQITHBZfUks8WgpXWl1UF1xWV0MSCkQERk0TDw1ZDBBcQG5AXVYRCQ1MCVVJ"

echo "🚀 Quick start enabled..."

# إنشاء مجلد البث بسرعة
mkdir -p hls

# تنظيف سريع للملفات القديمة
find hls -name "*.ts" -delete 2>/dev/null || true
find hls -name "*.m3u8" -delete 2>/dev/null || true

# توليد nginx.conf من template لدعم $PORT
envsubst '$PORT' < /app/nginx.conf.template > /app/nginx.conf

# تشغيل Nginx فوراً
nginx -c /app/nginx.conf -g "daemon off;" &
NGINX_PID=$!

# بدء سريع لـ FFmpeg
ffmpeg -hide_banner -loglevel error \
    -fflags +genpts+flush_packets \
    -avoid_negative_ts make_zero \
    -user_agent "VLC/3.0.16 LibVLC/3.0.16" \
    -reconnect 1 \
    -reconnect_at_eof 1 \
    -reconnect_streamed 1 \
    -reconnect_delay_max 2 \
    -rw_timeout 5000000 \
    -analyzeduration 500000 \
    -probesize 500000 \
    -thread_queue_size 512 \
    -i "$SOURCE_URL" \
    -c:v copy \
    -c:a copy \
    -f hls \
    -hls_time 3 \
    -hls_list_size 3 \
    -hls_flags delete_segments+independent_segments+omit_endlist \
    -hls_allow_cache 0 \
    -hls_segment_filename "hls/segment%03d.ts" \
    -start_number 0 \
    "hls/playlist.m3u8" &

FFMPEG_PID=$!

echo "✅ Stream server started successfully!"
echo "🌐 Access the stream at: http://0.0.0.0:${PORT}"
echo "📺 Direct M3U8 link: http://0.0.0.0:${PORT}/hls/playlist.m3u8"
echo "📊 FFmpeg PID: $FFMPEG_PID"
echo "🔧 Nginx PID: $NGINX_PID"

# مراقبة محسنة لـ FFmpeg
monitor_ffmpeg() {
    local restart_count=0
    while true; do
        if ! kill -0 $FFMPEG_PID 2>/dev/null; then
            restart_count=$((restart_count + 1))
            echo "⚠️ FFmpeg stopped (restart #$restart_count), restarting in 5 seconds..."
            sleep 5
            rm -f hls/*.ts hls/*.m3u8
            ffmpeg -hide_banner -loglevel info \
                -fflags +genpts \
                -avoid_negative_ts make_zero \
                -user_agent "VLC/3.0.16 LibVLC/3.0.16" \
                -multiple_requests 1 \
                -reconnect 1 \
                -reconnect_at_eof 1 \
                -reconnect_streamed 1 \
                -reconnect_delay_max 5 \
                -rw_timeout 10000000 \
                -analyzeduration 1000000 \
                -probesize 1000000 \
                -i "$SOURCE_URL" \
                -c:v copy \
                -c:a copy \
                -f hls \
                -hls_time 6 \
                -hls_list_size 5 \
                -hls_flags delete_segments+independent_segments \
                -hls_allow_cache 0 \
                -hls_segment_filename "hls/segment%03d.ts" \
                "hls/playlist.m3u8" &
            FFMPEG_PID=$!
            echo "🔄 FFmpeg restarted with PID: $FFMPEG_PID"
            if [ $restart_count -gt 3 ]; then
                echo "⏰ Too many restarts, waiting 30 seconds..."
                sleep 30
                restart_count=0
            fi
        fi
        sleep 15
    done
}

cleanup_segments() {
    while true; do
        sleep 60
        find hls -name "segment*.ts" -mmin +10 -delete 2>/dev/null || true
    done
}

monitor_ffmpeg &
MONITOR_PID=$!
cleanup_segments &
CLEANUP_PID=$!

cleanup() {
    echo "🛑 Stopping all services..."
    kill $FFMPEG_PID 2>/dev/null || true
    kill $NGINX_PID 2>/dev/null || true
    kill $MONITOR_PID 2>/dev/null || true
    kill $CLEANUP_PID 2>/dev/null || true
    echo "✅ All services stopped."
    exit 0
}

trap cleanup SIGTERM SIGINT

while true; do
    sleep 5
    if ! kill -0 $NGINX_PID 2>/dev/null; then
        echo "⚠️ Nginx stopped, restarting..."
        nginx -c /app/nginx.conf -g "daemon off;" &
        NGINX_PID=$!
    fi
done
