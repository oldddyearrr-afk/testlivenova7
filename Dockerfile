FROM ubuntu:22.04

# تثبيت nginx و ffmpeg
RUN apt-get update && apt-get install -y \
    nginx ffmpeg curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# مجلد العمل
WORKDIR /app

# نسخ الملفات
COPY start.sh /app/start.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY hls /app/hls

RUN chmod +x /app/start.sh

EXPOSE 5000

CMD ["/app/start.sh"]
