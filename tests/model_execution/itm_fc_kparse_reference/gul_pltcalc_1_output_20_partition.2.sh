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
mkdir -p output/full_correlation/

find fifo/ \( -name '*P3[^0-9]*' -o -name '*P3' \) -exec rm -R -f {} +
mkdir -p fifo/full_correlation/
find work/ \( -name '*P3[^0-9]*' -o -name '*P3' \) -exec rm -R -f {} +
mkdir -p work/kat/
mkdir -p work/full_correlation/
mkdir -p work/full_correlation/kat/


mkfifo fifo/gul_P3

mkfifo fifo/gul_S1_summary_P3
mkfifo fifo/gul_S1_pltcalc_P3

mkfifo fifo/full_correlation/gul_P3

mkfifo fifo/full_correlation/gul_S1_summary_P3
mkfifo fifo/full_correlation/gul_S1_pltcalc_P3



# --- Do ground up loss computes ---
pltcalc -H < fifo/gul_S1_pltcalc_P3 > work/kat/gul_S1_pltcalc_P3 & pid1=$!
tee < fifo/gul_S1_summary_P3 fifo/gul_S1_pltcalc_P3 > /dev/null & pid2=$!
summarycalc -m -i  -1 fifo/gul_S1_summary_P3 < fifo/gul_P3 &

# --- Do ground up loss computes ---
pltcalc -H < fifo/full_correlation/gul_S1_pltcalc_P3 > work/full_correlation/kat/gul_S1_pltcalc_P3 & pid3=$!
tee < fifo/full_correlation/gul_S1_summary_P3 fifo/full_correlation/gul_S1_pltcalc_P3 > /dev/null & pid4=$!
summarycalc -m -i  -1 fifo/full_correlation/gul_S1_summary_P3 < fifo/full_correlation/gul_P3 &

eve 3 20 | getmodel | gulcalc -S100 -L100 -r -j fifo/full_correlation/gul_P3 -a1 -i - > fifo/gul_P3  &

wait $pid1 $pid2 $pid3 $pid4


# --- Do ground up loss kats ---

kat work/kat/gul_S1_pltcalc_P3 > output/gul_S1_pltcalc.csv & kpid1=$!

# --- Do ground up loss kats for fully correlated output ---

kat work/full_correlation/kat/gul_S1_pltcalc_P3 > output/full_correlation/gul_S1_pltcalc.csv & kpid2=$!
wait $kpid1 $kpid2

