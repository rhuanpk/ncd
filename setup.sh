#!/bin/bash

echo '### Nginx & Certbot with Docker - Setup'

echo '>> Cloning base repository...'
git clone -q 'https://github.com/rhuanpk/ncd.git'
cd './ncd/'

. './source/docker'

SOURCE_DOMAINS='./source/domains'
SOURCE_STAGING='./source/staging'
NGINX_FILE='./project/nginx/default.conf'

read -p '* Is production setup? (y/N) '
[ "${REPLY,,}" != 'y' ] && echo "IS_STAGING='true'" >> "$SOURCE_STAGING"

. "$SOURCE_STAGING"
[ -z "$IS_STAGING" ] && {
	read -p '* Domains (blank space separate domains): ' -a DOMAINS
	for domain in "${DOMAINS[@]}"; do
		CONCAT+="'$domain' "
	done
	echo "DOMAINS=(${CONCAT% })" >> "$SOURCE_DOMAINS"
} || {
	[ "$UID" -ne '0' ] && SUDO='sudo'
	echo '>> Setting up local domains...'
	echo "DOMAINS=('ncd.xyz' 'www.ncd.xyz')" >> "$SOURCE_DOMAINS"
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
}

echo '>> Setting up domains in config files...'
STRING_DOMAINS="${DOMAINS[@]}"
sed -i "s|#!SERVERNAMES!#|server_name $STRING_DOMAINS;|" "$NGINX_FILE"
MAPPED_DOMAINS="default\t$DOMAINS;\n"
for domain in "${DOMAINS[@]}"; do
	MAPPED_DOMAINS+="$domain\t$domain;\n"
done
sed -i "s~#!DOMAINS!#~${MAPPED_DOMAINS%\\n}~" "$NGINX_FILE"

echo '>> Executing SSL script setup...'
cd './project/'
bash ./ssl.sh

echo '>> Executing docker-compose file...'
$DOCKER up -d
