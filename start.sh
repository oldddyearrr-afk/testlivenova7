#!/bin/bash

# دعم Koyeb PORT
PORT=${PORT:-80}

# إعداد متغيرات البيئة
export SOURCE_URL="http://188.241.219.157/ulke.bordo1453.befhjjjj/Orhantelegrammmm30conextionefbn/274122?token=ShJdY2ZmQQNHCmMZCDZXUh9GSHAWGFMD.ZDsGQVN.WGBFNX013GR9YV1QbGBp0QE9SWmpcXlQXXlUHWlcbRxFACmcDY1tXEVkbVAoAAQJUFxUbRFldAxdeUAdaVAFcUwcHAhwWQlpXQQMLTFhUG0FQQU1VQl4HWTsFVBQLVABGCVxEXFgeEVwNZgFcWVlZBxcDGwESHERcFxETWAxCCQgfEFNZQEBSRwYbX1dBVFtPF1pWRV5EFExGWxMmJxVJRlZKRVVaQVpcDRtfG0BLFU8XUEpvQlUVQRYEUA8HRUdeEQITHBZfUks8WgpXWl1UF1xWV0MSCkQERk0TDw1ZDBBcQG5AXVYRCQ1MCVVJ"

echo "🚀 Quick start enabled..."

# إنشاء مجلد البث بسرعة
mkdir -p hls

# تنظيف الملفات القديمة
find hls -name "*.ts" -delete 2>/dev/null || true
find hls -name "*.m3u8" -delete 2>/dev/null || true

# توليد nginx.conf من template لدعم $PORT
envsubst '$PORT' < /app/nginx.conf.template > /app/nginx.conf

# بدء FFmpeg في الخلفية
start_ffmpeg() {
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
}

start_ffmpeg

# مراقبة FFmpeg لإعادة التشغيل عند التوقف
monitor_ffmpeg() {
    while true; do
        if ! kill -0 $FFMPEG_PID 2>/dev/null; then
            echo "⚠️ FFmpeg stopped, restarting..."
            sleep 5
            rm -f hls/*.ts hls/*.m3u8
            start_ffmpeg
        fi
        sleep 15
    done
}

monitor_ffmpeg &

# تنظيف HLS بشكل دوري
cleanup_segments() {
    while true; do
        sleep 60
        find hls -name "segment*.ts" -mmin +10 -delete 2>/dev/null || true
    done
}

cleanup_segments &

# إنهاء الحاوية
cleanup() {
    echo "🛑 Stopping all services..."
    kill $FFMPEG_PID 2>/dev/null || true
    echo "✅ All services stopped."
    exit 0
}

trap cleanup SIGTERM SIGINT

# تشغيل Nginx كـ process الرئيسي للحاوية (بدون الخلفية)
echo "🚀 Starting Nginx on port ${PORT}..."
exec nginx -c /app/nginx.conf -g "daemon off;"
