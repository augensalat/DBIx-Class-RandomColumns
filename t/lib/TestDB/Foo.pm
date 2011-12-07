package TestDB::Foo;

use strict;
use warnings;

use parent 'DBIx::Class::Core';

__PACKAGE__->load_components('RandomColumns');

__PACKAGE__->table('foo');

__PACKAGE__->add_columns(
    id => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 20,
    },
    string1 => {
        data_type => 'text',
        is_nullable => 0,
        size => 32,
    },
    number1 => {
        data_type => 'int',
        is_nullable => 0,
        size => 10,
        extra => {unsigned => 1},
    },
    number2 => {
        data_type => 'int',
        is_nullable => 0,
        size => 10,
    },
    number3 => {
        data_type => 'int',
        is_nullable => 0,
        size => 5,
    },
    number4 => {
        data_type => 'int',
        is_nullable => 0,
        size => 5,
        extra => {unsigned => 1},
    },
    string3 => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 10,
    },
    string4 => {
        data_type => 'varchar',
        is_nullable => 0,
        size => 32,
    },
    string5 => {
        data_type => 'varchar',
        is_nullable => 1,
        size => 32,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->add_unique_constraint(['string5']);

__PACKAGE__->random_columns(
    'id',
    'string1',
    'number1' => {max => 2**31-1},
    'number2' => {min => -2**31, max => 2**31-1},
    'number3',
    'number4' => {min => -5, max => 3},
    'string3' => {size => 3, set => [0..9], check => 1},
    'string4',
);

1;
