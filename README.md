# dev.boyersoftware.com

The landing page for Boyer Software's experiments and proofs of concept. It is
one static `index.html` served by nginx, and it links out to each project.
Every project lives in its own repo and deploys to its own subdomain:
`<name>.dev.boyersoftware.com`.

## Listing a project

Add an `<li>` to the list in `index.html` and push to `main`.

## Deploying

Every push to `main` runs `.github/workflows/deploy.yml`. It builds the image on
GitHub, pushes it to GHCR, and has Dokku on the server run it. The same run
creates the Dokku app if it is missing, sets its domain, and requests its first
HTTPS certificate, so the server needs no manual setup per project. Renewals
are the server's job (see below).

The repo needs two Actions secrets (Settings > Secrets and variables > Actions):

| Secret | Value |
| --- | --- |
| `DOKKU_SSH_KEY` | the private deploy key whose public half is added to Dokku |
| `DOKKU_HOST` | `15.204.120.53` |

## One-time server setup

Already done on the server, and shared by every project:

| What | Command (as root on the server) |
| --- | --- |
| The deploy key, named `github-projects` | `dokku ssh-keys:add github-projects <public key file>` |
| The email Let's Encrypt writes to | `dokku letsencrypt:set --global email <address>` |
| Daily certificate renewal | `dokku letsencrypt:cron-job --add` |
| The lock on the deploy key | the `projects-key-scope` plugin, below |

Without the renewal job, certificates lapse after 90 days, and the workflow will
not notice: it only asks for a certificate when the app has none.

### The lock on the deploy key

A Dokku key normally reaches every app on the server, and this one sits in the
secrets of every project repo. `dokku/projects-key-scope/user-auth` runs before
every Dokku command and holds the `github-projects` key to what the deploy
workflow does, plus what Let's Encrypt runs on its behalf. That means any app
except `budget`, and domains under `dev.boyersoftware.com` only. Anything else
fails with "Access denied". Other keys are unaffected. If another private app
joins the server, add its name next to `budget` there.

Install, as root on the server:

```bash
mkdir -p /var/lib/dokku/plugins/available/projects-key-scope
cd /var/lib/dokku/plugins/available/projects-key-scope
curl -fsSLO https://raw.githubusercontent.com/bboyer4806/dev/main/dokku/projects-key-scope/plugin.toml
curl -fsSLO https://raw.githubusercontent.com/bboyer4806/dev/main/dokku/projects-key-scope/user-auth
chmod 755 user-auth
dokku plugin:enable projects-key-scope
```

To pick up a change, re-run the two `curl` lines. To remove the lock:
`dokku plugin:disable projects-key-scope`.

## Starting a new project

1. **DNS.** boyersoftware.com's DNS is hosted at **Bluehost**, not Squarespace
   (its nameservers are `ns1.bluehost.com` and `ns2.bluehost.com`). In
   Bluehost's DNS settings, add an A record with host `<name>.dev` pointing at
   `15.204.120.53`.
2. **Repo.** Copy `.github/workflows/deploy.yml` and set `APP` to `<name>` and
   `DOMAIN` to `<name>.dev.boyersoftware.com`. Add the two secrets above.
3. **Port.** Dokku serves the domain from whatever port the image `EXPOSE`s.
   Port 80 works as is. For any other port, run this once on the server after
   the first deploy: `sudo dokku ports:set <name> http:80:<port> https:443:<port>`.
4. **List it.** Add it to `index.html` here.

## If a deploy fails

- **"Add the DOKKU_… secret"**: the secret is missing from this repo.
- **"Access denied"**: the key's lock refused the command shown just above it
  in the log.
- **The image pull is denied**: the server cannot read the GHCR package. Make it
  public at github.com > your profile > Packages > the package > Package
  settings > Change visibility. The repos are public already, so this exposes
  nothing new. It cannot be made private again.
- **Let's Encrypt fails**: the DNS record is missing or has not spread yet.
  Re-run the workflow once the domain resolves to the server. If the log says
  it cannot request a certificate without an e-mail address, the one-time setup
  above is missing.
