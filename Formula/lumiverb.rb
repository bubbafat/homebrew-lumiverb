class Lumiverb < Formula
  desc "Photo and video library server: search, faces and transcripts, on your own Mac"
  homepage "https://github.com/bubbafat/lumiverb"
  url "https://github.com/bubbafat/lumiverb/archive/refs/tags/v0.1.140.tar.gz"
  sha256 "f1001e68f96ffa0a818f4faad361ab5e9814c553f6c32eacbd5b0ec28b13b128"
  license "MIT"
  head "https://github.com/bubbafat/lumiverb.git", branch: "main"

  depends_on "node" => :build
  depends_on "pkgconf" => :build # pyvips finds libvips with it
  depends_on "uv" => :build
  depends_on "exiftool"
  depends_on "ffmpeg"
  depends_on :macos # the brain (Linux) installs with scripts/deploy-api.sh
  depends_on "nginx"
  depends_on "pgvector"
  depends_on "postgresql@18"
  depends_on "python@3.12"
  depends_on "vips"

  preserve_rpath # the wheels' library IDs: see keep_wheel_library_ids

  # What the server reads at run time; the rest of the repository (the apps,
  # tests, docs) isn't installed.
  RUNTIME = %w[src migrations alembic-control.ini alembic-tenant.ini
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
    keep_wheel_library_ids(libexec/".venv")
    %w[lumiverb lumiverb-server].each { |command| bin.install_symlink libexec/".venv/bin"/command }
  end

  # The libraries wheels bring (PyAV's codecs, Pillow's, ...) find each other
  # by @loader_path, so their own IDs are never used to load them. Homebrew
  # rewrites every ID to a longer opt path, which doesn't fit some headers
  # (PyAV's), failing the install. An @rpath ID is shorter than the one it
  # replaces, and preserve_rpath keeps it. A changed library is re-signed:
  # Apple Silicon won't load one whose signature is broken.
  def keep_wheel_library_ids(venv)
    # FNM_DOTMATCH: wheels keep them in hidden folders (av/.dylibs).
    venv.glob("lib/python*/site-packages/**/*.{dylib,so}", File::FNM_DOTMATCH).each do |file|
      next if file.symlink?

      id = MachO.open(file.to_s).dylib_id # none for a Python extension (a bundle)
      next if id.nil? || id.start_with?("@")

      MachO::Tools.change_dylib_id(file.to_s, "@rpath/#{File.basename(id)}")
      MachO.codesign!(file.to_s)
    rescue MachO::NotAMachOError
      next # not a Mac library at all (a stray Linux .so): nothing to keep
    end
  end

  # On every install and upgrade: each file only if it isn't there, so
  # nothing here (the secrets above all) is ever rewritten. That's why every
  # path is an opt one: a keg's own (Cellar/<version>) is gone after an
  # upgrade and `brew cleanup`, and the files would keep it. The env file
  # names what `lumiverb-server run` starts: Lumiverb's own PostgreSQL (made
  # on its first start, in var/lumiverb/postgres) and nginx, so
  # Homebrew's postgresql@18 and nginx are programs here, never services.
  # --local-roots: this Mac has the files, so the scheduler reads each library
  # folder where it is (said in the env file, never assumed).
  # --reset-on-this-machine: whoever is at this Mac owns it, so Forgot password
  # here gives the reset link at once (it has no email set up).
  post_install_steps do
    mkdir_p "{{var}}/log"
    run "lumiverb-server", base:           :bin,
                           args:           ["init",
                                            "--env", "{{etc}}/lumiverb/env",
                                            "--data-dir", "{{var}}/lumiverb",
                                            "--pg-bin", "{{HOMEBREW_PREFIX}}/opt/postgresql@18/bin",
                                            "--nginx-bin", "{{HOMEBREW_PREFIX}}/opt/nginx/bin/nginx",
                                            "--nginx-config", "{{etc}}/lumiverb/nginx.conf",
                                            "--web-root", "{{opt_prefix}}/libexec/src/ui/web/dist",
                                            "--local-roots",
                                            "--reset-on-this-machine"],
                           print_stdout:   true,
                           writable_paths: ["{{etc}}/lumiverb", "{{var}}/lumiverb"]
  end

  def caveats
    <<~EOS
      To start Lumiverb (it starts again at login):
        brew services start lumiverb

      Then open http://localhost:6464 on this Mac to create your account.

      Its settings are in #{etc}/lumiverb/env (written once; yours to edit).
    EOS
  end

  # Everything: its PostgreSQL and nginx, migrations, then the API,
  # the scheduler and upkeep (lumiverb-server run).
  service do
    run [opt_bin/"lumiverb-server", "run", "--env", etc/"lumiverb/env"]
    keep_alive true
    # launchd's ExitTimeOut: run stops its children one after another, each
    # given its own time (240 s at the longest; a test in lumiverb holds it).
    # launchd's default, 20 s, would kill PostgreSQL mid-shutdown.
    stop_timeout 240
    log_path var/"log/lumiverb.log"
    error_log_path var/"log/lumiverb.log"
    environment_variables PATH: std_service_path_env
  end

  test do
    assert_match "lumiverb-server", shell_output("#{bin}/lumiverb-server --help")
    system libexec/".venv/bin/python", "-c", "import pyvips; assert pyvips.API_mode"
    # Python through its opt path: a Cellar one is gone after python@3.12's next upgrade.
    refute_match "/Cellar/", (libexec/".venv/pyvenv.cfg").read
    refute_match "/Cellar/", (libexec/".venv/bin/python").readlink.to_s
  end
end
