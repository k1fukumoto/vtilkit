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

function mkdate_daily($day) {
	get-date -Date ("{0}/{1}/{2}" -f $day.Year,$day.Month,$day.Day)
}

function build_week_list() {
	$today = Get-Date
	$sunday = $today.AddDays(-1 * $today.DayOfWeek)
	$sunday = mkdate_daily($sunday)

	$arr = , $sunday
	foreach($i in 1..12) {
		$sunday = $sunday.AddDays(-7)
		$arr += , $sunday
	}
	$arr = $arr | Sort-Object
	return $arr
}

function build_day_list() {
	$d = mkdate_daily(Get-Date)
	$arr = , $d
	foreach($i in 1..91) {
		$d = $d.AddDays(-1)
		$arr += , $d
	}
	$arr = $arr | Sort-Object
	return $arr
}

function weekly_rollup($ci) {
	Dir $ci.PSPath -Exclude "*.xml","*.csv" | % {
		$counter = $_
		$cpath = $counter.PSPath
		$file = "$($cpath)\weekly_latest.csv"
		"time,min,max,avg" | Out-File $file -Encoding ASCII
	
		$table = @{}		
		$bitmap = @{}
		Dir "$($cpath)\1day_*.csv","$($cpath)\2hours_*.csv","$($cpath)\30mins_*.csv" -Exclude "*.xml" | % {
			"$(Get-Date): $($ci.Name): $($counter.Name): $($_.Name)" | Out-File $LOG -Append -Encoding ASCII
		
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
				"$(Get-date -date $_ -format d),,," | Out-File $file -Append -Encoding ASCII
			}
			else {
				($min,$max,$avg) = rollup($table[$_])
				"$(Get-date -date $_ -format d),$min,$max,$avg" | Out-File $file -Append -Encoding ASCII
			}
		}
	}
}

function daily_rollup($ci) {
	Dir $ci.PSPath -Exclude "*.xml","*.csv" | % {
		$counter = $_
		$cpath = $counter.PSPath
		$file = "$($cpath)\daily_latest.csv"
		"time,min,max,avg" | Out-File $file -Encoding ASCII
	
		$table = @{}		
		$bitmap = @{}
		Dir "$($cpath)\1day_*.csv","$($cpath)\2hours_*.csv","$($cpath)\30mins_*.csv" -Exclude "*.xml","vm","host" | % {
			"$(Get-Date): $($ci.Name): $($counter.Name): $($_.Name)" | Out-File $LOG -Append -Encoding ASCII
		
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
				"$(Get-date -date $_ -format d),,," | Out-File $file -Append -Encoding ASCII
			}
			else {
				($min,$max,$avg) = rollup($table[$_])
				"$(Get-date -date $_ -format d),$min,$max,$avg" | Out-File $file -Append -Encoding ASCII
			}
		}
	}
}

function host_weekly() {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		Dir "$($_.PSPath)\host" -Exclude "*.xml","*.csv" | % {
			weekly_rollup($_)
		}
	}
}

function host_daily() {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		Dir "$($_.PSPath)\host" -Exclude "*.xml","*.csv" | % {
			daily_rollup($_)
		}
	}
}

function vm_weekly {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv"| % {
		Dir "$($_.PSPath)\vm" -Exclude "*.xml","*.csv" | % {
			weekly_rollup($_)
		}
	}
}

function vm_daily {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		Dir "$($_.PSPath)\vm" -Exclude "*.xml","*.csv" | % {
			daily_rollup($_)
		}
	}
}

function cluster_daily {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		daily_rollup($_)
	}
}

