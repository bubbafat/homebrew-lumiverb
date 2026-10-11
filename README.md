# Lumiverb for Homebrew

[Lumiverb](https://github.com/bubbafat/lumiverb) as a server on your own Mac:
the API, the scheduler (all processing), the web app, and the search sidecar.
The Linux "brain" installs with `scripts/deploy-api.sh` instead.

## Install

```sh
brew install --HEAD bubbafat/lumiverb/lumiverb
```

It builds from `main` (there are no releases yet), and brings PostgreSQL 18
with pgvector, nginx, ffmpeg, exiftool, libvips, and Quickwit 0.8.2 from this
tap.

On install (and every upgrade) `lumiverb-server init` writes, **only if it
isn't there yet**:

| File | What |
|---|---|
| `$(brew --prefix)/etc/lumiverb/env` | The settings, with generated secrets (mode 600). Yours to edit. |
| `$(brew --prefix)/etc/lumiverb/quickwit.yaml` | Quickwit's config |
| `$(brew --prefix)/etc/nginx/servers/lumiverb.conf` | The web app on port 6464, for this Mac only |

Data goes in `$(brew --prefix)/var/lumiverb`, logs in `$(brew --prefix)/var/log`.

## First run

```sh
brew services start postgresql@18 && brew services start quickwit && brew services start nginx && brew services start lumiverb
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

`lumiverb` makes its database and migrates it when it starts, then runs the
API, the scheduler and upkeep. The services can start in any order:
`lumiverb` waits for PostgreSQL, and search uses PostgreSQL until Quickwit
answers.

## Upgrade

```sh
brew upgrade --fetch-HEAD lumiverb
brew services restart lumiverb
```

## Ports

| | Port |
|---|---|
| Web (nginx) | 6464, this Mac only |
| API | 6465, this Mac only |
| Quickwit | 6466 (gRPC 6467), this Mac only |
| PostgreSQL | 5432, Homebrew's |

They're clear of a Lumiverb dev checkout's (5173, 8000, 7280, 7281), except
PostgreSQL: the checkout's `docker-compose.yml` maps its own to 5432 too. Change
them in the env file; the nginx site and Quickwit's config were made from
it, so move them away and run `brew postinstall lumiverb` to make them again.
