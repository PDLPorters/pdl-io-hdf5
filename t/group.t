use PDL::HDF5;
use PDL::HDF5::Group;



print "1..1\n";  

my $testNo = 1;

# New File Check:
my $filename = "newFile.hd5";
# get rid of filename if it already exists
unlink $filename if( -e $filename);

my $hdfobj;
ok($testNo++,$hdfobj = new PDL::HDF5("newFile.hd5"));

my $group = new PDL::HDF5::Group( 'name'=> '/dude', filename => "newFile.hd5",
					fileID => $hdfobj->{fileID});
print "completed\n";


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
