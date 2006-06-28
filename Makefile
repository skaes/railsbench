.PHONY: export tar test clean tag deltag

VERSION:=$(shell cat VERSION)
ARCHIVE:=railsbench-$(VERSION)
TAG:=$(subst .,,RB$(VERSION))
REPO_URL:=svn+ssh://stkaes@rubyforge.org/var/svn/railsbench

tar: export
	tar czvf $(ARCHIVE).tar.gz $(ARCHIVE)
	rm -rf $(ARCHIVE)

export:
	svn export . $(ARCHIVE)

tag:
	svn copy $(REPO_URL)/trunk/railsbench \
          $(REPO_URL)/tags/railsbench-$(VERSION) \
          -m "Tagged release $(VERSION) of railsbench."

deltag:
	svn delete $(REPO_URL)/tags/railsbench-$(VERSION) \
          -m "Deleted tag $(VERSION) of railsbench."

clean:
	rm -rf railsbench* *.tar.gz
	find . -name '*~' | xargs rm

test:
	@echo $(VERSION)
	@echo $(ARCHIVE)
	@echo $(TAG)
