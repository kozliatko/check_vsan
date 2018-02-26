#!/bin/bash

########################################################################################
#
# script to automate nagios check on vmware VSAN infrastructure
#
# 0.91 - Tue Feb 13 11:55:40 CET 2018
# 0.92 - Mon Feb 26 15:52:34 CET 2018
#
# (c) Jan ' Kozo ' Vajda <Jan.Vajda@gmail.com>
#
########################################################################################

PROGNAME=$(basename $0)
PROGPATH=$(echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,')

CURL=$(which curl)|| { echo "There is no curl binary in path"; exit 1; }
PERL=$(which perl)|| { echo "There is no perl binary in path"; exit 1; }

REVISION="0.92"


usage() { 
  echo "Usage: ${PROGNAME} [-h | --help | -s server -u user -p password | --username user --password password --server server] [-v | --verbose ] [ -n | --noclean ]" 1>&2; 
  echo "" 1>&2;
  echo "Check VMWare VSAN status " 1>&2;
  echo "(Version: ${PROGNAME} ${REVISION})" 1>&2;
  echo "" 1>&2;
  echo "  ${PROGNAME} -h | --help" 1>&2;
  echo "     print this help" 1>&2;
  echo "" 1>&2;
  echo "  ${PROGNAME} -v | --verbose" 1>&2;
  echo "     verbose output to logfile" 1>&2;
  echo "" 1>&2;
  echo "  ${PROGNAME} -n | --noclean" 1>&2;
  echo "     do not delete temporary directory /tmp/vsan-*" 1>&2;
  echo "" 1>&2;
  echo "  ${PROGNAME} -u | --username" 1>&2;
  echo "     vcenter username (can be omitted if VCENTERUSERNAME is set)" 1>&2;
  echo "" 1>&2;
  echo "  ${PROGNAME} -p | --password" 1>&2;
  echo "     vcenter password (can be omitted if VCENTERPASSWORD is set)" 1>&2;
  echo "" 1>&2;
  echo "  ${PROGNAME} -s | --server" 1>&2;
  echo "     vcenter hostname (can be omitted if VCENTERSERVER is set)" 1>&2; 
  echo "" 1>&2;
  echo "" 1>&2;
  echo "" 1>&2;
  echo "If the plugin doesn't work, you have patches or want to suggest improvements" 1>&2;
  echo "send email to jan.vajda@gmail.com." 1>&2;
  echo "Please include version information with all correspondence" 1>&2;
  echo "" 1>&2;
  exit 1;
}

### conditional verbose output
verbose () {
  if [[ ${VERBOSE} == "-v" ]]; then
    echo $@ >> ${LOGFILE} 2>&1
  fi
}

### conditional cleanup of temporary directory after finish
cleanup () {
  if [ -z ${CLEAN} ] ; then
    rm -rf ${VSANTMPDIR}
  fi
}

TEMP=$(getopt -o :hvnu:p:s: --long help,verbose,noclean,username:,password:,server: -- "$@")
if [ $? != 0 ] ; then usage; fi
eval set -- "${TEMP}"

### default
VERBOSE="-s"


while true
do
    case "$1" in
        -u | --username ) VCENTERUSERNAME="$2"; shift 2;;
        -p | --password )  VCENTERPASSWORD="$2"; shift 2;;
        -s | --server ) VCENTERSERVER=$2; shift 2;;
        -v | --verbose ) VERBOSE="-v"; shift ;;
        -n | --noclean ) CLEAN="no"; shift ;;
        -h | --help ) usage; exit;;
        -- ) shift; break ;;
    esac
done

if [ -z ${VCENTERUSERNAME} ] || [ -z ${VCENTERPASSWORD} ] || [ -z ${VCENTERSERVER} ] ; then usage; fi

