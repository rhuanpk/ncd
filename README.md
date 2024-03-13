# Nginx & Certbot with Docker (NCD)

Sample repository that contains a minimal project with Nginx and Certbot running under Docker containers that request Let's Encrypt certificate for your domains.

## Running

Run this command to automatic setup the project:
```sh
FILE='./setup.sh'; curl -fsSLo "$FILE" 'https://raw.githubusercontent.com/rhuanpk/ncd/main/setup.sh' && chmod +x "$FILE" && "$FILE"
```

## In Production

In all cases:
- Keep open ports `80` and `443` in your **firewall**.

Before run the script:
- Creates the VPS (or use local exposed IP);
- Creates the A/AAAA domain that points to IP server.

After run the script:
- Change the config files (docker compose and nginx) as necessary;
- After all done if desired can exlude `.git` folder;
- Add **crontab** for regular renewal attempt e.g.:
```
0 0 15 * * docker-compose -f /path/to/docker-compose.yml up -d certbot
30 0 15 * * docker-compose -f /path/to/docker-compose.yml restart nginx
```

## Step By Step

Running by the [recommended command](#running), the script will execute in order:

<a id="link1"></a>

1. Clone this repository (`git`);

1. Comment the [first command](#link1) (`sed`);

1. Enter the repository folder (`cd`);

1. Iterate over modified or untracked files if it exists (`for`):
	1. Case untrackeds:
		1. Ask to clean them (`read`, `for`, `su || sudo`, `git`).  
		OBS: This is necessary in case the user **runs the setup script again** (with `./setup.sh`) to generate the certificates, opting for a different [strategy](#link2) so this flow deletes the created certificates. Case you desire only update the certificates, choose "n".

	1. Case modifieds:
		1. Ask to restore them (`read`, `for`, `git`).

1. Ask for environment type (`read`):
	1. Case production:
		1. Ask for production domains (`read`);

	1. Case testing:
		1. Set default local testing domains (`su > echo || sudo > tee`);
		OR
		1. Ask for testing domains (`read`).

<a id="link2"></a>

6. Ask for certificate generation strategy (`read`):
	1. Case single:
		1. Setup Nginx config with all domains and generate one certificate for all too (_`heredoc`_).

	1. Case multiple:
		1. Iterate over all domains grouping them with max amount of 2 consisting in the `domain.*` and your `www.domain.*` (`for`);
		1. Iterate over all group of domains appending a specific confi in Nginx cofig file (`for`, _`heredoc`_).

1. Edit config files based on options chosen (`sed`);

1. Copy pre Nginx config for ACME challange (`cp`);

1. Enter the `project/` folder (`cd`);

1. Execute **ssl script** (`./ssl.sh`);

1. Ask for email of the admin (`read`);

1. Create some necessary folders (`mkdir`);

1. Start Nginx container (`docker`);

1. Request Let's Encrypt certificates (`docker > certbot`);

1. Download recommended files for Nginx (`curl`);

1. Copy final Nginx config (with HTTPS redirect) (`cp`);

1. Reload Nginx daemon (`docker`).
