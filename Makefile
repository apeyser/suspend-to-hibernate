prefix=usr
bin=bin
systemd_prefix=$(prefix)/lib
systemd=systemd/system
etc=etc

targets=suspend-to-hibernate

all: $(targets)
clean: ; rm $(targets)

suspend-to-hibernate: suspend-to-hibernate.sh
	sed -e "s:@etc@:/$(etc):g" $< >$@

install: install-script install-service install-config

install-script: suspend-to-hibernate
	install -p -m 0755 -D -t $(DESTDIR)$(prefix)/$(bin)/ $<

install-service: suspend-to-hibernate.service
	install -p -m 0644 -D -t $(DESTDIR)$(systemd_prefix)/$(systemd)/ $<

install-config: suspend-to-hibernate.conf
	install -p -m 0644 -D -t $(DESTDIR)$(etc)/ $<

.PHONY: all clean install install-script install-service install-config
