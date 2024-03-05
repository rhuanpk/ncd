#!/bin/bash

set -e
. ../bash/source

DOMAINS=('example.xyz' 'www.example.xyz') # your domains
RSA_KEY_SIZE='4096' # can change
IS_STAGING='true' # comment in production
#EMAIL='your@email.here' # uncomment for use
CERTBOT_PATH='./certbot/conf'
STRING_DOMAINS="`sed 's/ /, /g' <<< "${DOMAINS[*]}"`"

echo '### SSL - Setup'

[ -d "$CERTBOT_PATH/" ] && {
	read -p '* Certbot path exists! Continue replacing? (y/N) '
	[ "${REPLY,,}" != 'y' ] && exit 1
} || mkdir -p "$CERTBOT_PATH/"

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
			-subj '/CN=localhost' \
	" certbot
done

echo '>> Starting Nginx container...'
$DOCKER up -d --build nginx

echo ">> Deleting dummy certificate for $STRING_DOMAINS..."
for domain in "${DOMAINS[@]}"; do
	CONF_PATH="$CERTBOT_PATH"
	rm -rf "$CONF_PATH/live/$domain" && \
	rm -rf "$CONF_PATH/archive/$domain" && \
	rm -rf "$CONF_PATH/renewal/$domain.conf" \
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
		"${IS_STAGING:+--staging}" \
		"`[ -z "$EMAIL" ] && echo '--register-unsafely-without-email' || echo "--email $EMAIL"`" \
" certbot
echo

echo ">> Restarting Nginx container..."
$DOCKER exec nginx nginx -s reload