function cluster_4weeks() {
	$cntr_4weeks = 'mem.usage.average','cpu.usage.average','disk.usage.average'
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		$cluster = $_
		$table = @()
		Dir "$($_.PSPath)\host" -Exclude "*.csv","*.xml" | % {
			$esx = $_
			 $cntr_4weeks | % {
				$counter = $_
				Import-Csv "$($esx.PSPath)\$counter\weekly_latest.csv" | % {
					$_ | Add-Member -MemberType NoteProperty -Name esx -Value $esx.Name
					$_ | Add-Member -MemberType NoteProperty -Name counter -Value $counter
					$table += $_
				}
			}
		}

		$cntr_4weeks | % {
			$counter = $_

			$outdir = "$($cluster.PSPath)\$($counter)"
			if(-not (Test-Path $outdir)) {
				New-Item $outdir -Type directory | Out-Null
			}
			
			$file = "$outdir\4weeks_latest.csv"
			"esx,4 weeks ago,3 weeks ago,2 weeks ago,last week" | Out-File $file -Encoding ASCII
			$table | where {$_.counter -eq $counter} | Group-Object esx | Sort-Object Name | % {
				$row = "$($_.Name)"
				$_.Group | Sort-Object time | Select-Object -Last 4 | % {
					$row += ",$($_.avg)"
				}
				$row | Out-File $file -Append -Encoding ASCII
			}
		}
	}
}

function cluster_report() {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		$cluster = $_
		$table = @{}
		
		"mem.vmmemctl.average","mem.swapused.average" | % {
			$counter = $_
			Dir "$($cluster.PSPath)\host" -Exclude "*.xml","*.csv" | % {
				$esx = $_
				$file = "$($esx.PSPath)\$counter\daily_latest.csv"
				Import-Csv $file  | % {
					$t1 = Get-date -Date $_.time
					$t2 = mkdate_daily($t1)
					if(!$table[$t2]) {$table[$t2]=@{}}
					$table[$t2][$counter] += [int]$_.max
				}			
			}
		}
		
		$DBINFO.counters.cluster.counter | % {
			$counter = $_
			$file = "$($cluster.PSPath)\$($counter.name)\daily_latest.csv"
			"$(Get-Date): $($cluster.Name): $($counter.name)" | Out-File $LOG -Append -Encoding ASCII
			
			Import-Csv $file  | % {
				$t1 = Get-date -Date $_.time
				$t2 = mkdate_daily($t1)
				if(!$table[$t2]) {$table[$t2]=@{}}
				$table[$t2][$counter.name] = $_.avg
			}
		}
		
		Import-Csv "$($cluster.PSPath)\vm_daily_count.csv" | % {
			$t1 = Get-date -Date $_.time
			$t2 = mkdate_daily($t1)
			if(!$table[$t2]) {$table[$t2]=@{}}
			$table[$t2]['numPowerOnVM'] = $_.count
			$table[$t2]['szPowerOnVM'] = $_.memsz
		}

		$file = "$($cluster.PSPath)\cpu_memory.csv"
		"Date,Effective CPU (MHz),Effective Mem (MB),Power ON VMs,Power ON VMs Mem (MB),CPU Usage (MHz),CPU Usage (%),Mem Consumed (KB),Mem Overhead (KB),Mem Baloon (MB),Mem Swap (MB)" |
			Out-File $file -Encoding ASCII
		
		$table.GetEnumerator() | Sort-Object Name | % {
			"{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}" -f 
				$(Get-date -date $_.Name -format d),
				$_.Value['clusterServices.effectivecpu.average'],
				$_.Value['clusterServices.effectivemem.average'],
				$_.Value['numPowerOnVM'],
				$_.Value['szPowerOnVM'],
				$_.Value['cpu.usagemhz.average'],
				$_.Value['cpu.usage.average'],
				$_.Value['mem.consumed.average'],
				$_.Value['mem.overhead.average'],
				(format_MB($_.Value['mem.vmmemctl.average'])),
				(format_MB($_.Value['mem.swapused.average'])) | Out-File $file -Append -Encoding ASCII
		}
	}
}

function format_MB($v) {
	if($v) {
		return "{0}" -f ([float]$v/1024)
	} 
	else {
		return ''
	}
}

