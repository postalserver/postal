# CHANGELOG

This file contains all the latest changes and updates to Postal.

## 2.1.1

### Features

- allow @ and % in webhook urls ([c60c69](https://github.com/postalserver/postal/commit/c60c69db1800775776da4c28c68001f230fe5888))

### Bug Fixes

- fixes broken styling on errors ([a0c87e](https://github.com/postalserver/postal/commit/a0c87e7bf16a19f06c13797e3329a4fed91370a1))
- use the Postal logger system for the rails log ([5b04fa](https://github.com/postalserver/postal/commit/5b04faca39c69757bd7d695b82984f8b4a41cac3))

## 2.1.0

### Features

- support for configuring the default spam threshold values for new servers ([724325](https://github.com/postalserver/postal/commit/724325a1b97d61ef1e134240e4f70aaad39dbf98))
- support for using rspamd for spam filtering ([a1277b](https://github.com/postalserver/postal/commit/a1277baba56ea6d6b4da4bba87b00cd3dbf0305e))

### Bug Fixes

- **dkim:** fixes timing race condition when signing emails ([232b60](https://github.com/postalserver/postal/commit/232b605f5bb8ab61156e1fb9860705fed017ed41))
- **docker:** fixes issue caused by changes to underlying ruby:2.6 image ([6570ff](https://github.com/postalserver/postal/commit/6570ff1f7797ff9a307dd96ed4ff37be14bf79ab))

## 2.0.0

### Features

- **ui:** add footer with links to docs and discussions ([1247da](https://github.com/postalserver/postal/commit/1247dae2e060a695a13a30ba072ca5e6dea45202))

### Bug Fixes

- **dkim:** ensure DKIM-Signature headers are appropriately wrapped ([476129](https://github.com/postalserver/postal/commit/476129cc1ba44e9014768d5ba7193587f78cb5d5))
- **docs:** update port numbers to specify the actual port number the SMTP server is listening on ([4404b3](https://github.com/postalserver/postal/commit/4404b3e02c1722808157c3f590310ead9e28641d))
- **logging:** fix spelling of graylog ([2a11e0](https://github.com/postalserver/postal/commit/2a11e0c0a5b7c7f630af28cf4af5511d9bce6dda))

## 2.0.0-beta.1

### Features

- **config:** support for loading a postal.local.yml config file from the config root if it exists ([8e3294](https://github.com/postalhq/postal/commit/8e3294ba1af4b797d36bd1ca9226190ed80f65cc))
- **smtp_server:** allow bind address to be configured ([4a410c](https://github.com/postalhq/postal/commit/4a410c8c9f6fa1ef993a68c37afeaf31230585f7))
- add priorities to IP address assignment ([21a8d8](https://github.com/postalhq/postal/commit/21a8d890459958375d4a49a5b7f31f4900a9e8b1))

### Bug Fixes

- **dkim:** fixes bug with signing dkim bodies ([189dfa](https://github.com/postalhq/postal/commit/189dfa509b4750f1e4cc6f43f6565edd3a35139c))
- **smtp_server:** attempt to redact plain-text passwords from log output ([fcb636](https://github.com/postalhq/postal/commit/fcb63616e1ce578d7d4fd1c96ddc4ee0f7a71534))
- **smtp_server:** fixes issue with malformed rcpt to ([e0ba05](https://github.com/postalhq/postal/commit/e0ba05acb11108d98a460ae3fac653ceefb5f672))
- **smtp_server:** refactor mx lookups to randomly order mx records with the same priority ([bc2239](https://github.com/postalhq/postal/commit/bc22394fdd4f26dddd576840b49d7c25802cda7d))
- **smtp_server:** updated line split logic, normalize all linebreaks to \r\n ([e8ba9e](https://github.com/postalhq/postal/commit/e8ba9ee4276e81af84ecb6ff6f0c024ef99f6ddc))
- add resolv 0.2.1 ([eef1a3](https://github.com/postalhq/postal/commit/eef1a365a28e133750c4d5a4ac0eeeed223e303d))
- always obey POSTAL_CONFIG_ROOT ([1d22ca](https://github.com/postalhq/postal/commit/1d22ca0f85b58b04aedde9071d9fc5ecd44af4de))
- fix issue with determining if an SMTP connection is encrypted or not ([73870d](https://github.com/postalhq/postal/commit/73870d6a92400fc8ec1493016817dfac074ffd06))
- remove a few leftover fast server artifacts ([5cd06e](https://github.com/postalhq/postal/commit/5cd06e126b6caac502245754b360194365152415))
- replace Fixnum with Integer ([52a23f](https://github.com/postalhq/postal/commit/52a23fa86f94c14dfc7edccbf414dda34c46bc12))
