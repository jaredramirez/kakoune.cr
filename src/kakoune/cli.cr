require "option_parser"
require "json"
require "file_utils"

module Kakoune::CLI
  extend self

  RUNTIME_PATH = Path[ENV["KCR_RUNTIME"]]

  KCR_LOGO_URL = "https://github.com/alexherbo2/kcr-resources/raw/master/logo/kcr.svg"

  struct Options
    property command : Symbol?
    property context = Context.new(session: ENV["KAKOUNE_SESSION"]?, client: ENV["KAKOUNE_CLIENT"]?)
    property buffer_names = [] of String
    property working_directory : Path?
    property position = Position.new
    property length = 0
    property timestamp = 0
    property? raw = false
    property? lines = false
    property? stdin = false
    property kakoune_arguments = [] of String
  end

  def start(argv)
    # Environment variables
    if ENV["KCR_DEBUG"] == "1"
      Log.level = ::Log::Severity::Debug
    end

    # Options
    options = Options.new

    # Option parser
    option_parser = OptionParser.new do |parser|
      parser.banner = "Usage: kcr <command> [arguments]"

      parser.on("-s NAME", "--session=NAME", "Session name") do |name|
        options.context.session_name = name
      end

      parser.on("-c NAME", "--client=NAME", "Client name") do |name|
        options.context.client_name = name
      end

      parser.on("-b NAME", "--buffer=NAME", "Buffer name") do |name|
        options.buffer_names << name
      end

      parser.on("-r", "--raw", "Use raw output") do
        options.raw = true
      end

      parser.on("-R", "--no-raw", "Do not use raw output") do
        options.raw = false
      end

      parser.on("-l", "--lines", "Read input as JSON Lines") do
        options.lines = true
      end

      parser.on("-d", "--debug", "Debug mode") do
        Log.level = ::Log::Severity::Debug
      end

      parser.on("-v", "--version", "Display version") do
        puts VERSION
        exit
      end

      parser.on("-V", "--version-notes", "Display version notes") do
        changelog = read("pages/changelog.md")

        # Print version notes
        puts <<-EOF
        ---
        version: #{VERSION}
        ---

        #{changelog}
        EOF

        exit
      end

      parser.on("-h", "--help", "Show help") do
        puts parser
        exit
      end

      parser.on("--", "Stop handling options") do
        parser.stop
      end

      parser.on("-", "Stop handling options and read stdin") do
        parser.stop
        options.stdin = true
      end

      parser.on("tldr", "Show usage") do
        options.command = :tldr
      end

      parser.on("prompt", "Print prompt") do
        options.command = :prompt
      end

      parser.on("init", "Print functions") do
        options.command = :init

        parser.banner = "Usage: kcr init <name>"

        parser.on("kakoune", "Print Kakoune definitions") do
          options.command = :init_kakoune
        end

        parser.on("starship", "Print Starship configuration") do
          options.command = :init_starship
        end
      end

      parser.on("install", "Install files") do
        options.command = :install

        parser.banner = "Usage: kcr install <name>"

        parser.on("commands", "Install commands") do
          options.command = :install_commands
        end

        parser.on("desktop", "Install desktop application") do
          options.command = :install_desktop_application
        end
      end

      parser.on("env", "Print Kakoune environment information") do
        options.command = :env
      end

      parser.on("play", "Start playground") do
        options.command = :play
      end

      parser.on("create", "Create a new session") do
        options.command = :create
      end

      parser.on("attach", "Connect to session") do
        options.command = :attach
      end

      parser.on("kill", "Kill session") do
        options.command = :kill
      end

      parser.on("list", "List sessions") do
        options.command = :list
      end

      parser.on("shell", "Start an interactive shell") do
        options.command = :shell

        parser.on("-d PATH", "--working-directory=PATH", "Working directory") do |path|
          options.working_directory = Path[path]
        end
      end

      parser.on("edit", "Edit files") do
        options.command = :edit
      end

      parser.on("open", "Open files") do
        options.command = :open
      end

      parser.on("send", "Send commands to client at session") do
        options.command = :send
      end

      parser.on("echo", "Print arguments") do
        options.command = :echo
      end

      parser.on("get", "Get states from a client in session") do
        options.command = :get

        parser.on("-V NAME", "--value=NAME", "Value name") do |name|
          options.kakoune_arguments << "%val{#{name}}"
        end

        parser.on("-O NAME", "--option=NAME", "Option name") do |name|
          options.kakoune_arguments << "%opt{#{name}}"
        end

        parser.on("-R NAME", "--register=NAME", "Register name") do |name|
          options.kakoune_arguments << "%reg{#{name}}"
        end

        parser.on("-S COMMAND", "--shell=COMMAND", "Shell command") do |command|
          options.kakoune_arguments << "%sh{#{command}}"
        end
      end

      parser.on("cat", "Print buffer content") do
        options.command = :cat
      end

      parser.on("pipe", "Pipe selections to a program") do
        options.command = :pipe
      end

      parser.on("escape", "Escape arguments") do
        options.command = :escape
      end

      parser.on("set-completion", "Set completion") do
        options.command = :set_completion

        parser.on("--line=VALUE", "Line number") do |value|
          options.position.line = value.to_i
        end

        parser.on("--column=VALUE", "Column number") do |value|
          options.position.column = value.to_i
        end

        parser.on("--length=VALUE", "Length value") do |value|
          options.length = value.to_i
        end

        parser.on("--timestamp=VALUE", "Timestamp value") do |value|
          options.timestamp = value.to_i
        end
      end

      parser.on("help", "Show help") do
        options.command = :help
      end

      parser.on("version", "Display version") do
        options.command = :version
      end

      parser.invalid_option do |flag|
        abort "Error: Unknown option: #{flag}"
      end
    end

    # Parse options
    option_parser.parse(argv)

    parse_position(argv) do |line, column|
      options.position = Position.new(line, column)
      options.kakoune_arguments << "+%d:%d" % { line, column }
    end

    # Current context
    context = options.context.scope

    # Environment variables
    environment = {
      "KAKOUNE_SESSION" => options.context.session_name,
      "KAKOUNE_CLIENT" => options.context.client_name,
      "KCR_RUNTIME" => RUNTIME_PATH.to_s,
      "KCR_DEBUG" => Log.level.debug? ? "1" : "0",
      "KCR_VERSION" => VERSION
    }

    # Run command
    case options.command
    when :tldr
      puts read("pages/tldr.txt")

    when :prompt
      case context
      when Client
        print "%s@%s" % { options.context.client_name, options.context.session_name }
      when Session
        print "null@%s" % options.context.session_name
      else
        exit(1)
      end

    when :init
      option_parser.parse(["init", "--help"])

    when :init_kakoune
      puts read("init/kakoune.kak")

    when :init_starship
      puts read("init/starship.toml")

    when :install
      option_parser.parse(["install", "--help"])

    when :install_commands
      install_commands

    when :install_desktop_application
      install_desktop_application

    when :env
      if options.raw?
        text = environment.join('\n') do |key, value|
          "#{key}=#{value}"
        end

        puts text
      else
        print_json(environment)
      end

    when :play
      file = argv.fetch(0, RUNTIME_PATH / "init/example.kak")

      config = <<-EOF
        source #{RUNTIME_PATH / "init/kakoune.kak"}
        source #{RUNTIME_PATH / "init/playground.kak"}
        initialize #{file}
      EOF

      # Forward the --debug flag
      environment["KCR_DEBUG"] = "1"

      # Start playground
      Process.run("kak", ["-e", config], env: environment, input: :inherit, output: :inherit, error: :inherit)

    when :create
      session_name = argv.fetch(0, options.context.session_name)

      if session_name
        Session.create(session_name)
      end

    when :attach
      session_name = argv.fetch(0, options.context.session_name)

      if !session_name
        abort "No session in context"
      end

      Session.new(session_name).attach

    when :kill
      session_name = argv.fetch(0, options.context.session_name)

      if !session_name
        abort "No session in context"
      end

      Session.new(session_name).kill

    when :list
      data = Session.all.flat_map do |session|
        working_directory = session.working_directory

        [{ session: session.name, client: nil, buffer_name: nil, working_directory: working_directory }] +

        session.clients.map do |client|
          { session: session.name, client: client.name, buffer_name: client.current_buffer.name, working_directory: working_directory }
        end
      end

      if options.raw?
        text = data.join('\n') do |data|
          data.values.join('\t') do |field|
            field || "null"
          end
        end

        puts text
      else
        print_json(data)
      end

    when :shell
      if !context
        abort "No session in context"
      end

      command, arguments = if argv.any?
        { argv[0], argv[1..] }
      else
        { ENV["SHELL"], [] of String }
      end

      session = options.context.session

      if !session.exists?
        puts "Create the session: #{session.name}"
        session.create
      end

      working_directory = options.working_directory || session.get("%sh{pwd}")[0]

      # Start an interactive shell
      # – Forward options and working directory
      Process.run(command, arguments, env: environment, chdir: working_directory.to_s, input: :inherit, output: :inherit, error: :inherit)

    when :edit
      if context
        context.fifo(STDIN) if options.stdin?
        context.edit(argv, options.position)
      else
        Process.run("kak", options.kakoune_arguments + ["--"] + argv, input: :inherit, output: :inherit, error: :inherit)
      end

    when :open
      if context
        context.edit(argv, options.position)
      else
        open_client = <<-EOF
          rename-client dummy
          new evaluate-commands -client dummy quit
        EOF

        Process.setsid("kak", ["-ui", "dummy", "-e", open_client] + options.kakoune_arguments + ["--"] + argv)
      end

    when :send
      if !context
        abort "No session in context"
      end

      command_builder = CommandBuilder.new

      command = if options.raw?
        STDIN.gets_to_end
      else
        command_builder.add(argv) if argv.any?
        command_builder.add(STDIN, options.lines?) if options.stdin? || options.lines?
        command_builder.build
      end

      context.send(command)

    when :echo
      # Example – Streaming data:
      #
      # kcr echo -- evaluate-commands -draft {} |
      # kcr echo - execute-keys '<a-i>b' 'i<backspace><esc>' 'a<del><esc>'
      IO.copy(STDIN, STDOUT) if options.stdin?

      if argv.any?
        print_json(argv)
      end

    when :get
      if !context
        abort "No session in context"
      end

      # Example – Streaming data:
      #
      # kcr get --option pokemon |
      # kcr get --option regions -
      IO.copy(STDIN, STDOUT) if options.stdin?

      arguments = options.kakoune_arguments + argv

      if arguments.any?
        data = context.get(arguments)

        if options.raw?
          puts data.join('\n')
        else
          print_json(data)
        end
      end

    when :cat
      if !context
        abort "No session in context"
      end

      buffer_names = options.buffer_names + argv
      session = options.context.session
      client = options.context.client

      buffer_contents = if buffer_names.empty?
        [client.current_buffer.content]
      else
        buffer_names.map { |name| session.buffer(name).content }
      end

      if options.raw?
        puts buffer_contents.join('\n')
      else
        print_json(buffer_contents)
      end

    when :pipe
      if !context
        abort "No session in context"
      end

      if options.stdin?
        selections = Array(String).from_json(STDIN)
        context.set_selections_content(selections)
      else
        command = argv.shift
        context.pipe(command, argv)
      end

    when :escape
      command = CommandBuilder.build do |builder|
        builder.add(argv) if argv.any?
        builder.add(STDIN, options.lines?) if options.stdin? || options.lines?
      end

      puts command

    when :set_completion
      if !context.is_a?(Client)
        abort "No client in context"
      end

      name = argv.first

      command = CompletionBuilder.build(name, options.position.line, options.position.column, options.length, options.timestamp) do |builder|
        builder.add(STDIN)
      end

      context.send(command)

    when :help
      option_parser.parse(argv + ["--help"])

    when :version
      puts VERSION
      exit

    else
      # Missing command
      if argv.empty?
        abort option_parser
      end

      # Extending kakoune.cr
      subcommand = argv.shift
      command = "kcr-#{subcommand}"

      # Cannot find executable
      if !Process.find_executable(command)
        abort "Cannot find executable: #{command}"
      end

      # Run subcommand
      # – Forward options
      Process.run(command, argv, env: environment, input: :inherit, output: :inherit, error: :inherit)
    end
  end

  def install_commands
    command_paths = Dir[RUNTIME_PATH / "commands" / "*" / "kcr-*"]
    bin_path = Path["~/.local/bin"].expand(home: true)

    { command_paths, bin_path.to_s }.tap do |sources, destination|
      Dir.mkdir_p(destination) unless Dir.exists?(destination)
      FileUtils.cp(sources, destination)
      puts "Copied #{sources} to #{destination}"
    end
  end

  def install_desktop_application
    # Download kakoune.cr logo
    kcr_logo_install_path = Path[ENV["XDG_DATA_HOME"], "icons/hicolor/scalable/apps/kcr.svg"]

    { KCR_LOGO_URL, kcr_logo_install_path.to_s }.tap do |source, destination|
      status = Process.run("curl", { "-sSL", source, "--create-dirs", "-o", destination })

      if status.success?
        puts "Downloaded #{source} to #{destination}"
      else
        STDERR.puts "Cannot download #{source}"
      end
    end

    # Install the desktop application
    kcr_desktop_path = RUNTIME_PATH / "applications/kcr.desktop"
    kcr_desktop_install_path = Path[ENV["XDG_DATA_HOME"], "applications/kcr.desktop"]

    { kcr_desktop_path.to_s, kcr_desktop_install_path.to_s, kcr_desktop_install_path.dirname }.tap do |source, destination, directory|
      Dir.mkdir_p(directory) unless Dir.exists?(directory)
      FileUtils.cp(source, destination)
      puts "Copied #{source} to #{destination}"
    end
  end

  def read(part)
    File.read(RUNTIME_PATH / part)
  end

  def print_json(data)
    json = data.to_json

    if STDOUT.tty?
      input = IO::Memory.new(json)
      Process.run("jq", input: input, output: :inherit)
    else
      puts json
    end
  end

  def parse_position(arguments, &block)
    unhandled_arguments = [] of String

    arguments.each do |argument|
      case argument
      when /^[+]([0-9]+)$/
        yield $1.to_i, 0
      when /^[+]([0-9]+):([0-9]+)$/
        yield $1.to_i, $2.to_i
      else
        unhandled_arguments << argument
      end
    end

    arguments.replace(unhandled_arguments)
  end
end
