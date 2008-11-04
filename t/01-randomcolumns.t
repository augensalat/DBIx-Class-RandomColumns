#!perl -wT
use strict;
use warnings;
use Test::More;

BEGIN {
    use lib 't/lib';
    use TestDB;

    eval 'require DBD::SQLite';
    if ($@) {
        plan skip_all => 'DBD::SQLite not installed';
    } else {
        plan tests => 26;
    }
};

my $schema = TestDB->init_schema;

my $rs;

for my $table (qw(Foo Bar)) {
    $rs = $schema->resultset($table);

    my $row = $rs->new_result({number1 => 4711, string1 => 'foo'});

    my $random_columns = $row->random_columns;

    isa_ok($random_columns, 'HASH', 'random_columns() returns a hash');

    is_deeply(
	[sort keys %$random_columns],
	[qw(id number1 number2 string1 string3 string4)],
	'keys of random columns all there'
    );

    like($row->get_random_value('string4'), qr/^[\da-z]{32}$/, 'get_random_value() standalone usage');

    ok(!defined($row->string4), 'random_columns yet not populated');

    $row->insert;

    like($row->id, qr/^[\da-z]{20}$/, 'random string with full field length');
    is($row->number1, 4711, 'stay away from defined numbers');
    is($row->string1, 'foo', 'stay away from defined strings');
    like($row->number2, qr/^\d{10}$/, 'random number with full field length');
    like($row->string3, qr/^\d{3}$/, 'random string with custom character set and length');
    like($row->string4, qr/^[\da-z]{32}$/, 'another random string with full field length');

    $row = $rs->create({string5 => $table});

    like(sprintf('%010d', $row->number1), qr/^[01]{10}$/, 'binary random value');
    unlike($row->number1, qr/[2..9]/, 'binary random value does not contain digits above 1');
    like($row->string1, qr/^[\da-z]{32}$/, 'random string with full field length');
}
