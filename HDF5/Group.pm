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

=item groupName

Name of the group. (Absolute to the root group '/'. e.g. /maingroup/subgroup)

=item parentID

ID (fileID or groupID) of the HDF file/group that owns this group.

=item parentName

Name of the HDF file or group that owns this group

=item fileObj

Ref to the L<PDL::HDF5> object that owns this object.

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
   
   $a = new PDL::HDF5:Group( groupName => $name, parentName => $parentName,
   			     parentID => $parentID, fileObj => $fileObj );
	Args:
	$name				Name of the group (relative to the parent)
	$parentName			Filename that owns this group
	$parentID			FileID of the file that owns this group
	$fileObj                        PDL::HDF object that owns this group.

=cut

sub new{

	my $type = shift;
	my %parms = @_;
	my $self = {};

	my @DataMembers = qw( groupName parentName parentID fileObj);
	my %DataMembers;
	@DataMembers{ @DataMembers } = @DataMembers; # hash for quick lookup
	# check for proper supplied names:
	my $varName;
	foreach $varName(keys %parms){
 		unless( defined($DataMembers{$varName})){
			carp("Error Calling ".__PACKAGE__." Constuctor\n  \'$varName\' not a valid data member\n"); 
			return undef;
		}
		$self->{$varName} = $parms{$varName};
	}
	
	my $parentID = $self->{parentID};
	my $parentName = $self->{parentName};
	my $groupName = $self->{groupName};
	my $groupID;
	
	# Adjust groupname to be absolute:
	$self->{groupName} = "$parentName/$groupName";
	

	# Turn Error Reporting off for the following, so H5 lib doesn't complain
	#  if the group isn't found.
	PDL::HDF5::H5errorOff();
	my $rc = PDL::HDF5::H5Gget_objinfo($parentID, $groupName,1,0);
	PDL::HDF5::H5errorOn();
	# See if the group exists:
	if(  $rc >= 0){ 
		#Group Exists open it:
		$groupID = PDL::HDF5::H5Gopen($parentID, $groupName);
	}
	else{  # group didn't exist, create it:
		$groupID = PDL::HDF5::H5Gcreate($parentID, $groupName, 0);
		# Clear-out the attribute index, it is no longer valid with the updates
		#  we just made.
		$self->{fileObj}->clearAttrIndex;

	}
	# Try Opening the Group First (Assume it already exists)

	if($groupID < 0 ){
		carp "Error Calling ".__PACKAGE__." Constuctor: Can't open or create group '$groupName'\n";
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
  print "In Group DEstroy\n";
  if( PDL::HDF5::H5Gclose($self->{groupID}) < 0){
	warn("Error closing HDF5 Group '".$self->{name}."' in file '".$self->{parentName}."'\n");
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
		PDL::HDF5::H5Tset_size($typeID, length($value) || 1 ); # make legth of type eaual to length of $value or 1 if zero
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
	# Clear-out the attribute index, it is no longer valid with the updates
	#  we just made.
	$self->{fileObj}->clearAttrIndex;
	
	return 1;
  
}


=head2 attrGet

=for ref

Get the value of an attribute(s)

Currently the only attribute types supported are null-terminated strings.

B<Usage:>

=for usage

   my @attrs = $group->attrGet( 'attr1', 'attr2');


=cut

sub attrGet {
	my $self = shift;

	my @attrs = @_; # get atribute array
	
	my $groupID = $self->{groupID};
	
	my($attrName,$attrValue);

	my @attrValues; #return array
	
	my $typeID; # id used for attribute
	my $dataspaceID; # id used for the attribute dataspace
	
	my $attrID;
	foreach $attrName( @attrs){
		
		$attrValue = undef;
		
		# Open the Attribute
		$attrID = PDL::HDF5::H5Aopen_name($groupID, $attrName );
		unless( $attrID >= 0){
			carp "Error Calling ".__PACKAGE__."::attrget: Can't open HDF5 Attribute name '$attrName'.\n";
			next;
		}			
		 
		# Open the data-space
		$dataspaceID = PDL::HDF5::H5Aget_space($attrID);
		if( $dataspaceID < 0 ){
			carp("Can't Open Dataspace for Attribute name '$attrName' in  ".__PACKAGE__."::attrget\n");
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}

		# Check to see if the dataspace is simple
		if( PDL::HDF5::H5Sis_simple($dataspaceID) < 0 ){
			carp("Warning: Non-Simple Dataspace for Attribute name '$attrName' ".__PACKAGE__."::attrget\n");
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}


		# Get the number of dims:
		my $Ndims = PDL::HDF5::H5Sget_simple_extent_ndims($dataspaceID);
		unless( $Ndims == 0){
			if( $Ndims < 0 ){
				carp("Warning: Can't Get Number of Dims in Attribute name '$attrName' Dataspace in ".__PACKAGE__.":get\n");
			}
			if( $Ndims > 0 ){
				carp("Warning: Non-Scalar Dataspace for Attribute name '$attrName' Dataspace in ".__PACKAGE__.":get\n");
			}			
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}


		# Get the HDF5 dataset datatype;
        	my $HDF5type = PDL::HDF5::H5Aget_type($attrID );
		unless( $HDF5type >= 0 ){
			carp "Error Calling ".__PACKAGE__."::attrGet: Can't get HDF5 Dataset type in Attribute name '$attrName'.\n";
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}
		
		# Get the size so we can allocate space for it
		my $size = PDL::HDF5::H5Tget_size($HDF5type);
		unless( $size){
			carp "Error Calling ".__PACKAGE__."::attrGet: Can't get HDF5 Dataset type size in Attribute name '$attrName'.\n";
			carp("Can't close Datatype in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}
		
		#init attr value to the length of the type
		$attrValue = ' ' x ($size);
		
		if( PDL::HDF5::H5Aread($attrID, $HDF5type, $attrValue) < 0 ){
			carp "Error Calling ".__PACKAGE__."::attrGet: Can't read Attribute Value for Attribute name '$attrName'.\n";
			carp("Can't close Datatype in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
			carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
			carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);
			next;
		}			



		# Cleanup
		carp("Can't close Datatype in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Tclose($HDF5type) < 0);
		carp("Can't close DataSpace in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Sclose($dataspaceID) < 0);
		carp("Can't close Attribute in ".__PACKAGE__.":attrGet\n") if( PDL::HDF5::H5Aclose($attrID) < 0);


	}
	continue{
		
		push @attrValues, $attrValue;
	}

	return @attrValues;

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
	# Clear-out the attribute index, it is no longer valid with the updates
	#  we just made.
	$self->{fileObj}->clearAttrIndex;
	
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


=head2 dataset

=for ref

Open an existing or create a new dataset in a group.

B<Usage:>

=for usage

   $dataset = $group->dataset('newdataset');

Returns undef on failure, 1 on success.

=cut

sub dataset {
	my $self = shift;

	my $name = $_[0];

	my $groupID = $self->{groupID}; # get the group name of the current group
	my $groupName = $self->{groupName};
	
	my $dataset = PDL::HDF5::Dataset->new( name=> $name, groupName => $groupName,
					groupID => $groupID, fileObj => $self->{fileObj} );

}



=head2 datasets

=for ref

Get a list of all dataset names in a group. (Relative to the current group)


B<Usage:>

=for usage

   @datasets = $group->datasets;


=cut

sub datasets {
	my $self = shift;

	my $groupID = $self->{groupID};
	
	my @totalDatasets = PDL::HDF5::H5GgetDatasetNames($groupID,".");
	
		
	
	return @totalDatasets;
  
}

=head2 group

=for ref

Open an existing or create a new group in an existing group.

B<Usage:>

=for usage

   $newgroup = $oldgroup->group("newgroup");

Returns undef on failure, 1 on success.

=cut

sub group {
	my $self = shift;

	my $name = $_[0]; # get the group name
	
	my $parentID = $self->{groupID}; # get the group name of the current group
	my $parentName = $self->{groupName};
	
	my $group =  new PDL::HDF5::Group( groupName=> $name, parentName => $parentName,
					parentID => $parentID, fileObj => $self->{fileObj}  );
					

	return $group;

}




=head2 groups

=for ref

Get a list of all group names in a group. (Relative to the current group)


B<Usage:>

=for usage

   @groupNames = $group->groups;


=cut

sub groups {
	my $self = shift;

	my $groupID = $self->{groupID};
	
	my @totalgroups = PDL::HDF5::H5GgetGroupNames($groupID,'.');
	
		
	
	return @totalgroups;
  
}



=head2 groupName

=for ref

Get the name of the group (absolute to the root group)


B<Usage:>

=for usage

   print $group->groupName;


=cut

sub groupName {
	my $self = shift;

	
	return $self->{groupName};
  
}

=head2 _buildAttrIndex

=for ref

Internal Recursive Method to build the attribute index hash
for the object

For the purposes of indexing groups by their attributes, the attributes are 
applied hierarchial. i.e. any attributes of the higher level groups are assumed to be 
apply for the lower level groups.


B<Usage:>

=for usage

   $group->_buildAttrIndex($index, $currentAttrs);

    
 Input/Output:

         $index:        Total Index hash ref
	 $currentAttrs: Hash refs of the attributes valid 
	                for the current group.
	                


=cut

sub _buildAttrIndex{

	my ($self, $index, $currentAttrs) = @_;
	
	# Take care of any attributes in the current group
	my @attrs = $self->attrs;
	
	my @attrValues = $self->attrGet(@attrs);
	
	# Get the group name
	my $groupName = $self->groupName;
	
	my %indexElement; # element of the index for this group
	
	%indexElement = %$currentAttrs; # Initialize index element
				        # with attributes valid at the 
					# group above
					
	# Add (or overwrite) attributes for this group
	#    i.e. local group attributes take precedence over
	#         higher-level attributes
	@indexElement{@attrs} = @attrValues;
	
	$index->{$groupName} = \%indexElement;
	
	 
	# Now Do any subgroups: 
	my @subGroups = $self->groups;
	my $subGroup;
	
	foreach $subGroup(@subGroups){
		$self->group($subGroup)->_buildAttrIndex($index,\%indexElement);
	}
	
}



1;

