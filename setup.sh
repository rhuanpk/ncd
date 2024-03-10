#!/bin/bash

setup-domains-array(){
	read -p '* Domains (space separated): ' -a DOMAINS
	for domain in "${DOMAINS[@]}"; do
		CONCAT+="'$domain' "
	done
	echo "DOMAINS=(${CONCAT% })" > "$SOURCE_DOMAINS"
}

echo '### Nginx & Certbot with Docker - Setup'

echo '>> Cloning base repository...'
git clone -q 'https://github.com/rhuanpk/ncd.git'
cd './ncd/'

. './source/docker'

SOURCE_CERT='./source/cert'
SOURCE_DOMAINS='./source/domains'
SOURCE_SINGLE='./source/single'
SOURCE_STAGING='./source/staging'
NGINX_FOLDER='./project/nginx'

read -p '* Is production setup? (y/N) '
[ "${REPLY,,}" != 'y' ] && echo "IS_STAGING='true'" > "$SOURCE_STAGING"
. "$SOURCE_STAGING"

[ -z "$IS_STAGING" ] && {
	setup-domains-array
} || {
	read -p '* Is local test? (Y/n) '
	[ "${REPLY,,}" != 'n' ] && {
		[ "$UID" -ne '0' ] && SUDO='sudo'
		echo '>> Setting up local domains...'
		echo "DOMAINS=('ncd.xyz' 'www.ncd.xyz')" > "$SOURCE_DOMAINS"
		. "$SOURCE_DOMAINS"
		sudo -k 2>&-
		read -sp '* User password: '; echo
		OUTPUT="`echo -e "${REPLY}\n" | sudo -Sv 2>&1`"
		EXIT="$?"
		[[ "$EXIT" -ne '0' && ! "$OUTPUT" =~ incorrect\ password ]] && {
			while :; do
				echo -n '* [ROOT] '
				if su - -c "echo $'\n# Only tests\n127.0.0.1\tncd.xyz\n127.0.0.1\twww.ncd.xyz' >> '/etc/hosts'"; then break; fi
			done
		} || {
			while :; do
				if $SUDO tee -a '/etc/hosts' >'/dev/null' <<< $'\n# Only tests\n127.0.0.1\tncd.xyz\n127.0.0.1\twww.ncd.xyz'; then break; fi
			done
		}
	} || setup-domains-array
}

read -p '* Generate single certificate? (Y/n) '
[ "${REPLY,,}" != 'n' ] && echo "IS_SINGLE='true'" > "$SOURCE_SINGLE"
. "$SOURCE_SINGLE"

echo '>> Setting up config files...'
if "$IS_SINGLE"; then
cat << EOF >> "$NGINX_FOLDER/post.conf"

server {

	listen      443 ssl;
	listen [::]:443 ssl;
	#!SERVERNAMES!#

	include /etc/letsencrypt/options-ssl-nginx.conf;
	ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
	ssl_certificate /etc/letsencrypt/live/$DOMAINS/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$DOMAINS/privkey.pem;

	# this static or a specific proxy location
	location / {
		root /var/www/html;
	}

}
EOF
else
	for domain in "${DOMAINS[@]}"; do
		[ "`tr -d ' ' <<< "$GROUP"`" = "${domain#www.}" ] && {
			GROUPS+=("$GROUP$domain")
			uset GROUP
		} || GROUP="$domain "
	done
	for group in "${GROUPS[@]}"; do
		SHORTED="$(cut -d ' ' -f '1' <<< "$group" | sed 's/^www.//')"
		CERT_OPTIONS="--cert-name '$SHORTED'" > "$SOURCE_CERT"
cat << EOF >> "$NGINX_FOLDER/post.conf"

server {

	listen      443 ssl;
	listen [::]:443 ssl;
	server_name $group;

	include /etc/nginx/conf.d/includes/global.conf;
	include /etc/nginx/conf.d/includes/global.locations;
	include /etc/nginx/conf.d/$SHORTED/ssl.conf;

}
EOF
		mkdir "$NGINX_FOLDER/conf/$SHORTED/"
		cat <<- EOF > "$NGINX_FOLDER/conf/$SHORTED/ssl.conf"
			ssl_certificate /etc/letsencrypt/live/$SHORTED/fullchain.pem;
			ssl_certificate_key /etc/letsencrypt/live/$SHORTED/privkey.pem;
		EOF
	done
fi
STRING_DOMAINS="${DOMAINS[@]}"
find "$NGINX_FOLDER/" -maxdepth 1 -type f -exec sed -i "s|#!SERVERNAMES!#|server_name $STRING_DOMAINS;|" '{}' \+
cp -f "$NGINX_FOLDER/pre.conf" "$NGINX_FOLDER/conf/default.conf"

echo '>> Executing SSL script setup...'
cd './project/'
./ssl.sh
