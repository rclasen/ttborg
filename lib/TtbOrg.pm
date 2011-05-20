# upload files to trainingstagebuch.org

package TtbOrg;
use strict;
use warnings;
use Carp;
#use LWP::Debug qw/ + +conns/;
use LWP::ConnCache;
use LWP::UserAgent;
use XML::Simple;

our $ttborg_url = 'http://trainingstagebuch.org';

sub new {
	my( $proto, $arg ) = @_;

	bless {
		$arg ? %$arg : (),
		ua	=> LWP::UserAgent->new(
			conn_cache	=> LWP::ConnCache->new,
		),
	}, ref $proto || $proto;
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
	#print STDERR "request post : $req, param=@$param, @arg";

	my $res = $self->{ua}->post( $req, $param, @arg );

	$res->is_success
		or croak "request failed: ". $res->status_line;

	#print STDERR "response status: ", $res->status_line;
	#print STDERR "response content: ", $res->content;

	XMLin( $res->content );
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

	my $res = $self->request( '/login/sso', [
		user	=> $self->{user},
		pass	=> $self->{pass},
	]);

	$res->{session}
		or croak "login failed, got no session-ID";

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

	$res->{id};
}

1;
