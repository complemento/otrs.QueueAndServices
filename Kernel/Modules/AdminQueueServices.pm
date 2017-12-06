# --
# Kernel/Modules/AdminQueueServices.pm - to add/update/delete queue <- -> services
# Copyright (C) 20011-2011 Ronaldo Richieri http://www.richieri.com
# --
# $Id: AdminQueueServices.pm,v 1.0 2011/10/15 16:53:28 mg Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminQueueServices;

use strict;
use warnings;

use Kernel::System::Queue;
use Kernel::System::SysConfig;
use Kernel::System::Service;
use Kernel::System::Valid;


use Data::Dumper;



use vars qw($VERSION);
$VERSION = qw($Revision: 1.41 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check all needed objects
    

    $Self->{SysConfig}          = $Kernel::OM->Get('Kernel::System::SysConfig');
    $Self->{QueueObject}        = $Kernel::OM->Get('Kernel::System::Queue');
    $Self->{ServiceObject} 	    = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{ConfigObject}	    = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}	    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $Self->{ParamObject} 	= $Kernel::OM->Get('Kernel::System::Web::Request');
    

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # ------------------------------------------------------------ #
    # queue <-> services n:1
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Queue' ) {
                        
        $Self->{ConfigObject}->Set(
	    Key => 'QueueService::QSActive',
	    Value => 1,
	);$Kernel::OM->Get('Kernel::Output::HTML::Layout');
        # get queue data
        my $ID = $Self->{ParamObject}->GetParam( Param => 'ID' );
        my %QueueData = $Self->{QueueObject}->QueueGet( ID => $ID );
	# Services available        
        my %ServiceData
            = $Self->{ServiceObject}->ServiceList(UserID=>$Self->{UserID}, Valid => 1 );
	# Check selected services on this queue
	my %QueueServicesID = %{$Self->{ConfigObject}->Get('QueueService::QueueServicesID')};
	my %QueueServicesName = %{$Self->{ConfigObject}->Get('QueueService::QueueServicesName')};
        my %SelServices;
	my @Items;
        for my $Queue ( keys %QueueServicesID ) {
        	if ($Queue eq $ID) {
        	        @Items = split /;/, $QueueServicesID{$Queue};
        	}
        }        
        for my $Item (@Items) {
	        $SelServices{ $Item } = '1';
        }

      
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->_Change(
            Selected => \%SelServices,
            Data     => \%ServiceData,
            ID       => $QueueData{QueueID},
            Name     => $QueueData{Name},
            Type     => 'Queue',
        );
        $Output .= $Self->{LayoutObject}->Footer();


        return $Output;
    }

    # ------------------------------------------------------------ #
    # add user to groups
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeQueue' ) {

        # get new role member
        my @IDs = $Self->{ParamObject}->GetArray( Param => 'Queue' );

        my $ID = $Self->{ParamObject}->GetParam( Param => 'ID' );

		my %QueueServicesID = %{$Self->{ConfigObject}->Get('QueueService::QueueServicesID')};
		my %QueueServicesName = %{$Self->{ConfigObject}->Get('QueueService::QueueServicesName')};

		#Delete Example data @todo	
		delete $QueueServicesID{9999999999999};
		delete $QueueServicesName{9999999999999};
		#Delete the actual Queue Data
		delete $QueueServicesID{$ID};
		delete $QueueServicesName{$ID};
		
		my @servicesName;

		for my $service (@IDs){
			push(@servicesName,$Self->{ServiceObject}->ServiceLookup(ServiceID=>$service)) if scalar @IDs;
		}
		$QueueServicesID{$ID}=join(';',@IDs) if scalar @IDs;
		$QueueServicesName{$ID}=join(';',@servicesName) if scalar @IDs;
		
		my %ServiceQueuesIDHashOfArray;
		for my $QueueID (keys %QueueServicesID){
			my $Queue = $Self->{QueueObject}->QueueLookup(QueueID=>$QueueID);
			my @Services = split /;/,$QueueServicesID{$QueueID};
			SERVICE:
			for my $ServiceID (@Services){
				next SERVICE if !$ServiceID;
				if(defined $ServiceQueuesIDHashOfArray{$ServiceID}){
					if (!( grep $_ eq $Queue, @{$ServiceQueuesIDHashOfArray{$ServiceID}} )){
						push @{$ServiceQueuesIDHashOfArray{$ServiceID}},$Queue;
					}
				} else {
					$ServiceQueuesIDHashOfArray{$ServiceID}=["$Queue"];
				}
			}
		}
		
		my %ServiceQueuesIDs;
		
		for my $Service (keys %ServiceQueuesIDHashOfArray){
			$ServiceQueuesIDs{$Service} = join(';',@{$ServiceQueuesIDHashOfArray{$Service}});
		}
		
		$Self->{SysConfig}->ConfigItemUpdate(
				Valid => 1,
				Key => 'QueueService::QueueServicesID',
				Value => \%QueueServicesID,
			 );

		$Self->{SysConfig}->ConfigItemUpdate(
				Valid => 1,
				Key => 'QueueService::ServiceQueuesID',
				Value => \%ServiceQueuesIDs,
			 );
			 
		$Self->{SysConfig}->ConfigItemUpdate(
				Valid => 1,
				Key => 'QueueService::QueueServicesName',
				Value => \%QueueServicesName,
			 );

        return $Self->{LayoutObject}->Redirect( OP => "Action=$Self->{Action}" );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();
    $Output .= $Self->_Overview();
    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}

