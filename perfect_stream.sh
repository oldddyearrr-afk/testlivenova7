#!/bin/bash

# تنظيف شامل
echo "🧹 Multi-Stream cleanup..."
pkill -f nginx 2>/dev/null || true
pkill -f ffmpeg 2>/dev/null || true
sleep 3

# دالة قراءة ملف التكوين المبسط
load_streams_config() {
    local config_file="$WORK_DIR/streams.conf"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ ملف التكوين غير موجود: $config_file"
        exit 1
    fi
    
    declare -ga SOURCE_URLS=()
    declare -ga STREAM_NAMES=()
    
    echo "📖 قراءة ملف التكوين المبسط: $config_file"
    
    while IFS='|' read -r stream_name source_url; do
        # تجاهل الأسطر الفارغة والتعليقات
        if [[ -z "$stream_name" || "$stream_name" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # إزالة المسافات الزائدة
        stream_name=$(echo "$stream_name" | xargs)
        source_url=$(echo "$source_url" | xargs)
        
        if [[ -n "$stream_name" && -n "$source_url" ]]; then
            STREAM_NAMES+=("$stream_name")
            SOURCE_URLS+=("$source_url")
            echo "📺 تمت إضافة القناة: $stream_name"
        fi
    done < "$config_file"
    
    if [ ${#STREAM_NAMES[@]} -eq 0 ]; then
        echo "❌ لم يتم العثور على قنوات صالحة في ملف التكوين"
        exit 1
    fi
    
    echo "✅ تم تحميل ${#STREAM_NAMES[@]} قناة من ملف التكوين المبسط"
}

WORK_DIR="$(pwd)"
STREAM_DIR="$WORK_DIR/stream"
LOGS_DIR="$STREAM_DIR/logs"
NGINX_CONF="$WORK_DIR/nginx.conf"
PORT=${PORT:-10000}
HOST=${HOST:-0.0.0.0}

declare -a FFMPEG_PIDS=()
declare -a MONITOR_PIDS=()

# دالة تنظيف المجلدات غير المستخدمة
cleanup_unused_directories() {
    echo "🧹 تنظيف المجلدات غير المستخدمة..."
    
    # الحصول على قائمة المجلدات الموجودة
    if [ -d "$STREAM_DIR" ]; then
        for dir in "$STREAM_DIR"/hls_*; do
            if [ -d "$dir" ]; then
                # استخراج اسم القناة من المجلد
                folder_name=$(basename "$dir")
                stream_name_from_folder=${folder_name#hls_}
                
                # التحقق إذا كانت القناة موجودة في القائمة الحالية
                found=false
                for active_stream in "${STREAM_NAMES[@]}"; do
                    if [ "$stream_name_from_folder" = "$active_stream" ]; then
                        found=true
                        break
                    fi
                done
                
                # إذا لم توجد القناة في القائمة الحالية، احذف المجلد
                if [ "$found" = false ]; then
                    echo "🗑️ حذف مجلد غير مستخدم: $dir"
                    rm -rf "$dir" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    echo "✅ تم تنظيف المجلدات غير المستخدمة"
}

# تحميل إعدادات القنوات من ملف التكوين
load_streams_config

# تنظيف المجلدات غير المستخدمة بعد تحميل القنوات الجديدة
cleanup_unused_directories

echo "🚀 Ultra-Stable Multi-Stream Server v5.0"
echo "📁 Stream dir: $STREAM_DIR"
echo "🌐 Port: $PORT"
echo "📺 Streams: ${#SOURCE_URLS[@]}"

# دالة إنشاء nginx configuration ديناميكياً
generate_nginx_config() {
    echo "🔧 إنشاء nginx.conf ديناميكياً للقنوات ${#STREAM_NAMES[@]}..."
    
    cat > "$NGINX_CONF" << EOF
worker_processes auto;
error_log $WORK_DIR/stream/logs/nginx_error.log warn;
pid $WORK_DIR/stream/logs/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    types {
        text/html                             html htm;
        text/css                              css;
        application/javascript                js;
        application/vnd.apple.mpegurl         m3u8;
        video/mp2t                            ts;
        application/json                      json;
        application/octet-stream              bin;
    }
    default_type application/octet-stream;

    access_log $WORK_DIR/stream/logs/nginx_access.log;
    client_body_temp_path $WORK_DIR/stream/logs/client_temp;
    proxy_temp_path $WORK_DIR/stream/logs/proxy_temp;
    fastcgi_temp_path $WORK_DIR/stream/logs/fastcgi_temp;
    uwsgi_temp_path $WORK_DIR/stream/logs/uwsgi_temp;
    scgi_temp_path $WORK_DIR/stream/logs/scgi_temp;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 30;
    keepalive_requests 100;
    reset_timedout_connection on;

    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_comp_level 6;
    gzip_types text/plain application/vnd.apple.mpegurl video/mp2t application/json text/css application/javascript;

    server {
        listen $PORT;
        server_name _;
EOF

    # إضافة location blocks لكل قناة ديناميكياً
    for i in "${!STREAM_NAMES[@]}"; do
        local stream_name="${STREAM_NAMES[$i]}"
        cat >> "$NGINX_CONF" << STREAMEOF

        # Stream: $stream_name
        location /hls_$stream_name/ {
            alias $WORK_DIR/stream/hls_$stream_name/;

            add_header Access-Control-Allow-Origin "*" always;
            add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Range" always;
            add_header Accept-Ranges "bytes";

            location ~* \.m3u8$ {
                add_header Cache-Control "no-cache, no-store, must-revalidate";
                add_header Pragma "no-cache";
                add_header Expires "0";
                add_header X-Accel-Buffering "no";
                expires off;
            }

            location ~* \.ts$ {
                add_header Cache-Control "public, max-age=4";
                add_header X-Accel-Buffering "no";
                expires 4s;
                sendfile on;
                tcp_nopush off;
            }
        }
STREAMEOF
    done

    # إضافة الأجزاء الثابتة المتبقية
    cat >> "$NGINX_CONF" << 'EOF'

        # API for stream status
        location /api/status {
            return 200 '{"status":"running","server":"dynamic-multi-stream-server"}';
            add_header Content-Type application/json;
        }

        # Simple main page
        location / {
            return 200 'the broadcast is on';
            add_header Content-Type text/plain;
        }

        # Health check endpoint
        location /health {
            return 200 'OK - Dynamic Multi-Stream Server Running';
            add_header Content-Type text/plain;
        }
    }
}
EOF

    echo "✅ تم إنشاء nginx.conf مع ${#STREAM_NAMES[@]} قناة"
}


# إنشاء nginx configuration ديناميكياً
generate_nginx_config

# إنشاء المجلدات المطلوبة لكل بث
mkdir -p "$LOGS_DIR" 2>/dev/null || true
mkdir -p "$LOGS_DIR/client_temp" "$LOGS_DIR/proxy_temp" "$LOGS_DIR/fastcgi_temp" "$LOGS_DIR/uwsgi_temp" "$LOGS_DIR/scgi_temp" 2>/dev/null || true

for i in "${!SOURCE_URLS[@]}"; do
    STREAM_NAME="${STREAM_NAMES[$i]}"
    HLS_DIR="$STREAM_DIR/hls_${STREAM_NAME}"

    echo "📁 Setting up stream: $STREAM_NAME"
    mkdir -p "$HLS_DIR" 2>/dev/null || true
    find "$HLS_DIR" -name "*.ts" -delete 2>/dev/null || true
    find "$HLS_DIR" -name "*.m3u8" -delete 2>/dev/null || true
done

rm -f "$LOGS_DIR"/*.log "$LOGS_DIR"/*.pid 2>/dev/null || true

echo "🌐 Starting nginx (multi-stream config)..."
nginx -c "$NGINX_CONF" &
NGINX_PID=$!
sleep 2

# دالة لبدء FFmpeg بإعدادات مبسطة للغاية
start_ffmpeg() {
    local stream_index=$1
    local source_url="${SOURCE_URLS[$stream_index]}"
    local stream_name="${STREAM_NAMES[$stream_index]}"
    local hls_dir="$STREAM_DIR/hls_${stream_name}"

    echo "📺 Starting $stream_name with ultra-simple settings..."
    
    ffmpeg -hide_banner -loglevel error \
        -fflags +genpts \
        -user_agent "Mozilla/5.0 (compatible; Stream/1.0)" \
        -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 \
        -reconnect_delay_max 3 \
        -rw_timeout 8000000 \
        -i "$source_url" \
        -c:v copy -c:a copy \
        -avoid_negative_ts make_zero \
        -f hls \
        -hls_time 8 \
        -hls_list_size 6 \
        -hls_flags delete_segments+independent_segments \
        -hls_segment_filename "$hls_dir/seg_%03d.ts" \
        -hls_delete_threshold 2 \
        "$hls_dir/playlist.m3u8" > "$LOGS_DIR/${stream_name}_ffmpeg.log" 2>&1 &

    local ffmpeg_pid=$!
    FFMPEG_PIDS[$stream_index]=$ffmpeg_pid
    echo "✅ $stream_name ultra-simple ready!"
}

# بدء جميع عمليات FFmpeg
for i in "${!SOURCE_URLS[@]}"; do
    start_ffmpeg $i
    sleep 1
done

echo "✅ Multi-Stream Server Running!"
echo "🌐 Web Interface: http://$HOST:$PORT"
for i in "${!STREAM_NAMES[@]}"; do
    echo "📺 Stream ${STREAM_NAMES[$i]}: http://$HOST:$PORT/hls_${STREAM_NAMES[$i]}/playlist.m3u8"
done
echo "📊 Total FFmpeg processes: ${#FFMPEG_PIDS[@]} | Nginx: $NGINX_PID"

# دالة مراقبة FFmpeg مبسطة
monitor_ffmpeg() {
    local stream_index=$1
    local stream_name="${STREAM_NAMES[$stream_index]}"
    local source_url="${SOURCE_URLS[$stream_index]}"
    local hls_dir="$STREAM_DIR/hls_${stream_name}"

    while true; do
        sleep 30
        if ! kill -0 ${FFMPEG_PIDS[$stream_index]} 2>/dev/null; then
            echo "🔄 $stream_name FFmpeg crashed, restarting..."
            ffmpeg -hide_banner -loglevel error \
                -fflags +genpts \
                -user_agent "Mozilla/5.0 (compatible; Stream/1.0)" \
                -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 \
                -reconnect_delay_max 3 \
                -rw_timeout 8000000 \
                -i "$source_url" \
                -c:v copy -c:a copy \
                -avoid_negative_ts make_zero \
                -f hls \
                -hls_time 8 \
                -hls_list_size 6 \
                -hls_flags delete_segments+independent_segments \
                -hls_segment_filename "$hls_dir/seg_%03d.ts" \
                -hls_delete_threshold 2 \
                "$hls_dir/playlist.m3u8" > "$LOGS_DIR/${stream_name}_ffmpeg.log" 2>&1 &
            FFMPEG_PIDS[$stream_index]=$!
            echo "✅ $stream_name restarted (PID: ${FFMPEG_PIDS[$stream_index]})"
        fi
    done
}



# بدء مراقبة مبسطة لكل بث
for i in "${!SOURCE_URLS[@]}"; do
    monitor_ffmpeg $i &
    MONITOR_PIDS[$i]=$!
    echo "📊 Started simple monitoring for ${STREAM_NAMES[$i]} (Monitor PID: ${MONITOR_PIDS[$i]})"
done

# دالة إيقاف محسنة
cleanup() {
    echo "🛑 Stopping all multi-stream services..."

    # إيقاف جميع عمليات FFmpeg
    for pid in "${FFMPEG_PIDS[@]}"; do
        kill $pid 2>/dev/null || true
    done

    # إيقاف جميع عمليات المراقبة
    for pid in "${MONITOR_PIDS[@]}"; do
        kill $pid 2>/dev/null || true
    done

    # إيقاف Nginx
    kill $NGINX_PID 2>/dev/null || true

    echo "✅ All multi-stream services stopped."
    exit 0
}

trap cleanup SIGTERM SIGINT

# حلقة رئيسية مع تقرير حالة دوري
while true; do
    sleep 30

    # تقرير حالة سريع كل 30 ثانية
    running_count=0
    for pid in "${FFMPEG_PIDS[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            ((running_count++))
        fi
    done

    echo "📊 Status: $running_count/${#FFMPEG_PIDS[@]} streams running"
done
