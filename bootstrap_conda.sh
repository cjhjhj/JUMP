#!/bin/bash
echo "creating conda environment $PWD/conda/jump"
if [ ! -e $(which conda) ] ; then
    echo "conda not found on $PATH ; please ensure conda is in your PATH variable"
    exit 255;
fi
if [ ! -e $PWD/conda ] ; then mkdir $PWD/conda ; fi
conda create -p $PWD/conda/jump -c conda-forge -c bioconda perl-mime-base64 perl-data-dumper perl-class-std perl-file-spec perl-pod-usage perl-class-std perl-file-spec perl-pod-usage perl-statistics-distributions perl-file-temp perl-excel-writer-xlsx perl-statistics-r perl-file-find perl-http-date perl-math-bigint perl-list-util perl-mime-base64 perl-getopt-long perl-data-dumper perl-parallel-forkmanager perl-clone perl-app-cpanminus
echo "installing cpan modules"
source activate $PWD/conda/ 
cpanm File::Copy
cpanm File::Basename
cpanm Scalar::Util
cpanm LWP::UserAgent
cpanm Set::Partition
cpanm Sys::Hostname
source deactivate
