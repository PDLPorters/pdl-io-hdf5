# Makefile.PL for a package defined by PP code.

use PDL::Core::Dev;            # Pick up development utilities
use ExtUtils::MakeMaker;
use Config;

# 
## Search for hdf5 library and include file
#
$ENV{'HOME'} = '' unless defined( $ENV{'HOME'} ) ;

foreach my $libdir (
		    '/usr/local/hdf5/lib',
		    '/usr/local/lib',
		    '/opt/local/lib',
		    '/usr/lib',
		    '/opt/lib',
		    "$ENV{HOME}/hdf5/lib",  # for local hdf5 installs
		                  # Add new library paths here!!
		    ) {

  if (-e "$libdir/libhdf5.so") {
    $hdf5_lib_path = $libdir;
    print "Found libhdf5.so at $libdir/libhdf5.so\n";
    last;
  }

  if (-e "$libdir/libhdf5.a") {
    $hdf5_lib_path = $libdir;
    print "Found libhdf5.a at $libdir/libhdf5.a\n";
    last;
  }

}

die "Cannot find hdf5 library, libhdf5.so or libhdf5.a.  
Please add the correct library path to Makefile.PL or install HDF" 
  unless defined ($hdf5_lib_path);

foreach my $incdir (
		    '/usr/local/hdf5/include',
		    '/usr/local/include',
		    '/opt/local/include',
		    '/usr/include',
		    '/opt/include',
		    "$ENV{HOME}/hdf5/include",  # for local hdf5 installs

		                  # Add new header paths here!!
		    ) {

  if (-e "$incdir/hdf5.h") {
    $hdf5_include_path = $incdir;
    print "Found hdf5.h at $incdir/hdf5.h\n";
    last;
  }
}

die "Cannot find hdf5 header file, hdf5.h.
Please add the correct library path to Makefile.PL or install HDF" 
  unless defined ($hdf5_include_path);

# Flags to include jpeg and/or zlib during compilation
$jpegLib = 0;
$zLib = 0;
if( -e "$hdf5_include_path/H5config.h"){
	open( H5CONFIG, "$hdf5_include_path/H5config.h") or 
           die("Can't Open Include File '$hdf5_include_path/H5config.h'\n");
	while(defined( $_ = <H5CONFIG>)){
		$jpegLib = 1 if( /^\s*\#define\s+HAVE_LIBJPEG\s+1/ );
		$zLib = 1 if( /^\s*\#define\s+HAVE_LIBZ\s+1/ );
	}
}


# The following code was originally in the PDL::netCDF Makefile.PL
#  (Not sure if it is really needed here)
# Check if compiled under gcc/Linux.  In which case, define bool for the compiler
$define_bool = '';
if ($Config{'osname'} =~ /linux/) {
  $define_bool = '-Dbool=int';
  print "Defining bool=int (linux seems to need this)\n";
}
            
$LIBS = "-L$hdf5_lib_path -lhdf5 ";
$LIBS .= " -lz" if($zLib);
$LIBS .= " -ljpeg" if($jpegLib);

$package = ["hdf5.pd",HDF5,PDL::HDF5];
WriteMakefile(
	      'NAME'  	     => 'PDL::HDF5',
	      'CCFLAGS'      => "$define_bool -g",  
	      'VERSION_FROM' => 'hdf5.pd',
	      'TYPEMAPS'     => [&PDL_TYPEMAP()], 
	      'OBJECT'       => 'HDF5.o ',
	      'PM'           => { 'HDF5.pm' => '$(INST_LIBDIR)/HDF5.pm',
	      			  'HDF5/Group.pm' => '$(INST_LIBDIR)/HDF5/Group.pm',
	      			  'HDF5/Dataset.pm' => '$(INST_LIBDIR)/HDF5/Dataset.pm',
	      			  'HDF5/tkview.pm' => '$(INST_LIBDIR)/HDF5/tkview.pm',
				},
	      'INC'          => &PDL_INCLUDE()." -I$hdf5_include_path", 
	      'LIBS'         => [$LIBS],  
	      'clean'        => {'FILES'  => 
				   'HDF5.pm HDF5.xs HDF5.o HDF5.c'},
	      'dist'         => { COMPRESS => 'gzip', SUFFIX => 'gz' },	
	      );

sub MY::postamble { pdlpp_postamble($package); }	





