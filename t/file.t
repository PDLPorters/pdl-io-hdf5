use PDL::IO::HDF5;


print "1..3\n";  

my $testNo = 1;

# New File Check:
my $filename = "newFile.hd5";
# get rid of filename if it already exists
unlink $filename if( -e $filename);
ok($testNo++,new PDL::IO::HDF5("newFile.hd5"));

#Existing File for Writing Check
ok($testNo++,new PDL::IO::HDF5(">newFile.hd5"));

#Existing File for Reading Check
ok($testNo++,new PDL::IO::HDF5("newFile.hd5"));


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
print "Completed\n";
