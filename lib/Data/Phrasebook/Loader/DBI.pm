package Data::Phrasebook::Loader::DBI;
use strict;
use warnings FATAL => 'all';
use base qw( Data::Phrasebook::Loader::Base Data::Phrasebook::Debug );
use Carp qw( croak );
use DBI;

our $VERSION = '0.03';

=head1 NAME

Data::Phrasebook::Loader::DBI - Absract your phrases with a DBI driver.

=head1 SYNOPSIS

    use Data::Phrasebook;

    my $q = Data::Phrasebook->new(
        class     => 'Fnerk',
        loader    => 'DBI',
        file      => {
            dsn       => 'dbi:mysql:database=test',
            dbuser    => 'user',
            dbpass    => 'pass',
            dbtable   => 'phrasebook',
            dbcolumns => ['keyword','phrase','dictionary'],
        }
    );

    OR

    my $q = Data::Phrasebook->new(
        class     => 'Fnerk',
        loader    => 'DBI',
        file      => {
            dbh       => $dbh,
            dbtable   => 'phrasebook',
            dbcolumns => ['keyword','phrase','dictionary'],
        }
    );

    $q->delimiters( qr{ \[% \s* (\w+) \s* %\] }x );
    my $phrase = $q->fetch($keyword);

=head1 ABSTRACT

This module provides a loader class for phrasebook implementations using DBI.

=head1 DESCRIPTION

This class loader implements phrasebook patterns using DBI. 

Phrases can be contained within one or more dictionaries, with each phrase 
accessible via a unique key. Phrases may contain placeholders, please see 
L<Data::Phrasebook> for an explanation of how to use these. Groups of phrases
are kept in a dictionary. The first dictionary is used as the default, unless 
a specific dictionary is requested.

This module provides a base class for phrasebook implementations via a database.
Note that the order of table columns is significant. If there is no dictionary
field, all entries are assumed to be part of the default dictionary.

=head1 INHERITANCE

L<Data::Phrasebook::Loader::DBI> inherits from the base class
L<Data::Phrasebook::Loader::Base>.
See that module for other available methods and documentation.

=head1 METHODS

=head2 load

Given the appropriate settings, connects to the designated database. Note that
for consistency, the connection string and other database specific settings,
are passed via a hashref.

   $loader->load( $file );

The hashref can be either:

   my $file => {
            dsn       => 'dbi:mysql:database=test',
            dbuser    => 'user',
            dbpass    => 'pass',
            dbtable   => 'phrasebook',
            dbcolumns => ['keyword','phrase','dictionary'],
   };

which will create a connection to the specified database. Or:

   my $file => {
            dbh       => $dbh,
            dbtable   => 'phrasebook',
            dbcolumns => ['keyword','phrase','dictionary'],
   };

which will reuse and already established connection.

This method is used internally by L<Data::Phrasebook::Generic>'s
C<data> method, to initialise the data store.

=cut

sub load
{
    my ($self, $file, $dict) = @_;

	$self->{file} = $file;
	$self->{dict} = $dict;

	croak "Phrasebook table name missing"
		unless($self->{file}{dbtable});
	croak "Phrasebook column names missing"
		unless($self->{file}{dbcolumns} && $self->{file}{dbcolumns} >= 2);

	$self->{dbh} = $self->{file}{dbh}	if(defined $self->{file}{dbh});

	$self->{dbh} ||= do {
		croak "No DSN specified for a database connection"
			unless($self->{file}{dsn});
		croak "DB user details missing"
			unless($self->{file}{dbuser} && $self->{file}{dbpass});

		DBI->connect(	$self->{file}{dsn}, 
						$self->{file}{dbuser}, $self->{file}{dbpass},
						{ RaiseError => 1, AutoCommit => 1 });
	};
};

=head2 get

Returns the phrase stored in the phrasebook, for a given keyword.

   my $value = $loader->get( $key );

=cut

sub get {
    my ($self,$key) = @_;

	my $sql =
			'SELECT '.$self->{file}{dbcolumns}[1].
			' FROM  '.$self->{file}{dbtable}.
			' WHERE '.$self->{file}{dbcolumns}[0].'=?';
	$sql .= ' AND   '.$self->{file}{dbcolumns}[2].'=?'	
		if($self->{file}{dbcolumns}[2]);

	my $sth = $self->{dbh}->prepare($sql);
	if($self->{file}{dbcolumns}[2]) {
		$sth->execute($key,$self->{dict});
	} else {
		$sth->execute($key);
	}
	my @row = $sth->fetchrow_array;
	$sth->finish;
	return $row[0];
}

sub DESTROY {
	my $self = shift;
	$self->{dbh}->disconnect	if defined $self->{dbh};
}

1;

__END__

=head1 SEE ALSO

L<Data::Phrasebook>.

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (http://rt.cpan.org/). However, it would help greatly if you are 
able to pinpoint problems or even supply a patch. 

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  for Miss Barbell Productions <http://www.missbarbell.co.uk>.

=head1 LICENCE AND COPYRIGHT

  Copyright (C) 2004-2005 Barbie for Miss Barbell Productions.

  This library is free software; you can redistribute it and/or modify
  it under the same terms as Perl itself.

The full text of the licences can be found in the F<Artistic> and
F<COPYING> files included with this module, or in L<perlartistic> and
L<perlgpl> in Perl 5.8.1 or later.

=cut