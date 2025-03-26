# Stage 1: Build PHP Extensions
FROM php:8.4-fpm-alpine as build

# Install dependencies for PHP extensions and Imagick
RUN apk add --no-cache \
    libpng-dev libjpeg-turbo-dev libfreetype-dev libzip-dev \
    libxml2-dev oniguruma-dev imagemagick imagemagick-dev curl bash \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd zip pdo pdo_mysql xml mbstring opcache \
    && pecl install imagick \
    && docker-php-ext-enable imagick

# Stage 2: Nginx and PHP Setup
FROM nginx:alpine

# Install curl
RUN apk add --no-cache curl

# Download and extract latest WordPress
RUN curl -o wordpress.tar.gz -L https://wordpress.org/latest.tar.gz \
    && tar -xzf wordpress.tar.gz -C /var/www/ \
    && mv /var/www/wordpress/* /var/www/html/ \
    && rm -rf /var/www/wordpress /var/www/latest.tar.gz

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /var/www/html
USER appuser

# Configure Nginx directly in the Dockerfile
RUN echo "server {\n \
    listen 80;\n \
    server_name localhost;\n \
    root /var/www/html;\n \
    index index.php index.html index.htm;\n \
    location / {\n \
        try_files \$uri \$uri/ /index.php?\$args;\n \
    }\n \
    location ~ \\.php\$ {\n \
        include fastcgi_params;\n \
        fastcgi_pass php-fpm:9000;\n \
        fastcgi_index index.php;\n \
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n \
    }\n \
    location ~ /favicon.ico {\n \
        log_not_found off;\n \
        access_log off;\n \
    }\n \
    location ~ /robots.txt {\n \
        allow all;\n \
        log_not_found off;\n \
        access_log off;\n \
    }\n \
}" > /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]

# Healthcheck to ensure Nginx is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1
