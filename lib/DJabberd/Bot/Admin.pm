package DJabberd::Bot::Admin;
use strict;
use warnings;
use base qw[DJabberd::Bot];
use xmpproxy::Command;

require Carp;

### this initializes a log object
our $logger = DJabberd::Log->get_logger;

### When this plugin is called, it calls the following methods:
### sub new
###     * inherited from DJabberd::Bot, which inherits from DJabberd::Plugin
###     * called when the <Plugin> directives in the configuration file are read
###     * returns an object of this class
###     * See DJabberd::Plugin for details
###
### sub finalize
###     * inherited from DJabberd::Bot, which inherits from DJabberd::Plugin
###     * callback before the server starts up. allows you to finalize or throw
###       an exception
###
### sub register
###     * inherited from DJabberd::Bot, which inherits from DJabberd::Plugin
###     * must be overridden by your class if DJabberd::Bot does not implement
###       what you want
###     * does all the necessary setup steps for your bot
###     * See DJabberd::Bot and DJabberd::Plugin for details
###
### sub set_config_ARGUMENT_PROVIDED_IN_CONFIGURATION
###     * inherited from DJabberd::Bot, which inherits from DJabberd::Plugin
###     * must be implemented by your class if not implemented in DJabberd::Bot
###     * See DJabberd::Bot and DJabberd::Plugin for details

my $commandroot = new xmpproxy::Command(
	"name"        => "root",
	"helptext"    => "",
	"coderef"     => undef,
	"subcommands" => {
		"user" => new xmpproxy::Command(
			"name"        => "user",
			"helptext"    => "Manages users for this server. Only administrative users are able to use this command. Available subcommands are \"add\", \"del\", \"list\" and \"set\"",
			"coderef"     => \&process_user_command,
			"subcommands" => {
				"set" => new xmpproxy::Command(
					"name"        => "set",
					"coderef"     => \&process_user_set_command,
					"helptext"    => "Set attributes of a user. Possible attributes are jid and passwd \n Syntax: \"account <id> set attribute=value",
					"subcommands" => undef
				),
				"add" => new xmpproxy::Command(
					"name"        => "add",
					"coderef"     => \&process_user_add_command,
					"helptext"    => "Add user. Syntax: \"user add <jid> <password>\"",
					"subcommands" => undef
				),
				"del" => new xmpproxy::Command(
					"name"        => "del",
					"coderef"     => \&process_user_del_command,
					"helptext"    => "Delete user Syntax: \"user del\"<id>",
					"subcommands" => undef
				),
				"list" => new xmpproxy::Command(
					"name"    => "list",
					"coderef" => \&process_user_list_command,
					"helptext" =>
"List accounts registered for the user. Syntax: \"account list\"\nAdmin users can list accounts by other users by adding the username: \"account list <username>",
					"subcommands" => undef
				),
			}
		),
		"account" => new xmpproxy::Command(
			"name"        => "account",
			"coderef"     => \&process_account_command,
			"helptext"    => "Manages proxy accounts for a registered user. Syntax: \"account <id> <subcommand>\"",
			"subcommands" => {
				"set" => new xmpproxy::Command(
					"name"    => "set",
					"coderef" => \&process_account_set_command,
					"helptext" =>
"Set attributes of a proxy account. Possible attributes are jid,passwd and resource.\n Syntax: \"account <id> set attribute=value",
					"subcommands" => undef
				),
				"add" => new xmpproxy::Command(
					"name"        => "add",
					"coderef"     => \&process_account_add_command,
					"helptext"    => "Add proxy account. Syntax: \"account add <jid> <password> <resource>\"",
					"subcommands" => undef
				),
				"del" => new xmpproxy::Command(
					"name"        => "del",
					"coderef"     => \&process_account_del_command,
					"helptext"    => "Delete proxy account. Syntax: \"account del\"<id>",
					"subcommands" => undef
				),
				"list" => new xmpproxy::Command(
					"name"    => "list",
					"coderef" => \&process_account_list_command,
					"helptext" =>
"List accounts registered for the user. Syntax: \"account list\"\nAdmin users can list accounts by other users by adding the username: \"account list <username>",
					"subcommands" => undef
				),
			},
		),
		"help" => new xmpproxy::Command(
			"coderef"     => \&process_help_command,
			"helptext"    => "Prints out this help",
			"subcommands" => undef
		  )

	}
);

$commandroot->{subcommands}->{help}->{subcommands} = $commandroot->{subcommands};

sub process_account_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;
}

sub process_account_add_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;

}

sub process_account_del_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;

}

sub process_account_list_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;

}

sub process_account_set_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;

}

sub process_user_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;
}

sub process_user_add_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;
}

sub process_user_del_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;

}

sub process_user_list_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = $self->helptext();
	return $result;

}

sub process_help_command
{
	my $self   = shift;
	my @args   = @_;
	my $result = "";
	$result = "Available commands: " . join( " ", keys( $self->subcommands ) .". Use help <command> to receive further information on how to use a specific command");
	
	return $result;
}

sub new
{
	my $class = shift;
	my $self  = {};
	bless( $self, $class );
	$self->{'nodename'} = "root";
	$self->{'resource'} = "xmpproxy";
	return $self;
}

sub register
{
	my $self   = shift;
	my $vhost  = shift;
	my $server = $vhost->server;

	### this must be called first, so all kinds of things get set up
	### for us, including the JID
	$self->SUPER::register($vhost);

	### sample info message showing us the bot started up
	$logger->info("Starting up Admin Bot");

}

### retrieve the bots name
### falling back to a default
sub name
{
	my $self = shift;
	return $self->{'name'} || 'Unknown Bot';
}

### process any incoming messages
sub process_text
{
	my ( $self, $text, $from, $ctx ) = @_;

	#TODO: Sanitize input!!!!!

	my @commandparts = split( " ", $text );
	my $result       = "";
	my $command      = $commandroot->find_command(@commandparts);
	if ( defined($command->coderef) )
	{
		$result = &{$command->coderef}($command,@commandparts);
	}
	else
	{
		$result = "Unknown command. Use the \"help\" command to get help on the available commands.";
	}

	### log the message we got
	#$logger->info(  "Got '$text' from $from" );

	### and echo it straight back to them
	$ctx->reply($result);

	return 1;
}

1;
