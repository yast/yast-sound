#!/usr/bin/perl

#
# Mark texts to tanslation in the yast sound card database.
#
# Usage: ./translate_strings.pl translated_strings proofread_strings sndcards.ycp
#

#use Data::Dumper;

# text mapping: 'original text' => 'replacement'
my %db;

my $traslated_strings = $ARGV[0];
my $proofread_strings = $ARGV[1];
my $input_file = $ARGV[2];

# read translatable strings 
open(DB, "<$traslated_strings");

while (my $line = <DB>) 
{
    chomp($line);
    
    if ($line ne "")
    {
	# replacement is the original text -> no change
	$db{$line} = $line;
    }
}

close(DB);

# read proofread strings 
open(DB2, "<$proofread_strings");

while (my $line = <DB2>) 
{
    chomp($line);
    
    if ($line =~ /^[ \t]*"(.*)"[ \t]*"(.*)"/)
    {
	# replacement is the proofread texts
	$db{$1} = $2;
    }
}

close(DB2);


# read input file
open(INPUT, "<$input_file");

while (my $inp = <INPUT>) 
{
    # change the line if a replacement is found
    if ($inp =~ /^(.*)"(.*)"(.*)/)
    {
	my $traslated = $db{$2};

	if ($traslated)
	{
	    print "$1_(\"$traslated\")$3\n";
	}
	else
	{
	    print $inp;
	}
    }
    else
    {
	print $inp;
    }
}

close(INPUT);

