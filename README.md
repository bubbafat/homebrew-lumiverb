# Lumiverb for Homebrew

[Lumiverb](https://github.com/bubbafat/lumiverb) as a server on your own Mac,
as one service: the API, the scheduler (all processing), the web app, and
its own PostgreSQL (its search too) and nginx. The Linux "brain" installs with
`scripts/deploy-api.sh` instead.

## Install

```sh
brew trust --tap bubbafat/lumiverb && brew install bubbafat/lumiverb/lumiverb
```

Homebrew installs from a tap that isn't its own only once you trust it:
`brew trust` does that once.

It installs the latest release (`--HEAD` instead: `main`), and brings PostgreSQL 18
with pgvector, nginx, ffmpeg, exiftool and libvips.

On install (and every upgrade) `lumiverb-server init` writes, **only if it
isn't there yet**:

| File | What |
|---|---|
| `$(brew --prefix)/etc/lumiverb/env` | The settings, with generated secrets (mode 600). Yours to edit. |
| `$(brew --prefix)/etc/lumiverb/nginx.conf` | nginx's: the web app on port 6464 (where it listens: Settings › Network) |

Data goes in `$(brew --prefix)/var/lumiverb` (its database in `postgres/`
there), the log in `$(brew --prefix)/var/log/lumiverb.log`.

## First run

```sh
brew services start lumiverb
```

Then open <http://localhost:6464> on this Mac and create your account: you
look after this Lumiverb, and can add people later. Or, in Terminal:

```sh
lumiverb-server setup --env "$(brew --prefix)/etc/lumiverb/env"
```

Either works only until the first account exists, and the web page only on
this Mac. Finish it before putting a tunnel or proxy in front of Lumiverb
(`tailscale serve`, cloudflared, ngrok): their requests arrive from this Mac,
so until then they could create that account too.

Lumiverb reads your library folders where they are, so a library's folder
can be chosen only on this Mac, too. And Forgot password on this Mac gives the
reset link at once, since there's no email set up. A tunnel or proxy in front
of Lumiverb opens both to whoever reaches it, for as long as it's there:
choosing folders, and resetting any account's password.

To use Lumiverb from a phone or another computer, an admin turns on Settings ›
Network › Let other devices on my network use Lumiverb, on this Mac. It shows
the addresses to open (`http://<this Mac's name>.local:6464`, and its IP
address for devices that can't use the name). Only do it on a network you
trust: the connection isn't encrypted.

To add people, Admin › Manage users › Invite someone gives you a link to send
them (it works once, for 7 days); they choose their own password there.

Forgot your password? Use Forgot password on this Mac, or in Terminal:

```sh
lumiverb-server reset-password --env "$(brew --prefix)/etc/lumiverb/env"
```

It starts again at login. On its first start it makes its own PostgreSQL
(not Homebrew's: nothing is shared with another you run) and its databases.
Every start, it runs PostgreSQL and nginx, migrates, then runs the
API, the scheduler and upkeep; stopping it stops them all.

## Upgrade

```sh
brew upgrade lumiverb
```

It restarts itself into the new version: no `brew services restart` needed.

From 0.1.27, search is in Lumiverb's own PostgreSQL; from 0.1.28 Quickwit
isn't used at all, and the upgrade removes what it kept (its index and
config). Homebrew leaves the program itself installed:
`brew uninstall bubbafat/lumiverb/quickwit` removes it.
An install made with `--HEAD` stays on `main`. To move it to releases, once
a release is at least as new as it (`brew info lumiverb` shows both: a newer
install has already migrated its database past what the release knows),
stop it, then uninstall and install again (its settings, account and data
stay):

```sh
brew services stop lumiverb && brew uninstall lumiverb && brew install bubbafat/lumiverb/lumiverb && brew services start lumiverb
```

## Ports

| | Port |
|---|---|
| Web (nginx) | 6464, this Mac only until Settings › Network says other devices may use it |
| API | 6465, this Mac only |
| PostgreSQL | 6468, Lumiverb's own, this Mac only |

They're clear of Homebrew's PostgreSQL (5432) and a Lumiverb dev checkout's
(5173, 8000). Change them in the env file; nginx's config was made from it,
so move it away and run `brew postinstall lumiverb` to make it again.
