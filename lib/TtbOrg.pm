# upload files to trainingstagebuch.org

package TtbOrg;
use strict;
use warnings;
use Carp;
#use LWP::Debug qw/ + +conns/;
use LWP::ConnCache;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;

our $ttborg_url = 'http://trainingstagebuch.org';

sub new {
	my( $proto, $arg ) = @_;

	bless {
		debug	=> 0,
		debug_data => 0,
		$arg ? %$arg : (),
		ua	=> LWP::UserAgent->new(
			conn_cache	=> LWP::ConnCache->new,
		),
	}, ref $proto || $proto;
}

sub debug {
	my $self = shift;
	return unless $self->{debug};
	print STDERR "@_\n";
}

sub request {
	my( $self, $path, $param ) = @_;

	# TODO: allow %$param, too
	my @arg;

	# enable form based file upload:
	foreach my $val ( @$param ){
		next unless ref $val;
		push @arg, Content_Type	=> 'form-data';
		last;
	}

	my $req = $ttborg_url . $path;
	$self->{debug} && $self->debug( "request post : $req, param=@$param, @arg" );

	my $res = $self->{ua}->post( $req, $param, @arg );

	$res->is_success
		or croak "request failed: ". $res->status_line;

	$self->debug( "response status: ", $res->status_line );
	$self->{debug_data} && $self->debug( "response content: ", $res->content );

	my $xml = XMLin( $res->content );
	$self->{debug_data} && $self->debug( "response xml: ", Dumper( $xml ) );

	$xml
}

sub srequest {
	my( $self, $path, $param ) = @_;

	# TODO: allow %$param, too
	$self->request( $path, [
		view	=> 'xml',
		sso	=> $self->session,
		$param ? @$param : (),
	])
}

sub login {
	my( $self ) = @_;

	$self->debug( "logging in..." );
	my $res = $self->request( '/login/sso', [
		user	=> $self->{user},
		pass	=> $self->{pass},
	]);

	$res->{session}
		or croak "login failed, got no session-ID";

	$self->debug( "logged in with session ". $res->{session} );
	$self->{session} = $res->{session};
}

sub session {
	my( $self ) = @_;

	$self->{session} or $self->login;
}

############################################################

sub sport_list {
	my( $self, $page, $rows ) = @_;

	$self->srequest( '/sports/list', [
		page	=> $page || 1,
		rows	=> $rows || 20,
	]);
}

############################################################

sub material_list {
	my( $self, $page, $rows ) = @_;

	$self->srequest( '/material/list', [
		page	=> $page || 1,
		rows	=> $rows || 20,
	]);
}

############################################################

sub zone_list {
	my( $self, $page, $rows ) = @_;

	$self->srequest( '/zones/list', [
		page	=> $page || 1,
		rows	=> $rows || 20,
	]);
}

############################################################

sub workout_list {
	my( $self, $page, $rows ) = @_;

	$self->srequest( '/workouts/list', [
		page	=> $page || 1,
		rows	=> $rows || 20,
	]);
}

sub workout_get {
	my( $self, $id ) = @_;

	$self->srequest( '/workouts/show/'. $id );
}

sub workout_set {
	my( $self, $id, $param ) = @_;

	$self->srequest( '/workouts/edit/'. $id, $param );
}

sub file_upload {
	my( $self, $file ) = @_;

	my $res = $self->srequest( '/file/upload', [
		upload_submit	=> 'hrm',
		file		=> [$file],
	]);

	$self->debug( "saved as workout ". $res->{id} );
	$res->{id};
}

1;
