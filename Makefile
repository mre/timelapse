# Needed SHELL since I'm using zsh
SHELL := /bin/bash

.PHONY: help
help: ## This help message
	@echo -e "$$(grep -hE '^\S+:.*##' $(MAKEFILE_LIST) | sed -e 's/:.*##\s*/:/' -e 's/^\(.\+\):\(.*\)/\\x1b[36m\1\\x1b[m:\2/' | column -c2 -t -s :)"

.PHONY: clean
clean: ## Clean up project assets
	@find . -name "*.pyc" | xargs rm -rf
	@find . -name "*.pyo" | xargs rm -rf
	@find . -name "__pycache__" -type d | xargs rm -rf
	@rm -rf build/ dist/

.PHONY: install
install: ## Install app dependencies
	poetry install

.PHONY: run
run: clean ## Run application in shell
	poetry run

.PHONY: test
test: clean ## Run pytest
	poetry run pytest

.PHONY: lint
lint: ## Lint project code
	poetry run pylint timelapse

.PHONY: open
open: ## Open project folder in Finder
	open .

.PHONY: app 
app: ## Build app from source code
	poetry run python setup.py py2app --emulate-shell-environment

.PHONY: test-app 
test-app: ## Quickly build test app for debugging
	poetry run python setup.py py2app -A --emulate-shell-environment
