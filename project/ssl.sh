#!/bin/bash

. '../source/docker'
. '../source/domains'
. '../source/staging'

RSA_KEY_SIZE='4096'
CERTBOT_PATH='./certbot/conf'
STRING_DOMAINS="`sed 's/ /, /g' <<< "${DOMAINS[*]}"`"

echo '### SSL - Setup'

[ -d "$CERTBOT_PATH/" ] && {
	read -p '* Certbot path exists! Continue replacing? (y/N) '
	[ "${REPLY,,}" != 'y' ] && exit 1
}

read -p '* Admin email (blank for not use): '
[ "$REPLY" ] && EMAIL="$REPLY"

read -p "* RSA key size ($RSA_KEY_SIZE): "
[ "$REPLY" ] && RSA_KEY_SIZE="$REPLY"

echo '>> Creating necessary folders...'
mkdir -p ./certbot/{conf,www}/

SSL_NGINX_FILE="$CERTBOT_PATH/options-ssl-nginx.conf"
SSL_DHPARAMS_FILE="$CERTBOT_PATH/ssl-dhparams.pem"
[[ ! -f "$SSL_NGINX_FILE" || ! -f "$SSL_DHPARAMS_FILE" ]] && {
	echo '>> Downloading recommended files...'
	URL_PART='https://raw.githubusercontent.com/certbot/certbot/master'
	curl -fsSLo "$SSL_NGINX_FILE" "$URL_PART/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf"
	curl -fsSLo "$SSL_DHPARAMS_FILE" "$URL_PART/certbot/certbot/ssl-dhparams.pem"
}

echo ">> Creating dummy certificate for $STRING_DOMAINS..."
for domain in "${DOMAINS[@]}"; do
	mkdir -p "$CERTBOT_PATH/live/$domain/"
	DOMAIN_PATH="/etc/letsencrypt/live/$domain"
	$DOCKER run --rm --entrypoint " \
		openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1 \
			-keyout '$DOMAIN_PATH/privkey.pem' \
			-out '$DOMAIN_PATH/fullchain.pem' \
			-subj '/CN=#!COMMONNAME!#' \
	" certbot
done

echo '>> Starting Nginx container...'
$DOCKER up -d --build --force-recreate nginx

echo ">> Deleting dummy certificate for $STRING_DOMAINS..."
for domain in "${DOMAINS[@]}"; do
	rm -rf "$CERTBOT_PATH/live/$domain"
	rm -rf "$CERTBOT_PATH/archive/$domain"
	rm -rf "$CERTBOT_PATH/renewal/$domain.conf"
done

echo ">> Requesting Let's Encrypt certificate for $STRING_DOMAINS..."
for domain in "${DOMAINS[@]}"; do
	DOMAIN_ARGS+="-d '$domain' "
done
$DOCKER run --rm --entrypoint " \
	certbot certonly --webroot -w /var/www/certbot \
		--rsa-key-size $RSA_KEY_SIZE \
		--agree-tos \
		--force-renewal \
		$DOMAIN_ARGS \
		${IS_STAGING:+--staging} \
		`[ "$EMAIL" ] && echo "--email $EMAIL" || echo '--register-unsafely-without-email'` \
" certbot

echo ">> Restarting Nginx container..."
$DOCKER exec nginx nginx -s reload
