use strict;
use warnings;
use utf8;
use locale;
use Encode qw/encode decode/;
use FindBin;
use String::Trigram qw/compare/;
use open IO => qw/:encoding(UTF-8)/;
use Math::Round;
use Data::Dumper;
use XML::Twig;


# Local time settings
my $times = time();
my ($sec, $min, $hour, $mday, $month, $year, $wday, $stime) = localtime($times);
$month++;
my $datetime = sprintf '%04d%02d%02d%02d%02d%02d', $year + 1900, $month, $mday, $hour, $min, $sec;

my $script_dir = $FindBin::Bin;

# Result file
open( my $out, ">", "result_$datetime.tsv" ) or die "$!:result_$datetime.tsv";

# TM
print "TM(TMX): ";
chomp(my $tm_dir = <STDIN>);
$tm_dir =~ s/^"//;
$tm_dir =~ s/"$//;

# Trans source
print "Trans source(TMX): ";
chomp(my $transSource_dir = <STDIN>);
$transSource_dir =~ s/^"//;
$transSource_dir =~ s/"$//;

# Get en-US segment text from TM tmx
chdir $tm_dir;
my @tm;
while (<*.tmx>){
	my $file = $_;
	chomp $file;
	my $twig = new XML::Twig( TwigRoots => {
							'//tuv[@xml:lang="en-US"]/seg' => \&tmxExtructText, 
						});
	
	$twig->parsefile( $file );
}

# Get en-US segment text from Trans source tmx
chdir $transSource_dir;
my @trans;
while (<*.tmx>){
	my $file = $_;
	chomp $file;
	my $twig = new XML::Twig( TwigRoots => {
							'//tuv[@xml:lang="en-US"]/seg' => \&tmxExtructText2, 
						});
	
	$twig->parsefile( $file );
}

chdir $script_dir;

# Similarity calculation
foreach my $trans_str ( @trans ){
	my $max = 0;
	my $trans_str_max;

	foreach my $tm_str ( @tm ){
		my $sim = compare($trans_str,
		                  $tm_str,
		                  minSim         => 0,
		                  warp           => 1.3,
		                  ignoreCase     => 0,
		                  keepOnlyAlNums => 0,
		                  ngram          => 3,
		                  debug          => 0);
		
		$sim = percentGen( $sim );

		if ($sim > $max){
			$max = $sim;
			$trans_str_max = $trans_str;
		}
	}

	print $trans_str_max . "\t" . $max . "\n";
	print {$out} $trans_str_max . "\t" . $max . "\n";
}

close($out);

print "\nDone!\n";


sub percentGen{
	my ( $sim ) = shift;
	$sim = $sim * 100;         # Percentage
	$sim = nearest(0.1, $sim); # Round off
	$sim = round($sim);        # Decimal point truncation

	return $sim;
}

sub tmxExtructText{
	my( $tree, $elem ) = @_;
	#my $text = $elem->text;
	my $text = $elem->toString;
	$text =~ s|^<seg>||;
	$text =~ s|</seg>$||;
	print $text ."\n";
	push (@tm, $text);
	
	{
	local *STDOUT;
	local *STDERR;
  	open STDOUT, '>', undef;
  	open STDERR, '>', undef;
	$tree->flush_up_to( $elem ); #Memory clear
	}
}

sub tmxExtructText2{
	my( $tree, $elem ) = @_;
	#my $text = $elem->text;
	my $text = $elem->toString;
	$text =~ s|^<seg>||;
	$text =~ s|</seg>$||;
	print $text ."\n";
	push (@trans, $text);
	
	{
	local *STDOUT;
	local *STDERR;
  	open STDOUT, '>', undef;
  	open STDERR, '>', undef;
	$tree->flush_up_to( $elem ); #Memory clear
	}
}

