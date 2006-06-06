use strict;
use warnings;
use Test::More;
$| = 1;

BEGIN {
    eval "use DBD::SQLite";
    plan $@ ? (skip_all => 'needs DBD::SQLite for testing') : (tests => 7);
}

{
    package Foo;
    use base 'DBIx::Class';
    use strict;
    use warnings;
    use DBIx::Class::RandomColumns;

    use File::Temp 'tempfile';
    my (undef, $DB) = tempfile();
    my @DSN = ("dbi:SQLite:dbname=$DB", '', '', { AutoCommit => 1 });

    END { unlink $DB if -e $DB }

    __PACKAGE__->load_components(qw/RandomColumns Core DB/);
    __PACKAGE__->connection(@DSN);
    __PACKAGE__->storage->dbh->do(<<'');
CREATE TABLE foo (
    session_id VARCHAR(32) PRIMARY KEY,
    u_rand_id  VARCHAR(32),
    number     INT,
    rand_id    VARCHAR(32),
    rand_id2   VARCHAR(20),
    rand_pat   VARCHAR(11)
)

    __PACKAGE__->table('foo');
    __PACKAGE__->add_columns(qw(session_id u_rand_id number rand_id rand_id2 rand_pat));
    __PACKAGE__->set_primary_key('session_id');
    __PACKAGE__->random_columns(
	'session_id',
    	'u_rand_id',
	'rand_id' => {size => 3, set => [0..9], check => 1},
	'rand_id2',
	'rand_pat' => {set => sub {
		my @a = ('A'..'Z', '');
		'B-' . $a[int(rand $#a)] . $a[int(rand @a)] . ' ' . (int(rand 9999)+1)
	    }
	},
    );
}

ok(Foo->can('storage'), 'storage');
#is(Foo->__driver, "SQLite", "Driver set correctly");

my $foo = Foo->create({number => 3, u_rand_id => 'foo'});
is($foo->number, 3, 'can set number');
is($foo->u_rand_id, 'foo', 'no rewrite if set');
like($foo->session_id, qr/^[a-z0-9]{32}$/, 'set random string column');
like($foo->rand_id,  qr/^[0-9]{3}$/, 'set random string column at rand_id');
like($foo->rand_id2, qr/^[a-z0-9]{20}$/, 'set random string column at rand_id2');
like($foo->rand_pat, qr/^B-[A-Z]{1,2} \d{1,4}$/, 'set random pattern string column at rand_pat');

# vim: set ft=perl :
