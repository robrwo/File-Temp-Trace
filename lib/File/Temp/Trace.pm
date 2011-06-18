package File::Temp::Trace;

=head1 NAME

File::Temp::Trace - Trace the creation of temporary files

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 REQUIREMENTS

=head1 SYNPOSIS

=head1 DESCRIPTION

This module allows you to trace the creation of temporary files. By
default, files are all created in the same directory, and files are
prefixed by the name of the function or method that created them.

You can optionally log the creation of temporary files with a stack
trace as well.

=cut

use strict;
use warnings;

use self;

use overload
    '""' => \&dir;

use Attribute::Handlers;
use Carp qw( longmess );
use File::Path qw( make_path );
use File::Spec;
use File::Temp ();
use Scalar::Util qw( refaddr );

BEGIN {
    %File::Temp::Trace::SkipName = ( );
}

sub UNIVERSAL::skip_temp : ATTR(CODE) {
  my ($pkg, $sym, $ref, $attr, $data) = @_;
  $File::Temp::Trace::SkipName{substr($$sym,1)} = $data;
}

my %LogFiles = ( );

sub _name_to_template {
    my ($name) = @_;
    $name =~ s/\:\:/-/g;
    $name = "UNKNOWN", if (($name eq "") || ($name eq "(eval)"));
    return "${name}-XXXXXXXX";
}

=head2 new

=over

=item cleanup

=item template

=item dir

=item log

=back

=cut

sub new {
    my $class = shift || __PACKAGE__;

    my %opts = @args;

    my %ftopts = ( CLEANUP => 1, TEMPLATE => _name_to_template(__PACKAGE__), TMPDIR => 1 );
    foreach my $o (qw( cleanup template tmpdir dir )) {
	$ftopts{ uc($o) } = $opts{$o}, if (exists $opts{$o});
    }

    $self = \ File::Temp->newdir($ftopts{TEMPLATE}, %ftopts);
    bless $self, $class;

    if ($opts{log}) {
	$LogFiles{ refaddr $self } = File::Temp->new( TEMPLATE => _name_to_template(__PACKAGE__), DIR => $self->dir, SUFFIX => ".log", UNLINK => 0 );
    }

    return $self;
}

=head2 dir

=head2 tmpdir

  $dir = $tmp->tmpdir;

This is an alias of L</dir>.

=cut

sub dir {
    return ${$self};
}

=head2 log

=head2 tmplog

  $fh = $tmp->tmplog;

This is an alias of L</log>.

=cut

sub log {
    return $LogFiles{ refaddr $self };
}

=head2 file

=over

=item unlink

=item suffix

=item exlock

=item log

=item dir

=back

=head2 tmpfile

  $fh = tmpfile(%options);

This is an alias of L</file>.

=cut

sub file {
    my $level = 1;
    my @frame = ( );
    my $name;
    do {
	@frame = caller($level++);
	$name   = $frame[3] || "";
    } while ($name && (exists $File::Temp::Trace::SkipName{$name}));

    my %opts = @args;

    my %ftopts = ( UNLINK => 0, TEMPLATE => _name_to_template($name), DIR => $self->dir, EXLOCK => 1 );
    foreach my $o (qw( unlink suffix exlock )) {
	$ftopts{ uc($o) } = $opts{$o}, if (exists $opts{$o});
    }

    if (exists $opts{dir}) {
	$ftopts{DIR} = File::Spec->catfile(File::Spec->splitdir($self->dir), File::Spec->splitdir($opts{dir}));
	make_path($ftopts{DIR});
    }

    my $fh = File::Temp->new(%ftopts);
    if ((my $lh = $self->log) || ($opts{log})) {
	my $ts  = sprintf("[%s]", (scalar gmtime()));
	my $msg = sprintf("%s File %s created%s", $ts, $fh->filename, longmess());
	$msg =~ s/\n(.)/\n$ts $1/g;

	if ($lh) { print $lh $msg; }
	if ($opts{log}) {
	    open my $fhlh, sprintf(">%s.log", $fh->filename);
	    print $fhlh $msg;
	    close $fhlh;
	}
    }
    return $fh;
}

BEGIN{
    *tmpdir = \&dir;
    *tmplog = \&log;
    *tmpfile = \&file;
}

=head1 SEE ALSO

L<File::Temp>

=head1 AUTHOR

Robert Rothenberg, C<< <rrwo@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-file-temp-trace@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=File-Temp-Trace>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::Temp::Trace

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=File-Temp-Trace>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/File-Temp-Trace>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/File-Temp-Trace>

=item * Search CPAN

L<http://search.cpan.org/dist/File-Temp-Trace/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Robert Rothenberg.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;

