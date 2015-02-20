all: clean doc

doc: generated/example-json.tex generated/list-of-tests.tex generated/run-tests.tex
	pdflatex runnable-tests.tex
	pdflatex runnable-tests.tex

generated/example-json.tex: example.json.template
	mkdir -p generated
	echo '\\begin{verbatim}' > $@
	cat example.json.template >> $@
	echo '\\end{verbatim}' >> $@

generated/list-of-tests.tex:
	mkdir -p generated
	../process-tests.py --latex > $@

generated/run-tests.tex:
	mkdir -p generated
	echo '\\begin{verbatim}' > $@
	../process-tests.py -h >> $@
	echo '\\end{verbatim}' >> $@

clean:
	rm -rf generated
	rm -f *.aux
	rm -f *~
	rm -f *.log
	rm -f *.pdf
	rm -f *.out
	rm -f plot/mplhelper.pyc

