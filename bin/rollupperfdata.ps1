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
. .\CONFIG.ps1
$LOG = "$VTILLOG\rollupperfdata.log"
[xml]$DBINFO = Get-Content $VTILDBINFO

#
# rollup
#  Take the array of numeric values and return ($min, $max, $avg)
#
function rollup($arr) {
	$min = $max = $arr[0]
	$sum = 0
	foreach($v in $arr) {
		if($min -gt $v) {$min = $v}
		if($max -lt $v) {$max = $v}
		$sum += $v
	}	
	return $min,$max,($sum/$arr.Length)
}

#
# mkdate_daily
#  Make date value by parsing "YYYY/MM/DD" for daily rollup basis
#
function mkdate_daily($day) {
	get-date -Date ("{0}/{1}/{2}" -f $day.Year,$day.Month,$day.Day)
}

#
# build_weekly_list
#  Build array of last 13 Sundays
#
function build_week_list() {
	$sunday = $VIEWFINISH.AddDays(-1 * $VIEWFINISH.DayOfWeek)
	$sunday = mkdate_daily($sunday)

	$arr = , $sunday
	foreach($i in 1..12) {
		$sunday = $sunday.AddDays(-7)
		$arr += , $sunday
	}
	$arr = $arr | Sort-Object
	return $arr
}

#
# build_daily_list
#  Build array of last 92 days
#
function build_day_list() {
	$d = mkdate_daily($VIEWFINISH)
	$arr = , $d
	foreach($i in 1..91) {
		$d = $d.AddDays(-1)
		$arr += , $d
	}
	$arr = $arr | Sort-Object
	return $arr
}

#
# for-each CI
#
function foreach_ci($root) {
	Dir $root -Exclude "*.xml","*.csv"
}

function foreach_cluster {
	foreach_ci("$VTILDATA\cluster")
}

function foreach_host($cluster) {
	foreach_ci("$($cluster.PSPath)\host")
}

function foreach_vm($cluster) {
	foreach_ci("$($cluster.PSPath)\vm")
}

function foreach_perfdata($dir) {
	Dir "$dir\1day_*.csv","$dir\2hours_*.csv","$dir\30mins_*.csv" -Exclude "*.xml","vm","host"
}

#
# format_MB
#
function format_MB($v) {
	if($v) {
		return "{0}" -f ([float]$v/1024)
	} 
	else {
		return ''
	}
}

#
# Log helper
#
function log($str) {
	"$(Get-Date): $str" | Out-File $LOG -Append -Encoding ASCII
}

#
# CSV creation helpers
#
function data2view($path) {
	return $path.Replace($VTILDATA,$VIEWROOT)
}

function output_csv($dir,$base,$str) {
	$d = data2view $dir
	if(-not (Test-Path $d)) {
		New-Item $d -Type directory | Out-Null
	}
	$file = "$d/$base"
	$str | Out-File $file -Encoding ASCII
	return $file
}
function append_csv($file,$str) {
	$str | Out-File $file -Encoding ASCII -Append
}

#
# weekly_rollup
#
function weekly_rollup($ci) {
	foreach_ci($ci.PSPath) | % {
		$counter = $_
		$cpath = $counter.PSPath
		$file = output_csv $cpath "weekly_latest.csv" "time,min,max,avg"
	
		$table = @{}		
		$bitmap = @{}
		foreach_perfdata $cpath | % {
			log("$($ci.Name): $($counter.Name): $($_.Name)")
		
			Import-Csv $_  | % {
				if(!$bitmap[$_.time]) {
					$t1 = Get-date -Date $_.time
					$t2 = $t1.AddDays(-1 * $t1.DayOfWeek)
					$t2 = mkdate_daily($t2)
					$table[$t2] += , [float]$_.value
					$bitmap[$_.time] = 1
				}
			}
		}
	
		$weeks = build_week_list
		$weeks | % {
			if(!$table[$_]) {
				append_csv $file "$(Get-date -date $_ -format d),,,"
			}
			else {
				($min,$max,$avg) = rollup($table[$_])
				append_csv $file "$(Get-date -date $_ -format d),$min,$max,$avg"
			}
		}
	}
}

