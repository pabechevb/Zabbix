#!/bin/bash
declare -A FD_COUNT
declare -A WAIT_COUNT
declare -A CPU_TIME
for pid in /proc/[0-9]*; do
    PID="${pid##*/}"
    fdcount=0
    for fd in "$pid"/fd/*; do
        [[ -e "$fd" || -L "$fd" ]] && ((fdcount++))
    done
    FD_COUNT["$PID"]=$fdcount
done
for stat in /proc/[0-9]*/task/[0-9]*/stat; do
    PID="${stat#/proc/}"
    PID="${PID%%/*}"
    read -r line < "$stat" 2>/dev/null || continue
    STATE="${line#*) }"
    STATE="${STATE%% *}"
    case "$STATE" in
        S|D)
            ((WAIT_COUNT["$PID"]++))
            ;;
    esac
done
for stat in /proc/[0-9]*/stat; do
    PID="${stat#/proc/}"
    PID="${PID%/stat}"
    read -r line < "$stat" 2>/dev/null || continue
    rest="${line#*) }"
    read -r state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt utime stime _ <<< "$rest"
    CPU_TIME["$PID"]=$((utime + stime))
done
CLK_TCK=$(getconf CLK_TCK)
while read -r PID COMMAND RSS VSZ NLWP; do
    printf "%s %s %s %s %s %s %s\n" \
	    "$COMMAND" "${CPU_TIME[$PID]:-0}" "$RSS" "$VSZ" "$NLWP" "${FD_COUNT[$PID]:-0}" "${WAIT_COUNT[$PID]:-0}"
done < <(ps -eo pid,cmd:100,rss,vsz,nlwp --no-headers) |
awk -v clk="$CLK_TCK" '
{
    cmd = $1
	gsub(/^\[|\]$/, "", cmd)
    if (cmd ~ /^kworker\//) cmd = "kworker"
    else if (cmd ~ /^cpuhp\//) cmd = "cpuhp"
    else if (cmd ~ /^jbd2/) cmd = "jbd2"
    else if (cmd ~ /^kcs(-|$)/) cmd = "kcs"
    else if (cmd ~ /^ksoftirqd\//) cmd = "ksoftirqd"
    else if (cmd ~ /^migration\//) cmd = "migration"
    else if (cmd ~ /^scsi_eh_/) cmd = "scsi_eh"
    else if (cmd ~ /^scsi_tmf_/) cmd = "scsi_tmf"
    else if (cmd ~ /^scsi_scan_/) cmd = "scsi_scan"
    else if (cmd ~ /^scsi_/) cmd = "scsi"
    else if (cmd ~ /^veeam/) cmd = "veeam"
    else if (cmd ~ /^watchdog/) cmd = "watchdog"
    else if (cmd ~ /^xfs/) cmd = "xfs"
    cpu[cmd] += $2
    rss[cmd] += $3 * 1024
    vsz[cmd] += $4 * 1024
    threads[cmd] += $5
    fds[cmd] += $6
    wait[cmd] += $7
    procs[cmd]++
}
END {
    printf "[\n"
    first = 1
    for (cmd in procs) {
        if (cpu[cmd] == 0 && rss[cmd] == 0 && vsz[cmd] == 0)
            continue
        if (!first)
            printf ",\n"
        printf "  {\"PRG\":\"%s\",\"CPU\":%.2f,\"MEM\":%d,\"VMM\":%d,\"THR\":%d,\"HND\":%d,\"WTC\":%d}",
            cmd, cpu[cmd] / clk, rss[cmd], vsz[cmd], threads[cmd], fds[cmd], wait[cmd]
        first = 0
    }
    printf "\n]\n"
}'