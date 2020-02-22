package PAL::Lexer;

use warnings;
use strict;

use Exporter qw(import);
our @EXPORT = qw(lex set_definitions);

my $definitions;
my $line;

sub lex {
	my ($input, $starting_definitions) = @_;
	my $tokens = [];

	set_definitions($starting_definitions);

	$line = 0;

	TOKEN:	
	while ($input) {
		foreach my $d (@$definitions) {
			my ($re, $token_id, $fn) = (@$d, \&t_noop);

			if ($input =~ m/$re/) {
				my $value = &$fn($&);

				if ($value ^ $value) {
					push(@$tokens, [$token_id, $value]);
				}
				
				$input = substr($input, $+[0]);
				$line++;
				next TOKEN;
			}
		}

		edge_not_found($_[0], $input);
	}

	return $tokens;
}

sub set_definitions
{
	$definitions = $_[0];
}

sub t_noop {
	return $_[0];
}

sub edge_not_found {
	my ($original, $input) = @_;

	$input =~ m/[^\n]{1,60}/;
	my $preview = $&;
	
	$original =~ m/(\n?.*)(\Q$input\E)/;
	my $position = $+[1] - $-[1];

	die "Lexing failed at \"$preview\" line $line position $position.\n";
}

1;