# frozen_string_literal: true

require "highline"

module UserCreator

  ENV_PREFIX = "POSTAL_INITIAL_USER_"
  REQUIRED_ENV_VARS = %w[EMAIL FIRST_NAME LAST_NAME PASSWORD].map { |s| "#{ENV_PREFIX}#{s}" }.freeze

  class << self

    # Create (or update) a user. If POSTAL_INITIAL_USER_EMAIL is set in the
    # environment, runs non-interactively using POSTAL_INITIAL_USER_*
    # variables and upserts by email. Otherwise prompts on STDIN.
    def start(&block)
      if non_interactive_env?
        start_from_env(&block)
      else
        start_interactive(&block)
      end
    end

    private

    def non_interactive_env?
      ENV["#{ENV_PREFIX}EMAIL"].to_s.strip != ""
    end

    def start_from_env(&block)
      puts "\e[32mPostal User Creator\e[0m (non-interactive mode)"

      missing = REQUIRED_ENV_VARS.reject { |k| ENV[k].to_s.strip != "" }
      unless missing.empty?
        warn "\e[31mFailed to create user\e[0m"
        warn " * missing required environment variables: #{missing.join(', ')}"
        exit 1
      end

      email = ENV.fetch("#{ENV_PREFIX}EMAIL")
      user = User.find_by(email_address: email) || User.new
      user.email_address = email
      user.first_name = ENV.fetch("#{ENV_PREFIX}FIRST_NAME")
      user.last_name = ENV.fetch("#{ENV_PREFIX}LAST_NAME")
      user.password = ENV.fetch("#{ENV_PREFIX}PASSWORD")

      block.call(user) if block_given?

      action = user.new_record? ? "created" : "updated"
      if user.save
        puts "User \e[32m#{user.email_address}\e[0m has been #{action}"
      else
        warn "\e[31mFailed to create user\e[0m"
        user.errors.full_messages.each do |error|
          warn " * #{error}"
        end
        exit 1
      end
    end

    def start_interactive(&block)
      cli = HighLine.new
      puts "\e[32mPostal User Creator\e[0m"
      puts "Enter the information required to create a new Postal user."
      puts "This tool is usually only used to create your initial admin user."
      puts
      user = User.new
      user.email_address = cli.ask("E-Mail Address".ljust(20, " ") + ": ")
      user.first_name = cli.ask("First Name".ljust(20, " ") + ": ")
      user.last_name = cli.ask("Last Name".ljust(20, " ") + ": ")
      user.password = cli.ask("Initial Password".ljust(20, " ") + ": ") { |value| value.echo = "*" }

      block.call(user) if block_given?
      puts
      if user.save
        puts "User has been created with e-mail address \e[32m#{user.email_address}\e[0m"
      else
        puts "\e[31mFailed to create user\e[0m"
        user.errors.full_messages.each do |error|
          puts " * #{error}"
        end
      end
      puts
    end

  end

end
