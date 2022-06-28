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

find /tmp/%FIFO_DIR%/fifo/ \( -name '*P4[^0-9]*' -o -name '*P4' \) -exec rm -R -f {} +
rm -R -f work/*
mkdir -p work/kat/

mkdir -p work/il_S1_summaryleccalc

mkfifo /tmp/%FIFO_DIR%/fifo/il_P4

mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_summary_P4
mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_summary_P4.idx



# --- Do insured loss computes ---
tee < /tmp/%FIFO_DIR%/fifo/il_S1_summary_P4 work/il_S1_summaryleccalc/P4.bin > /dev/null & pid1=$!
tee < /tmp/%FIFO_DIR%/fifo/il_S1_summary_P4.idx work/il_S1_summaryleccalc/P4.idx > /dev/null & pid2=$!
summarycalc -m -f  -1 /tmp/%FIFO_DIR%/fifo/il_S1_summary_P4 < /tmp/%FIFO_DIR%/fifo/il_P4 &

eve 4 20 | getmodel | gulcalc -S100 -L100 -r -a1 -i - | fmcalc -a2 > /tmp/%FIFO_DIR%/fifo/il_P4  &

wait $pid1 $pid2

