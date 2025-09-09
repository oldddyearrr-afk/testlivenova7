
#!/bin/bash

# تثبيت FFmpeg وNginx
echo "📦 Installing dependencies for Render..."
apt-get update && apt-get install -y ffmpeg nginx curl

# إنشاء المجلدات المطلوبة
mkdir -p stream/hls stream/logs
mkdir -p /var/log/nginx /var/lib/nginx /run
chmod +x perfect_stream.sh
chmod 755 stream/hls

# تشغيل السكريبت الرئيسي
exec ./perfect_stream.sh
