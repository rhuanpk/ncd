FROM alpine:latest as builder

RUN apk --update \
	add -u --no-cache \
		build-base \
		pcre-dev \
		zlib-dev \
		openssl-dev \
		curl

RUN wget -qO nginx.tar.gz "$( \
		curl -fsL 'https://nginx.org/en/download.html' \
		| sed 's~<a~\n&~g' \
		| grep -A2 'Stable version' \
		| sed -nE 's~^.*"(.*)".*$~https://nginx.org\1~p' \
		| tail -1 \
	)" \
	&& tar -zxvf nginx.tar.gz \
	&& cd nginx-* \
	&& ./configure \
		--with-stream \
		--with-stream_ssl_preread_module \
		--with-http_ssl_module \
	&& make \
	&& make install

FROM nginx:alpine

RUN apk --update add --no-cache pcre-dev

RUN mkdir -p /usr/local/nginx/conf \
	&& mkdir -p /usr/local/nginx/logs \
	&& ln -s /etc/nginx/nginx.conf /usr/local/nginx/conf/ \
	&& touch /usr/local/nginx/logs/error.log

COPY --from=builder /usr/local/nginx/sbin/nginx /usr/sbin/nginx

EXPOSE 80/tcp

CMD ["nginx", "-g", "daemon off;"]