function host_report() {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		Dir "$($_.PSPath)\host" -Exclude "*.csv","*.xml" | % {
			$esx = $_
			$table = @{}		
			$DBINFO.counters.host.counter | % {
				$counter = $_
				Dir "$($esx.PSPath)\$($counter.name)\daily_latest.csv" | % {
					"$(Get-Date): $($esx.Name): $($counter.name): $($_.Name)" | Out-File $LOG -Append -Encoding ASCII
				
					Import-Csv $_  | % {
						$t1 = Get-date -Date $_.time
						if(!$table[$t1]) {$table[$t1]=@{}}
						$table[$t1][$counter.name] = @{avg=$_.avg; min=$_.min; max=$_.max;}
					}
				}
			}

			$file = "$($esx.PSPath)\cpu_memory.csv"
			"Date,CPU Usage (MHz), CPU Usage (%),Mem Consumed (KB),Mem Usage (%)" |
				Out-File $file -Encoding ASCII
			
			$table.GetEnumerator() | Sort-Object Name | % {
				"{0},{1},{2},{3},{4}" -f 
					$(Get-date -date $_.Name -format d),
					$_.Value['cpu.usagemhz.average']['avg'],
					$_.Value['cpu.usage.average']['avg'],
					$_.Value['mem.consumed.average']['avg'],
					$_.Value['mem.usage.average']['avg'] | Out-File $file -Append -Encoding ASCII
			}

			$file = "$($esx.PSPath)\memory.csv"
			"Date,Mem Consumed Avg (MB)," +
			"Mem Consumed Max(MB)," +
			"Mem Consumed Min (MB)," +
			"Active Memory (MB)," +
			"Mem Shared Common (MB)," +
			"Balloon Memory Max (MB)," +
			"Swap Memory Max (MB)," +
			"Granted Memory (MB)" |
				Out-File $file -Encoding ASCII
			
			$table.GetEnumerator() | Sort-Object Name | % {
				"{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f $(Get-date -date $_.Name -format d),
					(format_MB($_.Value['mem.consumed.average']['avg'])),
					(format_MB($_.Value['mem.consumed.average']['max'])),
					(format_MB($_.Value['mem.consumed.average']['min'])),
					(format_MB($_.Value['mem.active.average']['avg'])),
					(format_MB($_.Value['mem.shared.average']['avg'])),
					(format_MB($_.Value['mem.vmmemctl.average']['max'])),
					(format_MB($_.Value['mem.swapused.average']['max'])),
					(format_MB($_.Value['mem.granted.average']['max'])) |
					Out-File $file -Append -Encoding ASCII
			}

			$file = "$($esx.PSPath)\disk.csv"
			"Date,Disk Usage Avg(KB/sec), Disk Usage Max (KB/sec),Disk Usage Min (KB/sec), Disk Read Ratio(%), Disk Write Ratio(%), Disk Total Latency (ms)" |
				Out-File $file -Encoding ASCII
			
			$table.GetEnumerator() | Sort-Object Name | % {
				$disk_rw = [float]$_.Value['disk.read.average']['avg'] +
					[float]$_.Value['disk.write.average']['avg']  
					
				$disk_r = $disk_w = ''
				if($disk_rw -gt 0) {
					$disk_r = ([float]$_.Value['disk.read.average']['avg'])*100/$disk_rw
					$disk_w = ([float]$_.Value['disk.write.average']['avg'])*100/$disk_rw
				}

				"{0},{1},{2},{3},{4},{5},{6}" -f $(Get-date -date $_.Name -format d),
					$_.Value['disk.usage.average']['avg'],
					$_.Value['disk.usage.average']['max'],
					$_.Value['disk.usage.average']['min'],
					$disk_r, $disk_w,
					$_.Value['disk.maxtotallatency.latest']['avg'] |
					Out-File $file -Append -Encoding ASCII
			}

			$file = "$($esx.PSPath)\net.csv"
			"Date,Network Usage Avg(Mbps), Network Usage Max (Mbps),Network Usage Min (Mbps), Receive Ratio(%), Transmit Ratio(%)" |
				Out-File $file -Encoding ASCII
			
			$table.GetEnumerator() | Sort-Object Name | % {
				$net_rw = [float]$_.Value['net.received.average']['avg'] +
					[float]$_.Value['net.transmitted.average']['avg']  
					
				$net_r = $net_w = ''
				if($net_rw -gt 0) {
					$net_r = ([float]$_.Value['net.received.average']['avg'])*100/$net_rw
					$net_w = ([float]$_.Value['net.transmitted.average']['avg'])*100/$net_rw
				}

				"{0},{1},{2},{3},{4},{5}" -f $(Get-date -date $_.Name -format d),
					(format_MB($_.Value['net.usage.average']['avg'])),
					(format_MB($_.Value['net.usage.average']['max'])),
					(format_MB($_.Value['net.usage.average']['min'])),
					$net_r, $net_w |
					Out-File $file -Append -Encoding ASCII
			}
		}
	}
}

