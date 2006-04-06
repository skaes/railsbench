.PHONY: export tar upload test clean

VERSION:=$(shell cat VERSION)
ARCHIVE:=railsbench-$(VERSION)
TAG:=$(subst .,,RB$(VERSION))

tar: export
	tar czvf $(VERSION).tar.gz railsbench
	rm -rf railsbench

export: tag
	cvs export -r $(TAG) -d $(ARCHIVE) railsbench

tag:
	cvs tag -R -F $(TAG)

clean:
	rm -rf railsbench *.tar.gz

test:
	@echo $(VERSION)
	@echo $(ARCHIVE)
	@echo $(TAG)
