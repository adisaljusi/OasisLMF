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

find fifo/ \( -name '*P11[^0-9]*' -o -name '*P11' \) -exec rm -R -f {} +
mkdir -p fifo/full_correlation/
rm -R -f work/*
mkdir -p work/kat/
mkdir -p work/full_correlation/
mkdir -p work/full_correlation/kat/

mkdir -p work/gul_S1_summaryleccalc
mkdir -p work/gul_S1_summaryaalcalc
mkdir -p work/full_correlation/gul_S1_summaryleccalc
mkdir -p work/full_correlation/gul_S1_summaryaalcalc
mkdir -p work/il_S1_summaryleccalc
mkdir -p work/il_S1_summaryaalcalc
mkdir -p work/full_correlation/il_S1_summaryleccalc
mkdir -p work/full_correlation/il_S1_summaryaalcalc

mkfifo fifo/full_correlation/gul_fc_P11

mkfifo fifo/gul_P11

mkfifo fifo/gul_S1_summary_P11
mkfifo fifo/gul_S1_summary_P11.idx
mkfifo fifo/gul_S1_eltcalc_P11
mkfifo fifo/gul_S1_summarycalc_P11
mkfifo fifo/gul_S1_pltcalc_P11

mkfifo fifo/il_P11

mkfifo fifo/il_S1_summary_P11
mkfifo fifo/il_S1_summary_P11.idx
mkfifo fifo/il_S1_eltcalc_P11
mkfifo fifo/il_S1_summarycalc_P11
mkfifo fifo/il_S1_pltcalc_P11

mkfifo fifo/full_correlation/gul_P11

mkfifo fifo/full_correlation/gul_S1_summary_P11
mkfifo fifo/full_correlation/gul_S1_summary_P11.idx
mkfifo fifo/full_correlation/gul_S1_eltcalc_P11
mkfifo fifo/full_correlation/gul_S1_summarycalc_P11
mkfifo fifo/full_correlation/gul_S1_pltcalc_P11

mkfifo fifo/full_correlation/il_P11

mkfifo fifo/full_correlation/il_S1_summary_P11
mkfifo fifo/full_correlation/il_S1_summary_P11.idx
mkfifo fifo/full_correlation/il_S1_eltcalc_P11
mkfifo fifo/full_correlation/il_S1_summarycalc_P11
mkfifo fifo/full_correlation/il_S1_pltcalc_P11



# --- Do insured loss computes ---
eltcalc -s < fifo/il_S1_eltcalc_P11 > work/kat/il_S1_eltcalc_P11 & pid1=$!
summarycalctocsv -s < fifo/il_S1_summarycalc_P11 > work/kat/il_S1_summarycalc_P11 & pid2=$!
pltcalc -H < fifo/il_S1_pltcalc_P11 > work/kat/il_S1_pltcalc_P11 & pid3=$!
tee < fifo/il_S1_summary_P11 fifo/il_S1_eltcalc_P11 fifo/il_S1_summarycalc_P11 fifo/il_S1_pltcalc_P11 work/il_S1_summaryaalcalc/P11.bin work/il_S1_summaryleccalc/P11.bin > /dev/null & pid4=$!
tee < fifo/il_S1_summary_P11.idx work/il_S1_summaryaalcalc/P11.idx work/il_S1_summaryleccalc/P11.idx > /dev/null & pid5=$!
summarycalc -m -f  -1 fifo/il_S1_summary_P11 < fifo/il_P11 &

# --- Do ground up loss computes ---
eltcalc -s < fifo/gul_S1_eltcalc_P11 > work/kat/gul_S1_eltcalc_P11 & pid6=$!
summarycalctocsv -s < fifo/gul_S1_summarycalc_P11 > work/kat/gul_S1_summarycalc_P11 & pid7=$!
pltcalc -H < fifo/gul_S1_pltcalc_P11 > work/kat/gul_S1_pltcalc_P11 & pid8=$!
tee < fifo/gul_S1_summary_P11 fifo/gul_S1_eltcalc_P11 fifo/gul_S1_summarycalc_P11 fifo/gul_S1_pltcalc_P11 work/gul_S1_summaryaalcalc/P11.bin work/gul_S1_summaryleccalc/P11.bin > /dev/null & pid9=$!
tee < fifo/gul_S1_summary_P11.idx work/gul_S1_summaryaalcalc/P11.idx work/gul_S1_summaryleccalc/P11.idx > /dev/null & pid10=$!
summarycalc -m -i  -1 fifo/gul_S1_summary_P11 < fifo/gul_P11 &

# --- Do insured loss computes ---
eltcalc -s < fifo/full_correlation/il_S1_eltcalc_P11 > work/full_correlation/kat/il_S1_eltcalc_P11 & pid11=$!
summarycalctocsv -s < fifo/full_correlation/il_S1_summarycalc_P11 > work/full_correlation/kat/il_S1_summarycalc_P11 & pid12=$!
pltcalc -H < fifo/full_correlation/il_S1_pltcalc_P11 > work/full_correlation/kat/il_S1_pltcalc_P11 & pid13=$!
tee < fifo/full_correlation/il_S1_summary_P11 fifo/full_correlation/il_S1_eltcalc_P11 fifo/full_correlation/il_S1_summarycalc_P11 fifo/full_correlation/il_S1_pltcalc_P11 work/full_correlation/il_S1_summaryaalcalc/P11.bin work/full_correlation/il_S1_summaryleccalc/P11.bin > /dev/null & pid14=$!
tee < fifo/full_correlation/il_S1_summary_P11.idx work/full_correlation/il_S1_summaryaalcalc/P11.idx work/full_correlation/il_S1_summaryleccalc/P11.idx > /dev/null & pid15=$!
summarycalc -m -f  -1 fifo/full_correlation/il_S1_summary_P11 < fifo/full_correlation/il_P11 &

# --- Do ground up loss computes ---
eltcalc -s < fifo/full_correlation/gul_S1_eltcalc_P11 > work/full_correlation/kat/gul_S1_eltcalc_P11 & pid16=$!
summarycalctocsv -s < fifo/full_correlation/gul_S1_summarycalc_P11 > work/full_correlation/kat/gul_S1_summarycalc_P11 & pid17=$!
pltcalc -H < fifo/full_correlation/gul_S1_pltcalc_P11 > work/full_correlation/kat/gul_S1_pltcalc_P11 & pid18=$!
tee < fifo/full_correlation/gul_S1_summary_P11 fifo/full_correlation/gul_S1_eltcalc_P11 fifo/full_correlation/gul_S1_summarycalc_P11 fifo/full_correlation/gul_S1_pltcalc_P11 work/full_correlation/gul_S1_summaryaalcalc/P11.bin work/full_correlation/gul_S1_summaryleccalc/P11.bin > /dev/null & pid19=$!
tee < fifo/full_correlation/gul_S1_summary_P11.idx work/full_correlation/gul_S1_summaryaalcalc/P11.idx work/full_correlation/gul_S1_summaryleccalc/P11.idx > /dev/null & pid20=$!
summarycalc -m -i  -1 fifo/full_correlation/gul_S1_summary_P11 < fifo/full_correlation/gul_P11 &

tee < fifo/full_correlation/gul_fc_P11 fifo/full_correlation/gul_P11  | fmcalc -a2 > fifo/full_correlation/il_P11  &
eve 11 20 | getmodel | gulcalc -S100 -L100 -r -j fifo/full_correlation/gul_fc_P11 -a1 -i - | tee fifo/gul_P11 | fmcalc -a2 > fifo/il_P11  &

wait $pid1 $pid2 $pid3 $pid4 $pid5 $pid6 $pid7 $pid8 $pid9 $pid10 $pid11 $pid12 $pid13 $pid14 $pid15 $pid16 $pid17 $pid18 $pid19 $pid20

