all: doc

doc:
	mkdir -p generated
	echo '\\begin{verbatim}' > generated/run-tests.tex
	cd .. ; ./run-tests.py -h >> doc/generated/run-tests.tex
	echo '\\end{verbatim}' >> generated/run-tests.tex
	cd .. ; ./run-tests.py --latex > doc/generated/list-of-tests.tex
	pdflatex runnable-tests.tex
	pdflatex runnable-tests.tex

clean:
	rm -rf generated
	rm -f *.aux
	rm -f *~
	rm -f *.log
	rm -f *.pdf

