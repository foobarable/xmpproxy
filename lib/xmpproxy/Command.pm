package xmpproxy::Command;
use strict;
use warnings;

our $logger = DJabberd::Log->get_logger();

sub new
{
	my $class = shift;
	my $self  = {};
	bless( $self, $class );
	$self->{name}        = "";
	$self->{subcommands} = [];
	$self->{helptext}    = "";
	$self->{coderef}     = undef;
	if (@_)
	{

		while ( $#_ >= 0 )
		{
			$self->{ lc pop(@_) } = pop(@_);
		}
	}
	return $self;
}

sub find_command
{
	my $self         = shift;
	my @commandparts = @_;
	#print( ref($self) . " " . join( " ", @commandparts ) . "\n" );
	my $nextcommand = undef;
	if ( scalar(@commandparts) > 0 and defined( $self->subcommands ) )
	{
		$nextcommand = $self->{subcommands}->{ shift(@commandparts) };
	}

	if ( ( not defined($nextcommand) ) or ( ref($nextcommand) ne "xmpproxy::Command" ) )
	{
		#print( "Returning coderef.." . "\n" );
		return $self;
	}
	else
	{
		$self = $nextcommand;
		$self->find_command(@commandparts);
	}
}

sub find_coderef
{
	my $self         = shift;
	my @commandparts = @_;
	print( ref($self) . " " . join( " ", @commandparts ) . "\n" );
	my $nextcommand = undef;
	if ( scalar(@commandparts) > 0 and defined( $self->subcommands ) )
	{
		$nextcommand = $self->{subcommands}->{ shift(@commandparts) };
	}

	if ( ( not defined($nextcommand) ) or ( ref($nextcommand) ne "xmpproxy::Command" ) )
	{
		print( "Returning coderef.." . "\n" );
		return $self->{coderef};
	}
	else
	{
		$self = $nextcommand;
		$self->find_coderef(@commandparts);

		#xmpproxy::Command->find_coderef($nextcommand,@commandparts);
	}
}

sub subcommands
{
	my $self = shift;
	return $self->{subcommands};
}

sub helptext
{
	my $self = shift;
	return $self->{helptext};
}

sub coderef
{
	my $self = shift;
	return $self->{coderef};
}

