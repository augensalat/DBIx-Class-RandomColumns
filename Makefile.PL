use inc::Module::Install;

name     'DBIx-Class-RandomColumns';
license 'perl';
all_from 'lib/DBIx/Class/RandomColumns.pm';
author   'Bernhard Graf <graf@cpan.org>';

requires 'DBIx::Class' => '0.08009';

test_requires 'Test::More';
test_requires 'Path::Class';
test_requires 'SQL::Translator';

recommends 'DBD::SQLite' => '1.11';

auto_install;

WriteAll;

