# -*- coding: utf-8 -*-

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

from builtins import open as io_open
from builtins import str

from future import standard_library
standard_library.install_aliases()

__all__ = [
    'get_gul_input_items',
    'write_coverages_file',
    'write_gulsummaryxref_file',
    'write_gul_input_files',
    'write_items_file',
    'write_complex_items_file'
]

import os
import multiprocessing
import sys

from itertools import (
    chain,
    product,
)
from future.utils import viewkeys

import pandas as pd

from ..utils.concurrency import (
    multithread,
    Task,
)
from ..utils.data import (
    get_dataframe,
    merge_dataframes,
)
from ..utils.defaults import get_default_exposure_profile
from ..utils.exceptions import OasisException
from ..utils.log import oasis_log
from ..utils.metadata import COVERAGE_TYPES
from ..utils.path import as_path
from .il_inputs import (
    get_sub_layer_calcrule_id,
    unified_fm_profile_by_level_and_term_group,
    unified_fm_terms_by_level_and_term_group,
    unified_id_terms,
)


@oasis_log
def get_gul_input_items(
    exposure_fp,
    keys_fp,
    exposure_profile=get_default_exposure_profile()
):
    """
    Generates and returns a Pandas dataframe of GUL input items.

    :param exposure_fp: OED source exposure file
    :type exposure_df: pandas.DataFrame

    :param keys_df: Keys data generated by a model lookup or some other source
    :type keys_df: pandas.DataFrame

    :param exposure_profile: OED source exposure profile
    :type exposure_profile: dict
    """
    #import ipdb; ipdb.set_trace()
    gul_inputs_df = pd.DataFrame()

    exposure_df = get_dataframe(
        src_fp=exposure_fp,
        col_dtypes={'LocNumber': 'str', 'AccNumber': 'str', 'PortNumber': 'str'},
        required_cols=(
            'LocNumber', 'AccNumber', 'PortNumber', 'CountryCode',
            'LocPerilsCovered',
            'BuildingTIV', 'OtherTIV', 'ContentsTIV', 'BITIV',),
        empty_data_error_msg='No exposure found in the source exposure (loc.) file'
    )
    keys_df = get_dataframe(
        src_fp=keys_fp,
        col_dtypes={'LocID': 'str'},
        empty_data_error_msg='No keys found in the keys file'
    )

    exppf = exposure_profile

    ufp = unified_fm_profile_by_level_and_term_group(profiles=(exppf,))

    if not ufp:
        raise OasisException(
            'Source exposure profile is possibly missing FM term information: '
            'FM term definitions for TIV, limit, deductible, attachment and/or share.'
        )

    id_terms = unified_id_terms(unified_profile_by_level_and_term_group=ufp)
    loc_id = id_terms['locid']
    acc_id = id_terms['accid']
    policy_num = id_terms['polid']
    portfolio_num = id_terms['portid']

    fm_levels = tuple(ufp)[1:]

    try:
        for df in [exposure_df, keys_df]:
            df['index'] = df.get('index', range(len(df)))

        expkeys_df = merge_dataframes(exposure_df, keys_df, left_on=loc_id, right_on='locid', how='outer')

        cov_level = min(fm_levels)

        cov_tivs = tuple(t for t in [ufp[cov_level][gid].get('tiv') for gid in ufp[cov_level]] if t)

        if not cov_tivs:
            raise OasisException('No coverage fields found in the source exposure profile - please check the source exposure (loc) profile')

        fm_terms = unified_fm_terms_by_level_and_term_group(unified_profile_by_level_and_term_group=ufp)[cov_level]

        group_id = 0
        prev_it_loc_id = -1
        item_id = 0
        zero_tiv_items = 0

        def positive_tiv_coverages(it):
            return [t for t in cov_tivs if it.get(t['ProfileElementName'].lower()) and it[t['ProfileElementName'].lower()] > 0 and t['CoverageTypeID'] == it['coveragetypeid']] or [0]

        def generate_items(group_id, prev_it_loc_id, item_id, zero_tiv_items):
            for _it, ptiv in chain((_it, ptiv) for _, _it in expkeys_df.iterrows() for _it, ptiv in product([_it], positive_tiv_coverages(_it))):
                if ptiv == 0:
                    zero_tiv_items += 1
                    continue

                item_id += 1
                if _it[loc_id] != prev_it_loc_id:
                    group_id += 1

                tiv_elm = ptiv['ProfileElementName'].lower()
                tiv = _it[tiv_elm]
                tiv_tgid = ptiv['FMTermGroupID']

                it = {
                    'item_id': item_id,
                    'loc_id': _it[loc_id],
                    'portfolio_num': _it[portfolio_num],
                    'acc_id': _it[acc_id],
                    'peril_id': _it['perilid'],
                    'model_data': _it.get('modeldata'),
                    'areaperil_id': -1 if _it.get('modeldata') else _it['areaperilid'],
                    'vulnerabilityid': -1 if _it.get('modeldata') else _it['vulnerabilityid'],
                    'coverage_type_id': _it['coveragetypeid'],
                    'coverage_id': item_id,
                    'is_bi_coverage': _it['coveragetypeid'] == COVERAGE_TYPES['bi']['id'],
                    'tiv_elm': tiv_elm,
                    'tiv': tiv,
                    'tiv_tgid': tiv_tgid,
                    'deductible': _it.get(fm_terms[tiv_tgid].get('deductible') or None) or 0.0,
                    'deductible_min': _it.get(fm_terms[tiv_tgid].get('deductiblemin') or None) or 0.0,
                    'deductible_max': _it.get(fm_terms[tiv_tgid].get('deductiblemax') or None) or 0.0,
                    'limit': _it.get(fm_terms[tiv_tgid].get('limit') or None) or 0.0,
                    'agg_id': item_id,
                    'group_id': group_id,
                    'summary_id': 1,
                    'summaryset_id': 1
                }

                if it['deductible'] < 1:
                    it['deductible'] *= it['tiv']
                if it['limit'] < 1:
                    it['limit'] *= it['tiv']
                it['calcrule_id'] = get_sub_layer_calcrule_id(
                    it['deductible'],
                    it['deductible_min'],
                    it['deductible_max'],
                    it['limit']
                )

                yield it

                prev_it_loc_id = _it[loc_id]

        gul_inputs_df = pd.DataFrame(data=[it for it in generate_items(group_id, prev_it_loc_id, item_id, zero_tiv_items)])
        gul_inputs_df['index'] = gul_inputs_df.index
    except (AttributeError, KeyError, IndexError, TypeError, ValueError) as e:
        raise OasisException(e)
    else:
        if zero_tiv_items == len(expkeys_df):
            raise OasisException('All source exposure items have zero TIVs - please check the source exposure (loc.) file')

    try:
        for col in gul_inputs_df.columns:
            if col in ['peril_id', 'loc_id', 'acc_id', 'portfolio_num']:
                gul_inputs_df[col] = gul_inputs_df[col].astype(object)
            elif col.endswith('id') and not col.startswith('areaperil'):
                gul_inputs_df[col] = gul_inputs_df[col].astype(int)
            elif col == 'tiv':
                gul_inputs_df[col] = gul_inputs_df[col].astype(float)
    except (IOError, MemoryError, OasisException, OSError, TypeError, ValueError) as e:
        raise OasisException(e)

    return gul_inputs_df, exposure_df


