package DBIx::Class::RandomColumns;

use strict;
use warnings;

our $VERSION = '0.003000';

use DBIx::Class 0.08009;

use base qw/DBIx::Class/;
__PACKAGE__->mk_group_accessors(
    inherited => qw/_random_columns max_dup_checks default_field_size/
);

use constant TEXT_SET => ['0'..'9', 'a'..'z'];
use constant NUM_SET => ['0'..'9'];

__PACKAGE__->max_dup_checks(100);
__PACKAGE__->default_field_size(32);

=head1 NAME

DBIx::Class::RandomColumns - Implicit random columns

=head1 SYNOPSIS

  package My::Schema::Utz;
  use base 'DBIx::Class';

  __PACKAGE__->load_components(qw/RandomColumns Core/);
  __PACKAGE__->table('utz');
  __PACKAGE__->add_columns(qw(id foo bar baz));
  __PACKAGE__->random_columns('id', bar => {size => 10});

  package My::Schema::Gnarf;
  use base 'DBIx::Class';

  __PACKAGE__->load_components(qw/RandomColumns Core/);
  __PACKAGE__->table('gnarf');
  __PACKAGE__->add_columns(
    id => {
      datatype => 'varchar',
      is_random => 1,
      size => 20,
    },
    foo => {
      datatype => 'int',
      size => 10,
    },
    bar => {
      datatype => 'varchar',
      is_random => {size => 10},
      size => 32,
    },
    baz => {
      datatype => 'varchar',
      size => 255,
    },
  );

=head1 VERSION

This is version 0.003000

=head1 DESCRIPTION

This DBIx::Class component makes columns implicitly create random values.

The main reason why this module exists is to generate unpredictable primary
keys to add some additional security to web applications.

Note that the component needs to be loaded before Core.

=head1 METHODS

=cut

sub add_columns {
    my $class = shift;
    my @random_columns;
    my ($info, $opt);

    $class->next::method(@_);

    for my $column ($class->columns) {
	$info = $class->column_info($column);
	$opt = $info->{is_random}
	    or next;
	push @random_columns, $column;
	push @random_columns, $opt
	    if ref($opt) eq 'HASH';
    }
    $class->random_columns(@random_columns);

    return;	# nothing
}

=head2 random_columns

  __PACKAGE__->random_columns(@column_names);
  __PACKAGE__->random_columns(name1 => \%options1, name2 => \%options2);
  $random_columns = __PACKAGE__->random_columns;

Define or query fields that get random strings at creation. Each column
name can be followed by a hash reference containing options.

Valid options are:

=over 3

=item set

A string or an array reference that contains the set of characters to use
for building the random key. The default set is C<['0'..'9', 'a'..'z']>
for character type fields and C<['0'..'9']> for number type fields.

=item size

Length of the random string to create. Defaults to the size of the column or - if this
cannot be determined for whatever reason - to 32.

=item check

Search table before insert until generated column value is not found.
Defaults to false and must be set to a true value to activate.
Provided Perl's rand() function has sufficient entropy this lookup is only
usefull for short fields, because with the default set there are
C<36^field-size> possible combinations.

=back

Returns a has reference, with column names of the random columns as keys and
array references as values, that contain C<set>, C<size> and C<check>.

=cut

sub random_columns {
    my $class = shift;
    my $random_auto_columns = $class->_random_columns || {};

    # act as read accessor when no arguments are given
    return $random_auto_columns
	unless @_;

    my ($col, $info, $opt, $set, $data_type);

    # loop over argument list
    while ($col = shift @_) {
	$info = $class->column_info($col);
        $class->throw_exception(qq{column "$col" doesn't exist})
	    unless $class->has_column($col);
        $opt = ref $_[0] eq 'HASH' ? shift(@_) : {};

	# set auto column settings of current column
	# as an array reference in $class->_random_columns,
	# the array is organized as follows:
	# 0: set
	# 1: size
	# 2: check on/off
	$random_auto_columns->{$col} = [
	    defined($set = $opt->{set}) ?
		ref($set) ? $set : [ split //, $set ] :
		lc($info->{data_type} || '') =~
			/^(?:var(?:char2?|binary)|(?:char(?:acter(?:\s+varying)?)?)|binary|(?:tiny|medium|long)?blob|(?:tiny|medium|long)?text|clob|comment|bytea)$/ ?
		    TEXT_SET : NUM_SET,
            $opt->{size} || $info->{size} || $class->default_field_size,
            $opt->{check}
        ];
    }

    # set internal class variable _random_columns
    return $class->_random_columns($random_auto_columns);
}

=head2 insert

Hooks into L<DBIx::Class::Row::insert()|DBIx::Class::Row/insert> to create
a random value for each L<random column/random_columns> that is not
defined.

=cut

sub insert {
    my $self = shift;

    my $accessor;
    for (keys %{$self->random_columns}) {
	next if defined $self->get_column($_);	# skip if defined

	$accessor = $self->column_info($_)->{accessor} || $_;
        $self->$accessor($self->get_random_value($_));
    }
    return $self->next::method;
}

=head2 get_random_value

  $value = $instance->get_random_value($column_name);

Compute a random value for the given C<$column_name>.

Throws an exception if the concerning column has not been declared
as a random column.

=cut

sub get_random_value {
    my $self   = shift;
    my $column = shift;
    my $conf = $self->random_columns->{$column}
	or $self->throw_exception(qq{column "$column" is not a random column});
    my ($set, $size, $check) = @$conf;
    my $id;

    my $tries = $self->max_dup_checks;
    do { # check uniqueness if check => 1 for this column
	$id = '';
	# random id is as good as Perl's rand()
	$id .= $set->[int(rand(@$set))] for (1 .. $size);
    } while ($check and $tries-- and $self->result_source->resultset->search({$column => $id})->count);

    $self->throw_exception("escaped from busy loop in DBIx::Class::RandomColumns::get_random_column_id()")
	unless $tries;

    return $id;
}

1;

__END__

=head1 OPTIONS

=head2 is_random

  is_random => 1

  is_random => {size => 16, set => ['0'..'9','A'..'F']}

Instead of calling L</random_columns> it is also possible to specify option
C<is_random> in L<add_columns|DBIx::Class::ResultSource/add_columns>.
The value is either a true scalar, indicating that this in fact is a
random column, or a hash reference, that has the same meaning as described
under L</random_columns>.

=head1 SEE ALSO

L<DBIx::Class>

=head1 AUTHOR

Bernhard Graf C<< <graf(a)cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-dbix-class-randomclumns at rt.cpan.org>, or through the web interface
at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Class-RandomColumns>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Bernhard Graf.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
