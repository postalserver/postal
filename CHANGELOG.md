# CHANGELOG

This file contains all the latest changes and updates to Postal.

## [2.2.2](https://github.com/postalserver/postal/compare/2.2.1...2.2.2) (2024-02-06)


### Bug Fixes

* adds new connection pool which will discard failed clients ([54306a9](https://github.com/postalserver/postal/commit/54306a974802c2e4d17e0980531e2d0dba08150a)), closes [#2780](https://github.com/postalserver/postal/issues/2780)
* re-add reconnect: true to database ([7bc5230](https://github.com/postalserver/postal/commit/7bc5230cbaae58fb6f8512d1d1b0e6a2eb989b56))
* upgrade nokogiri ([f05c2e4](https://github.com/postalserver/postal/commit/f05c2e4503688e59a5ef513a5a1064d0ebbb5813))


### Tests

* rename database spec file ([b9edcf5](https://github.com/postalserver/postal/commit/b9edcf5b7dda7f4976a9d3f90668bbdacea57350))

## [2.2.1](https://github.com/postalserver/postal/compare/2.2.0...2.2.1) (2024-02-03)


### Bug Fixes

* fixes issue starting application in production mode ([4528a14](https://github.com/postalserver/postal/commit/4528a14d273c141e5719f19c3b08c00364b47638))


### Code Refactoring

* remove Postal.database_url ([96ba4b8](https://github.com/postalserver/postal/commit/96ba4b8f309cfcd1d605e5c7fc05507b21c78c6f))

## [2.2.0](https://github.com/postalserver/postal/compare/2.1.6...2.2.0) (2024-02-01)


### Features

* load signing key path from POSTAL_SIGNING_KEY_PATH ([4a46f69](https://github.com/postalserver/postal/commit/4a46f690de3010f1ae4d6c17739530a4eae35c09))
* support for configuring postal with environment variables ([854aa5e](https://github.com/postalserver/postal/commit/854aa5ebc87de692b4691d48759aefd6fae9d133))


### Bug Fixes

* don't use indifferent access for job params ([2bad645](https://github.com/postalserver/postal/commit/2bad645d980ad4b712a3c863b5350e4ee2895071)), closes [#2477](https://github.com/postalserver/postal/issues/2477) [#2714](https://github.com/postalserver/postal/issues/2714) [#2476](https://github.com/postalserver/postal/issues/2476) [#2500](https://github.com/postalserver/postal/issues/2500)
* extract x-postal-tag before holding ([6b2bf90](https://github.com/postalserver/postal/commit/6b2bf9062d662ede14617c4995ffaacca023a3b1)), closes [#2684](https://github.com/postalserver/postal/issues/2684)
* fixes error messages in web ui ([71f51db](https://github.com/postalserver/postal/commit/71f51db3c2515addaf8b280667555427d64796be))
* ignore message DB migrations in autoloader ([3fb40e4](https://github.com/postalserver/postal/commit/3fb40e4e247893b314e42affa4604a7a71a52c59))
* move tracking middleware before host authorization ([49cceaa](https://github.com/postalserver/postal/commit/49cceaa6ca862965448041279fc439ecba163ff8)), closes [#2415](https://github.com/postalserver/postal/issues/2415)
* use utc timestamps when determining raw table names ([ce19bf7](https://github.com/postalserver/postal/commit/ce19bf7988d522bf46aabf68090751427e286ffc))


### Miscellaneous Chores

* add binstubs for bundle and rspec ([41f6cf4](https://github.com/postalserver/postal/commit/41f6cf4d909518526af55ecb3fcccfa8fb8e1da2))
* add script to send html emails to a local SMTP server ([8794a2f](https://github.com/postalserver/postal/commit/8794a2f44783658a075a6f3985079ae4743412b1))


### Code Refactoring

* remove explicit autoload ([0f9882f](https://github.com/postalserver/postal/commit/0f9882f13204124df630606b1b9e36787c9c4011))
* remove Postal::Job.perform method ([990b575](https://github.com/postalserver/postal/commit/990b575902c45bb1678cc95f53ef3166c4b7092e))

## [2.1.6](https://github.com/postalserver/postal/compare/2.1.5...2.1.6) (2024-01-30)


### Miscellaneous Chores

* **build:** fixes docker login action credentials ([8810856](https://github.com/postalserver/postal/commit/88108566f8ab33f1a4263a36a5c1ffc071645ac3))
* update release please to include more categories in changelog ([e156c21](https://github.com/postalserver/postal/commit/e156c21dee304de7d10c2958c493cce73c2d8fea))

## [2.1.5](https://github.com/postalserver/postal/compare/2.1.4...2.1.5) (2024-01-30)


### Bug Fixes

* duplicate string before modifying it to prevent frozen string errors ([f0a8aca](https://github.com/postalserver/postal/commit/f0a8aca6e10064fb16daefff9e22dcc20a831868))
* fixed typo (rfc number) ([2f62baa](https://github.com/postalserver/postal/commit/2f62baa238fc1102706ee4acf079b7a876b05283))
* fixes typo in on track domains page ([77bd77b](https://github.com/postalserver/postal/commit/77bd77b629fcbc44b8d27deb0d33a457b02309f2))
* mail view encoding issue [#2462](https://github.com/postalserver/postal/issues/2462) ([#2596](https://github.com/postalserver/postal/issues/2596)) ([59f4478](https://github.com/postalserver/postal/commit/59f44781973489817efb5b3435d95d25f44f90ce))
* match IPv4 mapped IPv6 addresses when searching for SMTP-IP credentials ([8b525d0](https://github.com/postalserver/postal/commit/8b525d0381a9e0113af808b9ec2eb47bf78ec60b))

## 2.1.4

### Bug Fixes

- Move RubyVer functionality to Utilities module ([5998bf](https://github.com/postalserver/postal/commit/5998bf376a274df19f29877e7f68ea75f298c9f9))

## 2.1.3

### Features
- Upgrade to Ruby 3.2.1 & Rails 6.1 ([957b78](https://github.com/postalserver/postal/commit/957b784658cda8c4c95cf1f2b65e05d99d23d427))
- Make resent-sender header optional ([c6fb8d](https://github.com/postalserver/postal/commit/c6fb8d223bdeaccdc9e8bdbd031fe3f325ac0677))
- Log CRAM-MD5 authentication failures ([9b1ed1](https://github.com/postalserver/postal/commit/9b1ed1e7e16a8f55a5bd7b7ce72195a08ca2968d))
- Always use multipart/alternative parts in generated emails ([d0db13](https://github.com/postalserver/postal/commit/d0db1345a2bf8f538b01b974e74391da6fffe2b1))

### Bug Fixes

- Use non-blocking function to negotiate TLS connections ([a7dd19](https://github.com/postalserver/postal/commit/a7dd19baac8300f4d8ee89d0050479e08fdf9176))
- Fix to newline conversion process ([9f4ef8](https://github.com/postalserver/postal/commit/9f4ef8f57a839c5529b4f00a36b832740386b4ed))
- Remove custom scrollbars ([b22f1b](https://github.com/postalserver/postal/commit/b22f1bdb2e2d66b096ca993d6a5f4f708274a4a2))
- Truncate 'output' field to avoid overflowing varchar(512) in database ([a188a1](https://github.com/postalserver/postal/commit/a188a161cbdcfd70158b09b53cef622842357c26))
- Fix link replacement in multipart messsages ([7ea00d](https://github.com/postalserver/postal/commit/7ea00dfa3bc3c7650cc2b134beacbff22101a913))
- Fix confusing error message when deleting IP pools ([cefc7d](https://github.com/postalserver/postal/commit/cefc7d17b82f610001859a8e323ee1dfde149ba5))
- Connect to correct IP rather than hostname suring SMTP delivery ([159509](https://github.com/postalserver/postal/commit/159509a3ed29ae33cba522b255904992922dcfdf))
- Change retry timings to avoid re-sending messages too early ([c8d27b](https://github.com/postalserver/postal/commit/c8d27b2963af122d6555abdf0742d2d2d6f11ce5))

## 2.1.2

### Features

- support for AMQPS for rabbitmq connections ([9f0697](https://github.com/postalserver/postal/commit/9f0697f194209f5fae5e451ba8fb888413fe37fa))

### Bug Fixes

- retry connections without SSL when SSL issue is encountered during smtp sending ([0dc682](https://github.com/postalserver/postal/commit/0dc6824a8f0315ea42b08f7e6812b821b62489c9))

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