def write_complex_items_file(gul_inputs_df, items_fp):
    """
    Writes an items file.
    """
    try:
        if "model_data" in gul_inputs_df.columns:
            gul_inputs_df.to_csv(
                columns=['item_id', 'coverage_id', 'model_data', 'group_id'],
                path_or_buf=items_fp,
                encoding='utf-8',
                chunksize=1000,
                index=False
            )
    except (IOError, OSError) as e:
        raise OasisException(e)


def write_items_file(gul_inputs_df, items_fp):
    """
    Writes an items file.
    """
    try:
        gul_inputs_df.to_csv(
            columns=['item_id', 'coverage_id', 'areaperil_id', 'vulnerability_id', 'group_id'],
            path_or_buf=items_fp,
            encoding='utf-8',
            chunksize=1000,
            index=False
        )
    except (IOError, OSError) as e:
        raise OasisException(e)

    return items_fp


def write_coverages_file(gul_inputs_df, coverages_fp):
    """
    Writes a coverages file.
    """
    try:
        gul_inputs_df.to_csv(
            columns=['coverage_id', 'tiv'],
            path_or_buf=coverages_fp,
            encoding='utf-8',
            chunksize=1000,
            index=False
        )
    except (IOError, OSError) as e:
        raise OasisException(e)

    return coverages_fp


def write_gulsummaryxref_file(gul_inputs_df, gulsummaryxref_fp):
    """
    Writes a gulsummaryxref file.
    """
    try:
        gul_inputs_df.to_csv(
            columns=['coverage_id', 'summary_id', 'summaryset_id'],
            path_or_buf=gulsummaryxref_fp,
            encoding='utf-8',
            chunksize=1000,
            index=False
        )
    except (IOError, OSError) as e:
        raise OasisException(e)

    return gulsummaryxref_fp


@oasis_log
def write_gul_input_files(
    exposure_fp,
    keys_fp,
    target_dir,
    exposure_profile=get_default_exposure_profile(),
    oasis_files_prefixes={
        'items': 'items',
        'complex_items': 'complex_items',        
        'coverages': 'coverages',
        'gulsummaryxref': 'gulsummaryxref'
    },
    write_inputs_table_to_file=False
):
    """
    Writes the standard Oasis GUL input files, namely::

        items.csv
        coverages.csv
        gulsummaryxref.csv
    """
    # Clean the target directory path
    target_dir = as_path(target_dir, 'Target IL input files directory', is_dir=True, preexists=False)

    gul_inputs_df, exposure_df = get_gul_input_items(exposure_fp, keys_fp, exposure_profile=exposure_profile)

    if write_inputs_table_to_file:
        gul_inputs_df.to_csv(path_or_buf=os.path.join(target_dir, 'gul_inputs.csv'), index=False, encoding='utf-8', chunksize=1000)

    gul_input_files = {
        k: os.path.join(target_dir, '{}.csv'.format(oasis_files_prefixes[k])) 
        for k in viewkeys(oasis_files_prefixes)
    }

    concurrent_tasks = (
        Task(
            getattr(sys.modules[__name__], 'write_{}_file'.format(f)), 
            args=(gul_inputs_df.copy(deep=True), gul_input_files[f],), key=f)
        for f in gul_input_files
    )
    num_ps = min(len(gul_input_files), multiprocessing.cpu_count())
    for _, _ in multithread(concurrent_tasks, pool_size=num_ps):
        pass

    return gul_input_files, gul_inputs_df, exposure_df
