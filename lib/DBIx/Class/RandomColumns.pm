package DBIx::Class::RandomColumns;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'DBIx::Class';

__PACKAGE__->mk_classdata(random_auto_columns => []);

=head1 NAME

DBIx::Class::RandomColumns - Implicit random columns

=head1 SYNOPSIS

  package My::Schema::Table;
  use base 'DBIx::Class';

  __PACKAGE__->load_components(qw/RandomColumns Core/);
  __PACKAGE__->table('table');
  __PACKAGE__->add_columns(qw(id foo bar baz));
  __PACKAGE__->random_columns('id', bar => {length => 10});

=head1 DESCRIPTION

This L<DBIx::Class|DBIx::Class> component is a replacement for
L<DBIx::Class::RandomStringColumns|DBIx::Class::RandomStringColumns>
which is broken at least with L<DBIx::Class|DBIx::Class> E<gt>= 0.05.
Since the author doesn't reply to emails for two weeks now I decided to
write this module.

This component resembles the behaviour of
L<Class::DBI::Plugin::RandomStringColumn|Class::DBI::Plugin::RandomStringColumn>,
to make some columns implicitly created as random string.

Note that the component needs to be loaded before Core.

=head1 METHODS

=head2 random_columns

  __PACKAGE__->random_columns(@column_names);
  __PACKAGE__->random_columns(name1 => \%options1, name2 => \%options2);

Define fields that get random strings at creation. Each column name can
be followed by a hash reference containing options.

Valid options are:

=over 3

=item set

Can be either data or a code reference.

=over 3

=item data

A string or an array reference that contains the set of characters to use for
building the random key. The default set is C<['0'..'9', 'a'..'z']>.

=item code

A reference to a subroutine that returns the random string. Usefull if random
data must have a certain form. For example to build a valid license plate
number for Berlin/Germany, the subroutine would (basically) look like:

  sub {
    my @a = ('A'..'Z', '');
    'B-'.$a[int(rand $#a)].$a[int(rand @a)].' '.(int(rand 9999)+1);
  }

=back

=item length

Length of the random string to create. Defaults to 32. This is ignored if
C<set> is a code reference.

=item check

Search table before insert until generated column value is not found.
Defaults to false and must be set to a true value to activate.
Provided Perl rand() function has sufficient entropy this lookup is not
really usefull in combination with the default set and length, which
gives 36^32 possible combinations.

=back

=cut

sub random_columns {
    my ($class, @cols) = @_;

    my ($col, $opt, $set);
    while ($col = shift @cols) {
        $class->throw_exception(qq{column "$col" doesn't exist})
	    unless $class->has_column($col);
        $opt = ref $cols[0] eq 'HASH' ? shift(@cols) : {};
	# push auto column settings onto $class->random_auto_columns.
	# 0: Column name
	# 1: set
	# 2: length
	# 3: check on/off
	$set = $opt->{set};
        push @{$class->random_auto_columns}, [
            $col,
	    defined($set) ?
		ref($set) ? $set : [ split //, $set ] :
		['0'..'9', 'a'..'z'],
            $opt->{length} || 32,
            $opt->{check}
        ];
    }
}

sub insert {
    my ($self) = @_;
    for my $column (@{$self->random_auto_columns}) {
        $self->store_column($column->[0], $self->_get_random_column_id($column))
            unless defined $self->get_column($column->[0]);
    }
    $self->next::method;
}

sub _get_random_column_id {
    my $self   = shift;
    my ($name, $set, $length, $check) = @{shift()};
    my $id;

    my $tries = 100;
    do { # check uniqueness if check => 1 for this column
	if (ref($set) eq 'CODE') {
	    $id = &$set();
	}
	else {
	    $id = '';
	    # random id is as good as Perl's rand()
	    $id .= $set->[int(rand(@$set))] for (1 .. $length);
	}
    } while ($check and $tries-- and $self->result_source->resultset->search({$name => $id})->count);

    $self->throw_exception("escaped from busy loop in DBIx::Class::RandomColumns::get_random_column_id()")
	unless $tries;

    $id;
}

1;

__END__

=head1 AUTHORS

Bernhard Graf <perl-dbic-randomcolumns@movingtarget.de>

=head1 CREDITS

Matsuno Tokuhiro <tokuhiro at mobilefactory.jp> wrote
Class::DBI::Plugin::RandomStringColumn.

Kan Fushihara <kan at mobilefactory.jp> wrote
DBIx::Class::RandomStringColumns.

Matt S Trout <mst@shadowcatsystems.co.uk> wrote DBIx::Class.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.
