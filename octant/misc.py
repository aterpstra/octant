# -*- coding: utf-8 -*-
"""Miscellanea."""
from collections.abc import Iterable

import numpy as np

import xarray as xr

from .decor import get_pbar
from .exceptions import ArgumentError
from .utils import great_circle, mask_tracks

DENSITY_TYPES = ["point", "track", "genesis", "lysis"]


def _exclude_by_first_day(df, m, d):
    """Check if OctantTrack starts on certain day and month."""
    return not ((df.time.dt.month[0] == m).any() and (df.time.dt.day[0] == d).any())


def _exclude_by_last_day(df, m, d):
    """Check if OctantTrack ends on certain day and month."""
    return not ((df.time.dt.month[-1] == m).any() and (df.time.dt.day[-1] == d).any())


def calc_all_dens(tr_obj, lon2d, lat2d, subsets=None, density_types=DENSITY_TYPES, **kwargs):
    """
    Calculate all types of cyclone density for subsets of TrackRun.

    Parameters
    ----------
    lon2d: numpy.ndarray
        2D array of longitudes
    lat2d: numpy.ndarray
        2D array of latitudes
    subsets: list, optional
        Subsets of `TrackRun` to process. By default, all subsets are processed.
    density_types: list, optional
        Types of cyclone density
    **kwargs: dict
        Keyword arguments passed to `octant.core.TrackRun.density()`.
        Should not include `subset` and `by` keywords, because they are passed separately.

    Returns
    -------
    da: xarray.DataArray
       4d array with dimensions (subset, dens_type, latitude, longitude)

    """
    pbar = get_pbar()

    if subsets is None:
        if tr_obj.is_categorised:
            subsets = tr_obj.cat_labels
        else:
            subsets = None
    else:
        if not isinstance(subsets, Iterable) or isinstance(subsets, str):
            raise ArgumentError("`subsets` should be a sequence of strings")

    subset_dim = xr.DataArray(name="subset", dims=("subset"), data=subsets)
    dens_dim = xr.DataArray(name="dens_type", dims=("dens_type"), data=density_types)
    list1 = []
    for subset in pbar(subsets):  # , desc="subsets"):
        list2 = []
        for by in pbar(density_types):  # , desc="density_types"):
            list2.append(tr_obj.density(lon2d, lat2d, by=by, subset=subset, **kwargs))
        list1.append(xr.concat(list2, dim=dens_dim))
    da = xr.concat(list1, dim=subset_dim)
    return da.rename("density")


def bin_count_tracks(tr_obj, start_year, n_winters, by="M"):
    """
    Take `octant.TrackRun` and count cyclone tracks by month or by winter.

    Parameters
    ----------
    tr_obj: octant.core.TrackRun
        TrackRun object
    start_year: int
        Start year
    n_winters: int
        Number of years

    Returns
    -------
    counter: numpy.ndarray
        Binned counts of shape (N,)

    """
    pbar = get_pbar()

    if by.upper() == "M":
        counter = np.zeros(12, dtype=int)
        for _, df in pbar(tr_obj.gb, leave=False):  # , desc="tracks"):
            track_months = df.time.dt.month.unique()
            for m in track_months:
                counter[m - 1] += 1
    if by.upper() == "W":
        # winter
        counter = np.zeros(n_winters, dtype=int)
        for _, df in pbar(tr_obj.gb, leave=False):  # , desc="tracks"):
            track_months = df.time.dt.month.unique()
            track_years = df.time.dt.year.unique()

            for i in range(n_winters):
                if track_months[-1] <= 6:
                    if track_years[0] == i + start_year + 1:
                        counter[i] += 1
                else:
                    if track_years[-1] == i + start_year:
                        counter[i] += 1
    return counter


