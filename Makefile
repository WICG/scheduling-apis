SHELL=/bin/bash

build: spec/index.bs spec/*.md
	cd spec && bikeshed --die-on=warning spec index.bs index.html
	cd ..
	mkdir -p out
	mv spec/index.html out/index.html

clean:
	rm -rf out/
