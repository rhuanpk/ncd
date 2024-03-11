#!/bin/bash

. '../source/docker'
. '../source/domains'
. '../source/single' 2>&-
. '../source/staging' 2>&-

SOURCE_CERT='../source/cert'
SOURCE_GROUPS='../source/groups'
CERTBOT_CONF='./certbot/conf'

echo '### SSL - Setup'

read -p '* Admin email (blank for not use): '
[ "$REPLY" ] && EMAIL="$REPLY"

echo '>> Creating necessary folders...'
mkdir -p ./certbot/{conf,www}/

# step 1 - start nginx with sample http config
echo '>> Starting Nginx container...'
$DOCKER up -d --build --force-recreate nginx

# step 2 - request let's encrypt certificate
echo ">> Requesting Let's Encrypt certificate for `sed 's/ /, /g' <<< "${DOMAINS[*]}"`..."
if "${IS_SINGLE:-false}"; then
	for domain in "${DOMAINS[@]}"; do
		DOMAIN_ARGS+="-d '$domain' "
	done
	$DOCKER run --rm --entrypoint " \
		certbot certonly \
			-w /var/www/certbot \
			--webroot \
			--key-type ecdsa \
			--agree-tos \
			$DOMAIN_ARGS \
			${IS_STAGING:+--dry-run} \
			`[ "$EMAIL" ] && echo "--email $EMAIL" || echo '--register-unsafely-without-email'` \
	" certbot
else
	. "$SOURCE_GROUPS"
	for index in $(seq `wc -l < "$SOURCE_CERT"`); do
		$DOCKER run --rm --entrypoint " \
			certbot certonly \
				-w /var/www/certbot \
				--webroot \
				--key-type ecdsa \
				--agree-tos \
				-d '${DOMAINS_GROUPS["$((index-1))"]// /,}' \
				`sed -n "${index}p" "$SOURCE_CERT"` \
				${IS_STAGING:+--dry-run} \
				`[ "$EMAIL" ] && echo "--email $EMAIL" || echo '--register-unsafely-without-email'` \
		" certbot
	done
fi

# step 3 - download nginx recommended files
SSL_NGINX_FILE="$CERTBOT_CONF/options-ssl-nginx.conf"
SSL_DHPARAMS_FILE="$CERTBOT_CONF/ssl-dhparams.pem"
[[ ! -f "$SSL_NGINX_FILE" || ! -f "$SSL_DHPARAMS_FILE" ]] && {
	echo '>> Downloading recommended files...'
	URL_PART='https://raw.githubusercontent.com/certbot/certbot/master'
	curl -fsSLo "$SSL_NGINX_FILE" "$URL_PART/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf"
	curl -fsSLo "$SSL_DHPARAMS_FILE" "$URL_PART/certbot/certbot/ssl-dhparams.pem"
}

# step 4 - change nginx config file for https redirect
echo '>> Changing nginx config file...'
cp -f './nginx/post.conf' './nginx/conf/default.conf'

# step 5 - reload nginx container
echo ">> Restarting Nginx container..."
$DOCKER exec nginx nginx -s reload
