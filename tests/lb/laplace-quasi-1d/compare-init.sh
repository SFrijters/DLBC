#!/bin/bash
h5totxt output-d1q3/laplace*/density-red*t00000000.h5 > init-d1q3.txt
h5totxt output-d1q5/laplace*/density-red*t00000000.h5 > init-d1q5.txt
h5totxt output-d2q9/laplace*/density-red*t00000000.h5 | cut -f 1 -d , > init-d2q9.txt

