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
sed -i 's/^git clone/#&/' "$0"
cd './ncd/'
for status in `git status --porcelain | sed -n 's/^.\(.\).*$/\1/;{/^\(M\|\?\)/p}' | sort -u`; do
	[[ "$status" = '?' && -d './project/certbot/conf/live/' ]] && {
		read -p '* Certs already exists, gens in different way (delete existing)? (y/N) '
		[ "${REPLY,,}" = 'y' ] && {
			sudo -k 2>&-
			read -sp '* User password: '; echo
			if ! OUTPUT="`echo -e "${REPLY}\n" | sudo -Sv 2>&1`" && [[ ! "$OUTPUT" =~ incorrect\ password ]]; then
				while :; do
					unset EXITS
					echo -n '* [ROOT] '
					if EXITS=$(
						su - -c " \
							cd \"`pwd`\"; \
							for file in \`find ./project/certbot/ ./project/nginx/conf/ -type d -user 0\`; do \
								chown -R 1000:1000 \"\$file\"; \
								echo \"#@\$?@#\"; \
							done \
						"
					); then
						break
					fi
					[[ "`sed -n 's/^.*#@\([[:digit:]]\+\)@#.*$/\1/pg' <<< "$EXITS" | tr -d '\n'`" =~ [^0] ]] && HAS_ERROR=true
				done
			else
				while :; do
					IS_SUDO=true
					unset EXITS
					for file in `find ./project/certbot/ ./project/nginx/conf/ -type d -user 0`; do
						sudo chown -R 1000:1000 "$file"
						EXITS+="$?"
					done
					[[ "$EXITS" =~ [^0] ]] && HAS_ERROR=true
					if ! "${HAS_ERROR:-false}"; then break; fi
				done
			fi
			git clean -f 'project/certbot/' 'project/nginx/conf/' 'source/'
			if "${HAS_ERROR:-false}"; then
				echo '! Some error occurred, try on your own: git clean -f ./'
				exit 1
			fi
		}
	}
	[ "$status" = 'M' ] && {
		read -p '* Config files are modified, reset? (Y/n) '
		[ "${REPLY,,}" != 'n' ] && git restore --worktree ./
	}
done

SOURCE_CERT='./source/cert'
SOURCE_DOMAINS='./source/domains'
SOURCE_GROUPS='./source/groups'
SOURCE_SINGLE='./source/single'
SOURCE_STAGING='./source/staging'
NGINX_FOLDER='./project/nginx'

read -p '* Is production setup? (y/N) '
[ "${REPLY,,}" != 'y' ] && echo "IS_STAGING='true'" > "$SOURCE_STAGING"
. "$SOURCE_STAGING" 2>&-

[ -z "$IS_STAGING" ] && {
	setup-domains-array
} || {
	read -p '* Is local test? (Y/n) '
	[ "${REPLY,,}" != 'n' ] && {
		echo '>> Setting up local domains...'
		echo "DOMAINS=('ncd.xyz' 'www.ncd.xyz')" > "$SOURCE_DOMAINS"
		. "$SOURCE_DOMAINS"
		sudo -k 2>&-
		read -sp '* User password: '; echo
		if ! OUTPUT="`echo -e "${REPLY}\n" | sudo -Sv 2>&1`" && [[ ! "$OUTPUT" =~ incorrect\ password ]]; then
			while :; do
				echo -n '* [ROOT] '
				if su - -c "echo $'\n# Only tests\n127.0.0.1\tncd.xyz\n127.0.0.1\twww.ncd.xyz' >> '/etc/hosts'"; then
					break
				fi
			done
		else
			while :; do
				if sudo tee -a '/etc/hosts' >'/dev/null' <<< $'\n# Only tests\n127.0.0.1\tncd.xyz\n127.0.0.1\twww.ncd.xyz'; then
					break
				fi
			done
		fi
	} || setup-domains-array
}

read -p '* Generate single certificate? (Y/n) '
[ "${REPLY,,}" != 'n' ] && echo "IS_SINGLE='true'" > "$SOURCE_SINGLE"
. "$SOURCE_SINGLE" 2>&-

echo '>> Setting up config files...'
if "${IS_SINGLE:-false}"; then
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
		[ "${PREVIOUS_DOMAIN#www.}" = "${domain#www.}" ] && {
			DOMAINS_GROUPS+=("$PREVIOUS_DOMAIN $domain")
		} || {
			[[ -z "$PREVIOUS_DOMAIN" || "$domain" =~ ^www\. ]] && {
				PREVIOUS_DOMAIN="$domain"
				continue
			}
			DOMAINS_GROUPS+=("$domain")
		}
		PREVIOUS_DOMAIN="$domain"
	done
	unset CONCAT
	rm -f "$SOURCE_CERT"
	for group in "${DOMAINS_GROUPS[@]}"; do
		CONCAT+="'$group' "
		SHORTED="$(cut -d ' ' -f '1' <<< "$group" | sed 's/^www.//')"
		echo "--cert-name '$SHORTED'" >> "$SOURCE_CERT"
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
	echo "DOMAINS_GROUPS=(${CONCAT% })" > "$SOURCE_GROUPS"
fi
STRING_DOMAINS="${DOMAINS[@]}"
find "$NGINX_FOLDER/" -maxdepth 1 -type f -exec sed -i "s|#!SERVERNAMES!#|server_name $STRING_DOMAINS;|" '{}' \+
cp -f "$NGINX_FOLDER/pre.conf" "$NGINX_FOLDER/conf/default.conf"

echo '>> Executing SSL script setup...'
cd './project/'
./ssl.sh
