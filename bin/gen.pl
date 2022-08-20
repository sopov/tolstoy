#!perl

use strict;
use warnings;
use autodie;
use FindBin qw($Bin);
use utf8;
use open ':encoding(UTF-8)';
use File::Slurp;

my $ch = repl();

my $IN  = "$Bin/../source";
my $OUT = "$Bin/../site";
my $re  = sprintf '(?:%s)', join q{|}, map {quotemeta} keys %{$ch};

convert();
unionmd();

sub convert {
    opendir my ($dh), $IN;
    my @files = grep { -f "$IN/$_" && /[.]md$/ } readdir $dh;
    closedir $dh;
    foreach my $f ( sort @files ) {
        print "$f\n";
        convert_file($f);
    }
}

sub convert_file {
    my $file = shift;
    my $data = read_file "$IN/$file", { binmode => ':utf8' };
    $data =~ s/(?<![:])($re)/$ch->{$1}/eg;
    write_file "$OUT/$file", { binmode => ':utf8' }, fix_md($data);
}

sub unionmd() {
    my $links = links();

    opendir my ($dh), $OUT;
    my @files = grep { -f "$OUT/$_" && /^\d\d\d-.*[.]md$/ } readdir $dh;
    closedir $dh;
    my $u = {};
    foreach my $f ( sort @files ) {
        if ( $f =~ /(\d+)-(\S+)/ ) {
            next if $1 < 10;
            $u->{$2}->{$1} = $f;
        }
    }

    foreach my $f ( sort keys %{$u} ) {
        ( my $url = $f ) =~ s/[.]md//;
        my $title = $links->{$f};
        my $data  = q{};
        my $pages = 0;
        my $empty = 0;
        foreach my $n ( sort { $a <=> $b } keys %{ $u->{$f} } ) {
            $pages++;
            my $fn = join q{/}, $OUT, $u->{$f}->{$n};
            my $d = read_file $fn, { binmode => ':utf8' };
            $empty++ if $d !~ /a name/;
            $data .= $d;
            unlink $fn;
        }
        my $total = () = $data =~ /(a name)/g;
        my $finish = ($pages-$empty)/$pages;
        my $await = $finish > 0 ? $total/$finish - $total: $pages * 90;
        
        $data = sprintf q{---
layout: page
title: %s
permalink: /%s/
---
> %d слов (%s%.02f%% завершено, ещё ~ %d слов)

%s
}, $title, $url, $total, ($empty > 0 ? q{~} : q{}), 100*$finish, $await, $data;
        write_file "$OUT/$f", { binmode => ':utf8' }, $data;
    }
}


sub fix_md {
    my $text = shift;
    for ($text) {
        s{(permalink:\s+)/source}{$1}g;
       s/\((.+?[.]md)\)/fix_md_link($1)/eg;
       s{\s+#([a-z]\S+)\s*}{ <a name="$1"></a>}gi;
    }
    return $text;
}

sub fix_md_link {
    my $orig = shift;
    $orig =~ s/^\d+-//;
    $orig =~ s/[.]md$//;
    $orig =~ s{-rs$}{/rs};
    return sprintf '(/%s/)', $orig;
}
sub links {
    my $res = {};
    open my $fh, qw{<}, "$IN/004-abc.md";
    while (<$fh>) {
        if (/\[(.+?)\]\((.+?)\)/) {
            $res->{$2} = $1;
        }
    }
    close $fh;
    return $res;
}

sub repl {
    open my $fh, qw{<}, "$Bin/chars.md";
    my $res = {};
    while (<$fh>) {
        if (/(\S+)\s+(\S+)/) {
            my ( $c, $v ) = ( $1, chr hex $2 );
            if ( length $c > 1 ) {
                $res->{$c} = $v;
            }
            my $cc = sprintf '[%s]', $c;
            $res->{$cc} = $v;
        }
    }
    close $fh;
    return $res;
}
