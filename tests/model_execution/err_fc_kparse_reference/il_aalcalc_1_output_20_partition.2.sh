#!/bin/bash
SCRIPT=$(readlink -f "$0") && cd $(dirname "$SCRIPT")

# --- Script Init ---
set -euET -o pipefail
shopt -s inherit_errexit 2>/dev/null || echo "WARNING: Unable to set inherit_errexit. Possibly unsupported by this shell, Subprocess failures may not be detected."

mkdir -p log
rm -R -f log/*


touch log/stderror.err
ktools_monitor.sh $$ & pid0=$!

exit_handler(){
   exit_code=$?

   # disable handler
   trap - QUIT HUP INT KILL TERM ERR EXIT

   kill -9 $pid0 2> /dev/null
   if [ "$exit_code" -gt 0 ]; then
       # Error - run process clean up
       echo 'Ktools Run Error - exitcode='$exit_code

       set +x
       group_pid=$(ps -p $$ -o pgid --no-headers)
       sess_pid=$(ps -p $$ -o sess --no-headers)
       script_pid=$$
       printf "Script PID:%d, GPID:%s, SPID:%d
" $script_pid $group_pid $sess_pid >> log/killout.txt

       ps -jf f -g $sess_pid > log/subprocess_list
       PIDS_KILL=$(pgrep -a --pgroup $group_pid | awk 'BEGIN { FS = "[ \t\n]+" }{ if ($1 >= '$script_pid') print}' | grep -v celery | egrep -v *\\.log$  | egrep -v *\\.sh$ | sort -n -r)
       echo "$PIDS_KILL" >> log/killout.txt
       kill -9 $(echo "$PIDS_KILL" | awk 'BEGIN { FS = "[ \t\n]+" }{ print $1 }') 2>/dev/null
       exit $exit_code
   else
       # script successful
       exit 0
   fi
}
trap exit_handler QUIT HUP INT KILL TERM ERR EXIT

check_complete(){
    set +e
    proc_list="eve getmodel gulcalc fmcalc summarycalc eltcalc aalcalc leccalc pltcalc ordleccalc"
    has_error=0
    for p in $proc_list; do
        started=$(find log -name "$p*.log" | wc -l)
        finished=$(find log -name "$p*.log" -exec grep -l "finish" {} + | wc -l)
        if [ "$finished" -lt "$started" ]; then
            echo "[ERROR] $p - $((started-finished)) processes lost"
            has_error=1
        elif [ "$started" -gt 0 ]; then
            echo "[OK] $p"
        fi
    done
    if [ "$has_error" -ne 0 ]; then
        false # raise non-zero exit code
    else
        echo 'Run Completed'
    fi
}
# --- Setup run dirs ---

find output -type f -not -name '*summary-info*' -not -name '*.json' -exec rm -R -f {} +
mkdir output/full_correlation/

rm -R -f fifo/*
mkdir fifo/full_correlation/
rm -R -f work/*
mkdir work/kat/
mkdir work/full_correlation/
mkdir work/full_correlation/kat/

mkdir work/il_S1_summaryaalcalc
mkdir work/full_correlation/il_S1_summaryaalcalc

mkfifo fifo/full_correlation/gul_fc_P3

mkfifo fifo/il_P3

mkfifo fifo/il_S1_summary_P3
mkfifo fifo/il_S1_summary_P3.idx

mkfifo fifo/full_correlation/il_P3

mkfifo fifo/full_correlation/il_S1_summary_P3
mkfifo fifo/full_correlation/il_S1_summary_P3.idx



# --- Do insured loss computes ---
tee < fifo/il_S1_summary_P3 work/il_S1_summaryaalcalc/P3.bin > /dev/null & pid1=$!
tee < fifo/il_S1_summary_P3.idx work/il_S1_summaryaalcalc/P3.idx > /dev/null & pid2=$!
( summarycalc -m -f  -1 fifo/il_S1_summary_P3 < fifo/il_P3 ) 2>> log/stderror.err  &

# --- Do insured loss computes ---
tee < fifo/full_correlation/il_S1_summary_P3 work/full_correlation/il_S1_summaryaalcalc/P3.bin > /dev/null & pid3=$!
tee < fifo/full_correlation/il_S1_summary_P3.idx work/full_correlation/il_S1_summaryaalcalc/P3.idx > /dev/null & pid4=$!
( summarycalc -m -f  -1 fifo/full_correlation/il_S1_summary_P3 < fifo/full_correlation/il_P3 ) 2>> log/stderror.err  &

( fmcalc -a2 < fifo/full_correlation/gul_fc_P3 > fifo/full_correlation/il_P3 ) 2>> log/stderror.err &
( eve 3 20 | getmodel | gulcalc -S100 -L100 -r -j fifo/full_correlation/gul_fc_P3 -a1 -i - | fmcalc -a2 > fifo/il_P3  ) 2>> log/stderror.err &

wait $pid1 $pid2 $pid3 $pid4


# --- Do insured loss kats ---


# --- Do insured loss kats for fully correlated output ---


check_complete
