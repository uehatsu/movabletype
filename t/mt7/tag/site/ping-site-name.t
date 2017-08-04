#!/usr/bin/perl

use strict;
use warnings;

use lib qw(lib t/lib);

BEGIN {
    $ENV{MT_CONFIG} = 'mysql-test.cfg';
}

use MT::Test::Tag;

plan tests => 2 * blocks;

use MT;
use MT::Test qw(:db :data);
use MT::Test::Permission;

filters {
    blog_id  => [qw( chomp )],
    template => [qw( chomp )],
    expected => [qw( chomp )],
    error    => [qw( chomp )],
};

MT::Test::Tag->run_perl_tests;
MT::Test::Tag->run_php_tests;

__END__

=== mt:PingSiteName - blog
--- blog_id
1
--- template
<mt:Pings lastn="1"><mt:PingSiteName></mt:Pings>
--- expected
Example Blog

=== mt:PingSiteName - website
--- blog_id
2
--- template
<mt:Pings lastn="1"><mt:PingSiteName></mt:Pings>
--- expected


