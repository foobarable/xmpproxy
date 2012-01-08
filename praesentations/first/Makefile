GNUPLOT = $(addsuffix .pdf, $(basename $(wildcard *.plot)))
INKSCAPE = $(addsuffix .pdf, $(basename $(wildcard *.svg)))
DIRS= `find -maxdepth 1  -type d ! -wholename \*.svn\* | grep /`
PDF = $(addsuffix .pdf, $(basename $(wildcard *.eps)))
FILE = "slides"


show: all
	evince ./$(FILE).pdf & 2> /dev/null

all: $(PDF) $(GNUPLOT) $(INKSCAPE)  
	pdflatex --halt-on-error ./$(FILE).tex

slides.aux:
	pdflatex --halt-on-error ./$(FILE).tex


%.pdf: %.plot *.dat $(FILE).bbl
	gnuplot $(basename $@).plot 2> $(basename $@).log
	touch $(basename $@).pdf
	epstopdf $(basename $@).eps

%.pdf: %.svg
	inkscape $(basename $@).svg --export-eps=$(basename $@).eps
	epstopdf $(basename $@).eps

%.pdf: %.eps
	epstopdf $(basename $@).eps


.PHONY: clean
clean:
	-rm -f *~ *.bak *.aux *.log *.toc *.out *.nav *.snm

replot:
	for i in `find -type f ! -wholename \*.svn\* | grep .dat`; do touch $$i; echo $$i getoucht.; done
#	for i in `find -type f ! -wholename \*.svn\* | grep .plot`; do touch $$i; echo $$i getoucht.; done
	make all

.PHONY: all-evince
all-evince: show
