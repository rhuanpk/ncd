# Nginx & Certbot with Docker (NCD)

Sample repository that contains a minimal project with Nginx and Certbot running under Docker containers.

## Running

Run this command to automatic setup the project:
```sh
FILE='./setup.sh'; curl -fsSLo "$FILE" 'https://raw.githubusercontent.com/rhuanpk/ncd/main/setup.sh' && chmod +x "$FILE" && "$FILE"
```

## In Production

Before run the script:
- Creates the VPS (or use local exposed IP);
- Creates the A/AAAA domain and link with IP server.

After run the script:
- Change the config files (docker compose, nginx and etc);
- Add directive in **certbot** service: `command: renew`
