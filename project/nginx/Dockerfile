FROM alpine:latest as builder

RUN apk add --no-cache \
	build-base \
	pcre-dev \
	zlib-dev \
	openssl-dev \
	libxslt-dev \
	gd-dev \
	geoip-dev \
	curl

RUN wget -qO nginx.tar.gz "$( \
		curl -fsL 'https://nginx.org/en/download.html' \
		| sed 's~<a~\n&~g' \
		| grep -A2 'Stable version' \
		| sed -nE 's~^.*"(.*)".*$~https://nginx.org\1~p' \
		| tail -1 \
	)" \
	&& tar -zxvf nginx.tar.gz \
	&& cd nginx-*

RUN ./configure --with-stream --with-stream_ssl_preread_module \
	&& make \
	&& make install

FROM nginx:alpine

COPY --from=builder /usr/local/nginx/sbin/nginx /usr/sbin/nginx

EXPOSE 80/tcp

CMD ["nginx", "-g", "daemon off;"]
