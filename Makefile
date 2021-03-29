SHELL=/bin/bash

SPEC_RAW_URL=https://raw.githubusercontent.com/WICG/scheduling-apis/main/spec/index.bs

local: spec/index.bs spec/*.md
	cd spec && bikeshed --die-on=warning spec index.bs index.html

index.html:
	@ (HTTP_STATUS=$$(curl https://api.csswg.org/bikeshed/ \
	                       --output index.html \
	                       --write-out "%{http_code}" \
	                       --header "Accept: text/plain, text/html" \
	                       -F die-on=warning \
	                       -F url=${SPEC_RAW_URL}) && \
	[[ "$$HTTP_STATUS" -eq "200" ]]) || ( \
		echo ""; cat index.html; echo ""; \
		rm -f index.html; \
		exit 22 \
	);

remote-source: index.html

ci:
	mkdir -p out
	make remote-source
	mv index.html out/index.html

clean:
	rm index.html
