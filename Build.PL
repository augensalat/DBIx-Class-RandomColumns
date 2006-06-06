#!/usr/bin/perl
use warnings;
use strict;

use Module::Build;

Module::Build->new(
    module_name => 'DBIx::Class::RandomColumns',
    author => 'Bernhard Graf <perl-dbic-randomcolumns@movingtarget.de>',
    license => 'perl',
    requires => {
	'DBIx::Class' => 0.06,
    },
    build_requires => {
	'Test::More' => 0,
	'File::Temp' => 0,
    },
    recommends => {
	'DBD::SQLite' => 1.11,
    },
    create_makefile_pl => 'traditional',
)->create_build_script;