sub _Change {
    my ( $Self, %Param ) = @_;

    my %Data   = %{ $Param{Data} };
    my $Type   = $Param{Type} || 'Service';
    my $NeType = $Type eq 'Queue' ? 'Service' : 'Queue';

    my %VisibleType = ( Service => 'Service', Queue => 'Queue', );

    my $MyType = $VisibleType{$Type};

    $Self->{LayoutObject}->Block( Name => 'Overview' );
    $Self->{LayoutObject}->Block( Name => 'ActionList' );
    $Self->{LayoutObject}->Block( Name => 'ActionOverview' );
    $Self->{LayoutObject}->Block( Name => 'Filter' );

    #fixed link
    my $QueueTag;

    $QueueTag = $Type eq 'Queue' ? 'Queue' : '';

    $Self->{LayoutObject}->Block(
        Name => 'Change',
        Data => {
            %Param,
            ActionHome    => 'Admin' . $Type,
            NeType        => $NeType,
            VisibleType   => $VisibleType{$Type},
            VisibleNeType => $VisibleType{$NeType},
            Queue         => $QueueTag,

        },
    );

    $Self->{LayoutObject}->Block( Name => "ChangeHeader$VisibleType{$NeType}" );

    $Self->{LayoutObject}->Block(
        Name => 'ChangeHeader',
        Data => {
            %Param,
            Type          => $Type,
            NeType        => $NeType,
            VisibleType   => $VisibleType{$Type},
            VisibleNeType => $VisibleType{$NeType},
        },
    );

    for my $ID ( sort { uc( $Data{$a} ) cmp uc( $Data{$b} ) } keys %Data ) {

        # set output class
        my $Selected = $Param{Selected}->{$ID} ? ' checked="checked"' : '';

        $QueueTag = $Type ne 'Queue' ? 'Queue' : '';

        $Self->{LayoutObject}->Block(
            Name => 'ChangeRow',
            Data => {
                %Param,
                Name          => $Param{Data}->{$ID},
                NeType        => $NeType,
                Type          => $Type,
                ID            => $ID,
                Selected      => $Selected,
                VisibleType   => $VisibleType{$Type},
                VisibleNeType => $VisibleType{$NeType},
                Queue         => $QueueTag,
            },
        );
    }

    return $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminQueueServices',
        Data         => \%Param,
        VisibleType  => $MyType,

    );
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    $Self->{LayoutObject}->Block(
        Name => 'Overview',
        Data => {},
    );

	# check if service is enabled to use it here
	if ( !$Self->{ConfigObject}->Get('Ticket::Service') ) {
	    $Self->{LayoutObject}->Notify(
		Priority => 'Error',
		Data     => '$Text{"Please activate %s first!", "Service"}',
		Link =>
		    '$Env{"Baselink"}Action=AdminSysConfig;Subaction=Edit;SysConfigGroup=Ticket;SysConfigSubGroup=Core::Ticket#Ticket::Service',
	    );
	}

    # no actions in action list
    #    $Self->{LayoutObject}->Block(Name=>'ActionList');
    #    $Self->{LayoutObject}->Block( Name => 'FilterResponse' );
    $Self->{LayoutObject}->Block( Name => 'FilterService' );
    $Self->{LayoutObject}->Block( Name => 'FilterQueue' );
    $Self->{LayoutObject}->Block( Name => 'OverviewResult' );

    # get std response list
    my %ServiceData = $Self->{ServiceObject}->ServiceList(
    						Valid  => 1,
						UserID => $Self->{UserID},
				             );

    # if there are results to show
    if (%ServiceData) {
        for my $ServiceID (
            sort { uc( $ServiceData{$a} ) cmp uc( $ServiceData{$b} ) }
            keys %ServiceData
            )
        {

            # set output class
            $Self->{LayoutObject}->Block(
                Name => 'List1n',
                Data => {
                    Name      => $ServiceData{$ServiceID},
                    Subaction => 'Service',
                    ID        => $ServiceID,
                },
            );
        }
    }

    # otherwise it displays a no data found message
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoResponsesFoundMsg',
            Data => {},
        );
    }

    # get queue data
    my %QueueData = $Self->{QueueObject}->QueueList( Valid => 1 );

    # if there are results to show
    if (%QueueData) {
        for my $QueueID ( sort { uc( $QueueData{$a} ) cmp uc( $QueueData{$b} ) } keys %QueueData ) {

            # set output class
            $Self->{LayoutObject}->Block(
                Name => 'Listn1',
                Data => {
                    Name      => $QueueData{$QueueID},
                    Subaction => 'Queue',
                    ID        => $QueueID,
                },
            );
        }
    }

    # otherwise it displays a no data found message
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoQueuesFoundMsg',
            Data => {},
        );
    }

    # return output
    return $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminQueueServices',
        Data         => \%Param,
    );
}

1;
