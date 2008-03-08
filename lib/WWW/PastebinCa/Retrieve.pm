package WWW::PastebinCa::Retrieve;

use warnings;
use strict;

our $VERSION = '0.002';
use Carp;
use URI;
use LWP::UserAgent;
use HTML::TokeParser::Simple;
use HTML::Entities;
use base 'Class::Data::Accessor';
__PACKAGE__->mk_classaccessors qw(
    ua
    timeout
    html_content
    id
    uri
    error
    results
    response
);

sub new {
    my $class = shift;
    croak "Must have even number of arguments to new()"
        if @_ & 1;

    my %args = @_;
    $args{ +lc } = delete $args{ $_ } for keys %args;

    $args{timeout} ||= 30;
    $args{ua} ||= LWP::UserAgent->new(
        timeout => $args{timeout},
        agent   => 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.8.1.12)'
                    .' Gecko/20080207 Ubuntu/7.10 (gutsy) Firefox/2.0.0.12',
    );

    my $self = bless {}, $class;
    $self->timeout( $args{timeout} );
    $self->ua( $args{ua} );

    return $self;
}

sub retrieve {
    my ( $self, $id ) = @_;
    croak "Missing paste URI or ID (or it's undefined)"
        unless defined $id;

    $id =~ s{ ^ \s+ | (?:http://)? (?:www\.)? pastebin\.ca/ | \s+ $}{}gxi;
    $self->id( $id );

    $self->$_(undef)
        for qw(error results html_content);

    my $uri = URI->new("http://pastebin.ca/$id");
    $self->uri($uri);

    my $response = $self->ua->get( $uri );
    $self->response( $response );
    if ( $response->is_success ) {
        return $self->_parse( $response->content );
    }
    else {
        return $self->_set_error(
            'Failed to retrieve the paste: ' . $response->status_line
        );
    }
}

sub _parse {
    my ( $self, $content ) = @_;
    return $self->_set_error( 'Nothing to parse (empty document retrieved)' )
        unless defined $content and length $content;

    $self->html_content( $content );
    my $parser = HTML::TokeParser::Simple->new( \$content );

    my %data;
    my %nav = (
        level       => 0,
        get_name    => 0,
        get_date    => 0,
    );
    while ( my $t = $parser->get_token ) {
        if ( $t->is_start_tag('h2')
            and defined $t->get_attr('class')
            and $t->get_attr('class') eq 'first'
        ) {
            $nav{level} = 1;
        }
        elsif ( $nav{level} == 1 and $t->is_start_tag('dt') ) {
            @nav{ qw(level  get_name) } = (2, 1);
        }
        elsif ( $nav{get_name} == 1 and $t->is_text ) {
            $data{name} = $t->as_is;
            $nav{get_name} = 0;
        }
        elsif ( $nav{level} == 2 and $t->is_start_tag('dd') ) {
            $nav{get_date} = 1;
            $nav{level}++;
        }
        elsif ( $nav{get_date} and $t->is_text ) {
            $data{post_date} = $t->as_is;
            $data{post_date} =~ s/\s+/ /g;
            $nav{get_date} = 0;
            $nav{level}++;
        }
        elsif ( ( $nav{level} == 4
                  or $nav{level} == 5
                )
             and $t->is_start_tag('dt')
        ) {
            $nav{level}++;
        }
        elsif ( $nav{level} == 6 and $t->is_text ) {
            $data{language} = $t->as_is;
            $data{language} =~ s/Language:\s+//;
            $nav{level}++;
        }
        elsif ( $nav{level} == 7 and $t->is_start_tag('span') ) {
            $nav{level}++;
        }
        elsif ( $nav{level} == 8 and $t->is_text ) {
            $data{age} = $t->as_is;
            $data{age} =~ s/Age:\s+//;
            $nav{level}++;
        }
        elsif ( $t->is_start_tag('textarea') ) {
            $nav{get_paste} = 1;
        }
        elsif ( $nav{get_paste} and $t->is_text ) {
            $data{content} = $t->as_is;
            $nav{success} = 1;
            last;
        }
    }
    unless ( $nav{success} ) {
        my $message = "Failed to parse paste.. ";
        $message .= $nav{level}
                  ? "\$nav{level} == $nav{level}"
                  : "that paste ID doesn't seem to exist";
        return $self->_set_error( $message );
    }

    decode_entities( $_ ) for values %data;

    return $self->results( \%data );
}

sub _set_error {
    my ( $self, $error ) = @_;
    $self->error( $error );
    return;
}

1;
__END__

=head1 NAME

WWW::PastebinCa::Retrieve - retrieve pastes from http://pastebin.ca

=head1 SYNOPSIS

    use strict;
    use warnings;
    use WWW::PastebinCa::Retrieve;

    my $paster = WWW::PastebinCa::Retrieve->new;

    my $content_ref = $paster->retrieve('http://pastebin.ca/930000')
        or die "Failed to retrieve: " . $paster->error;

    printf "Posted on %s (%s ago), titled %s\n\n%s\n",
            @$content_ref{ qw(post_date  age  name  content ) };

=head1 DESCRIPTION

Retrieve pastes on from L<http://pastebin.ca> via Perl

=head1 CONSTRUCTOR

=head2 new

    my $paster = WWW::PastebinCa::Retrieve->new;

    my $paster = WWW::PastebinCa::Retrieve->new(
        timeout => 10,
    );

    my $paster = WWW::PastebinCa::Retrieve->new(
        ua => LWP::UserAgent->new(
            timeout => 10,
            agent   => 'PasterUA',
        ),
    );

Constructs and returns a brand new yummy juicy WWW::PastebinCa::Retrieve
object. Takes two arguments, both are I<optional>. Possible arguments are
as follows:

=head3 timeout

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for pasting. B<Defaults to:> C<30> seconds.

=head3 ua

    ->new( ua => LWP::UserAgent->new( agent => 'Foos!' ) );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for pasting, feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::PastebinCa::Retrieve>'s C<timeout> argument is
set to as well as C<agent> argument is set to mimic Firefox.

=head1 METHODS

=head2 retrieve

    my $content_ref = $paster->retrieve('http://pastebin.ca/930000')
        or die $paster->error;

    my $content_ref = $paster->retrieve('930000')
        or die $paster->error;

Instructs the object to retrieve a specified paste. Takes one mandatory
argument which can be either a full URI to the paste you want to retrieve
or just the paste's ID number. If an error occurs returns either C<undef>
or an empty list depending on the context and the reason for the error
will be available via C<error()> method. Upon success returns a hashref
with the following keys/values:

    $VAR1 = {
          'language' => 'Raw',
          'content' => 'select t.terr_id, max(t.start_date) as start_dat',
          'post_date' => 'Wednesday, March 5th, 2008 at 10:31:42pm MST',
          'name' => 'Mine',
          'age' => '17 hrs 43 mins'
    };

=over 14

=item language

    { 'language' => 'Raw' }

The (computer) language of the paste.

=item content

    { 'content' => 'select t.terr_id, max(t.start_date) as start_dat' }

The content of the paste.

=item post_date

    { 'post_date' => 'Wednesday, March 5th, 2008 at 10:31:42pm MST' }

The date when the paste was created

=item name

    { 'name' => 'Mine' }

Tha name of the poster or the title of the paste.

=item age

    { 'age' => '17 hrs 43 mins' }

The age of the paste (how long ago it was created).

=back

=head2 error

    my $content_ref = $paster->retrieve('930000')
        or die $paster->error;

If an error occured during the call to C<retrieve()> method it will return
either C<undef> or an empty list depending on the context and the reason
for an error will be available via C<error()> method. Takes no arguments,
returns human parseable reason for failure.

B<Note:> if the error message contains
C<Failed to parse paste.. $nav{level} ==> it means that the parser
was stopped half-way thru. Please submit a bug with the
ID of the paste you've tried to retrieve. Thank you.

=head2 results

    my $last_retrieve_results = $paster->results;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns a hashref which is exactly the same as the return value of
C<retrieve()> method.

=head2 id

    my $paste_id = $paster->id;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns a paste ID number of the last retrieved paste irrelevant of whether
an ID or a URI was given to C<retrieve()>

=head2 uri

    my $paste_uri = $paster->uri;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns a L<URI> object with the URI pointing to the last retrieved paste
irrelevant of whether an ID or a URI was given to C<retrieve()>

=head2 response

    my $response_obj = $paster->response;

Must be called after a call to C<retrieve()>. Takes no arguments,
returns an L<HTTP::Response> object which was obtained while trying to
retrieve your paste. You can use it in case you want to thoroughly
investigate why the C<retrieve()> might have failed

=head2 html_content

    my $paste_html = $paster->html_content;

Must be called after a successfull call to C<retrieve()>. Takes no arguments,
returns an unparsed HTML content of the paste ID you've specified to
C<retrieve()>

=head2 timeout

    my $ua_timeout = $paster->timeout;

Takes no arguments, returns the value you've specified in the C<timeout>
argument to C<new()> method (or its default if you didn't). See C<new()>
method above for more information.

=head2 ua

    my $old_LWP_UA_obj = $paster->ua;

    $paster->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object used for retrieving
pastes. Takes one optional argument which must be an L<LWP::UserAgent>
object, and the object you specify will be used in any subsequent calls
to C<retrieve()>.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-pastebinca-retrieve at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-PastebinCa-Retrieve>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::PastebinCa::Retrieve

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-PastebinCa-Retrieve>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-PastebinCa-Retrieve>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-PastebinCa-Retrieve>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-PastebinCa-Retrieve>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
