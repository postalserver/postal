# CHANGELOG

This file contains all the latest changes and updates to Postal.

## [3.0.2](https://github.com/postalserver/postal/compare/3.0.1...3.0.2) (2024-03-05)


### Bug Fixes

* default to listening on all addresses when using legacy config ([48f6494](https://github.com/postalserver/postal/commit/48f6494240eb0374d5f865425b362e6f306b2653))


### Miscellaneous Chores

* removing arm64 support until we can get a reasonable build pipeline sorted ([e8e44f5](https://github.com/postalserver/postal/commit/e8e44f54b09426c8a04e466bc037851a0833d124))

## [3.0.1](https://github.com/postalserver/postal/compare/3.0.0...3.0.1) (2024-03-05)


### Bug Fixes

* fix issue with sending mail when smtp relays are configured ([6dd6e29](https://github.com/postalserver/postal/commit/6dd6e29929c70eaa8b9d3b33c184996b0b6abb82))

## [3.0.0](https://github.com/postalserver/postal/compare/2.3.2...3.0.0) (2024-03-04)

This version of Postal introduces a number of larger changes. Please be sure to follow the [upgrade guide](https://docs.postalserver.io/getting-started/upgrade-to-v3) when upgrading to Postal v3. Highlights include:

* Removal of RabbitMQ dependency
* Removal of `cron` and `requeuer` processes
* Improved logging
* Improved configuration
* Adds prometheus metric exporters for workers and SMTP servers
* Only accepted RFC-compliant end-of-DATA sequences (to avoid SMTP smuggling)

### Features

* add health server and prometheus metrics to worker ([a2eb70e](https://github.com/postalserver/postal/commit/a2eb70e))
* add option to delay starting processes until all migrations are run ([1c5ff5a](https://github.com/postalserver/postal/commit/1c5ff5a))
* add prometheus metrics to smtp server ([2e7b36c](https://github.com/postalserver/postal/commit/2e7b36c))
* add prometheus metrics to worker ([bea7450](https://github.com/postalserver/postal/commit/bea7450))
* more consistent logging ([044058d](https://github.com/postalserver/postal/commit/044058d))
* new background work process ([dc8e895](https://github.com/postalserver/postal/commit/dc8e895))
* new configuration system (and schema) (#2819) ([0163ac3](https://github.com/postalserver/postal/commit/0163ac3))
* only accept RFC-compliant End-of-DATA sequence ([0140dc4](https://github.com/postalserver/postal/commit/0140dc4))
* add "postal:update" task ([b35eea6](https://github.com/postalserver/postal/commit/b35eea6338f1888bfac2ed377d0a412680483e90))
* add helm env var config exporter ([8938988](https://github.com/postalserver/postal/commit/893898835dcd9684ae3401549389b173a3feb1fb))
* include list-unsubscribe-post header in dkim signatures ([e1bae60](https://github.com/postalserver/postal/commit/e1bae60768c4cf151d5a6a141985c78753dce02d)), closes [#2789](https://github.com/postalserver/postal/issues/2789) [#2788](https://github.com/postalserver/postal/issues/2788)
* support for additional SMTP client options ([0daa667](https://github.com/postalserver/postal/commit/0daa667b55fd9b948da643d37ec438e341809369))


### Bug Fixes

* fixes potential issue if machine hostname cannot be determined ([0fcf778](https://github.com/postalserver/postal/commit/0fcf778))
* raise an error if MX lookup times out during sending ([fadca88](https://github.com/postalserver/postal/commit/fadca88)), closes [#2833](https://github.com/postalserver/postal/issues/2833)
* set correct component in health server log lines ([a7a9a18](https://github.com/postalserver/postal/commit/a7a9a18))
* translate unicode domain names to Punycode for compatibility with DNS (#2823) ([be0df7b](https://github.com/postalserver/postal/commit/be0df7b))
* remove user email verification ([e05f0b3](https://github.com/postalserver/postal/commit/e05f0b3616da8b962b763c48a2139882fd88047a))
* unescape in URLs which are stored for tracking ([1da1182](https://github.com/postalserver/postal/commit/1da1182c23e9673d8f109d8ed29e80983cdccabf)), closes [#2568](https://github.com/postalserver/postal/issues/2568) [#907](https://github.com/postalserver/postal/issues/907) [#115](https://github.com/postalserver/postal/issues/115)
* update wording about tracking domain cnames ([0d3eccb](https://github.com/postalserver/postal/commit/0d3eccb368630b4fd21bd858a7829ec00c35f153)), closes [#2808](https://github.com/postalserver/postal/issues/2808)


### Documentation

* add message_db.encoding to config docs ([0c1f925](https://github.com/postalserver/postal/commit/0c1f925))
* add new repo readme welcome image ([afa1726](https://github.com/postalserver/postal/commit/afa1726))
* add quick contributing instructions ([8d21adc](https://github.com/postalserver/postal/commit/8d21adc))
* update SECURITY policy ([cfc1c9b](https://github.com/postalserver/postal/commit/cfc1c9b))
* update docs for how IP address allocation works ([07eb152](https://github.com/postalserver/postal/commit/07eb152)), closes [#2209](https://github.com/postalserver/postal/issues/2209)

### Miscellaneous Chores

* upgrade bundler to 2.5.6 ([1ae8ef6](https://github.com/postalserver/postal/commit/1ae8ef6))
* upgrade rails to 7.0 and other dependencies ([ecd09a2](https://github.com/postalserver/postal/commit/ecd09a2))
* upgrade ruby to 3.2.2 and nodejs to 20.x ([72715fe](https://github.com/postalserver/postal/commit/72715fe))

## [2.3.2](https://github.com/postalserver/postal/compare/2.3.1...2.3.2) (2024-03-01)


### Bug Fixes

* truncate output and details in deliveries to 250 characters ([694240d](https://github.com/postalserver/postal/commit/694240ddcdef1df9b32888de8fb743d2dee86462)), closes [#2831](https://github.com/postalserver/postal/issues/2831)

## [2.3.1](https://github.com/postalserver/postal/compare/2.3.0...2.3.1) (2024-02-23)


### Bug Fixes

* update raw headers after changing messages to during parsing ([2834e2c](https://github.com/postalserver/postal/commit/2834e2c37971db9b0b0498e38b382cf1f8ee26eb)), closes [#2816](https://github.com/postalserver/postal/issues/2816)


### Miscellaneous Chores

* **github-actions:** add 'docs' label to exclude from staleness checks ([57b72fb](https://github.com/postalserver/postal/commit/57b72fb4b7f7fc934cfa23906de65b8f6d6d1978))
* **github-actions:** add action to close stale issues and PRs ([d90a456](https://github.com/postalserver/postal/commit/d90a456dfa661d87e820160d2045c73c765564d2))
* **github-actions:** allow stale action to be run on demand ([559b08d](https://github.com/postalserver/postal/commit/559b08ddd31ecd904fd09c1e2822161b853166b9))

## [2.3.0](https://github.com/postalserver/postal/compare/2.2.2...2.3.0) (2024-02-13)


### Features

* privacy mode ([15f9671](https://github.com/postalserver/postal/commit/15f9671b667cf369255aaa27ee4257267990095c))
* remove strip_received_headers config option ([ed2e62b](https://github.com/postalserver/postal/commit/ed2e62b94fe76d7aeca0ede98f11a1c4f94c5996))


### Bug Fixes

* add ruby platform to gemfile ([1fceef7](https://github.com/postalserver/postal/commit/1fceef7cea76352fd6166fb3f1e8d0ff8591078e))
* explicitly disable TLS & starttls for unknown SSL modes ([42ab5b3](https://github.com/postalserver/postal/commit/42ab5b3a6b21992c89f8479137699dc9090f0ccc)), closes [#2564](https://github.com/postalserver/postal/issues/2564)
* fix bug with received header in SMTP server ([ba5bfbd](https://github.com/postalserver/postal/commit/ba5bfbd6a0af9ea33bedb2948822417bd1a3fbc5))
* retry mysql connections on message DB pool ([f9f7fb3](https://github.com/postalserver/postal/commit/f9f7fb30fee46b661b6dccde4362383ea591532b))
* use correct method for disconnecting smtp connections ([7c23994](https://github.com/postalserver/postal/commit/7c23994d243ec7d9a17ee053f8c3fa8de0a33097))


### Styles

* **rubocop:** disable complexity cops for now ([930cf39](https://github.com/postalserver/postal/commit/930cf39dba37401f90e293c938dee07daf3d9a31))
* **rubocop:** disable Style/SpecialGlobalVars ([be97f43](https://github.com/postalserver/postal/commit/be97f4330897f96085eb29ed7019b1a3e50af88e))
* **rubocop:** disable Style/StringConcatenation cop ([d508772](https://github.com/postalserver/postal/commit/d508772a40ef26e5c3a8304aa1f2b8c7985081bd))
* **rubocop:** Layout/* ([0e0aca0](https://github.com/postalserver/postal/commit/0e0aca06c90f6d2f4db1c4090a35c4537c76e13a))
* **rubocop:** Layout/EmptyLineAfterMagicComment ([0e4ed5c](https://github.com/postalserver/postal/commit/0e4ed5ca0393f9a56e1efa7ae377d2e4b876bfe1))
* **rubocop:** Layout/EmptyLines ([0cf35a8](https://github.com/postalserver/postal/commit/0cf35a83926d499a279775bcc32dd4ea79b7a8c9))
* **rubocop:** Layout/EmptyLinesAroundBlockBody ([cfd8d63](https://github.com/postalserver/postal/commit/cfd8d63321d1821aad7fa9d6b8462c3d551aca61))
* **rubocop:** Layout/LeadingCommentSpace ([59f299b](https://github.com/postalserver/postal/commit/59f299b704533488b74075beb8692397eb434aab))
* **rubocop:** Layout/LineLength ([e142d0d](https://github.com/postalserver/postal/commit/e142d0da5fbee19e6f9f1741ff9dee0a2d7dd169))
* **rubocop:** Layout/MultilineMethodCallBraceLayout ([a5d5ba5](https://github.com/postalserver/postal/commit/a5d5ba5326728413bb95456e92c854977d225a7f))
* **rubocop:** Lint/DuplicateBranch ([a1dc0f7](https://github.com/postalserver/postal/commit/a1dc0f77ac69937d7f30c9401608dfbe66987d45))
* **rubocop:** Lint/DuplicateMethods ([bab6346](https://github.com/postalserver/postal/commit/bab6346239e4f50bdd51101c45f3a0cd66f47096))
* **rubocop:** Lint/IneffectiveAccessModifier ([6ad56ee](https://github.com/postalserver/postal/commit/6ad56ee9c9e5bad19b065fcec3ada3280adbb1f4))
* **rubocop:** Lint/MissingSuper ([4674e63](https://github.com/postalserver/postal/commit/4674e63b5ff84307f5b772e870e88109af2daf52))
* **rubocop:** Lint/RedundantStringCoercion ([12a5ef3](https://github.com/postalserver/postal/commit/12a5ef3279bf6c1e5c38bf7e846de1d17bf98c09))
* **rubocop:** Lint/ShadowedException ([0966b44](https://github.com/postalserver/postal/commit/0966b44018bc1e2f131358635776fcc3b75ee8eb))
* **rubocop:** Lint/ShadowingOuterLocalVariable ([7119e86](https://github.com/postalserver/postal/commit/7119e8642dffeee7a27f90145073e45664ea58d3))
* **rubocop:** Lint/SuppressedException ([278ef08](https://github.com/postalserver/postal/commit/278ef0886ac53e6bed15793301dc69c95a37dbde))
* **rubocop:** Lint/UnderscorePrefixedVariableName ([ec7dcf4](https://github.com/postalserver/postal/commit/ec7dcf4f9a0bdb367a90f1a3b35336909ebc60d7))
* **rubocop:** Lint/UnusedBlockArgument ([ee94e4e](https://github.com/postalserver/postal/commit/ee94e4e1a013bbe8fbdd8ef94f15ed0fa20709ac))
* **rubocop:** Lint/UselessAssignment ([7590a46](https://github.com/postalserver/postal/commit/7590a462341bddd412e660db9546ba1909aea9d7))
* **rubocop:** Naming/FileName ([919a601](https://github.com/postalserver/postal/commit/919a60116c5d81ed787061ff4614da4f1e067d4e))
* **rubocop:** Naming/MemoizedInstanceVariableName ([9563f30](https://github.com/postalserver/postal/commit/9563f30c96fba12073e845319b8d79a542d88109))
* **rubocop:** relax method length and block nexting for now ([b0ac9ef](https://github.com/postalserver/postal/commit/b0ac9ef0b96ab78c2961f45b6e9f20f87a6f1d07))
* **rubocop:** remaining offences ([ec63666](https://github.com/postalserver/postal/commit/ec636661d5c4b9e8f48e6f263ffef834acb68b39))
* **rubocop:** Security/YAMLLoad ([389ea77](https://github.com/postalserver/postal/commit/389ea7705047bf8700836137514b2497af3c6c01))
* **rubocop:** Style/AndOr ([b9f3f31](https://github.com/postalserver/postal/commit/b9f3f313f8ec992917bad3a51f0481f89675e935))
* **rubocop:** Style/ClassAndModuleChildren ([e896f46](https://github.com/postalserver/postal/commit/e896f4689a8fc54979f0a6c2b7ce14746856bad6))
* **rubocop:** Style/For ([04a3483](https://github.com/postalserver/postal/commit/04a34831c74a3a44547f93100c35db650bc4eef6))
* **rubocop:** Style/FrozenStringLiteralComment ([6ab36c0](https://github.com/postalserver/postal/commit/6ab36c09c966eb9a8b8ada52155f74d2537977f2))
* **rubocop:** Style/GlobalStdStream ([75be690](https://github.com/postalserver/postal/commit/75be6907483ea25f828461eb790d3f6f46ca683b))
* **rubocop:** Style/GlobalVars ([157d114](https://github.com/postalserver/postal/commit/157d11457c520147807901b75b3ba22d29172f24))
* **rubocop:** Style/HashEachMethods ([c995027](https://github.com/postalserver/postal/commit/c995027ff53962ae49341372f75e2bf43ecde0d2))
* **rubocop:** Style/HashExcept ([83ac764](https://github.com/postalserver/postal/commit/83ac76451071f097e7197f77fc5ad16e9cf58593))
* **rubocop:** Style/IdenticalConditionalBranches ([6a58ecf](https://github.com/postalserver/postal/commit/6a58ecf605250b8fa891cb14fca0c0e0ce0d7eb9))
* **rubocop:** Style/MissingRespondToMissing ([ffcb707](https://github.com/postalserver/postal/commit/ffcb707247fe2a69905aa6e4dc668abeb9924611))
* **rubocop:** Style/MultilineBlockChain ([c6326a6](https://github.com/postalserver/postal/commit/c6326a6524e6d71d23bc2c256f3f9416c38b0846))
* **rubocop:** Style/MutableConstant ([129dffa](https://github.com/postalserver/postal/commit/129dffab9ed8726ca4066e7052adc699129de2d2))
* **rubocop:** Style/NumericPredicate ([c558f1c](https://github.com/postalserver/postal/commit/c558f1c69ce9498564161d8cef3fcb8213103498))
* **rubocop:** Style/PreferredHashMethods ([013b3ea](https://github.com/postalserver/postal/commit/013b3ea9315c14f24b08574d68e1688f33d78b8d))
* **rubocop:** Style/SafeNavigation ([00a02f2](https://github.com/postalserver/postal/commit/00a02f2655b6e3296ad0e7ea9b9872da936b56ed))
* **rubocop:** Style/SelectByRegexp ([9ce28a4](https://github.com/postalserver/postal/commit/9ce28a427fadf6fafd942e009792be4b5539d40d))
* **rubocop:** Style/StringLiterals ([b4cc812](https://github.com/postalserver/postal/commit/b4cc81264c85d5f0061e5b5121a30d7bdcabc189))
* **rubocop:** Style/WordArray ([bd85920](https://github.com/postalserver/postal/commit/bd8592056573d1c6933d753ed50bdf9a7466e761))
* **rubocop:** update rubocop rules ([6d4dea7](https://github.com/postalserver/postal/commit/6d4dea7f7f0145ff2b99cf2505bc70a3e5925256))


### Miscellaneous Chores

* annotate models ([6214892](https://github.com/postalserver/postal/commit/6214892710e21c2aa29a319d5809f7bdf0d50529))
* silence message DB migrations during provisioning ([c83601a](https://github.com/postalserver/postal/commit/c83601af69f35e338b1f7c10ef7994f74b96f8bf))


### Code Refactoring

* remove reloading on the smtp server ([c3c304e](https://github.com/postalserver/postal/commit/c3c304e98b3274433248792b6403acf63d7a513b))


### Tests

* add initial tests for Postal::SMTPServer::Client ([dece1d4](https://github.com/postalserver/postal/commit/dece1d487ac2fdce104700939a79a5579b60a0cb))
* FactoryBot.lint will lint all registered factories ([25d7d66](https://github.com/postalserver/postal/commit/25d7d66b4709fe5442d554097a6ef074aeb15f72))
* remove FACTORIES_EXCLUDED_FROM_LINT ([1cf665a](https://github.com/postalserver/postal/commit/1cf665a0cf61d1eae3d08bdadf6fccaab6413023))

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
