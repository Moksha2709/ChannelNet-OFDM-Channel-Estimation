# Makefile for compiling the ChannelNet Final Technical Report using LaTeX

TEX = latexmk
TEXFLAGS = -pdf -interaction=nonstopmode

all: main.pdf

main.pdf: main.tex refs.bib figures/*
	$(TEX) $(TEXFLAGS) main.tex

clean:
	$(TEX) -c
