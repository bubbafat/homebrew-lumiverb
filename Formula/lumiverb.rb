class Lumiverb < Formula
  desc "Photo and video library server: search, faces and transcripts, on your own Mac"
  homepage "https://github.com/bubbafat/lumiverb"
  license "MIT"
  head "https://github.com/bubbafat/lumiverb.git", branch: "main"

  depends_on "node" => :build
  depends_on "pkgconf" => :build # pyvips finds libvips with it
  depends_on "uv" => :build
  depends_on "bubbafat/lumiverb/quickwit"
  depends_on "exiftool"
  depends_on "ffmpeg"
  depends_on :macos # the brain (Linux) installs with scripts/deploy-api.sh
  depends_on "nginx"
  depends_on "pgvector"
  depends_on "postgresql@18"
  depends_on "python@3.12"
  depends_on "vips"

  # What the server reads at run time; the rest of the repository (the apps,
  # tests, docs) isn't installed.
  RUNTIME = %w[src migrations quickwit alembic-control.ini alembic-tenant.ini
               pyproject.toml uv.lock README.md LICENSE].freeze

  def install
    cd "src/ui/web" do
      system "npm", "ci", "--no-audit", "--no-fund"
      system "npm", "run", "build"
      rm_r "node_modules"
    end
    libexec.install RUNTIME

    # The server and the scheduler, as the brain's update installs them
    # (scripts/update-api.sh). pyvips is built here, every time, against
    # Homebrew's libvips: built without it (or taken from a cached build made
    # without it), it looks for libvips at run time and can't find it under launchd.
    ENV["UV_PYTHON_DOWNLOADS"] = "never"
    cd libexec do
      system "uv", "sync", "--frozen",
             "--python", formula_opt_bin("python@3.12")/"python3.12",
             "--extra", "cli", "--extra", "embeddings", "--extra", "face_recognition", "--extra", "workers",
             "--no-binary-package", "pyvips", "--refresh-package", "pyvips"
    end
    %w[lumiverb lumiverb-server].each { |command| bin.install_symlink libexec/".venv/bin"/command }
  end

  # On every install and upgrade: each file only if it isn't there, so
  # nothing here (the secrets above all) is ever rewritten. That's why the
  # web root is the opt path: init's default is this keg's own (Cellar/<version>),
  # which `brew cleanup` deletes after an upgrade, and the site would keep it.
  post_install_steps do
    mkdir_p "{{var}}/log"
    run "lumiverb-server", base:           :bin,
                           args:           ["init",
                                            "--env", "{{etc}}/lumiverb/env",
                                            "--data-dir", "{{var}}/lumiverb",
                                            "--quickwit-config", "{{etc}}/lumiverb/quickwit.yaml",
                                            "--nginx-site", "{{etc}}/nginx/servers/lumiverb.conf",
                                            "--web-root", "{{opt_prefix}}/libexec/src/ui/web/dist"],
                           print_stdout:   true,
                           writable_paths: ["{{etc}}/lumiverb", "{{etc}}/nginx/servers", "{{var}}/lumiverb"]
  end

  def caveats
    <<~EOS
      Lumiverb runs as three services, plus PostgreSQL:
        brew services start postgresql@18
        brew services start quickwit
        brew services start nginx
        brew services start lumiverb

      Its settings are in #{etc}/lumiverb/env (written once; yours to edit).
      The web app is at http://localhost:6464 once it's running.
    EOS
  end

  # Migrates, then runs the API, the scheduler and upkeep (lumiverb-server run).
  service do
    run [opt_bin/"lumiverb-server", "run", "--env", etc/"lumiverb/env"]
    keep_alive true
    log_path var/"log/lumiverb.log"
    error_log_path var/"log/lumiverb.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    assert_match "lumiverb-server", shell_output("#{bin}/lumiverb-server --help")
    system libexec/".venv/bin/python", "-c", "import pyvips; assert pyvips.API_mode"
  end
end
