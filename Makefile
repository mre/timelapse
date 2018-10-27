clean:
	@find . -name "*.pyc" | xargs rm -rf
	@find . -name "*.pyo" | xargs rm -rf
	@find . -name "__pycache__" -type d | xargs rm -rf
	@rm -rf build

install:
	pip install -r requirements.txt

install-dev:
	pip install -r requirements-dev.txt

run: clean
	python src/timelapse.py

test: clean
	pytest

