prefix=usr
bin=bin
systemd_prefix=$prefix/lib
systemd=systemd/system
etc=/etc

install: install-script install-service install-config

install-script: suspend-to-hibernate.sh
	install -p -m 0755 -D -t $DESTDIR/$prefix/$bin/ $@

install-service: suspend-to-hibernate.service
	install -p -m 0311 -D -t $DESTDIR/$systemd_prefix/$systemd/ $@

install-config: suspend-to-hibernate
	install -p -m 0311 -D -t $DESTDIR/$etc/ $@
