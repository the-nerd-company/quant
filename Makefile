LIVEBOOK = $(shell asdf where elixir)/.mix/escripts/livebook

test:
	MIX_ENV=test mix test

coverage:
	MIX_ENV=test mix coveralls.lcov

livebook_install:
	mix escript.install hex livebook
	mix escript.install github thmsmlr/livebook_tools
	
livebook:
	$(LIVEBOOK) server --port 8723 examples/

.PHONY: test coverage livebook

# Python dependency management with UV (recommended)
python-setup:
	./scripts/setup_python.sh

python-install-uv:
	uv pip install --system -e .

python-install-requirements:
	uv pip install --system -r requirements.txt

python-list:
	uv pip list

python-freeze:
	uv pip freeze > requirements.txt

python-test:
	mix test --include python_validation

# Legacy Python venv commands (for compatibility)
python-venv:
	python3 -m venv .venv
	source .venv/bin/activate; pip install -r requirements.txt

python-install:
	source .venv/bin/activate; pip install -r requirements.txt