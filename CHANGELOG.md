# Changelog

## [1.4.0](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.3.4...v1.4.0) (2026-10-26)


### Features

* add check_dependencies.sh to check required tools ([#90](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/90)) ([580f07e](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/580f07e2d06853d2e5359bdc9e71f798b4ce6955))


### Bug Fixes

* check targets before freeze and archive ([#110](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/110)) ([1639d09](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/1639d09f3f040be2a87b410fe56e78151d44ad65))
* fail when samples or reads are missing ([#114](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/114)) ([3c3f339](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/3c3f339bee42e1a3dbf3a89d4d59c547df3384bb))
* handle trailing commas and old data.csv ([#119](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/119)) ([31716f0](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/31716f0e89a7b60abd28ec60ed1e4bdd5245ae42))
* help text, stale names and printf style ([#97](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/97)) ([9b57749](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/9b577497af2ab19315383225d2e0eddb3473dda4))
* keep frozen copy until thaw is verified ([#111](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/111)) ([431bc3e](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/431bc3e3b727bf5b4754bbdd1584e414d76c943f))
* link .fq.gz reads into the study ([#107](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/107)) ([fda76e3](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/fda76e3289a47b6e0eb0f3ba43600b7728770160))
* list reads by name in tar archives ([#108](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/108)) ([aa4c3d4](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/aa4c3d466622fb22a3621d47da0fc772bfbb4ecc))
* refuse reads that would overwrite each other ([#113](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/113)) ([20c410c](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/20c410cbfd3f01158028a39c28cf9191e59b1645))
* reliable csv input ([#105](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/105)) ([a854ba1](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/a854ba1962510536a6e00e2cc6e8fff910c0835c))
* stop on errors in all scripts ([#118](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/118)) ([9d43d5b](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/9d43d5bfb48c9e42449e117b20eea68a75d6cf32))

## [1.3.4](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.3.3...v1.3.4) (2026-10-06)


### Bug Fixes

* corrected name of freeze log ([#68](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/68)) ([6a0fd44](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/6a0fd44fc49388fbeaee2afe7e2c3209c87c9022))
* use builtin cd ([#61](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/61)) ([48ab6e5](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/48ab6e5dddaad962c08c31df7434d39dd8758cfc))

## [1.3.3](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.3.2...v1.3.3) (2026-10-05)


### Bug Fixes

* rewrite missing_tarballs.csv on each run ([#57](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues/57)) ([745f33b](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/745f33b109f5d55515ef3436feb7f254f28d4fc0))

## [1.3.2](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.3.1...v1.3.2) (2026-04-14)


### Bug Fixes

* corrected arithmetic expansion, failed when count became 0 0 ([40892e7](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/40892e750f0fec9ab50c52f3be9cbb86f4bd7496))
* corrected study name in generated log files in activate_data.sh ([72f917f](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/72f917fca8e5c084c22a44b42f036a44046e4107))

## [1.3.1](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.3.0...v1.3.1) (2026-03-09)


### Bug Fixes

* added fullpaths to executables ([b288b11](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/b288b1125c8848166b838a95dc6f7f46f33d11e0))

## [1.3.0](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.2.0...v1.3.0) (2026-03-06)


### Features

* added "append" functionality and created functions of code chunks ([eece958](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/eece958d227b97838c0344e572851ca9ff5b2b22))
* added new information for append mode in activate_data.sh, and added updating of files and symlinks in the study dir ([4bd34f1](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/4bd34f18d0df78b9505973458b297492f76ff297))
* created functions of code chunks and moved them to lib.sh ([06aeaf5](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/06aeaf5f225b8c523021111c52c85ed0e5b76ac7))


### Bug Fixes

* added flags to the activate_data.sh call in thaw_study.sh ([4c396ce](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/4c396ce293ae71c7278776897a73b949bbb9c8d8))
* added shebang to lib.sh ([7531cab](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/7531cab38e5f8fad14217d946402d6f94c97762a))
* added verification step for archiving process ([6950c8e](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/6950c8e57aeede33ed20db30c70df91271eb01a6))
* corrected copied csv file name ([00c0c75](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/00c0c759e81c301dbaf9c1268a807ae4afe42928))
* corrected erroneous variable name ([e92f7d6](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/e92f7d6cafbc2582d00fcd65b14b9dd39301dbdf))
* corrected tarball creation to not include directories for the full path ([10578a8](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/10578a87e6f7ba9ce784acb96b670dcd71db4233))
* corrected variable names in create_study.sh ([d08f359](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/d08f3595672dc689982da2c74a49987478c2a19b))

## [1.2.0](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.1.0...v1.2.0) (2026-03-02)


### Features

* added configuration file for paths instead of hard-coded paths ([da7b102](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/da7b1027baec69d1720b2b5dac02f6b23b20554f))


### Bug Fixes

* added checks for rsync transfer ([c2c370c](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/c2c370cd4a9f7e4d5fbbeeb229d4dab6c987aff8))

## [1.1.0](https://github.com/NorwegianVeterinaryInstitute/ATLAS/compare/v1.0.0...v1.1.0) (2026-02-25)


### Features

* added release-please to the repo ([962f170](https://github.com/NorwegianVeterinaryInstitute/ATLAS/commit/962f170bcad80727ec314aae2d5ed5075d7e6855))
