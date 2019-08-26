######### MakeJobManager ######################################
#                                                             #
#       **************************************************    #  
#       **** Job Manager implementation using GNUmake ****    #     
#       ****				              ****    #  
#       ****Copyright (C) 2019 - Alex Breuer	      ****    #     
#       ****all rights reserved.	              ****    #  
#       ****alex.breuer@stjude.org	              ****    #  
#       ****				              ****    #  
#       ****				              ****    #  
#       **************************************************    # 
###############################################################

package Spiders::MakeJobManager;

use strict;
use Carp;
use File::Temp;
use Spiders::BatchSystem;
use Spiders::Config;
use Spiders::ClusterConfig;

sub new {
    my $class = shift;
    my $params = shift;
    my $options = shift || {};
    my $self = {};
    bless $self,$class;

    $self->{'config'} = new Spiders::Config();
    $self->{'params'} = $params;
    $self->{'unroll'} = $self->{'config'}->get( 'batch_job_unroll' );
    $self->{'debug'} = defined($options->{'DEBUG'});
    $self->{'myDir'} = File::Temp->newdir( TEMPLATE => (defined($options->{'DEBUG'} ? 
								'MAKE_JOB_MANAGER_TEMPDIR' : 'XXXXXXXXXXX')),
					   UNLINK => (!defined($options->{'DEBUG'})),
					   DIR => '.' );
    return $self;
}

sub _generateSMPMakefile {
    my $self = shift;
    my @jobs = @_;
    
    my %rules;
    my $njobs = scalar(@jobs);
    for( my $i = 0; $i < $njobs; $i += 1 ) {
	my $cmd = $jobs[$i]->{'cmd'};
	$rules{"$i-cmd-run"} = "( $cmd ) && echo finished job " . $i;
    }

    my $tfile = File::Temp->new( TEMPLATE => 'XXXXXX',
				 DIR => $self->{'myDir'},
				 UNLINK => 0 );
    open( my $outf, ">".$tfile->filename );
    print $outf 'all: ' . join( ' ', keys(%rules) ) . "\n";
    foreach my $k (keys(%rules)) {
	print $outf "$k:\n\t@" .  $rules{$k} . "\n";
    }
    close( $outf );
    return ($tfile,\%rules);

}

sub _generateBatchMakefile {
    my $self = shift;
    my @jobs = @_;
    my $batchSystem = new Spiders::BatchSystem();

    my %rules;
    my $njobs = scalar(@jobs);
    for( my $i = 0; $i < $njobs; $i += $self->{'unroll'} ) {
	my $cmd = $jobs[$i]->{'cmd'};
	(my $sfile, my $srules) = $self->_generateSMPMakefile( @jobs[$i..($i + $self->{'unroll'})] );
	$rules{"$i-cmd-run"} = $batchSystem->getBatchCmd( $jobs[$i]->{'toolType'} ) . ' "make -j 1 -f ' . $sfile .'" &> /dev/null ; echo finished job ' . $i;
    }

    my $tfile = File::Temp->new( TEMPLATE => 'XXXXXX',
				 DIR => $self->{'myDir'} );
    open( my $outf, ">".$tfile->filename );
    print $outf 'all: ' . join( ' ', keys(%rules) ) . "\n";
    foreach my $k (keys(%rules)) {
	print $outf "$k:\n\t@" .  $rules{$k} . "\n";
    }
    close( $outf );
    return ($tfile,\%rules);
}

sub runJobs {
    my $self = shift;
    my @jobs = @_;
    my $clusterConfig = Spiders::ClusterConfig::getClusterConfig($self->{'config'},$self->{'params'});

    my $code = 0;
    my $mfile;
    if( $clusterConfig eq Spiders::ClusterConfig::SMP ) {
	($mfile,my $rules) = $self->_generateSMPMakefile( @jobs );
	$code = system( "make -f " . $mfile->filename . ' -j ' . $self->{'config'}->get( 'max_search_worker_procs' ) );
    }
    elsif( $clusterConfig eq Spiders::ClusterConfig::CLUSTER ) {
	print "  Submitting " . scalar(@jobs) . " jobs for search\n";
	($mfile,my $rules) = $self->_generateBatchMakefile( @jobs );
	$code = system( "make -f " . $mfile->filename . ' -j ' . $self->{'config'}->get( 'max_dispatch_worker_procs' ) );
    }
    
    if( $code ne 0 ) {
	$self->{"myDir"}->unlink_on_destroy( 0 );
	croak( "make retured with nonzero exit code; see makefiles in " . $mfile . "\n" );
    }
}

1;