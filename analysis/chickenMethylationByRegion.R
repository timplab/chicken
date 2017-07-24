#!/usr/bin/Rscript
##Plots go here:
outdir="/home/isac/Dropbox/Data/Genetics/MethSeq/170120_chicken"
plotdir=file.path(outdir,"plots")

##All alignment data lives here 
datdir="/atium/Data/NGS/Aligned/170120_chicken"
analysisdir=file.path(datdir,"analysis")
rdadir=file.path(datdir,"rdas")
##annotation
cpganno="/atium/Data/Reference/chicken/galGal5/annotation/cpgIslandExt.txt.gz"
##Load libraries and sources
require(Biostrings)
require(plyr)
require(ggplot2)
require(bsseq)
require(reshape)
require(GenomicRanges)
source("~/Code/timp_genetics/util/timp_seqtools.R")
source("~/Code/timp_genetics/util/read_tools.R")

library(parallel)
library(ggjoy)

## load gene database
#source("https://bioconductor.org/biocLite.R")
#biocLite("TxDb.Ggallus.UCSC.galGal5.refGene")
library(TxDb.Ggallus.UCSC.galGal5.refGene)
ls('package:TxDb.Ggallus.UCSC.galGal5.refGene')
chicken.txdb=TxDb.Ggallus.UCSC.galGal5.refGene

## get annotation
cpg.df = read.table(gzfile(cpganno))[,c(2:4)]
colnames(cpg.df)=c("chr","start","end")
cpg.gr = makeGRangesFromDataFrame(df=cpg.df)

## get the gene info
chick.cols=c("GENEID","TXCHROM","TXSTART","TXEND","TXSTRAND")
chick.keytype="GENEID"
chick.keys=keys(chicken.txdb,keytype=chick.keytype)
chicken.genes=select(chicken.txdb,keys=chick.keys,columns=chick.cols,keytype=chick.keytype)
genes.gr = GRanges(chicken.genes)

##load Bsseq object R
load(file=file.path(rdadir,"bsobject.rda")) # bsobject has bismark,BS.fit.large,BS.fit.small
upheno=unique(pData(bismark)$pheno)
pd = pData(bismark)
pheno = pd$pheno

## get methylation
totmeth = getMeth(BS.fit.small,type="smooth",what="perBase")
totcov = getCoverage(bismark,type="Cov",what="perBase")
idx = which(rowSums(totcov>=2)==12)
colnames(totmeth) = rownames(pData)
meth = totmeth[idx,]
meth.loc=granges(BS.fit.small[idx])

## average the methylations across replicates
meth.phen=matrix(nrow=dim(meth)[1],ncol=length(upheno))
colnames(meth.phen)=upheno
for (i in seq(length(upheno))){
    p = upheno[i]
    ind = which(pheno==p)
    meth.phen[,i]=rowMeans(meth[,ind])
}

##subset methylation on gene bodies
geneovl=findOverlaps(meth.loc,genes.gr)
cpgovl = findOverlaps(meth.loc,cpg.gr)
meth.gene=meth[queryHits(geneovl),]
meth.cpg = meth[queryHits(cpgovl),]

##plotting
genebody.plt = melt(meth.gene)
cpg.plt = melt(meth.cpg)
colnames(genebody.plt)=colnames(cpg.plt)=c("pheno","samp","meth")
genebody.plt$pheno=rep(pheno,each=dim(meth.gene)[1])
cpg.plt$pheno=rep(pheno,each=dim(meth.cpg)[1])
cpg.sub=cpg.plt[sample(1:nrow(cpg.plt),500,replace=FALSE),]
genebody.sub=genebody.plt[sample(1:nrow(genebody.plt),500,replace=FALSE),]
g.body.box = ggplot(genebody.plt,aes(x=pheno,y=meth,group=samp,color=pheno))+
    geom_boxplot(lwd=0.3,fatten=0.5,outlier.shape=NA)+
    geom_jitter(data=genebody.sub,size=0.2,alpha=0.3)+
    theme_bw()+theme(legend.position="none")+
    labs(title="gene body",x="Phenotype","Methylation Frequency")
g.cpg.box = ggplot(cpg.plt,aes(x=pheno,y=meth,group=samp,color=pheno))+
    geom_boxplot(lwd=0.3,fatten=0.5,outlier.shape=NA)+
    geom_jitter(data=cpg.sub,size=0.2,alpha=0.3)+
    theme_bw()+theme(legend.position="none")+
    labs(title="cpgi",x="Phenotype","Methylation Frequency")
g.body.joy = ggplot(genebody.plt,aes(x=meth,y=pheno,group=samp,color=pheno))+
    geom_joy(fill=NA)+theme_joy()+
    theme_bw()+theme(legend.position="none")+
    labs(title="gene body",x="Methylation Frequency",y="Phenotype")
g.cpg.joy = ggplot(cpg.plt,aes(x=meth,y=pheno,group=samp,color=pheno))+
    geom_joy(fill=NA)+theme_joy()+
    theme_bw()+theme(legend.position="none")+
    labs(title="cpgi",x="Methylation Frequency",y="Phenotype")

pdf(file.path(plotdir,"globalMeth.pdf"),width=4,height=4)
print(g.body.box)
print(g.cpg.box)
print(g.body.joy)
print(g.cpg.joy)
dev.off()