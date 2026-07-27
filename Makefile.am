SUBDIRS = client server botml
prefix= @prefix@
datarootdir= @datarootdir@
srcdir= @srcdir@
mandir= @mandir@
exec_prefix=@exec_prefix@
bindir= @bindir@
INSTALL_PROGRAM = install

all-local: force
	cd botml ; make botml$(EXEEXT)
	cd server ; make thaydorserver$(EXEEXT)
	cd client ; make thaydor$(EXEEXT)

install-exec-local:
	$(INSTALL_PROGRAM) -m 755 server/thaydorserver $(DESTDIR)/$(bindir)
	$(INSTALL_PROGRAM) -m 755 client/thaydor $(DESTDIR)/$(bindir)

force:
