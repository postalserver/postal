require 'yaml'
require 'pathname'
require_relative 'error'
require_relative 'version'

module Postal

  def self.host
    @host ||= config.web.host || "localhost:5000"
  end

  def self.protocol
    @protocol ||= config.web.protocol || "http"
  end

  def self.host_with_protocol
    @host_with_protocol ||= "#{protocol}://#{host}"
  end

  def self.app_root
    @app_root ||= Pathname.new(File.expand_path('../../../', __FILE__))
  end

  def self.config
    @config ||= begin
      require 'hashie/mash'
      Hashie::Mash.new(yaml_config)
    end
  end

  def self.config_root
    @config_root ||= begin
      if __FILE__ =~ /\A\/opt\/postal/
        Pathname.new("/opt/postal/config")
      elsif ENV['AM_CONFIG_ROOT']
        Pathname.new(ENV['AM_CONFIG_ROOT'])
      else
        Pathname.new(File.expand_path("../../../config", __FILE__))
      end
    end
  end

  def self.config_file_path
    @config_file_path ||= File.join(config_root, 'postal.yml')
  end

  def self.yaml_config
    @yaml_config ||= File.exist?(config_file_path) ? YAML.load_file(config_file_path) : {}
  end

  def self.database_url
    if config.main_db
      "mysql2://#{config.main_db.username}:#{config.main_db.password}@#{config.main_db.host}:#{config.main_db.port}/#{config.main_db.database}?encoding=#{config.main_db.encoding || 'utf8mb4'}"
    else
      "mysql2://root@localhost/postal"
    end
  end

  def self.logger_for(name)
    @loggers ||= {}
    @loggers[name.to_sym] ||= begin
      require 'postal/app_logger'
      if config.logging.stdout || ENV['LOG_TO_STDOUT']
        Postal::AppLogger.new(name, STDOUT)
      else
        Postal::AppLogger.new(name, app_root.join('log', "#{name}.log"), config.logging.max_log_files || 10, (config.logging.max_log_file_size || 20).megabytes)
      end
    end
  end

  def self.process_name
    @process_name ||= begin
      string = "host:#{Socket.gethostname} pid:#{Process.pid}"
      string += " procname:#{ENV['PROC_NAME']}" if ENV['PROC_NAME']
      string
    rescue
      "pid:#{Process.pid}"
    end
  end

  def self.locker_name
    string = process_name.dup
    string += " job:#{Thread.current[:job_id]}" if Thread.current[:job_id]
    string
  end

  def self.smtp_from_name
    config.smtp&.from_name || "Postal"
  end

  def self.smtp_from_address
    config.smtp&.from_address || "postal@example.com"
  end

  def self.smtp_private_key
    @smtp_private_key ||= OpenSSL::PKey::RSA.new(File.read(smtp_private_key_path))
  end

  def self.smtp_private_key_path
    config_root.join('smtp.key')
  end

  def self.smtp_certificate_path
    config_root.join('smtp.cert')
  end

  def self.smtp_certificate_data
    @smtp_certificate_data ||= File.read(smtp_certificate_path)
  end

  def self.smtp_certificates
    @smtp_certificates ||= begin
      certs = self.smtp_certificate_data.scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m)
      certs.map do |c|
        OpenSSL::X509::Certificate.new(c)
      end.freeze
    end
  end

  def self.lets_encrypt_private_key_path
    @lets_encrypt_private_key_path ||= Postal.config_root.join('lets_encrypt.pem')
  end

  def self.signing_key_path
    config_root.join('signing.key')
  end

  def self.signing_key
    @signing_key ||= OpenSSL::PKey::RSA.new(File.read(signing_key_path))
  end

  def self.amrp_dkim_dns_record
    public_key = signing_key.public_key.to_s.gsub(/\-+[A-Z ]+\-+\n/, '').gsub(/\n/, '')
    "v=DKIM1; t=s; h=sha256; p=#{public_key};"
  end

  class ConfigError < Postal::Error
  end

  def self.check_config!
    unless File.exist?(self.config_file_path)
      raise ConfigError, "No config found at #{self.config_file_path}"
    end

    unless File.exist?(self.smtp_private_key_path)
      raise ConfigError, "No SMTP private key found at #{self.smtp_private_key_path}"
    end

    unless File.exist?(self.smtp_certificate_path)
      raise ConfigError, "No SMTP certificate found at #{self.smtp_certificate_path}"
    end

    unless File.exists?(self.lets_encrypt_private_key_path)
      raise ConfigError, "No Let's Encrypt private key found at #{self.lets_encrypt_private_key_path}"
    end

    unless File.exists?(self.signing_key_path)
      raise ConfigError, "No signing key found at #{self.signing_key_path}"
    end
  end

  def self.anonymous_signup?
    config.general&.anonymous_signup != false
  end

end