function cluster_inventory() {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		$cluster = $_
		$table = @{}
		Dir "$($_.PSPath)\host" -Exclude "*.xml","*.csv" | % {
			$esx = $_
			[xml]$ei = Get-Content "$($esx.PSPath)\esxinfo.xml"
			$table[$ei.esx.name] = $ei.esx.CpuTotalMhz, $ei.esx.MemoryTotalMB
		}

		$file = "$($cluster.PSPath)\vmhosts.csv"
		"esx,cpu,memory" | Out-File $file -Encoding ASCII
		$table.GetEnumerator() | sort-object Name | % {
			"$($_.Name),$($_.Value[0]),$($_.Value[1])" | Out-File $file -Append -Encoding ASCII 
		}
	}
}

function vm_daily_count {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		$cluster = $_
		$table = @{}
		Dir "$($cluster.PSPath)\vm" -Exclude "*.xml","*.csv" | % {
			$vm = $_
			[xml]$vi = Get-Content "$($vm.PSPath)\vminfo.xml"
			$memsz = [int]$vi.vm.MemoryMB
			$file = "$($vm.PSPath)\mem.usage.average\daily_latest.csv"
			Import-Csv $file | % {
				if($_.max -gt 0) {
					if(!$table[$_.time]) {$table[$_.time] = @{count=0; memsz=0;}}
					$table[$_.time].count += 1
					$table[$_.time].memsz += $memsz
				}
			}
		}
		$file = "$($cluster.PSPath)\vm_daily_count.csv"
		"time,count,memsz" | Out-File $file -Encoding ASCII
		$table.GetEnumerator() | Sort-Object Name | Select-Object -Last 92 | % {
			"$(Get-date -date $_.Name -format d),$($_.Value.count),$($_.Value.memsz)" | 
				Out-File $file -Append -Encoding ASCII
		}
	}
}

function vm_cpu_breakdown {
	Dir "$VTILDATA\cluster" -Exclude "*.xml","*.csv" | % {
		$cluster = $_
		$table = @{}
		1,2,4,8 | % {
			$vcpu = $_
			$table[$vcpu] = @{}
			build_day_list | % {
				$table[$vcpu][$_] = @{sum=0; cnt=0; cr_sum=0; cr_cnt=0}
			}
		}
		Dir "$($cluster.PSPath)\vm" -Exclude "*.xml","*.csv" | % {
			$vm = $_
			[xml]$vi = Get-Content "$($vm.PSPath)\vminfo.xml"
			$vcpu = [int]$vi.vm.NumCpu
			
			$file = "$($vm.PSPath)\cpu.usage.average\daily_latest.csv"
			Import-Csv $file | % {
				if($_.avg) {
					$t1 = mkdate_daily(Get-Date -date $_.time)
					$table[$vcpu][$t1].sum += [float]$_.avg
					$table[$vcpu][$t1].cnt += 1
				}
			}
			$file = "$($vm.PSPath)\cpu.ready.summation\daily_latest.csv"
			Import-Csv $file | % {
				if($_.avg) {
					$t1 = mkdate_daily(Get-Date -date $_.time)
					$table[$vcpu][$t1].cr_sum += [float]$_.avg
					$table[$vcpu][$t1].cr_cnt += 1
				}
			}
		}
		$file = "$($cluster.PSPath)\vm_cpu_breakdown.csv"
		"cpu,min,max,avg,cpuready" | Out-File $file -Encoding ASCII
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
				"$($vcpu),$min,$max,$($sum/$cnt),$($cr_sum/$cr_cnt)" | 
						Out-File $file -Append -Encoding ASCII
			}
			else {
				"$($vcpu),,,," | Out-File $file -Append -Encoding ASCII
			}
		}
	}
}

host_daily
host_weekly
vm_daily
vm_daily_count
vm_cpu_breakdown
cluster_daily
cluster_4weeks

host_report
cluster_report
