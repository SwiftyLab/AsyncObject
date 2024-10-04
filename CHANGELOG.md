## [2.1.0](https://github.com/SwiftyLab/AsyncObjects/compare/v2.0.0...v2.1.0) (2023-03-04)


### ✅ Tests

* add async signal tests for events ([#17](https://github.com/SwiftyLab/AsyncObjects/issues/17)) ([5ce6b1a](https://github.com/SwiftyLab/AsyncObjects/commit/5ce6b1a9f1322ddbbe0ae7852c10798942f5f397))


### 🔥 Refactorings

* add identifier metadata for cancellation source registered tasks ([#18](https://github.com/SwiftyLab/AsyncObjects/issues/18)) ([0ab431e](https://github.com/SwiftyLab/AsyncObjects/commit/0ab431e460463396761eb417f785922a04fe4680))
* modify cancellation source implementation to not store tasks and linked cancellation sources ([#15](https://github.com/SwiftyLab/AsyncObjects/issues/15)) ([3c3c61b](https://github.com/SwiftyLab/AsyncObjects/commit/3c3c61b4740f728bf3a3c53a387972fd09022498))

## [2.0.0](https://github.com/SwiftyLab/AsyncObjects/compare/v1.0.0...v2.0.0) (2023-01-07)


### ⚠ BREAKING CHANGES

* **`AsyncObject`:** propagate cancellation error instead of swallowing (#8)
* **`TaskOperation`:** use platform lock primitive instead of `DispatchQueue` for synchronization

### 🛠 Build System

* resolve concurrency check warnings ([c66bb81](https://github.com/SwiftyLab/AsyncObjects/commit/c66bb81b9d38faef7b88f1cbd11e26f2db53929e))


### 🐎 Performance Improvements

* **`TaskOperation`:** use platform lock primitive instead of `DispatchQueue` for synchronization ([f28ee66](https://github.com/SwiftyLab/AsyncObjects/commit/f28ee669d1685468f00eac9164f2bbc9158e7718))


### 🐛 Fixes

* fix data race with task cancellation ([bca8299](https://github.com/SwiftyLab/AsyncObjects/commit/bca8299ec67a9af96805af2e55a18f9a69dd9275))
* fix potential data race handling actor reentrancy ([63fed91](https://github.com/SwiftyLab/AsyncObjects/commit/63fed91f4da960e73346f1bd4a6b280e9d72fa34))


### 🚀 Features

* **`TaskOperation`:** allow customizing priority of task ([6650693](https://github.com/SwiftyLab/AsyncObjects/commit/6650693730334657ec87c7e35ca53963cf30bf06))
* **`TaskOperation`:** allow executing as detached task ([#7](https://github.com/SwiftyLab/AsyncObjects/issues/7)) ([e3dcfeb](https://github.com/SwiftyLab/AsyncObjects/commit/e3dcfeb8487b3d85fd7d68c7a56a382082125919))
* **`TaskOperation`:** allow tracking child tasks completion ([571419d](https://github.com/SwiftyLab/AsyncObjects/commit/571419d25b6bd89d944612b873e404f8bc31417d))
* **`TaskQueue`:** allow adding task to queue without waiting for completion ([d8ee18a](https://github.com/SwiftyLab/AsyncObjects/commit/d8ee18abc5b5abef9af572c267ca0a201602e2a1))
* add logging option ([#10](https://github.com/SwiftyLab/AsyncObjects/issues/10)) ([bdd688b](https://github.com/SwiftyLab/AsyncObjects/commit/bdd688b867e6c65b1060c88e5956e0676d31a610))
* add scheduling with Clock API support ([#9](https://github.com/SwiftyLab/AsyncObjects/issues/9)) ([d1c5531](https://github.com/SwiftyLab/AsyncObjects/commit/d1c55312d32de6e7caf863c685ecbac19f6d2a95))


### 🔥 Refactorings

* **`AsyncObject`:** propagate cancellation error instead of swallowing ([#8](https://github.com/SwiftyLab/AsyncObjects/issues/8)) ([9f7f243](https://github.com/SwiftyLab/AsyncObjects/commit/9f7f243cb0dd7fd64771207ef4ae51d4e9a077d2))
* fix actor isolation bug with protocol conformance on older swift versions ([#11](https://github.com/SwiftyLab/AsyncObjects/issues/11)) ([c1ce0e2](https://github.com/SwiftyLab/AsyncObjects/commit/c1ce0e2f48c20d3149a3d2b84ff25d445109bda4))


### 💄 Styles

* **`TaskOperation`:** add separate error for retrieving result without starting ([9a852d9](https://github.com/SwiftyLab/AsyncObjects/commit/9a852d9ebf57f71383f7c55bdf9b44405a7b2215))
* add swift package index documentation support ([3ae2525](https://github.com/SwiftyLab/AsyncObjects/commit/3ae2525d1e5b28e5a0a6e44ab99eac3a24bdce26))


### ✅ Tests

* improve async tests correctness ([#14](https://github.com/SwiftyLab/AsyncObjects/issues/14)) ([19405e3](https://github.com/SwiftyLab/AsyncObjects/commit/19405e3415726a2f8d18c0195c6412a3a8c83cfa))

## [1.0.0](https://github.com/SwiftyLab/AsyncObjects/compare/fbd6b6537060cbc6dd261b4a0f0b97b64542209d...v1.0.0) (2022-08-17)


### 💄 Styles

* add swift-format for code formatting ([001a1d2](https://github.com/SwiftyLab/AsyncObjects/commit/001a1d209ec8d3376481a82eb8368593863205c6))
* add vscode workspace settings ([92c5810](https://github.com/SwiftyLab/AsyncObjects/commit/92c58104533b1669ac03fbddb39b549e3fb04896))


### 🔥 Refactorings

* refactor continuation management to prevent race condition ([dfa3717](https://github.com/SwiftyLab/AsyncObjects/commit/dfa37179bda741a5fe9a5ae07bcb332b5c3a0394))
* use `CheckedContinuation` for debug mode or for `ASYNCOBJECTS_USE_CHECKEDCONTINUATION` flag ([3899792](https://github.com/SwiftyLab/AsyncObjects/commit/3899792d50f41b1653aeef10ba0177b8b5730188))


### ✅ Tests

* add async countdown event tests ([8e07add](https://github.com/SwiftyLab/AsyncObjects/commit/8e07add1715eabe8a225acc232af2f0688f5fe94))
* add async event tests ([ad42d72](https://github.com/SwiftyLab/AsyncObjects/commit/ad42d7246e8dd1b044f81da1d2353838535b0e2e))
* add async semaphore tests ([fd075bd](https://github.com/SwiftyLab/AsyncObjects/commit/fd075bd737833d97bf06c426c1fbba4e53473a6a))
* add future tests ([43a209e](https://github.com/SwiftyLab/AsyncObjects/commit/43a209e8c4019d68bdba85ca2f1cfe8c2ced5f28))
* add task queue tests ([bbb8188](https://github.com/SwiftyLab/AsyncObjects/commit/bbb8188b57c9868b623438beb75b5dc5d9ef553c))
* add tests for cancellation source ([3e81653](https://github.com/SwiftyLab/AsyncObjects/commit/3e816532fcf0fe5dd2b866f90bea7bd5257a39de))
* add tests for multiple synchronization objects wait ([dc56f4e](https://github.com/SwiftyLab/AsyncObjects/commit/dc56f4e01f2d126c9758505e3e30356b04d38f61))
* add tests for structured concurrency-GCD bridge ([7b36c93](https://github.com/SwiftyLab/AsyncObjects/commit/7b36c93add3d72973ac1b3f88097d27691be3812))
* remove methods usage not supported on linux ([485452c](https://github.com/SwiftyLab/AsyncObjects/commit/485452c5d75de9da7a170a1e32caab06d02e5a7c))


### 🚀 Features

* add `barrier` and `block` flags for `TaskQueue` ([d3e566a](https://github.com/SwiftyLab/AsyncObjects/commit/d3e566a32fe4ad9fc897609dcae84ab799fa65b8))
* add async countdown event ([f138abc](https://github.com/SwiftyLab/AsyncObjects/commit/f138abcafbef3469aa63ed2c5bcf62267f07127b))
* add async event ([dc3090c](https://github.com/SwiftyLab/AsyncObjects/commit/dc3090ce79be709130910ee9962d32dc6ebc7a6b))
* add async semaphore ([fbd6b65](https://github.com/SwiftyLab/AsyncObjects/commit/fbd6b6537060cbc6dd261b4a0f0b97b64542209d))
* add cancellation source for controlling multiple tasks cooperative cancellation ([b92665d](https://github.com/SwiftyLab/AsyncObjects/commit/b92665d8a216ce5b450fe2336f7148e38752a35b))
* add CocoaPods support ([646db5b](https://github.com/SwiftyLab/AsyncObjects/commit/646db5bcfbb1d8d49b6707a20c321540f141c362))
* add operation type to bridge GCD/`libdispatch` with structured concurrency ([51b302e](https://github.com/SwiftyLab/AsyncObjects/commit/51b302e00537e4def872a7888439f47ae2bf5c9a))
* add option to provide number of objects to wait for ([20b5725](https://github.com/SwiftyLab/AsyncObjects/commit/20b5725c6e6f59d79f562d32adcc2dd76688d52d))
* add priority based task execution on `TaskQueue` ([df5e6e7](https://github.com/SwiftyLab/AsyncObjects/commit/df5e6e7ece9c4c775aaac8d5c69338948ce60d66))
* add task queue to run concurrent tasks and barrier tasks similar to DispatchQueue ([84e4d29](https://github.com/SwiftyLab/AsyncObjects/commit/84e4d29370fff9695911b0dee89aa33fa06cce20))
* add transferring data across tasks with `Future` ([d4d658f](https://github.com/SwiftyLab/AsyncObjects/commit/d4d658fa1bd1c9381ab1facd133bc39e3afeff8d))
* add wait for multiple synchronization objects ([68702b5](https://github.com/SwiftyLab/AsyncObjects/commit/68702b5522ec04e329fb839e72d034a50149e9ef))


### 📚 Documentation

* add contributing guidelines ([e4a78ee](https://github.com/SwiftyLab/AsyncObjects/commit/e4a78ee75205d27868edb5d3ad56e8735f84256c))
* add docC catalog for library ([9e69dbb](https://github.com/SwiftyLab/AsyncObjects/commit/9e69dbb6d6d066ebfe04d920f96154e30a50af96))
* add github pages product specific documentation ([05e1e30](https://github.com/SwiftyLab/AsyncObjects/commit/05e1e30afe744bb69ce0998ddb9eb03859806226))
* add installation and usage guidelines ([0b4df47](https://github.com/SwiftyLab/AsyncObjects/commit/0b4df47b0e023d3553bcb06c7b9175ff3d6a033e))

