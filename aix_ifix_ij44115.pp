#
#  2023/02/27 - cp - Added the extra test against $::facts['aix_ifix_package']
#		for safety.
#
#-------------------------------------------------------------------------------
#
#  From Advisory.asc:
#
#    For CAA kernel extension:
#
#    AIX Level APAR     Availability  SP        KEY         PRODUCT(S)
#    -----------------------------------------------------------------
#    7.1.5     IJ43099  **            SP11      key_w_apar  CAA
#    7.2.5     IJ41975  **            SP06      key_w_apar  CAA
#    7.3.0     IJ42938  **            SP03      key_w_apar  CAA
#
#    VIOS Level APAR    Availability  SP        KEY         PRODUCT(S)
#    -----------------------------------------------------------------
#    3.1.2      IJ44115 **            3.1.2.50  key_w_apar  CAA
#    3.1.3      IJ41975 **            3.1.3.30  key_w_apar  CAA
#
#    For CAA kernel extension:
#
#    AIX Level  Interim Fix (*.Z)         KEY        PRODUCT(S)
#    ----------------------------------------------------------
#    7.1.5.8    IJ43099m8a.221110.epkg.Z  key_w_fix  CAA
#    7.1.5.9    IJ43099m9a.221102.epkg.Z  key_w_fix  CAA
#    7.1.5.9    IJ43099m9b.221213.epkg.Z  key_w_fix  CAA
#    7.1.5.10   IJ43099sAa.221024.epkg.Z  key_w_fix  CAA
#    7.2.5.2    IJ44115m2a.221102.epkg.Z  key_w_fix  CAA  <<-- covered here
#    7.2.5.3    IJ41975m3a.221027.epkg.Z  key_w_fix  CAA
#    7.2.5.3    IJ41975m3b.221212.epkg.Z  key_w_fix  CAA
#    7.2.5.4    IJ41975s4a.221017.epkg.Z  key_w_fix  CAA
#    7.3.0.1    IJ42938m1a.221027.epkg.Z  key_w_fix  CAA
#    7.3.0.2    IJ42938s2a.221018.epkg.Z  key_w_fix  CAA
#
#    Please note that the above table refers to AIX TL/SP level as
#    opposed to fileset level, i.e., 7.2.5.4 is AIX 7200-05-04.
#
#    NOTE:  Multiple iFixes are provided for AIX 7100-05-09 and
#    7200-05-03.
#    IJ43099m9a is for AIX 7100-05-09 with bos.cluster.rte fileset level 7.1.5.38.
#    IJ43099m9b is for AIX 7100-05-09 with bos.cluster.rte fileset level 7.1.5.37.
#    IJ41975m3a is for AIX 7200-05-03 with bos.cluster.rte fileset level 7.2.5.101.
#    IJ41975m3b is for AIX 7200-05-03 with bos.cluster.rte fileset level 7.2.5.100.
#
#    VIOS Level  Interim Fix (*.Z)         KEY        PRODUCT(S)
#    -----------------------------------------------------------
#    3.1.2.21    IJ44115m2a.221102.epkg.Z  key_w_fix  CAA
#    3.1.2.30    IJ44115m2a.221102.epkg.Z  key_w_fix  CAA
#    3.1.2.40    IJ44115m2b.221213.epkg.Z  key_w_fix  CAA
#    3.1.3.10    IJ41975m3b.221212.epkg.Z  key_w_fix  CAA
#    3.1.3.14    IJ41975m3a.221027.epkg.Z  key_w_fix  CAA
#    3.1.3.21    IJ41975s4a.221017.epkg.Z  key_w_fix  CAA
#
#-------------------------------------------------------------------------------
#
class aix_ifix_ij44115 {

    #  Make sure we can get to the ::staging module (deprecated ?)
    include ::staging

    #  This only applies to AIX and maybe VIOS in later versions
    if ($::facts['osfamily'] == 'AIX') {

        #  Set the ifix ID up here to be used later in various names
        $ifixName = 'IJ44115'

        #  Make sure we create/manage the ifix staging directory
        require aix_file_opt_ifixes

        #
        #  For now, we're skipping anything that reads as a VIO server.
        #  We have no matching versions of this ifix / VIOS level installed.
        #
        unless ($::facts['aix_vios']['is_vios']) {

            #  2023/02/27 - cp - Added for safety
            if ('bos.cluster.rte' in $::facts['aix_ifix_package']) {
                #
                #  Friggin' IBM...  The ifix ID that we find and capture in the fact has the
                #  suffix allready applied.
                #
                if ($::facts['kernelrelease'] in '7200-05-02-2114') {
                    $ifixSuffix = 'm2a'
                    $ifixBuildDate = '221102'
                }
                else {
                    $ifixSuffix = 'unknown'
                    $ifixBuildDate = 'unknown'
                }
            }
            else {
                $ifixSuffix = 'unknown'
                $ifixBuildDate = 'unknown'
            }

            #  Add the name and suffix to make something we can find in the fact
            $ifixFullName = "${ifixName}${ifixSuffix}"

            #  If we set our $ifixSuffix and $ifixBuildDate, we'll continue
            if (($ifixSuffix != 'unknown') and ($ifixBuildDate != 'unknown')) {

                #  Don't bother with this if it's already showing up installed
                unless ($ifixFullName in $::facts['aix_ifix']['hash'].keys) {
 
                    #  Build up the complete name of the ifix staging source and target
                    $ifixStagingSource = "puppet:///modules/aix_ifix_ij44115/${ifixName}${ifixSuffix}.${ifixBuildDate}.epkg.Z"
                    $ifixStagingTarget = "/opt/ifixes/${ifixName}${ifixSuffix}.${ifixBuildDate}.epkg.Z"

                    #  Stage it
                    staging::file { "$ifixStagingSource" :
                        source  => "$ifixStagingSource",
                        target  => "$ifixStagingTarget",
                        before  => Exec["emgr-install-${ifixName}"],
                    }

                    #  GAG!  Use an exec resource to install it, since we have no other option yet
                    exec { "emgr-install-${ifixName}":
                        path     => '/bin:/sbin:/usr/bin:/usr/sbin:/etc',
                        command  => "/usr/sbin/emgr -e $ifixStagingTarget",
                        unless   => "/usr/sbin/emgr -l -L $ifixFullName",
                    }

                    #  Explicitly define the dependency relationships between our resources
                    File['/opt/ifixes']->Staging::File["$ifixStagingSource"]->Exec["emgr-install-${ifixName}"]

                }

            }

        }

    }

}
