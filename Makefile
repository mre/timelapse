.PHONY: clean
clean:
	@find . -name "*.pyc" | xargs rm -rf
	@find . -name "*.pyo" | xargs rm -rf
	@find . -name "__pycache__" -type d | xargs rm -rf
	@rm -rf build/ dist/

.PHONY: install
install:
	pip install -r requirements.txt

.PHONY: install-dev
install-dev:
	pip install -r requirements-dev.txt

.PHONY: run
run: clean
	python timelapse

.PHONY: test
test: clean
	pytest

.PHONY: app 
app:
	python setup.py py2app