#
# daily_rollup
#
function daily_rollup($ci) {
	foreach_ci($ci.PSPath) | % {
		$counter = $_
		$cpath = $counter.PSPath
		$file = output_csv $cpath "daily_latest.csv" "time,min,max,avg"
	
		$table = @{}		
		$bitmap = @{}
		foreach_perfdata $cpath | % {
			log "$($ci.Name): $($counter.Name): $($_.Name)"
		
			Import-Csv $_  | % {
				if(!$bitmap[$_.time]) {
					$t1 = Get-date -Date $_.time
					$t2 = mkdate_daily($t1)
					$table[$t2] += , [float]$_.value
					$bitmap[$_.time] = 1
				}
			}
		}
		$days = build_day_list
		$days | % {
			if(!$table[$_]) {
				append_csv $file "$(Get-date -date $_ -format d),,,"
			}
			else {
				($min,$max,$avg) = rollup($table[$_])
				append_csv $file "$(Get-date -date $_ -format d),$min,$max,$avg"
			}
		}
	}
}

#
# Rollup functions
#
function cluster_weekly() { 
	foreach_cluster | % {weekly_rollup($_)}
}
function cluster_daily() { 
	foreach_cluster | % {daily_rollup($_)}
}

function host_weekly() { 
	foreach_cluster | % {foreach_host($_) | % {weekly_rollup($_)}}
}
function host_daily() {
	foreach_cluster | % {foreach_host($_) | % {daily_rollup($_)}}
}

function vm_weekly {
	foreach_cluster | % {foreach_vm($_) | % {weekly_rollup($_)}}
}
function vm_daily {
	foreach_cluster | % {foreach_vm($_) | % {daily_rollup($_)}}
}

#
# cluster_4weeks
#   Build CSV for past 4 weeks cluster chart
#
function cluster_4weeks() {
	$cntr_4weeks = 'mem.usage.average','cpu.usage.average','disk.usage.average'
	foreach_cluster | % {
		$cluster = $_
		$table = @()
		foreach_host($cluster) | % {
			$esx = $_
			 $cntr_4weeks | % {
				$counter = $_
				Import-Csv $(data2view "$($esx.PSPath)\$counter\weekly_latest.csv") | % {
					$_ | Add-Member -MemberType NoteProperty -Name esx -Value $esx.Name
					$_ | Add-Member -MemberType NoteProperty -Name counter -Value $counter
					$table += $_
				}
			}
		}

		$cntr_4weeks | % {
			$counter = $_
			$file = output_csv "$($cluster.PSPath)\$($counter)" "4weeks_latest.csv" "esx,4 weeks ago,3 weeks ago,2 weeks ago,last week"
			$table | where {$_.counter -eq $counter} | Group-Object esx | Sort-Object Name | % {
				$row = "$($_.Name)"
				$_.Group | Sort-Object time | Select-Object -Last 4 | % {
					$row += ",$($_.avg)"
				}
				append_csv $file $row
			}
		}
	}
}

