.PHONY: doc tidy

all: 
	${MAKE} tidy

tidy: 
	perltidy -b xmpproxy.pl
	rm xmpproxy.pl.bak
	cd lib && ${MAKE} tidy


doc:	
	doxygen && cd doc/latex && ${MAKE}

