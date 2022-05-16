#!/bin/bash
SCRIPT=$(readlink -f "$0") && cd $(dirname "$SCRIPT")

# --- Script Init ---
set -euET -o pipefail
shopt -s inherit_errexit 2>/dev/null || echo "WARNING: Unable to set inherit_errexit. Possibly unsupported by this shell, Subprocess failures may not be detected."

LOG_DIR=log
mkdir -p $LOG_DIR
rm -R -f $LOG_DIR/*

# --- Setup run dirs ---

find output -type f -not -name '*summary-info*' -not -name '*.json' -exec rm -R -f {} +

find /tmp/%FIFO_DIR%/fifo/ \( -name '*P18[^0-9]*' -o -name '*P18' \) -exec rm -R -f {} +
find work/ \( -name '*P18[^0-9]*' -o -name '*P18' \) -exec rm -R -f {} +
mkdir -p work/kat/


mkfifo /tmp/%FIFO_DIR%/fifo/il_P18

mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_summary_P18
mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_summarycalc_P18



# --- Do insured loss computes ---
summarycalctocsv -s < /tmp/%FIFO_DIR%/fifo/il_S1_summarycalc_P18 > work/kat/il_S1_summarycalc_P18 & pid1=$!
tee < /tmp/%FIFO_DIR%/fifo/il_S1_summary_P18 /tmp/%FIFO_DIR%/fifo/il_S1_summarycalc_P18 > /dev/null & pid2=$!
summarycalc -m -f  -1 /tmp/%FIFO_DIR%/fifo/il_S1_summary_P18 < /tmp/%FIFO_DIR%/fifo/il_P18 &

eve 18 20 | getmodel | gulcalc -S100 -L100 -r -a1 -i - | fmcalc -a2 > /tmp/%FIFO_DIR%/fifo/il_P18  &

wait $pid1 $pid2


# --- Do insured loss kats ---

kat work/kat/il_S1_summarycalc_P18 > output/il_S1_summarycalc.csv & kpid1=$!
wait $kpid1

