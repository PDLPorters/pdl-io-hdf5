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
	my $groupID;

	# Turn Error Reporting off for the following, so H5 lib doesn't complain
	#  if the group isn't found.
	PDL::HDF5::H5errorOff();
	my $rc = PDL::HDF5::H5Gget_objinfo($fileID, $name,1,0);
	PDL::HDF5::H5errorOn();
	# See if the group exists:
	if(  $rc >= 0){ 
		#Group Exists open it:
		$groupID = PDL::HDF5::H5Gopen($fileID, $name);
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

PDL::HDF5 Destructor - Closes the HDF5::Group Object.

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

=head2 attrSet

=for ref

Set the value of an attribute(s)

Currently the only attribute types supported are null-terminated strings.

B<Usage:>

=for usage

   $group->attrSet( 'attr1' => 'attr1Value',
   		    'attr2' => 'attr2 value', 
		    .
		    .
		    .
		   );

Returns undef on failure, 1 on success.

=cut

sub attrSet {
	my $self = shift;

	my %attrs = @_; # get atribute hash
	
	my $groupID = $self->{groupID};
	
	my($key,$value);

	my $typeID; # id used for attribute
	my $dataspaceID; # id used for the attribute dataspace
	
	my $attrID;
	foreach $key( sort keys %attrs){
		
		$value = $attrs{$key};
		
		# Create Null-Terminated String Type 
		$typeID = PDL::HDF5::H5Tcopy(PDL::HDF5::H5T_C_S1());
		PDL::HDF5::H5Tset_size($typeID, length($value)); # make legth of type eaual to length of $value
		$dataspaceID = PDL::HDF5::H5Screate_simple(0, 0, 0);

		#Note: If a attr already exists, then it will be deleted an re-written
		# Delete the attribute first
		PDL::HDF5::H5errorOff();  # keep h5 lib from complaining
		PDL::HDF5::H5Adelete($groupID, $key);
		PDL::HDF5::H5errorOn();

		
		$attrID = PDL::HDF5::H5Acreate($groupID, $key, $typeID, $dataspaceID, PDL::HDF5::H5P_DEFAULT());

		if($attrID < 0 ){
			carp "Error in ".__PACKAGE__." attrSet; Can't create attribute '$key'\n";

			PDL::HDF5::H5Sclose($dataspaceID);
			PDL::HDF5::H5Tclose($typeID); # Cleanup
			return undef;
		}
		
		# Write the attribute data.
		if( PDL::HDF5::H5Awrite($attrID, $typeID, $value) < 0){
			carp "Error in ".__PACKAGE__." attrSet; Can't write attribute '$key'\n";
			PDL::HDF5::H5Aclose($attrID);
			PDL::HDF5::H5Sclose($dataspaceID);
			PDL::HDF5::H5Tclose($typeID); # Cleanup
			return undef;
		}
		
		# Cleanup
		PDL::HDF5::H5Aclose($attrID);
		PDL::HDF5::H5Sclose($dataspaceID);
		PDL::HDF5::H5Tclose($typeID);

			
	}
	
	return 1;
  
}

=head2 attrDel

=for ref

Delete attribute(s)

B<Usage:>

=for usage

   $group->attrDel( 'attr1', 
      		    'attr2',
		    .
		    .
		    .
		   );

Returns undef on failure, 1 on success.

=cut

sub attrDel {
	my $self = shift;

	my @attrs = @_; # get atribute names
	
	my $groupID = $self->{groupID};
	
	my $attr;
	my $rc; #Return code returned by H5Adelete
	foreach $attr( @attrs ){
		

		# Note: We don't consider errors here as cause for aborting, we just
		#  complain using carp
		if( PDL::HDF5::H5Adelete($groupID, $attr) < 0){
			carp "Error in ".__PACKAGE__." attrDel; Error Deleting attribute '$attr'\n";
		}
		
	}
	
	return 1;
  
}


=head2 attrs

=for ref

Get a list of all attribute names in a group


B<Usage:>

=for usage

   @attrs = $group->attrs;


=cut

sub attrs {
	my $self = shift;

	my $groupID = $self->{groupID};
	
	my $defaultMaxSize = 256; # default max size of a attribute name

	my $noAttr = PDL::HDF5::H5Aget_num_attrs($groupID); # get the number of attributes

	my $attrIndex = 0; # attribute Index

	my @attrNames = ();
	my $attributeID;
	my $attrNameSize; # size of the attribute name
	my $attrName;     # attribute name

	# Go thru each attribute and get the name
	for( $attrIndex = 0; $attrIndex < $noAttr; $attrIndex++){

		$attributeID = PDL::HDF5::H5Aopen_idx($groupID, $attrIndex );

		if( $attributeID < 0){
			carp "Error in ".__PACKAGE__." attrs; Error Opening attribute number $attrIndex\n";
			next;
		}

	      	#init attrname to 256 length string (Maybe this not necessary with
		#  the typemap)
		$attrName = ' ' x 256;
		
		# Get the name
		$attrNameSize = PDL::HDF5::H5Aget_name($attributeID, 256, $attrName ); 

		# If the name is greater than 256, try again with the proper size:
		if( $attrNameSize > 256 ){
			$attrName = ' ' x $attrNameSize;
			$attrNameSize = PDL::HDF5::H5Aget_name($attributeID, $attrNameSize, $attrName ); 

		}

		push @attrNames, $attrName;

		# Close the attr:
		PDL::HDF5::H5Aclose($attributeID);
	}


	
	return @attrNames;
  
}

=head2 datasets

=for ref

Get a list of all dataset names in a group


B<Usage:>

=for usage

   @datasets = $group->datasets;


=cut

sub datasets {
	my $self = shift;

	my $groupID = $self->{groupID};
	

	my $groupName = $self->{name};
	
	my @totalDatasets = PDL::HDF5::H5GgetDatasetNames($groupID,$groupName);
	
		
	
	return @totalDatasets;
  
}


1;

