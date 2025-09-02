FROM ubuntu:22.04

# تثبيت nginx و ffmpeg و curl
RUN apt-get update && apt-get install -y \
    nginx \
    ffmpeg \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# نسخ الملفات من الجذر
COPY start.sh /app/start.sh
COPY nginx.conf.template /app/nginx.conf.template
COPY hls /app/hls

RUN chmod +x /app/start.sh

# إنشاء مجلدات مؤقتة لـ nginx logs و temp
RUN mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

# فتح البورت (Koyeb يستخدم متغير PORT)
EXPOSE 80

# تشغيل start.sh عند بدء الحاوية
CMD ["/app/start.sh"]
