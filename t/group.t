use PDL;
use PDL::HDF5;
use PDL::HDF5::Group;
use PDL::HDF5::Dataset;

# Script to test the group/dataset object separately.
#  i.e. not the way they would normally be used as described
#  in the PDL::HDF5 synopsis

print "1..10\n";  

my $testNo = 1;

# New File Check:
my $filename = "newFile.hd5";
# get rid of filename if it already exists
unlink $filename if( -e $filename);

my $hdfobj;
ok($testNo++,$hdfobj = new PDL::HDF5("newFile.hd5"));

my $group = new PDL::HDF5::Group( 'name'=> '/dude', filename => "newFile.hd5",
					fileID => $hdfobj->{fileID});
					
					
# Set attribute for group
ok($testNo++, $group->attrSet( 'attr1' => 'dudeman', 'attr2' => 'What??'));

# Try Setting attr for an existing attr
ok($testNo++,$group->attrSet( 'attr1' => 'dudeman23'));


# Add a attribute and then delete it
ok($testNo++, $group->attrSet( 'dummyAttr' => 'dummyman', 
				'dummyAttr2' => 'dummyman'));
				
ok($testNo++, $group->attrDel( 'dummyAttr', 'dummyAttr2' ));


# Get list of attributes
my @attrs = $group->attrs;
ok($testNo++, join(",",sort @attrs) eq 'attr1,attr2' );

# Get a list of datasets (should be none)
my @datasets = $group->datasets;

ok($testNo++, scalar(@datasets) == 0 );

# Create another group
my $group2 = new PDL::HDF5::Group( 'name'=> '/dude2', filename => "newFile.hd5",
					fileID => $hdfobj->{fileID});

# open the root group
my $rootGroup = new PDL::HDF5::Group( 'name'=> '/', filename => "newFile.hd5",
					fileID => $hdfobj->{fileID});

# Get a list of groups
my @groups = $rootGroup->groups;

# print "Root group has these groups '".join(",",sort @groups)."'\n";
ok($testNo++, join(",",sort @groups) eq 'dude,dude2' );


# Get a list of groups in group2 (should be none)
@groups = $group2->groups;

ok($testNo++, scalar(@groups) == 0 );


# Create a dataset in the root group
my $dataset = new PDL::HDF5::Dataset( 'name'=> 'data1', groupname => "dude",
					groupID => $group->{groupID});
					
my $pdl = sequence(5,4);


ok($testNo++, $dataset->set($pdl) );
# print "pdl = \n".$pdl."\n";


unlink("newfile.hd5");

print "completed\n";


#  Testing utility functions:
sub ok {
        my $no = shift ;
        my $result = shift ;
        print "not " unless $result ;
        print "ok $no\n" ;
}
