ARG ALPINE_VERSION=3.22.0
ARG MODULE_SOURCE=git

########################
# Get modules with git #
########################
FROM alpine:${ALPINE_VERSION} AS source-git
WORKDIR /home
RUN apk add --no-cache git
RUN git clone --recurse-submodules https://github.com/google/ngx_brotli /home/ngx_brotli
RUN git clone https://github.com/quictls/openssl

# TODO: Get from ./dependencies (raises fileNotFound: ngx_brotli/filter/config)

###########################
# Build Nginx from source #
###########################
FROM source-${MODULE_SOURCE} AS compile
ARG NGINX_VERSION=1.28.0

RUN apk --update add make cmake g++ zlib-dev linux-headers pcre-dev openssl-dev gd-dev

# Get Nginx source code
WORKDIR /home
RUN wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
RUN tar xvf nginx-$NGINX_VERSION.tar.gz

# Build brotli module
WORKDIR /home/ngx_brotli/deps/brotli/out
RUN cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
	-DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
	-DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
	-DCMAKE_INSTALL_PREFIX=./installed ..
RUN cmake --build . --config Release --target brotlienc

# Build Nginx from source with modules
WORKDIR /home/nginx-$NGINX_VERSION
RUN export CFLAGS="-m64 -march=native -mtune=native -Ofast -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections"
RUN export LDFLAGS="-m64 -Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections"
RUN ./configure \
	--add-module=/home/ngx_brotli \
	--prefix=/etc/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--sbin-path=/usr/sbin/nginx \
	--with-debug \
	--with-http_gzip_static_module \
	--with-http_image_filter_module \
	--with-http_v2_module \
	--with-http_v3_module \
	--with-cc-opt="-I../openssl/build/include" \
	--with-ld-opt="-L../openssl/build/lib"
RUN make && make install

# Setup container logging
WORKDIR /var/log/nginx
RUN touch /var/log/nginx/error.log
RUN touch /var/log/nginx/access.log

################################
# Only include necessary files #
################################
FROM alpine:${ALPINE_VERSION} AS base

RUN apk update
RUN apk add pcre gd

# Compiled nginx files 
WORKDIR /etc/nginx
COPY --from=compile /etc/nginx .
COPY --from=compile /usr/sbin/nginx /usr/sbin/nginx
COPY --from=compile /var/log/nginx /var/log/nginx

# Logs
RUN ln -sf /dev/stdout /var/log/nginx/access.log 
RUN ln -sf /dev/stderr /var/log/nginx/error.log 

# Config
# COPY src/nginx.conf nginx.conf

# Startup
CMD ["nginx", "-g", "daemon off;"]