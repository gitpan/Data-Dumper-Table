package Data::Dumper::Table;

use 5.018;
use utf8;
no diagnostics;

use Scalar::Util qw( reftype refaddr blessed );
use Text::Table;

use Exporter qw( import );
our @EXPORT = qw( Tabulate );

our $VERSION = 0.006;

our %seen;

sub Tabulate ($) {
    my ($thing) = @_;
    my $run = \do { my $o };
    $run = refaddr($run);
    $seen{ $run } = { };
    my $rv = _tblize($thing, $run);
    delete $seen{ $run };
    return $rv;
}

sub _tblize {
    my ($thing, $run) = @_;
    return '(* undef *)' unless defined $thing;
    my $r = reftype($thing);
    my $addr = lc sprintf('%x', refaddr($thing));
    my $alias
        = defined $thing
            ? ($r ? ($r . '(0x' . $addr . ')') : '( scalar )')
            : '(* undef *)'
            ;
    if (my $b = blessed($thing)) {
        $alias = $b . '=' . $alias unless $b eq 'Regexp';
    }
    if ($alias ne '( scalar )' and $seen{ $run }->{ $alias }++) {
        return 'CIRCULAR->' . $alias;
    }
    my $container = Text::Table->new(($alias)x!($alias eq '( scalar )'));
    my $inner = $thing;
    my $snidge = '+';
    if ($r eq 'ARRAY') {
        my %header;
        my @v = grep {
            ref($_) eq 'HASH' ?
            do {
                for my $k (keys %$_) {
                    undef $header{ $k };
                }
                1;
            } : undef
        } @$thing;
        if (@v == @$thing) {
            my @head = map { \' | ', $_ } sort keys %header;
            shift @head;
            unshift @head, \' ';
            push @head, \' ';
            $inner = Text::Table->new(@head);
            for my $row (@$thing) {
                my @body;
                for my $k (grep { !ref $_ } @head) {
                    push @body, (exists($row->{ $k }) ? _tblize($row->{ $k }, $run) : '(* no data *)');
                }
                $inner->add(@body);
            }
        }
        else {
            $inner = Text::Table->new();
            my $n = 0;
            my $index = "$alias [" . $n++ . "]";
            for my $row (@$thing) {
                $inner->add($index, _tblize($row, $run));
                $index = (' ' x (2 + length($alias) - length($n))) . '[' . $n++ . ']';
            }
            return $inner;
        }
    }
    elsif ($r eq 'HASH') {
        my @keys = sort keys %$thing;
        $inner = Text::Table->new();
        for my $k (@keys) {
            $inner->add($k, '=>', _tblize($thing->{ $k }, $run));
            $snidge = '-';
        }
    }
    elsif ($r eq 'CODE') {
        $inner = 'sub DUMMY { }'; # TODO for now
    }
    elsif (uc $r eq 'REGEXP') {
        return "qr/$thing/";
    }
    elsif ($r) {
        $inner = 'REF->' . _tblize($$thing, $run); # TODO for now
    }
    else {
        $inner = "`$inner'";
    }
    if (ref $inner) {
        $container->add($inner->title . $inner->rule('-', $snidge) . $inner->body);
        return $container->title . $container->body;
    }
    $container->add($inner);
    return $container->title . $container->body;
}

1;

__END__

=head1 NAME

Data::Dumper::Table - A more tabular way to Dumper your Data

=head1 VERSION

Version 0.006

=head1 SYNOPSIS

    use Data::Dumper::Table;

    say Tabulate $some_crazy_data_structure;

=head1 DESCRIPTION

The goal of Data::Dumper::Table is to provide a more-tabular alternative to Data::Dumper.

=head1 EXPORTED FUNCTIONS

=head2 Tabulate DATA

Turn the provided DATA into a (hopefully) nicely-formatted table. More verbose and space-hungry than Data::Dumer, but possibly easier to envision.

=head1 CAVEATS

=head2 This is Alpha software

This module is explicitly alpha-quality software. If you successfully use it in production, you're a braver being than I am.

=head1 TODO

=head2 Sortkeys

Replicate $Data::Dumper::Sortkeys

=head2 Deparse

Replicate $Data::Dumper::Deparse

=cut

