# One static page, so stable nginx is the whole runtime. The image EXPOSEs 80,
# which is how Dokku knows where to send dev.boyersoftware.com.
FROM nginx:1.30-alpine-slim
COPY index.html /usr/share/nginx/html/index.html
