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
		session	=> undef,
		pro	=> 0,
	}, ref $proto || $proto;
}

sub debug {
	my $self = shift;
	return unless $self->{debug};
	print STDERR "@_\n";
}

sub request {
	my( $self, $path, $query, $body ) = @_;

	my $uri = URI->new( $ttborg_url . $path );
	$uri->query_form(
		@$query,
		view	=> 'xml'
	);

	$self->debug( "request uri: ". $uri );

	my $res = $self->{ua}->post( $uri, ( $body
		? ( $body, Content_Type => 'form-data' )
		: () ),
	);

	$res->is_success
		or croak "request failed: ". $res->status_line;

	$self->debug( "response status: ", $res->status_line );
	$self->{debug_data} && $self->debug( "response content: ", $res->content );

	my $xml = XMLin( $res->content );
	$self->{debug_data} && $self->debug( "response xml: ", Dumper( $xml ) );

	$xml
		or croak "got invalid XML response";

	$xml->{error}
		&& croak "request failed: $xml->{error}";

	$xml;
}

sub srequest {
	my( $self, $path, $query, $body ) = @_;

	# TODO: allow %$param, too
	$self->request( $path, [
		sso	=> $self->session,
		$query ? @$query : (),
	], $body );
}

sub new_session {
	my( $self ) = @_;

	$self->debug( "requesting new SSO session..." );
	my $res = $self->request( '/login/sso', [
		user	=> $self->{user},
		pass	=> $self->{pass},
	]);

	$res->{session}
		or croak "SSO failed, got no session-ID";

	$self->debug( "got new SSO session ". $res->{session} );

	$res->{session};
}

sub get_session {
	my( $self ) = @_;

	$self->debug( "checking for SSO session..." );
	my $res = $self->request( '/settings/list', [
		user	=> $self->{user},
		pass	=> $self->{pass},
	]);

	$self->debug( "got pro=". ($res->{pro}||'-')
		.", session=".  ($res->{session}||'-') );
	$self->{pro} = $res->{pro};

	$res->{session};
}

sub session {
	my( $self ) = @_;

	$self->{session} ||= $self->get_session
		|| $self->new_session;
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

	$self->session;

	my $limit = $self->{pro}
		? 8 * 1024 * 1024
		: 4 * 1024 * 1024;

	my $size = (stat($file))[7]
		or croak "no/empty file: $file";

	$self->debug( "file size: $size, limit: $limit" );
	$size < $limit
		or croak "file too large, $size > $limit: $file";

	my $res = $self->srequest( '/file/upload', [], [
		upload_submit	=> 'hrm',
		file		=> [$file],
	] );

	$self->debug( "saved as workout ". ($res->{id}||'-') );
	$res->{id};
}

1;