function cluster_report() {
	foreach_cluster | % {
		$cluster = $_
		$table = @{}
				
		$DBINFO.counters.cluster.counter | % {
			$counter = $_
			$file = data2view "$($cluster.PSPath)\$($counter.name)\daily_latest.csv"
			log("$($cluster.Name): $($counter.name)")
			
			if(Test-Path $file) { 
				Import-Csv $file  | % {
					$t1 = Get-date -Date $_.time
					$t2 = mkdate_daily($t1)
					if(!$table[$t2]) {$table[$t2]=@{}}
					$table[$t2][$counter.name] = $_.avg
				}
			} else {
				# Rollup data doesn't exist in case no clusters exist in the target environment.
				# In such environment, cluster folder actually is mapped to datacenter object.
				log("'$($cluster.Name)' is a Datacenter object. No performance data is found.")
			}
		}
		
		Import-Csv $(data2view "$($cluster.PSPath)\vm_daily_count.csv") | % {
			$t1 = Get-date -Date $_.time
			$t2 = mkdate_daily($t1)
			if(!$table[$t2]) {$table[$t2]=@{}}
			$table[$t2]['numPowerOnVM'] = $_.count
			$table[$t2]['szPowerOnVM'] = $_.memsz
		}

		$file = output_csv $cluster.PSPath "cpu_memory.csv" "Date,Effective CPU (MHz),Effective Mem (MB),Power ON VMs,Power ON VMs Mem (MB),CPU Usage (MHz),CPU Usage (%),Mem Consumed (KB),Mem Overhead (KB)"		
		$table.GetEnumerator() | Sort-Object Name | % {
			append_csv $file $("{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f 
				$(Get-date -date $_.Name -format d),
				$_.Value['clusterServices.effectivecpu.average'],
				$_.Value['clusterServices.effectivemem.average'],
				$_.Value['numPowerOnVM'],
				$_.Value['szPowerOnVM'],
				$_.Value['cpu.usagemhz.average'],
				$_.Value['cpu.usage.average'],
				$_.Value['mem.consumed.average'],
				$_.Value['mem.overhead.average'])
		}
	}
}


function host_report() {
	foreach_cluster | % {
		#
		# On-memory table structure for all counters
		# table[host][time][counter] = {avg, min, max}
		#
		$table = @{}		
		
		foreach_host($_) | % {
			$esx = $_
			$esxtable = $table[$esx.Name] = @{}
			
			$DBINFO.counters.host.counter | % {
				$counter = $_
				log "$($esx.Name): $($counter.name): daily_latest.csv"

				Import-Csv  $(data2view "$($esx.PSPath)\$($counter.name)\daily_latest.csv") | % {
					$t1 = Get-date -Date $_.time
					if(!$esxtable[$t1]) {$esxtable[$t1]=@{}}
					$esxtable[$t1][$counter.name] = @{avg=$_.avg; min=$_.min; max=$_.max;}
				}
			}

			#
			# Write cpu_memory.csv
			#
			$file = output_csv $esx.PSPath "cpu_memory.csv" $("Date," +
			"CPU Usage (MHz)," +
			"CPU Usage (%)," +
			"Mem Consumed (KB)," +
			"Mem Usage (%)")
			
			$esxtable.GetEnumerator() | Sort-Object Name | % {
				append_csv $file $("{0},{1},{2},{3},{4}" -f 
					$(Get-date -date $_.Name -format d),
					$_.Value['cpu.usagemhz.average']['avg'],
					$_.Value['cpu.usage.average']['avg'],
					$_.Value['mem.consumed.average']['avg'],
					$_.Value['mem.usage.average']['avg'])
			}

			#
			# Write memory.csv
			#
			$file = output_csv $esx.PSPath "memory.csv" $("Date," +
			"Mem Consumed Avg (MB)," +
			"Mem Consumed Max (MB)," +
			"Mem Consumed Min (MB)," +
			"Active Memory (MB)," +
			"Mem Shared Common (MB)," +
			"Balloon Memory Max (MB)," +
			"Swap Memory Max (MB)," +
			"Granted Memory (MB)")

			$esxtable.GetEnumerator() | Sort-Object Name | % {
				append_csv $file $("{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f $(Get-date -date $_.Name -format d),
					(format_MB($_.Value['mem.consumed.average']['avg'])),
					(format_MB($_.Value['mem.consumed.average']['max'])),
					(format_MB($_.Value['mem.consumed.average']['min'])),
					(format_MB($_.Value['mem.active.average']['avg'])),
					(format_MB($_.Value['mem.shared.average']['avg'])),
					(format_MB($_.Value['mem.vmmemctl.average']['max'])),
					(format_MB($_.Value['mem.swapused.average']['max'])),
					(format_MB($_.Value['mem.granted.average']['max'])))
			}

			#
			# Write disk.csv
			#
			$file = output_csv $esx.PSPath "disk.csv" $("Date," +
			"Disk Usage Avg (KB/sec)," +
			"Disk Usage Max (KB/sec)," +
			"Disk Usage Min (KB/sec)," +
			"Disk Read Ratio (%)," +
			"Disk Write Ratio (%)," +
			"Disk Total Latency (ms)")

			$esxtable.GetEnumerator() | Sort-Object Name | % {
				$disk_rw = [float]$_.Value['disk.read.average']['avg'] +
					[float]$_.Value['disk.write.average']['avg']  
					
				$disk_r = $disk_w = ''
				if($disk_rw -gt 0) {
					$disk_r = ([float]$_.Value['disk.read.average']['avg'])*100/$disk_rw
					$disk_w = ([float]$_.Value['disk.write.average']['avg'])*100/$disk_rw
				}

				append_csv $file $("{0},{1},{2},{3},{4},{5},{6}" -f $(Get-date -date $_.Name -format d),
					$_.Value['disk.usage.average']['avg'],
					$_.Value['disk.usage.average']['max'],
					$_.Value['disk.usage.average']['min'],
					$disk_r, $disk_w,
					$_.Value['disk.maxtotallatency.latest']['avg'])
			}

			#
			# Write net.csv
			#
			$file = output_csv $esx.PSPath "net.csv" $("Date," +
			"Network Usage Avg (Mbps)," +
			"Network Usage Max (Mbps)," +
			"Network Usage Min (Mbps)," +
			"Receive Ratio (%)," +
			"Transmit Ratio (%)")
			$esxtable.GetEnumerator() | Sort-Object Name | % {
				$net_rw = [float]$_.Value['net.received.average']['avg'] +
					[float]$_.Value['net.transmitted.average']['avg']  
					
				$net_r = $net_w = ''
				if($net_rw -gt 0) {
					$net_r = ([float]$_.Value['net.received.average']['avg'])*100/$net_rw
					$net_w = ([float]$_.Value['net.transmitted.average']['avg'])*100/$net_rw
				}

				append_csv $file $("{0},{1},{2},{3},{4},{5}" -f $(Get-date -date $_.Name -format d),
					(format_MB($_.Value['net.usage.average']['avg'])),
					(format_MB($_.Value['net.usage.average']['max'])),
					(format_MB($_.Value['net.usage.average']['min'])),
					$net_r, $net_w)
			}
		}
	}
}

