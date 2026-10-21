.PHONY: build app format lint test clean

build:
	swift build

app:
	python3 scripts/build-app.py

format:
	swift format format --in-place --recursive Package.swift Sources Tests
	ruff check --select I --fix scripts
	ruff format scripts

lint:
	swift format lint --strict --recursive Package.swift Sources Tests
	swiftlint lint --strict --no-cache
	ruff check scripts
	ruff format --check scripts
	plutil -lint Resources/Info.plist

test:
	swift test
	python3 -m unittest discover -s scripts/tests -v

clean:
	swift package clean
