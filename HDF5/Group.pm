package PDL::HDF5::Group;

use Carp;

=head1 NAME

PDL::HDF5::Group - PDL::HDF5 Helper Object representing HDF5 groups.

=head1 DESCRIPTION

This is a helper-object used by PDL::HDF5 to interface with HDF5 format's group objects.
Information on the HDF5 Format can be found
at the NCSA's web site at http://hdf.ncsa.uiuc.edu/ .

=head1 SYNOPSIS

See L<PDL::HDF5>

=head1 MEMBER DATA

=over 1

=item groupID

ID number given to the group by the HDF5 library

=item groupname

Name of the group. (Absolute to the root group '/'. e.g. /maingroup/subgroup)

=item fileID

fileID of the HDF file that owns this group.

=item filename

filename of the HDF file that owns this group

=back

=head1 METHODS

####---------------------------------------------------------

=head2 new

=for ref

PDL::HDF5::Group Constructor - creates new object

B<Usage:>

=for usage

This object will usually be created using the calling format detailed in the L<SYNOPSIS>. The 
following syntax is used by the L<PDL::HDF5> object to build the object.
   
   $a = new PDL::HDF5:Group( name => $name, filename => $filename, fileID => $fileID );
	Args:
	$name				Name of the group
	$filename			Filename that owns this group
	$fileID				FileID of the file that owns this group

=cut

sub new{

	my $type = shift;
	my %parms = @_;
	my $self = {};

	my @DataMembers = qw( name filename fileID );
	my %DataMembers;
	@DataMembers{ @DataMembers } = @DataMembers; # hash for quick lookup
	# check for proper supplied names:
	my $varName;
	foreach $varName(keys %parms){
 		unless( defined($DataMembers{$varName})){
			carp("Error Calling ".__PACKAGE__." Constuctor\n  \'$varName\' not a valid data member\n"); 
			return undef;
		}
 		unless( defined($parms{$varName})){
			carp("Error Calling ".__PACKAGE__." Constuctor\n  \'$varName\' not supplied\n"); 
			return undef;
		}
		$self->{$varName} = $parms{$varName};
	}
	
	my $fileID = $self->{fileID};
	my $filename = $self->{filename};
	my $name = $self->{name};
	
	# Turn Error Reporting off for the following, so H5 lib doesn't complain
	#  if the group isn't found.
	PDL::HDF5::H5errorOff();
	my $rc = PDL::HDF5::H5Gget_objinfo($fileID, $name,1,0);
	PDL::HDF5::H5errorOn();
	# See if the group exists:
	if(  $rc >= 0){ 
		#Group Exists open it:
		my $groupID = PDL::HDF5::H5Gopen($fileID, $name);
	}
	else{  # group didn't exist, create it:
		$groupID = PDL::HDF5::H5Gcreate($fileID, $name, 0);
	}
	# Try Opening the Group First (Assume it already exists)

	if($groupID < 0 ){
		carp "Error Calling ".__PACKAGE__." Constuctor: Can't open or create group '$name'\n";
		return undef;
	}
		
	
	$self->{groupID} = $groupID;

	bless $self, $type;

	return $self;
}	

=head2 DESTROY

=for ref

PDL::HDF5 Desctructor - Closes the HDF5 file

B<Usage:>

=for usage

   No Usage. Automatically called
   
    
=cut


sub DESTROY {
  my $self = shift;

  if( H5Gclose($self->{groupID}) < 0){
	warn("Error closing HDF5 Group '".$self->{name}."' in file '".$self->{filename}."'\n");
  }

}


1;

