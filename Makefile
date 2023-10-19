
XCODE ?= 14.3.1

export TEST_DESTINATION ?= platform=iOS Simulator,OS=16.4,name=iPhone 14
export TEST_DESTINATION_TVOS ?= platform=tvOS Simulator,OS=16.4,name=Apple TV

export DEVELOPER_DIR = $(shell bash ./scripts/get_xcode_path.sh ${XCODE} $(XCODE_PATH))
export AIRSHIP_VERSION = $(shell bash "./scripts/airship_version.sh")

build_path = build
derived_data_path = ${build_path}/derived_data
archive_path = ${build_path}/archive

xcframeworks_path = ${build_path}/xcframeworks
docs_path = ${build_path}/Documentation
package_zip_path = ${build_path}/Airship.zip
package_carthage_zip_path = ${build_path}/Airship.xcframeworks.zip


.PHONY: setup
setup:
	test ${DEVELOPER_DIR}
	bundle install --quiet
	bundle exec pod install

.PHONY: all
all: setup build test pod-lint

.PHONY: build
build: build-package build-samples

.PHONY: build-package
build-package: clean-package build-docs build-xcframeworks
	bash ./scripts/package.sh \
	 "${package_zip_path}" \
	 "${xcframeworks_path}/*.xcframework" \
	 "${docs_path}" \
	 CHANGELOG.md \
	 README.md \
	 LICENSE
	bash ./scripts/package_carthage.sh "${package_carthage_zip_path}" "${xcframeworks_path}/" 

.PHONY: build-docs
build-docs: setup clean-docs
	bash ./scripts/build_docs.sh "${docs_path}"

.PHONY: build-xcframeworks
build-xcframeworks: setup clean-xcframeworks
	bash ./scripts/build_xcframeworks.sh "${xcframeworks_path}" "${derived_data_path}" "${archive_path}"

.PHONY: build-samples
build-samples: build-sample-tvos build-sample-objc build-sample-swift

.PHONY: build-sample-tvos
build-sample-tvos: setup
	bash ./scripts/build_sample.sh "tvOSSample" "${derived_data_path}"

.PHONY: build-sample-objc
build-sample-objc: setup
	bash ./scripts/build_sample.sh "Sample" "${derived_data_path}"

.PHONY: build-sample-swift
build-sample-swift: setup
	bash ./scripts/build_sample.sh "SwiftSample" "${derived_data_path}"

.PHONY: test
test: setup test-core test-accengage test-chat test-content-extension test-service-extension test-packages

.PHONY: test-core
test-core: setup
	bash ./scripts/run_tests.sh AirshipCore "${derived_data_path}"

.PHONY: test-chat
test-chat: setup
	bash ./scripts/run_tests.sh AirshipChat "${derived_data_path}"

.PHONY: test-accengage
test-accengage: setup
	bash ./scripts/run_tests.sh AirshipAccengage "${derived_data_path}"

.PHONY: test-content-extension
test-content-extension: setup
	bash ./scripts/run_tests.sh AirshipNotificationContentExtension "${derived_data_path}"

.PHONY: test-service-extension
test-service-extension: setup
	bash ./scripts/run_tests.sh AirshipNotificationServiceExtension "${derived_data_path}"

.PHONY: test-packages
test-packages: setup
	bash ./scripts/test_package.sh spm
	bash ./scripts/test_package.sh spm11.4

.PHONY: pod-publish
pod-publish: setup
	bundle exec pod trunk push Airship.podspec
	bundle exec pod trunk push AirshipExtensions.podspec
	bundle exec pod trunk push AirshipServiceExtension.podspec
	bundle exec pod trunk push AirshipContentExtension.podspec

.PHONY: pod-lint
pod-lint: setup
	bundle exec pod lib lint Airship.podspec --verbose --platforms=tvos,ios --fail-fast --skip-tests 
	bundle exec pod lib lint AirshipExtensions.podspec --verbose --platforms=ios --fail-fast --skip-tests 
	bundle exec pod lib lint AirshipServiceExtension.podspec --verbose --platforms=ios --fail-fast --skip-tests 
	bundle exec pod lib lint AirshipContentExtension.podspec --verbose --platforms=ios --fail-fast --skip-tests 

.PHONY: clean
clean:
	rm -rf "${build_path}"

.PHONY: clean-docs
clean-docs:
	rm -rf "${docs_path}"

.PHONY: clean-package
clean-package:
	rm -rf "${package_zip_path}"
	rm -rf "${package_carthage_zip_path}"

.PHONY: clean-xcframeworks
clean-xcframeworks:
	rm -rf "${xcframeworks_path}"