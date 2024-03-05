#!/bin/bash

set -e

. ./bash/source
[ "$UID" -ne '0' ] && SUDO='sudo'

echo '### Nginx & Certbot with Docker - Setup'

echo '>> Setting up local domains...'
$SUDO echo $'\n# Only tests\n127.0.0.1\texample.xyz\n127.0.0.1\twww.example.xyz' >> '/etc/hosts'

echo '>> Cloning base repository...'
git clone -q 'https://github.com/rhuanpk/ncd.git'; cd './ncd/project'

echo '>> Executing SSL script setup...'
./ssl.sh

echo '>> Executing docker-compose file...'
$DOCKER up -d
