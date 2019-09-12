# --
# VERSION:1.1
package Kernel::Config::Files::ZZZZQueuesAndServices;
use strict;
use warnings;
no warnings 'redefine';
use utf8;
sub Load {
    my ($File, $Self) = @_;

	# check if QueueServices is enabled
	if ( !$Self->{'QueueService::QSActive'} ) {
		return;
	} 

	if ( $Self->{'QueueService::QSActive'} eq "1" ) {
		# check if we will block all services for all queues standard
		if ( $Self->{'QueueService::BlockAll'} ) {
			$Self->{TicketAcl}->{'ACL-QS_000-All'} = {
				Properties => {},
				PossibleNot => {Ticket => {Service  => ['[RegExp]^']}}
			};
		}

		my $qs_hash=$Self->{'QueueService::QueueServicesName'} or return;
		my %QueueServices = %{$qs_hash};
		my @Items;
		for my $Queue ( keys %QueueServices ) {
			@Items = split /;/, $QueueServices{$Queue};
			$Self->{TicketAcl}->{'ACL-QS_0'.$Queue} = {
				Properties => {Queue => {QueueID => [$Queue]}},
				Possible => {Ticket => {Service  => [@Items]}}
			};
		}
	} else {
		# check if we will block all Queues for all Services standard
		if ( $Self->{'QueueService::BlockAll'} ) {
			$Self->{TicketAcl}->{'ACL-SQ_000-All'} = {
				Properties => {},
				PossibleNot => {Ticket => {Queue  => ['[RegExp]^']}}
			};
		}

		my $sq_hash=$Self->{'QueueService::ServiceQueuesID'} or return;
		my %ServiceQueues = %{$sq_hash};
		my @Items;
		for my $Service ( keys %ServiceQueues ) {
			@Items = split /;/, $ServiceQueues{$Service};
			$Self->{TicketAcl}->{'ACL-SQ_0'.$Service} = {
				Properties => {Service => {ServiceID => [$Service]}},
				Possible => {Ticket => {Queue  => [@Items]}}
			};
		}		
	}

	

}
1;
