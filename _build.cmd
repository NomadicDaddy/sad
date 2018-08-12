@d:
@cd\scripts\aw\sad\
perlsvc @sad.pl
@c:
@cd\ims\
@sad.exe -remove
@pskill sad.exe
copy /Y d:\scripts\aw\sad\sad.exe .
@sad.exe -install

@d:
@cd\scripts\aw\sad\
perlsvc @sadup.pl
@c:
@cd\ims\
@sadup.exe -remove
@pskill sadup.exe
copy /Y d:\scripts\aw\sad\sadup.exe .
@sadup.exe -install

@d:
@cd\scripts\aw\sad\
perlapp @sadtest.pl
copy /Y sadtest.exe c:\ims\sadtest.exe
