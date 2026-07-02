# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "optparse"
require "rbconfig"

module ProjectMirror
  class Launcher
    ROOT = File.expand_path("..", __dir__)
    DEFAULT_CONFIG = File.join(ROOT, "config", "project_mirror.json")

    def initialize(argv)
      @options = {
        config: ENV["PROJECT_MIRROR_CONFIG"] || DEFAULT_CONFIG,
        start_server: true,
        start_ai: true,
        open_menu: false,
        open_gui: false,
        status_only: false,
        once: false
      }
      @children = []
      parse(argv)
    end

    def run
      @config = load_config(@options[:config])

      if @options[:status_only]
        print_status
        return
      end

      FileUtils.mkdir_p(File.join(ROOT, "logs"))
      start_node_server if @options[:start_server]
      start_python_api if @options[:start_ai]

      puts "Project Mirror Dev Beta 1 is starting."
      puts "Node server: #{server_url}"
      puts "Python AI API: #{ai_url}"
      puts "Shared config: #{@options[:config]}"

      wait_for_health("#{server_url}/health", "Node server") if @options[:start_server]
      wait_for_health("#{ai_url}/health", "Python AI API") if @options[:start_ai]

      run_dotnet_menu if @options[:open_menu]
      run_swift_gui if @options[:open_gui]
      return if @options[:once]

      puts "Press Ctrl+C to stop Project Mirror services."
      sleep
    rescue Interrupt
      puts "\nStopping Project Mirror services..."
    ensure
      stop_children
    end

    private

    def parse(argv)
      OptionParser.new do |parser|
        parser.banner = "Usage: ruby launch_project_mirror.rb [options]"
        parser.on("--config PATH", "Use a custom config file") { |value| @options[:config] = value }
        parser.on("--no-server", "Do not start the Node control server") { @options[:start_server] = false }
        parser.on("--no-ai", "Do not start the Python AI API") { @options[:start_ai] = false }
        parser.on("--menu", "Open the .NET RAM/menu launcher") { @options[:open_menu] = true }
        parser.on("--gui", "Open the Swift GUI window") { @options[:open_gui] = true }
        parser.on("--status", "Print service status and exit") { @options[:status_only] = true }
        parser.on("--once", "Start, check health, then exit") { @options[:once] = true }
      end.parse!(argv)
    end

    def load_config(path)
      JSON.parse(File.read(path))
    rescue Errno::ENOENT, JSON::ParserError
      {
        "name" => "Project Mirror Dev Beta 1",
        "server" => { "host" => "127.0.0.1", "port" => 4971 },
        "aiApi" => { "host" => "127.0.0.1", "port" => 4972 },
        "runtime" => { "ramLimitMb" => 4096, "lowRamAlertMb" => 1024 }
      }
    end

    def server_url
      server = @config.fetch("server", {})
      "http://#{server.fetch("host", "127.0.0.1")}:#{server.fetch("port", 4971)}"
    end

    def ai_url
      api = @config.fetch("aiApi", {})
      "http://#{api.fetch("host", "127.0.0.1")}:#{api.fetch("port", 4972)}"
    end

    def start_node_server
      node = ENV["PROJECT_MIRROR_NODE"] || find_executable(%w[node node.exe])
      unless node
        warn "Node.js was not found. Install Node.js or set PROJECT_MIRROR_NODE."
        return
      end

      log = File.open(File.join(ROOT, "logs", "node-server.log"), "a")
      script = File.join(ROOT, "server", "server.js")
      pid = Process.spawn(process_env, node, script, chdir: ROOT, out: log, err: [:child, :out])
      @children << pid
      puts "Started Node server with PID #{pid}."
    end

    def start_python_api
      python = ENV["PROJECT_MIRROR_PYTHON"] || find_executable(%w[python python3 py python.exe])
      unless python
        warn "Python was not found. Install Python or set PROJECT_MIRROR_PYTHON. Node will use fallback optimization."
        return
      end

      env = process_env.merge("PYTHONPATH" => File.join(ROOT, "src", "python"))
      log = File.open(File.join(ROOT, "logs", "python-ai-api.log"), "a")
      pid = Process.spawn(
        env,
        python,
        "-m",
        "project_mirror_ai.server",
        "--config",
        @options[:config],
        chdir: ROOT,
        out: log,
        err: [:child, :out]
      )
      @children << pid
      puts "Started Python AI API with PID #{pid}."
    end

    def run_dotnet_menu
      dotnet = ENV["PROJECT_MIRROR_DOTNET"] || find_executable(%w[dotnet dotnet.exe])
      unless dotnet
        warn ".NET was not found. Install .NET SDK or set PROJECT_MIRROR_DOTNET."
        return
      end

      project = File.join(ROOT, "src", "dotnet", "ProjectMirrorLauncher", "ProjectMirrorLauncher.csproj")
      system(process_env, dotnet, "run", "--project", project, "--", "--config", @options[:config])
    end

    def run_swift_gui
      swift = ENV["PROJECT_MIRROR_SWIFT"] || find_executable(%w[swift swift.exe])
      unless swift
        warn "Swift was not found. Install Swift, refresh PATH, or set PROJECT_MIRROR_SWIFT."
        return
      end

      package_path = File.join(ROOT, "src", "swift", "ProjectMirrorGUI")
      system(process_env, swift, "run", "--package-path", package_path, "ProjectMirrorGUI")
    end

    def process_env
      runtime = @config.fetch("runtime", {})
      ENV.to_h.merge(
        "PROJECT_MIRROR_CONFIG" => @options[:config],
        "PROJECT_MIRROR_RAM_LIMIT_MB" => runtime.fetch("ramLimitMb", 4096).to_s
      )
    end

    def wait_for_health(url, name)
      20.times do
        uri = URI(url)
        response = Net::HTTP.get_response(uri)
        if response.is_a?(Net::HTTPSuccess)
          puts "#{name} is healthy."
          return true
        end
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout
        sleep 0.5
      end

      warn "#{name} did not report healthy yet."
      false
    end

    def print_status
      [["Node server", "#{server_url}/health"], ["Python AI API", "#{ai_url}/health"]].each do |name, url|
        uri = URI(url)
        response = Net::HTTP.get_response(uri)
        puts "#{name}: #{response.code}"
      rescue StandardError => error
        puts "#{name}: offline (#{error.message})"
      end
    end

    def stop_children
      @children.each do |pid|
        begin
          Process.kill("TERM", pid)
          Process.wait(pid)
        rescue Errno::ESRCH, Errno::ECHILD
          next
        end
      end
    end

    def find_executable(names)
      paths = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
      extensions = windows? ? ENV.fetch("PATHEXT", ".EXE;.BAT;.CMD").split(";") : [""]

      names.each do |name|
        paths.each do |directory|
          extensions.each do |extension|
            candidate = File.join(directory, name)
            candidate += extension unless candidate.downcase.end_with?(extension.downcase)
            return candidate if File.file?(candidate) && File.executable?(candidate)
          end
        end
      end

      nil
    end

    def windows?
      RbConfig::CONFIG["host_os"].match?(/mswin|mingw|cygwin/i)
    end
  end
end
