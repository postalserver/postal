# CHANGELOG

This file contains all the latest changes and updates to Postal.

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