VSANTMPDIR="$(mktemp -d -t vsan-XXXXXXXX )" || { echo "Failed to create temp directory"; exit 1; }
COOKIES="$(mktemp ${VSANTMPDIR}/cookies.XXXXXXXX)" || { echo "Failed to create temp file"; exit 1; }
LOGFILE="$(mktemp ${VSANTMPDIR}/logfile.XXXXXXXX)" || { echo "Failed to create temp file"; exit 1; }

    ENDPOINT="https://${VCENTERSERVER}:443/sdk/vimService.wsdl"
VSANENDPOINT="https://${VCENTERSERVER}:443/vsanHealth"



### auth
SOAP2=$(cat <<EOM
<?xml version="1.0" encoding="UTF-8"?>
   <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soapenv:Body>
   <Login xmlns="urn:vim25">
      <_this type="SessionManager">SessionManager</_this>
	<userName>${VCENTERUSERNAME}</userName>
	<password>${VCENTERPASSWORD}</password>
      </Login>
   </soapenv:Body>
   </soapenv:Envelope>
EOM
)

verbose "SOAP2: ${SOAP2}"
echo ${SOAP2} | ${CURL} ${VERBOSE} --header 'SOAPAction: urn:vim25/6.5' --header 'Content-Type: text/xml' -k -d @- -o ${VSANTMPDIR}/response2.xml -b ${COOKIES} -c ${COOKIES} -X POST $ENDPOINT >> ${LOGFILE} 2>&1

if [[ $? == "6" || $? == "7" || $? == "56" ]]; then
  cleanup
  echo "Cannot connect to ${VCENTERSERVER}"
  exit 1
fi

grep -q "incorrect user name or password" ${VSANTMPDIR}/response2.xml && { cleanup; echo "Incorrect user name or password"; exit 1;}

### get ClusterComputeResource
SOAP3=$(cat <<EOM
<?xml version="1.0" encoding="UTF-8"?>
   <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soapenv:Body>
<RetrieveProperties xmlns="urn:vim25">
<_this type="PropertyCollector">propertyCollector</_this>
<specSet>
<propSet>
<type>ClusterComputeResource</type>
<all>0</all>
<pathSet>name</pathSet>
</propSet>
<objectSet>
<obj type="Folder">group-d1</obj>
<skip>0</skip>

<selectSet xsi:type="TraversalSpec">
<name>folderTraversalSpec</name>
<type>Folder</type>
<path>childEntity</path>
<skip>0</skip>
<selectSet><name>folderTraversalSpec</name></selectSet>
<selectSet><name>datacenterHostTraversalSpec</name></selectSet>
<selectSet><name>datacenterVmTraversalSpec</name></selectSet>
<selectSet><name>datacenterDatastoreTraversalSpec</name></selectSet>
<selectSet><name>datacenterNetworkTraversalSpec</name></selectSet>
<selectSet><name>computeResourceRpTraversalSpec</name></selectSet>
<selectSet><name>computeResourceHostTraversalSpec</name></selectSet>
<selectSet><name>hostVmTraversalSpec</name></selectSet>
<selectSet><name>resourcePoolVmTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>datacenterDatastoreTraversalSpec</name>
<type>Datacenter</type>
<path>datastoreFolder</path>
<skip>0</skip>
<selectSet><name>folderTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>datacenterNetworkTraversalSpec</name>
<type>Datacenter</type>
<path>networkFolder</path>
<skip>0</skip>
<selectSet><name>folderTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>datacenterVmTraversalSpec</name>
<type>Datacenter</type>
<path>vmFolder</path>
<skip>0</skip>
<selectSet><name>folderTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>datacenterHostTraversalSpec</name>
<type>Datacenter</type>
<path>hostFolder</path>
<skip>0</skip>
<selectSet><name>folderTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>computeResourceHostTraversalSpec</name>
<type>ComputeResource</type>
<path>host</path>
<skip>0</skip>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>computeResourceRpTraversalSpec</name>
<type>ComputeResource</type>
<path>resourcePool</path>
<skip>0</skip>
<selectSet><name>resourcePoolTraversalSpec</name></selectSet>
<selectSet><name>resourcePoolVmTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>resourcePoolTraversalSpec</name>
<type>ResourcePool</type>
<path>resourcePool</path>
<skip>0</skip>
<selectSet><name>resourcePoolTraversalSpec</name></selectSet>
<selectSet><name>resourcePoolVmTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>hostVmTraversalSpec</name>
<type>HostSystem</type>
<path>vm</path>
<skip>0</skip>
<selectSet><name>folderTraversalSpec</name></selectSet>
</selectSet>

<selectSet xsi:type="TraversalSpec">
<name>resourcePoolVmTraversalSpec</name>
<type>ResourcePool</type>
<path>vm</path>
<skip>0</skip>
</selectSet>
</objectSet>
</specSet>
</RetrieveProperties></soapenv:Body></soapenv:Envelope>
EOM
)

