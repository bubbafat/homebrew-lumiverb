# Lumiverb for Homebrew

[Lumiverb](https://github.com/bubbafat/lumiverb) as a server on your own Mac,
as one service: the API, the scheduler (all processing), the web app, and
its own PostgreSQL, Quickwit and nginx. The Linux "brain" installs with
`scripts/deploy-api.sh` instead.

## Install

```sh
brew trust --tap bubbafat/lumiverb && brew install --HEAD bubbafat/lumiverb/lumiverb
```

Homebrew installs from a tap that isn't its own only once you trust it:
`brew trust` does that once. Without it the install stops at Quickwit, which
comes from this tap too.

It builds from `main` (there are no releases yet), and brings PostgreSQL 18
with pgvector, nginx, ffmpeg, exiftool, libvips, and Quickwit 0.8.2 from this
tap.

On install (and every upgrade) `lumiverb-server init` writes, **only if it
isn't there yet**:

| File | What |
|---|---|
| `$(brew --prefix)/etc/lumiverb/env` | The settings, with generated secrets (mode 600). Yours to edit. |
| `$(brew --prefix)/etc/lumiverb/quickwit.yaml` | Quickwit's config |
| `$(brew --prefix)/etc/lumiverb/nginx.conf` | nginx's: the web app on port 6464, for this Mac only |

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
can be chosen only on this Mac, too. A tunnel or proxy in front of Lumiverb
opens that to whoever reaches it, for as long as it's there.

It starts again at login. On its first start it makes its own PostgreSQL
(not Homebrew's: nothing is shared with another you run) and its databases.
Every start, it runs PostgreSQL, Quickwit and nginx, migrates, then runs the
API, the scheduler and upkeep; stopping it stops them all.

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
| PostgreSQL | 6468, Lumiverb's own, this Mac only |

They're clear of Homebrew's PostgreSQL (5432) and a Lumiverb dev checkout's
(5173, 8000, 7280, 7281). Change them in the env file; nginx's and Quickwit's
configs were made from it, so move them away and run `brew postinstall
lumiverb` to make them again.
