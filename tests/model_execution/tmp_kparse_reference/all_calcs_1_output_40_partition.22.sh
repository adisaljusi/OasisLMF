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

find /tmp/%FIFO_DIR%/fifo/ \( -name '*P23[^0-9]*' -o -name '*P23' \) -exec rm -R -f {} +
rm -R -f work/*
mkdir -p work/kat/

mkdir -p work/gul_S1_summaryleccalc
mkdir -p work/gul_S1_summaryaalcalc
mkdir -p work/il_S1_summaryleccalc
mkdir -p work/il_S1_summaryaalcalc

mkfifo /tmp/%FIFO_DIR%/fifo/gul_P23

mkfifo /tmp/%FIFO_DIR%/fifo/gul_S1_summary_P23
mkfifo /tmp/%FIFO_DIR%/fifo/gul_S1_summary_P23.idx
mkfifo /tmp/%FIFO_DIR%/fifo/gul_S1_eltcalc_P23
mkfifo /tmp/%FIFO_DIR%/fifo/gul_S1_summarycalc_P23
mkfifo /tmp/%FIFO_DIR%/fifo/gul_S1_pltcalc_P23

mkfifo /tmp/%FIFO_DIR%/fifo/il_P23

mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_summary_P23
mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_summary_P23.idx
mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_eltcalc_P23
mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_summarycalc_P23
mkfifo /tmp/%FIFO_DIR%/fifo/il_S1_pltcalc_P23



# --- Do insured loss computes ---
eltcalc -s < /tmp/%FIFO_DIR%/fifo/il_S1_eltcalc_P23 > work/kat/il_S1_eltcalc_P23 & pid1=$!
summarycalctocsv -s < /tmp/%FIFO_DIR%/fifo/il_S1_summarycalc_P23 > work/kat/il_S1_summarycalc_P23 & pid2=$!
pltcalc -H < /tmp/%FIFO_DIR%/fifo/il_S1_pltcalc_P23 > work/kat/il_S1_pltcalc_P23 & pid3=$!
tee < /tmp/%FIFO_DIR%/fifo/il_S1_summary_P23 /tmp/%FIFO_DIR%/fifo/il_S1_eltcalc_P23 /tmp/%FIFO_DIR%/fifo/il_S1_summarycalc_P23 /tmp/%FIFO_DIR%/fifo/il_S1_pltcalc_P23 work/il_S1_summaryaalcalc/P23.bin work/il_S1_summaryleccalc/P23.bin > /dev/null & pid4=$!
tee < /tmp/%FIFO_DIR%/fifo/il_S1_summary_P23.idx work/il_S1_summaryaalcalc/P23.idx work/il_S1_summaryleccalc/P23.idx > /dev/null & pid5=$!
summarycalc -m -f  -1 /tmp/%FIFO_DIR%/fifo/il_S1_summary_P23 < /tmp/%FIFO_DIR%/fifo/il_P23 &

# --- Do ground up loss computes ---
eltcalc -s < /tmp/%FIFO_DIR%/fifo/gul_S1_eltcalc_P23 > work/kat/gul_S1_eltcalc_P23 & pid6=$!
summarycalctocsv -s < /tmp/%FIFO_DIR%/fifo/gul_S1_summarycalc_P23 > work/kat/gul_S1_summarycalc_P23 & pid7=$!
pltcalc -H < /tmp/%FIFO_DIR%/fifo/gul_S1_pltcalc_P23 > work/kat/gul_S1_pltcalc_P23 & pid8=$!
tee < /tmp/%FIFO_DIR%/fifo/gul_S1_summary_P23 /tmp/%FIFO_DIR%/fifo/gul_S1_eltcalc_P23 /tmp/%FIFO_DIR%/fifo/gul_S1_summarycalc_P23 /tmp/%FIFO_DIR%/fifo/gul_S1_pltcalc_P23 work/gul_S1_summaryaalcalc/P23.bin work/gul_S1_summaryleccalc/P23.bin > /dev/null & pid9=$!
tee < /tmp/%FIFO_DIR%/fifo/gul_S1_summary_P23.idx work/gul_S1_summaryaalcalc/P23.idx work/gul_S1_summaryleccalc/P23.idx > /dev/null & pid10=$!
summarycalc -m -i  -1 /tmp/%FIFO_DIR%/fifo/gul_S1_summary_P23 < /tmp/%FIFO_DIR%/fifo/gul_P23 &

eve 23 40 | getmodel | gulcalc -S100 -L100 -r -a1 -i - | tee /tmp/%FIFO_DIR%/fifo/gul_P23 | fmcalc -a2 > /tmp/%FIFO_DIR%/fifo/il_P23  &

wait $pid1 $pid2 $pid3 $pid4 $pid5 $pid6 $pid7 $pid8 $pid9 $pid10

