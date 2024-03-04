# Configuring Postal

Postal can be configured in two ways: using a YAML-based configuration file or through environment variables.

If you choose to use environment variables, you don't need to provide a config file. A full list of environment variables is available in the `environment-variables.md` file in this directory. 

To use a configuration file, the `POSTAL_CONFIG_FILE_PATH` environment variable will dictate where Postal will look for the config file. An example YAML file containing all available configuration is provided in the `yaml.yml` file in this directory. Remember to include the `version: 2` key/value in your configuration file.

## Development 

When developing with Postal, you can configure the application by placing a configuration file in `config/postal/postal.yml`. Alternatively, you can use environment variables by placing configuration in `.env` in the root of the application.

### Running tests

By default, tests will use the `config/postal/postal.test.yml` configuration file and the `.env.test` environment file.

## Containers

Within a container, Postal will for a config file in `/config/postal.yml` unless overriden by the `POSTAL_CONFIG_FILE_PATH` environment variable.

## Ports & Bind Addresses

The web & SMTP server listen on ports and addresses. The defaults for these can be set through configuration however, if you're running multiple instances of these on a single host you will need to specify different ports for each one.

You can use the `PORT` and `BIND_ADDRESS` environment variables to provide instance-specific values for these processes.

Additionally, `HEALTH_SERVER_PORT` and `HEALTH_SERVER_BIND_ADDRESS`  can be used to set the port/address to use for running the health server alongside other processes.

## Legacy configuration

Legacy configuration files from Postal v1 and v2 are still supported. If you wish to use a new configuration option that is not available in the legacy format, you will need to upgrade the file to version 2.
