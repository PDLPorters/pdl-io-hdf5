
# Test case for reading variable-length string arrays.
#   These are converted to fixed-length PDL::Char types when read

use PDL;
use PDL::Char;
use PDL::IO::HDF5;

print "1..5\n";  

my $testNo = 1;


# New File Check:
my $filename = "varlen.h5";

my $h5obj;
ok($testNo++,$h5obj = new PDL::IO::HDF5($filename));

my $dataset = $h5obj->dataset("Dataset");


my $pdl = $dataset->get();

my @dims = $pdl->dims;

#print "dims = ".join(", ", @dims)."\n";
ok( $testNo++, join(", ", @dims) eq "93, 4");

#print $pdl->atstr(2)."\n";
ok( $testNo++,   $pdl->atstr(2) eq "Now we are engaged in a great civil war,");

# print "PDL::Char = $pdl\n";


###### Now check variable-length string attribute array ###
($pdl) = $dataset->attrGet('Attr1');

@dims = $pdl->dims;

#print "dims = ".join(", ", @dims)."\n";
ok( $testNo++, join(", ", @dims) eq "14, 4");

#print $pdl->atstr(2)."\n";
ok( $testNo++,   $pdl->atstr(2) eq "Attr String 3");


exit;


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