function vm_daily_count {
	foreach_cluster | % {
		$cluster = $_
		$table = @{}
		foreach_vm $cluster | % {
			$vm = $_
			[xml]$vi = Get-Content "$($vm.PSPath)\vminfo.xml"
			$memsz = [int]$vi.vm.MemoryMB
			$file = data2view "$($vm.PSPath)\mem.usage.average\daily_latest.csv"
			Import-Csv $file | % {
				if($_.max -gt 0) {
					if(!$table[$_.time]) {$table[$_.time] = @{count=0; memsz=0;}}
					$table[$_.time].count += 1
					$table[$_.time].memsz += $memsz
				}
			}
		}
		$file = output_csv $cluster.PSPath "vm_daily_count.csv" "time,count,memsz"
		$table.GetEnumerator() | Sort-Object Name | Select-Object -Last 92 | % {
			append_csv $file "$(Get-date -date $_.Name -format d),$($_.Value.count),$($_.Value.memsz)"
		}
	}
}

function vm_cpu_breakdown {
	foreach_cluster  | % {
		$cluster = $_
		$table = @{}
		1,2,4,8 | % {
			$vcpu = $_
			$table[$vcpu] = @{}
			build_day_list | % {
				$table[$vcpu][$_] = @{sum=0; cnt=0; cr_sum=0; cr_cnt=0}
			}
		}
		foreach_vm $cluster  | % {
			$vm = $_
			[xml]$vi = Get-Content "$($vm.PSPath)\vminfo.xml"
			$vcpu = [int]$vi.vm.NumCpu
			
			$file = data2view "$($vm.PSPath)\cpu.usage.average\daily_latest.csv"
			Import-Csv $file | % {
				if($_.avg) {
					$t1 = mkdate_daily(Get-Date -date $_.time)
					$table[$vcpu][$t1].sum += [float]$_.avg
					$table[$vcpu][$t1].cnt += 1
				}
			}
			$file = data2view "$($vm.PSPath)\cpu.ready.summation\daily_latest.csv"
			Import-Csv $file | % {
				if($_.avg) {
					$t1 = mkdate_daily(Get-Date -date $_.time)
					$table[$vcpu][$t1].cr_sum += [float]$_.avg
					$table[$vcpu][$t1].cr_cnt += 1
				}
			}
		}
		$file = output_csv $cluster.PSPath "vm_cpu_breakdown.csv" "cpu,min,max,avg,cpuready"
		1,2,4,8 | %{
			$vcpu = $_
			$min = 100
			$max = $sum = $cnt = $cr_sum = $cr_cnt = 0
			
			$table[$vcpu].GetEnumerator() | Sort-Object Name | % {
				$v = $_.Value
				if($v.cnt -gt 0 -and $v.cr_cnt -gt 0) {
					$tavg = $v.sum/$v.cnt
					if($min -gt $tavg) {$min = $tavg}
					if($max -lt $tavg) {$max = $tavg}
					$sum += $v.sum
					$cnt += $v.cnt
					$cr_sum += $v.cr_sum
					$cr_cnt += $v.cr_cnt
				}
			}
			if($cnt -gt 0 -and $cr_cnt -gt 0) {
				append_csv $file "$($vcpu),$min,$max,$($sum/$cnt),$($cr_sum/$cr_cnt)"
			}
			else {
				append_csv $file "$($vcpu),,,,"
			}
		}
	}
}

