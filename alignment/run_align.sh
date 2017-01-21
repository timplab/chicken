#!/bin/bash

outdir=/atium/Data/NGS/Aligned/170120_chicken

for samp in ACTTGA #AGTCAA AGTTCC ATGTCA CAGATC CCGTCC CTTGTA GATCAG GGCTAC GTCCGC GTGAAA TAGCTT
do
    mkdir ${outdir}/${samp}

    for lane in {1..8}
    do
	##bismark align
	if [ 0 -eq 1 ]; then	    
	    sbatch bismark_align_marcc.sh ${lane} ${samp}
	fi
    done
    
    if [[  1 -eq 0 ]]; then
	sbatch bismark_cat_marcc.sh ${samp}
    else
	echo ${samp} "already concatanated"
    fi
    
    if [ 0 -eq 0 ]; then
	./bismark_extract.sh $samp
    fi

done    





