# ======
# Build Nginx from source
# ======
FROM alpine:3.21 AS compile
ARG NGINX_VERSION=1.27.4

# Include dependencies
WORKDIR /home
ADD ./dependencies .

# Get required packages
RUN apk --update add make cmake g++ zlib-dev linux-headers pcre-dev openssl-dev gd-dev

# Get Nginx source code
RUN wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
RUN tar xvf nginx-$NGINX_VERSION.tar.gz

# Enable brotli compression
WORKDIR /home/ngx_brotli/deps/brotli/out
RUN cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
	-DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
	-DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
	-DCMAKE_INSTALL_PREFIX=./installed ..
RUN cmake --build . --config Release --target brotlienc

# Build Nginx from source (flags from brotli install instructions)
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

# Logs
WORKDIR /var/log/nginx
RUN touch /var/log/nginx/error.log
RUN touch /var/log/nginx/access.log



# ======
# Only include necessary files
# ======
FROM alpine:3.20.2 AS production

RUN apk update
RUN apk add pcre gd curl

# Compiled nginx files 
WORKDIR /etc/nginx
COPY --from=compile /etc/nginx .
COPY --from=compile /usr/sbin/nginx /usr/sbin/nginx
COPY --from=compile /var/log/nginx /var/log/nginx

# Logs
RUN ln -sf /dev/stdout /var/log/nginx/access.log 
RUN ln -sf /dev/stderr /var/log/nginx/error.log 

# Config
COPY src/nginx.conf nginx.conf
# COPY conf.d conf.d

# Startup
CMD nginx -g "daemon off;"



# ======
# Development build with untrusted localhost certificates
# ======
FROM production AS development

# SSL certificates
WORKDIR /etc/nginx/certs
RUN apk add openssl
RUN openssl req -x509 -out localhost.com.crt -keyout localhost.com.key \
			-newkey rsa:2048 -nodes -sha256 \
			-subj '/CN=localhost' -extensions EXT -config <( \
			printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
RUN apk del openssl

WORKDIR /etc/nginx