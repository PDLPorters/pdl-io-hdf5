#!/usr/local/bin/perl -w

package PDL::HDF5::tkview;

# Experimental module to view HDF5 using perl/tk and PDL::HDF5 modules

use Tk 800;
use Tk::Tree;
use IO::File;

=head1 NAME

PDL::HDF5::tkview - View HDF5 files using perl/tk and PDL::HDF5 modules

=head1 DESCRIPTION

This is a experimental object to view HDF5 files the PDL::HDF5 module.
The HDF files are displayed in a tree structure using Tk::Tree

=head1 SYNOPSIS

 use Tk;
 use PDL::HDF5::tkview
 use PDL::HDF5;

 my $mw = MainWindow->new;

 
 my $h5 = new PDL::HDF5('datafile.h5');  # open HDF5 file object

 my $tkview = new PDL::HDF5::tkview( $mw, $h5);
 
 MainLoop;

=head1 MEMBER DATA

=over 1

=item mw

Tk window where the file structure is displayed.

=item H5obj

PDL::HDF5 Object 

=item hl

Tk Hlist object 

=back

=head1 METHODS

####---------------------------------------------------------

=head2 new

=for ref

PDL::HDF5::tkview Constructor - creates new object

B<Usage:>

=for usage

 $tkview = new PDL::HDF5::tkview( $mw, $H5obj);
 
    Where:
	$mw     Tk window 
	$H5obj	PDL::HDF5::Object

=cut

# Cube Image Pixmap (ppm) format. raw data string
$cubeImage = 
'/* XPM */
static char * cube_xpm[] = {
"12 12 3 1",
" 	c #FFFFFFFFFFFF",
".	c #000000000000",
"X	c #FFFFFFFF0000",
"    ........",
"   .XXXXXX..",
"  .XXXXXX.X.",
" ........XX.",
" .XXXXXX.XX.",
" .XXXXXX.XX.",
" .XXXXXX.XX.",
" .XXXXXX.XX.",
" .XXXXXX.X. ",
" .XXXXXX..  ",
" ........   ",
"            "};';
# -----------------------------------------------
#   Routine to create the array_display window
sub new{


	my $type = shift; # get the class type
	my $mw = $_[0];
	my $H5obj = $_[1];
	
	my $self = {};
	
	
	# setup member variables:
	$self->{mw} = $mw;
	$self->{H5obj} = $H5obj;
	
	bless $self, $type;
		
	# setup the window
	if (defined $H5obj){
	
		
		  my $hl = $mw->Scrolled('Tree',-separator => "\01",-drawbranch => 1, -width => '15', -bg => 'white');
		  $hl->configure(-opencmd => [\&More,$self, $hl]); 
		
		  my $name = $H5obj->filename;
		  $hl->add($name, -text => $name, -data => $H5obj, -itemtype => 'imagetext');
		  $hl->setmode($name => 'close');
		  
 		   # Get Images for display
		   $self->{groupImage} = $mw->Pixmap(-file => Tk->findINC('winfolder.xpm') );
		   $self->{cubeImage} = $mw->Pixmap(-data => $cubeImage );
		
		  
		  AddChildren($self,$hl,$name,$H5obj);
		
		  $hl->pack(-expand=> 1, -fill => 'both');

		  $self->{hl} = $hl;
		


	 }
	

	return $self;

}




#  sub to add elements to the hlist after an element in the list has been expanded (i.e. clicked-on)
sub AddChildren
{ 

	 my $self = shift;
	
	 my ($hl,$path,$data) = @_;  # hl list object, location, data
	 my $w;
	 my $name;
	 my $text;
	  
	 if( ref($data) =~ /Group/ || !($path =~ /\01/ ) ){ # Current Item to expand is a group or top level of file
	
       		# Display any Attributes First:
		my @attrs;  # attributes stored
		my %attrs;  

		@attrs = sort $data->attrs;  

		if( @attrs){  # set attribute hash if there are attributes
			@attrs{@attrs} = $data->attrGet(@attrs); # attrget not defined yet
		}
		my ($attr, $attrValue);
		foreach $attr(@attrs){  # add each attribute to the display
			$attrValue = $attrs{$attr};
			$text = "$attr: $attrValue";
			$hl->add("$path\01_Attr$attr",  -text => $text, -data => $attrValue);

		}

		# Display Groups Next

		my @groups;  # groups stored

		@groups = sort $data->groups;  

		my ($group, $groupName);
		foreach $groupName(@groups){  # Add each group to the display

			# data element is the parent object and the group name.
			$hl->add("$path\01_Group$groupName", -image => $self->{groupImage}, -text => $groupName, -data => [ $data,$groupName] );
			$hl->setmode( "$path\01_Group$groupName",  "open");
		}


		# Display Datasets next:
		my @datasets;  # dataset names stored
		@datasets = sort $data->datasets; # get list of datasets in the current group/file

		my ($dataset, @dims);
		foreach $dataset(@datasets){  # add each attribute to the display
			@dims = $data->dataset($dataset)->dims;  # get the dims of the dataset
			$text = "Dataset: Dims ".join(", ",@dims);
			$hl->add("$path\01_Dset$dataset", -image => $self->{cubeImage}, -text => $text, -data => $data);

		}



	 }
	
	
}
#   This Sub called when a element of the H-list is expanded/collapsed. (i.e. clicked-on)
sub More
{
	 my $self = shift;   
	 my ($w,$item) = @_;  # hl list object, hlist item name
	 
	 if( defined $w->info('children',$item) > 0){  #get rid of old elements if it has already been opened
		# print "Has children\n";
		$w->delete('offsprings',$item);
	 }


	 # print "item = $item\n";
	 my $data = $w->entrycget($item,'-data');  #get the data ref for this entry
	 
	 my @levels = split("\01",$item);
	
	 if( @levels && ( $levels[-1] =~ /^_Group/) ){ # if this is a group then get the group object
	
		 my ($obj, $groupName) = @$data;
		 $data = $obj->group($groupName);
	 }
	
	 $self->AddChildren($w,$item,$data);

}


  
1;
