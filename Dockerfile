FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    nginx \
    ffmpeg \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# نسخ الملفات مباشرة من الجذر
COPY start.sh /app/start.sh
COPY nginx.conf.template /app/nginx.conf.template
COPY hls /app/hls

RUN chmod +x /app/start.sh

RUN mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

EXPOSE 80

CMD ["/app/start.sh"]
