#######################################################################################
# Copyright 2010 Kaoru Fukumoto All Rights Reserved
#
# You may freely use and redistribute this script as long as this 
# copyright notice remains intact 
#
#
# DISCLAIMER. THIS SCRIPT IS PROVIDED TO YOU "AS IS" WITHOUT WARRANTIES OR CONDITIONS 
# OF ANY KIND, WHETHER ORAL OR WRITTEN, EXPRESS OR IMPLIED. THE AUTHOR SPECIFICALLY 
# DISCLAIMS ANY IMPLIED WARRANTIES OR CONDITIONS OF MERCHANTABILITY, SATISFACTORY 
# QUALITY, NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. 
#
#######################################################################################

#
# CONSTANTS
#
. .\CONFIG.ps1
$LOG = "$VTILLOG\dumpperfdata.log"
[xml]$DBINFO = Get-Content $VTILDBINFO

#
# CONTROLS
#
$SINCEDAYS = 2
#$INIT = 1

#
# IMPORTS
#
Add-PSSnapin VMware.VimAutomation.Core


#
# FUNCTIONS
#
$INTERVAL = @{'1day'=1440;'2hours'=120;'30mins'=30;}
function dump_perf_data_impl($dir,$ci,$counter,$intvl) {
	$now = Get-date
	"$($now): $($ci.Name): $($counter): $($intvl)" | Out-File $LOG -Append -Encoding ASCII

	$file = "$dir\$($intvl)_{0}{1}{2}_{3:D2}{4:D2}{5:D2}.csv" -f 
		$now.Year, $now.Month, $now.Day, $now.Hour, $now.Minute, $now.Second
	"time,value" | Out-File $file -Encoding ASCII
	
	if($INIT -eq 1) {$SINCEDAYS = 94}
	$start = (Get-date).AddDays(-1 * $SINCEDAYS)
	$ci | Get-Stat -Stat $counter -IntervalMins $INTERVAL[$intvl] -start $start | % {
		if (($counter -like 'cpu*' -and $_.Instance -ne "" -and $_.Instance -ne "*") -or
			($counter -like 'cpu*' -and $_.Value -le 0) -or
			$_.Value -lt 0) {
		}
		else {
		  "{0},{1}" -f $_.Timestamp, $_.Value | Out-File $file -Append -Encoding ASCII
		}		
	}
}

function dump_perf_data($dir,$ci,$counter) {
	if($INIT -eq 1 -and $counter.init_interval) {
		$counter.init_interval | % {
			dump_perf_data_impl $dir $ci $counter.name $_
		}
	}
	$counter.interval | % {
			dump_perf_data_impl $dir $ci $counter.name $_
	}
}

function dump_vm_info($file,$vm) {
	$xml = "<vm name=`"$($vm.Name)`" host=`"$($vm.Host.Name)`" NumCpu=`"$($vm.NumCpu)`" MemoryMB=`"$($vm.MemoryMB)`" />"
	$xml  | Out-File $file -Encoding ASCII
}

function dump_esx_info($file,$cluster,$esx) {
	$xml = "<esx name=`"$($esx.Name)`" cluster=`"$($cluster)`" CpuTotalMhz=`"$($esx.CpuTotalMhz)`" MemoryTotalMB=`"$($esx.MemoryTotalMB)`" />"
	$xml  | Out-File $file -Encoding ASCII
}

function dump_host_data()  {
	Get-Cluster | % {
		$cluster = $_
		$cluster | Get-VMHost | % {
			$esx = $_			
			$DBINFO.counters.host.counter | % {
				$counter = $_
				$outdir = "$VTILDATA\cluster\$($cluster.Name)\host\$($esx.Name)\$($counter.name)"
				if(-not (Test-Path $outdir)) {
					New-Item $outdir -Type directory | Out-Null
				}
				dump_perf_data $outdir $esx $counter
			}
			$file = "$VTILDATA\cluster\$($cluster.Name)\host\$($esx.Name)\esxinfo.xml"			
			dump_esx_info $file $cluster.Name $esx
		}
	}
}

function dump_vm_data()  {
	Get-Cluster | % {
		$cluster = $_
		$cluster | Get-VMHost | % {
			$esx = $_			
			$esx | Get-VM  | % {
				$vm = $_			
				$DBINFO.counters.vm.counter | % {
					$counter = $_				
					$outdir = "$VTILDATA\cluster\$($cluster.Name)\vm\$($vm.Name)\$($counter.name)"
					if(-not (Test-Path $outdir)) {
						New-Item $outdir -Type directory | Out-Null
					}
					dump_perf_data $outdir $vm $counter
				}
				$file = "$VTILDATA\cluster\$($cluster.Name)\vm\$($vm.Name)\vminfo.xml"			
				dump_vm_info $file $vm
			}
		}
	}
}

function dump_cluster_data()  {
	Get-Cluster | % {
		$cluster = $_
		$DBINFO.counters.cluster.counter | % {
			$counter = $_
			$outdir = "$VTILDATA\cluster\$($cluster.Name)\$($counter.name)"
			if(-not (Test-Path $outdir)) {
				New-Item $outdir -Type directory | Out-Null
			}
			dump_perf_data $outdir $cluster $counter
		}
	}
}

# Connect to vCenter
$cred = New-Object System.Management.Automation.PSCredential($VTILVCUSER, (Get-Content $VTILCRD | ConvertTo-SecureString))
Connect-VIServer -Server $VTILVC -Credential $cred

dump_cluster_data
dump_host_data
dump_vm_data


