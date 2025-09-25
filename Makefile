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

python-venv:
	python3 -m venv .venv
	source .venv/bin/activate; pip install -r requirements.txt

python-freeze:
	pip freeze -l > requirements.txt 

python-install:
	source .venv/bin/activate; pip install -r requirements.txt