def check_by_mask(ot, trackrun, lsm, lmask_thresh=1, rad=50.0, mask_thresh=0.5):
    """
    Check how close the OctantTrack is to masked points.

    Check if the given track spends less than `mask_thresh` of its lifetime
    within `rad` away from the land or domain boundaries.

    This function can be passed to `octant.core.TrackRun.categorise()` to filter
    through cyclone tracks.

    Parameters
    ----------
    ot: octant.core.OctantTrack
        Cyclone track to check
    trackrun: octant.core.TrackRun
        (parent) track run instance to get lon/lat boundaries if present
    lsm: xarray.DataArray
        Two-dimensional land-sea mask
    lmask_thresh: float
        Threshold of `lsm` values, for flexible land-mask filtering
    rad: float
        Radius in km, passed to mask_tracks() function
    mask_thresh: float, optional
        Threshold for track's lifetime (0-1)

    Returns
    -------
    flag: bool
        The track is far away from the boundaries and land mask at given thresholds.

    Examples
    --------
    >>> from octant.core import TrackRun
    >>> import xarray as xr
    >>> land_mask = xr.open_dataarray(path_to_land_mask_file)
    >>> tr = TrackRun(path_to_directory_with_tracks)
    >>> random_track = tr.data.loc[123]
    >>> check_by_mask(random_track, tr, land_mask, lmask_thresh=0.5)
    True

    See Also
    --------
    octant.core.TrackRun.classify, octant.utils.mask_tracks
    """
    assert isinstance(lsm, xr.DataArray), "lsm variable should be an `xarray.DataArray`"
    lon2d, lat2d = np.meshgrid(lsm.longitude, lsm.latitude)
    l_mask = lsm.values
    inner_idx = True
    if getattr(trackrun.conf, "lon1", None):
        inner_idx &= lon2d >= trackrun.conf.lon1
    if getattr(trackrun.conf, "lon2", None):
        inner_idx &= lon2d <= trackrun.conf.lon2
    if getattr(trackrun.conf, "lat1", None):
        inner_idx &= lat2d >= trackrun.conf.lat1
    if getattr(trackrun.conf, "lat2", None):
        inner_idx &= lat2d <= trackrun.conf.lat2
    boundary_mask = np.zeros_like(lon2d)
    boundary_mask[~inner_idx] = 1.0
    trackrun.themask = ((boundary_mask == 1.0) | (l_mask >= lmask_thresh)) * 1.0
    themask_c = trackrun.themask.astype("double", order="C")
    lon2d_c = lon2d.astype("double", order="C")
    lat2d_c = lat2d.astype("double", order="C")
    flag = mask_tracks(themask_c, lon2d_c, lat2d_c, ot.lonlat_c, rad * 1e3) < mask_thresh
    return flag


def check_far_from_boundaries(ot, lonlat_box, dist=200e3):
    """
    Check if track is not too close to boundaries.

    Parameters
    ----------
    ot: octant.core.OctantTrack
        Individual cyclone-track object
    lonlat_box: list
        Boundaries of longitude-latitude rectangle (lon_min, lon_max, lat_min, lat_max)
        Note that the order matters!
    dist: float
        Minimum distance from a boundary in metres

    Returns
    -------
    result: bool
        True if track is not too close to boundaries

    Examples
    --------
    >>> from octant.core import TrackRun
    >>> tr = TrackRun("path/to/directory/with/tracks")
    >>> random_track = tr.data.loc[123]
    >>> check_far_from_boundaries(random_track, lonlat_box=[-10, 20, 60, 80], dist=250e3)
    True

    >>> from functools import partial
    >>> conds = [
            ('bound', [partial(check_far_from_boundaries, lonlat_box=tr.conf.extent)])
        ]  # construct a condition for tracks to be within the boundaries taken from the TrackRun
    >>> tr.classify(conds)
    >>> tr.cat_labels
    ['bound']

    See Also
    --------
    octant.core.TrackRun.classify, octant.utils.check_by_mask
    """
    # Preliminary check: track is within the rectangle
    # (Could be the case for a small rectangle.)
    result = (
        (ot.lon >= lonlat_box[0])
        & (ot.lon <= lonlat_box[1])
        & (ot.lat >= lonlat_box[2])
        & (ot.lat <= lonlat_box[3])
    ).all()
    if not result:
        return False

    # Main check
    for i, ll in enumerate(lonlat_box):

        def _func(row):
            args = [row.lon, row.lon, row.lat, row.lat].copy()
            args[2 * (i // 2)] = ll
            return great_circle(*args)

        result &= (ot.apply(_func, axis=1) > dist).all()

    return result
