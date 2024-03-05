#!/bin/bash

set -e
. ./bash/docker

NGINX_FILE='./project/nginx/default.conf'

echo '### Nginx & Certbot with Docker - Setup'

read -p '* Is production setup? (y/N) '
[ "${REPLY,,}" != 'y' ] && echo "IS_STAGING='true'" >> ./bash/staging

. ./bash/staging
[ -z "$IS_STAGING" ] && {
	read -p '* Domains (blank space separate domains): ' -a DOMAINS
} || {
	[ "$UID" -ne '0' ] && SUDO='sudo'
	echo '>> Setting up local domains...'
	echo "DOMAINS=('ncd.xyz' 'www.ncd.xyz')" >> ./bash/domains
	$SUDO echo $'\n# Only tests\n127.0.0.1\tncd.xyz\n127.0.0.1\twww.ncd.xyz' >> '/etc/hosts'
}

echo '>> Setting up domains in config files...'
STRING_DOMAINS="${DOMAINS[@]}"
sed -i "s|#!SERVERNAMES!#|server_name $STRING_DOMAINS;|" "$NGINX_FILE"
MAPPED_DOMAINS="default\t$DOMAINS;\n"
for domain in "${DOMAINS[@]}"; do
	MAPPED_DOMAINS+="$domain\t$domain;\n"
done
sed -i "s~#!DOMAINS!#~${MAPPED_DOMAINS%\\n}~" "$NGINX_FILE"

echo '>> Cloning base repository...'
git clone -q 'https://github.com/rhuanpk/ncd.git'
cd './ncd/project'

echo '>> Executing SSL script setup...'
./ssl.sh

echo '>> Executing docker-compose file...'
$DOCKER up -d
