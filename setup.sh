#!/bin/bash

setup-domains-array(){
	read -p '* Domains (space separated): ' -a DOMAINS
	for domain in "${DOMAINS[@]}"; do
		CONCAT+="'$domain' "
	done
	echo "DOMAINS=(${CONCAT% })" >> "$SOURCE_DOMAINS"
}

echo '### Nginx & Certbot with Docker - Setup'

echo '>> Cloning base repository...'
git clone -q 'https://github.com/rhuanpk/ncd.git'
cd './ncd/'

. './source/docker'

SOURCE_DOMAINS='./source/domains'
SOURCE_STAGING='./source/staging'
NGINX_FOLDER='./project/nginx'

read -p '* Is production setup? (y/N) '
[ "${REPLY,,}" != 'y' ] && echo "IS_STAGING='true'" >> "$SOURCE_STAGING"

. "$SOURCE_STAGING"
[ -z "$IS_STAGING" ] && {
	setup-domains-array
} || {
	read -p '* Is local test? (Y/n) '
	[ "${REPLY,,}" != 'n' ] && {
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
	} || setup-domains-array
}

echo '>> Setting up config files...'
STRING_DOMAINS="${DOMAINS[@]}"
sed -i "s|#!SERVERNAMES!#|server_name $STRING_DOMAINS;|" "$NGINX_FOLDER"/*
cd "$NGINX_FOLDER/conf/"
cp -f '../pre.conf' './default.conf'
for domain in "${DOMAINS[@]}"; do
cat << EOF >> '../post.conf'

server {

	listen      443 ssl;
	listen [::]:443 ssl;
	server_name $domain;

    include /etc/nginx/conf.d/global.conf;
    include /etc/nginx/conf.d/global.locations;
    include /etc/nginx/conf.d/$domain/ssl.conf;

}

EOF
mkdir "./$domain/"
cat <<- EOF > "./$domain/ssl.conf"
	ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
done
cd "$OLDPWD"

echo '>> Executing SSL script setup...'
cd './project/'
./ssl.sh