# Determine view tree root
$VIEWFINISH = Get-date
$VIEWSTART = $VIEWFINISH.AddDays(-1 * 91)
 
if ($args[0] -eq "-start") {
	$VIEWSTART = Get-Date -Date $args[1]
	$VIEWFINISH = $VIEWSTART.AddDays(91)
}

$VIEWROOT = "$VTILVIEW\{0:D4}{1:D2}{2:D2}-{3:D4}{4:D2}{5:D2}" -f 
	$VIEWSTART.Year, $VIEWSTART.Month, $VIEWSTART.Day, 
	$VIEWFINISH.Year, $VIEWFINISH.Month, $VIEWFINISH.Day 

host_daily
# >> HOST/COUNTER/daily_latest.csv

host_weekly
# >> HOST/COUNTER/weekly_latest.csv

cluster_daily
# >> CLUSTER/COUNTER/daily_latest.csv

vm_daily
# >> CLUSTER/VM/daily_latest.csv

# << CLUSTER/VM/mem.usage.average/daily_latest.csv
vm_daily_count
# >> CLUSTER/vm_daily_count.csv

# << HOST/COUNTER/daily_latest.csv
host_report
# >> *HOST/cpu_memory.csv
# >> *HOST/memory.csv
# >> *HOST/disk.csv
# >> *HOST/net.csv

# << CLUSTER/COUNTER/daily_latest.csv
# << CLUSTER/vm_daily_count.csv
cluster_report
# >> *CLUSTER/cpu_memory.csv

# << CLUSTER/HOST/COUNTER/weekly_latest.csv
cluster_4weeks
# >> *CLUSTER/cpu.usage.average/4weeks_latest.csv
# >> *CLUSTER/mem.usage.average/4weeks_latest.csv
# >> *CLUSTER/disk.usage.average/4weeks_latest.csv

# << CLUSTER/VM/cpu.usage.average/daily_latest.csv
# << CLUSTER/VM/cpu.ready.summation/daily_latest.csv
vm_cpu_breakdown
# >> *CLUSTER/vm_cpu_breakdown.csv