verbose "SOAP3: ${SOAP3}"
echo ${SOAP3} | ${CURL} ${VERBOSE} --header 'SOAPAction: urn:vim25/6.5' --header 'Content-Type: text/xml' -k -d @- -o ${VSANTMPDIR}/response3.xml -b ${COOKIES} -c ${COOKIES} -X POST $ENDPOINT >> ${LOGFILE} 2>&1
ID=$(grep RetrievePropertiesResponse ${VSANTMPDIR}/response3.xml | ${PERL} -pe 's/.*?<RetrievePropertiesResponse xmlns="urn:vim25"><returnval><obj type="ClusterComputeResource">([a-z0-9-]+)<\/obj>.*$/$1/')
verbose "This is ID: ${ID}"

### get health
SOAP5=$(cat <<EOM
<?xml version="1.0" encoding="UTF-8"?>
   <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soapenv:Body>
<VsanQueryVcClusterHealthSummary xmlns="urn:vim25">
  <_this type="VsanVcClusterHealthSystem">vsan-cluster-health-system</_this>
  <cluster type="ClusterComputeResource">$ID</cluster>
  <includeObjUuids>false</includeObjUuids>
  <fetchFromCache>false</fetchFromCache>
</VsanQueryVcClusterHealthSummary>
</soapenv:Body>
</soapenv:Envelope>

EOM
)

verbose "SOAP5: ${SOAP5}"
echo ${SOAP5} | ${CURL} ${VERBOSE} --header 'SOAPAction: urn:vim25/6.5' --header 'Content-Type: text/xml' -k -d @- -o ${VSANTMPDIR}/response5.xml -b ${COOKIES} -c ${COOKIES} -X POST $VSANENDPOINT >> ${LOGFILE} 2>&1
STATUS=$(grep VsanQueryVcClusterHealthSummaryResponse ${VSANTMPDIR}/response5.xml | ${PERL} -pe 's/.*?<VsanQueryVcClusterHealthSummaryResponse.*?<status>([a-z]+)<\/status>.*$/$1/')

verbose "STATUS: ${STATUS}"

### logout
SOAP6=$(cat <<EOM
<?xml version="1.0" encoding="UTF-8"?>
   <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
   <soapenv:Body>
   <Logout xmlns="urn:vim25">
     <_this type="SessionManager">SessionManager</_this>
   </Logout>
   </soapenv:Body>
   </soapenv:Envelope>

EOM
)


verbose "SOAP6: ${SOAP6}"
echo ${SOAP6} | ${CURL} ${VERBOSE} --header 'SOAPAction: urn:vim25/6.5' --header 'Content-Type: text/xml' -k -d @- -o ${VSANTMPDIR}/response6.xml -b ${COOKIES} -c ${COOKIES} -X POST $ENDPOINT >> ${LOGFILE} 2>&1


### cleanup
cleanup


### mapping to nagios states
case "${STATUS}" in 
  green) echo "OK - clusterStatus is ${STATUS}"; exit 0;;
  yelow) echo "WARNING - clusterStatus is ${STATUS}"; exit 1;;
  red) echo "CRITICAL - clusterStatus is ${STATUS}"; exit 2;;
  *) echo "UNKNOWN - clusterStatus is ${STATUS}"; exit 3;;
esac

