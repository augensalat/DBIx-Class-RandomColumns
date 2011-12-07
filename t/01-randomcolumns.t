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
        plan tests => 28;
    }
};

my $schema = TestDB->init_schema;

my $rs;

for my $table (qw(Foo Bar)) {
    $rs = $schema->resultset($table);

    my $row = $rs->new_result({number1 => 4711, string1 => 'foo'});

    my $random_columns = $row->random_columns;

    isa_ok $random_columns, 'HASH', 'random_columns() returns a hash';

    is_deeply $random_columns, {
        id => {set => ['0'..'9', 'a'..'z'], size => 20, check => undef},
        number1 => {min => 0, max => 2**31-1, check => undef},
        number2 => {min => -2**31, max => 2**31-1, check => undef},
        number3 => {min => 0, max => 2**31-1, check => undef},
        number4 => {min => -5, max => 3, check => undef},
        string1 => {set => ['0'..'9', 'a'..'z'], size => 32, check => undef},
        string3 => {set => [0..9], size => 3, check => 1},
        string4 => {set => ['0'..'9', 'a'..'z'], size => 32, check => undef},
    }, 'random_columns discloses configuration';
    like $row->get_random_value('string4'), qr/^[\da-z]{32}$/,
        'get_random_value() standalone usage on string';
    ok $_ >= -5 && $_ <= 3, 'get_random_value() standalone usage on integer'
        for $row->get_random_value('number4');

    ok !defined($row->string4), 'random_columns yet not populated';

    $row->insert;

    like $row->id, qr/^[\da-z]{20}$/, 'random string with full field length';
    is $row->number1, 4711, 'stay away from defined numbers';
    is $row->string1, 'foo', 'stay away from defined strings';
    like $row->number2, qr/^-?\d+$/, 'random integer';
    like $row->number3, qr/^\d+$/, 'positive random integer';
    ok $row->number4 >= -5 && $row->number4 <= 3,
        'random integer between -5 and +3';
    like $row->string3, qr/^\d{3}$/,
        'random string with custom character set and length';
    like $row->string4, qr/^[\da-z]{32}$/,
        'random string with full field length';

    $row = $rs->create({string5 => $table});

    like $row->string1, qr/^[\da-z]{32}$/,
        'another random string with full field length';
}
