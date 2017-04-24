# --
# VERSION:1.1
package Kernel::Config::Files::ZZZZQueuesAndServices;
use utf8;
sub Load {
    my ($File, $Self) = @_;

	# check if QueueServices is enabled

	if ( !$Self->Get('QueueService::QSActive') ) {
		return;
	} 


	# check if we will block all services for all queues standard
	if ( $Self->Get('QueueService::BlockAll') ) {
		$Self->{TicketAcl}->{'ACL-QS_000-All'} = {
			Properties => {},
			PossibleNot => {Ticket => {Service  => ['[RegExp]^']}}
		};
	}

	my $qs_hash=$Self->Get('QueueService::QueueServicesName') or return;
	my %QueueServices = %{$qs_hash};
	my @Items;
	for my $Queue ( keys %QueueServices ) {
		@Items = split /;/, $QueueServices{$Queue};
		$Self->{TicketAcl}->{'ACL-QS_0'.$Queue} = {
			Properties => {Queue => {QueueID => [$Queue]}},
			Possible => {Ticket => {Service  => [@Items]}}
		};
	}
}
1;
