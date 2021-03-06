# cython: language_level=3, boundscheck=False, wraparound=False
"""
Part of the octant package.

Optimized functions for working with cyclone tracks.
"""
cimport cython
import numpy as np
cimport numpy as np
from libc.math cimport pi, sin, cos, acos

from .params import EARTH_RADIUS


cdef double _great_circle(double lon1,
                          double lon2,
                          double lat1,
                          double lat2,
                          double r_planet=EARTH_RADIUS):
    """
    See the docstring for great_circle()
    """

    cdef double deg2rad = pi / 180.
    cdef double ang
    cdef double dist
    cdef double eps = 1e-12

    if abs(lon1-lon2) < eps and abs(lat1-lat2) < eps:
        dist = 0.
    else:
        ang = (sin(deg2rad * lat1) * sin(deg2rad * lat2) +
               cos(deg2rad * lat1) * cos(deg2rad * lat2)
               * cos(deg2rad * (lon1 - lon2)))
        dist = acos(ang) * r_planet
    return dist


cpdef double great_circle(double lon1,
                          double lon2,
                          double lat1,
                          double lat2,
                          double r_planet=EARTH_RADIUS):
    """
    Calculate great circle distance between two points on a sphere

    Parameters
    ----------
    lon1: double
        Longitude of the first point
    lon2: double
        Longitude of the second point
    lat1: double
        Latitude of the first point
    lat2: double
        Latitude of the second point
    r_planet: double, optional
        Radius of the planet in metres
        Default: EARTH_RADIUS

    Returns
    -------
    dist: double
        Distance in metres

    Examples
    --------
    >>> great_circle(-180.0, -170.0, 30.0, 40.0)
    1435334.9068947

    """

    return _great_circle(lon1, lon2, lat1, lat2, r_planet=r_planet)


cpdef double total_dist(double[:, ::1] lonlat):
    """
    Calculate the total distance given an array of longitudes and latitudes

    Parameters
    ----------
    lonlat: double, shape(N, 2)
        Array of longitudes and latitudes

    Returns
    -------
    dist: double
        Total distance in metres
    """
    cdef int p
    cdef int pmax = lonlat.shape[0]
    cdef double dist

    dist = 0.
    for p in range(pmax-1):
        dist = dist + _great_circle(lonlat[p, 0], lonlat[p+1, 0],
                                    lonlat[p, 1], lonlat[p+1, 1])
    return dist


# Density functions
cpdef double[:, ::1] point_density_cell(double[:, ::1] lon2d,
                                        double[:, ::1] lat2d,
                                        double[:, ::1] lonlat):
    """
    Calculate density in lon-lat grid cell boxes.

    Parameters
    ----------
    lon2d: numpy.array
        Array of longitudes of shape (M, N)
    lat2d: numpy.array
        Array of latitudes of shape (M, N)
    lonlat: numpy.array
        Array of track's longitude and latitude; of shape(P, 2)

    Returns
    -------
    count: numpy.array
        Cyclone point occurence in each grid cell

    Note
    ----
    `lon2d` and `lat2d` define the boundaries of grid cells, not centres.
    """
    cdef int i, j, p
    cdef int jmax = lat2d.shape[0]-1
    cdef int imax = lon2d.shape[1]-1
    cdef int pmax = lonlat.shape[0]
    cdef double[:, ::1] count = np.zeros([jmax, imax], dtype=np.double)

    for p in range(pmax):
        for j in range(jmax):
            for i in range(imax):
                if ((lon2d[j, i  ] <= lonlat[p, 0])
                and (lon2d[j, i+1] >  lonlat[p, 0])
                and (lat2d[j, i  ] <= lonlat[p, 1])
                and (lat2d[j+1, i] >  lonlat[p, 1])):
                    count[j, i] = count[j, i] + 1
    return count


cpdef double[:, ::1] track_density_cell(double[:, ::1] lon2d,
                                        double[:, ::1] lat2d,
                                        double[:, ::1] id_lon_lat):
    """
    Calculate cyclone track density in lon-lat grid cell boxes.

    Parameters
    ----------
    lon2d: numpy.array
        Array of longitudes of shape (M, N)
    lat2d: numpy.array
        Array of latitudes of shape (M, N)
    id_lon_lat: numpy.array
        Array of track's index, longitude, and latitude; of shape(P, 2)

    Returns
    -------
    count: numpy.array
        Cyclone occurence in each grid cell

    Note
    ----
    `lon2d` and `lat2d` define the boundaries of grid cells, not centres.
    """
    cdef int i, j, p
    cdef int jmax = lat2d.shape[0] - 1
    cdef int imax = lon2d.shape[1] - 1
    cdef int pmax = id_lon_lat.shape[0]
    cdef int track_idx
    cdef int prev_track_idx

    cdef double[:, ::1] count = np.zeros([jmax, imax], dtype=np.double)

    for j in range(jmax):
        for i in range(imax):
            prev_track_idx = -1
            for p in range(pmax):
                track_idx = <int>id_lon_lat[p, 0]
                if prev_track_idx != track_idx:
                    if ((lon2d[j, i  ] <= id_lon_lat[p, 1])
                    and (lon2d[j, i+1] >  id_lon_lat[p, 1])
                    and (lat2d[j, i  ] <= id_lon_lat[p, 2])
                    and (lat2d[j+1, i] >  id_lon_lat[p, 2])):
                        count[j, i] = count[j, i] + 1
                        prev_track_idx = track_idx
    return count


cpdef double[:, ::1] point_density_rad(double[:, ::1] lon2d,
                                       double[:, ::1] lat2d,
                                       double[:, ::1] lonlat,
                                       double dist,
                                       double r_planet=EARTH_RADIUS):
    """
    Calculate cyclone density within given radius from each grid point

    TODO: account for double-counting!
    """
    cdef int i, j, p
    cdef int jmax = lat2d.shape[0]
    cdef int imax = lon2d.shape[1]
    cdef int pmax = lonlat.shape[0]
    cdef double[:, ::1] count = np.zeros([jmax, imax], dtype=np.double)
    for p in range(pmax):
        for j in range(jmax):
            for i in range(imax):
                if _great_circle(lonlat[p, 0], lon2d[j, i],
                                 lonlat[p, 1], lat2d[j, i], r_planet=r_planet) <= dist:
                    count[j, i] = count[j, i] + 1
    return count


cpdef double[:, ::1] track_density_rad(double[:, ::1] lon2d,
                                       double[:, ::1] lat2d,
                                       double[:, ::1] id_lon_lat,
                                       double dist,
                                       double r_planet=EARTH_RADIUS):
    """
    Calculate cyclone track density within given radius from each grid point

    TODO: account for double-counting!
    """
    cdef int i, j, p
    cdef int jmax = lat2d.shape[0]
    cdef int imax = lon2d.shape[1]
    cdef int pmax = id_lon_lat.shape[0]
    cdef int track_idx
    cdef int prev_track_idx

    cdef double[:, ::1] count = np.zeros([jmax, imax], dtype=np.double)

    for j in range(jmax):
        for i in range(imax):
            prev_track_idx = -1
            for p in range(pmax):
                track_idx = <int>id_lon_lat[p, 0]
                if prev_track_idx != track_idx:
                    if _great_circle(id_lon_lat[p, 1], lon2d[j, i],
                                     id_lon_lat[p, 2], lat2d[j, i], r_planet=r_planet) <= dist:
                        count[j, i] = count[j, i] + 1
                        prev_track_idx = track_idx
    return count


# Masking functions
cdef double _masking_loop_func(double[:, ::1] mask,
                               double[:, ::1] lon2d,
                               double[:, ::1] lat2d,
                               double lon,
                               double lat,
                               double dist,
                               double r_planet=EARTH_RADIUS):
    """
    Masking function. See mask_tracks() for explanation.
    """
    cdef int i, j
    cdef int jmax = lon2d.shape[0]
    cdef int imax = lon2d.shape[1]

    for j in range(jmax):
        for i in range(imax):
            if _great_circle(lon, lon2d[j, i],
                             lat, lat2d[j, i], r_planet=r_planet) <= dist:
                if mask[j, i] == 1:
                    return 1.
    return 0.


cpdef double mask_tracks(double[:, ::1] mask,
                         double[:, ::1] lon2d,
                         double[:, ::1] lat2d,
                         double[:, ::1] lonlat,
                         double dist,
                         double r_planet=EARTH_RADIUS):
    """
    Count how many points of a cyclone track should be masked by their
    proximity to masked values in a 2D array.

    Parameters
    ----------
    mask: double, shape(M, N)
        Mask array with 1 for masked values
    lon2d: double, shape(M, N)
        Array of longitudes corresponding to the mask
    lat2d: double, shape(M, N)
        Array of latitudes corresponding to the mask
    lonlat: double, shape(P, 2)
        Array of track's longitudes and latitudes
    dist: double
        Distance in metres to check proximity
    r_planet: double, optional
        Radius of the planet in metres
        Default: EARTH_RADIUS

    Returns
    -------
    Fraction of masked points of the track
    """

    cdef int p
    cdef int pmax = lonlat.shape[0]
    cdef double points_near_coast

    points_near_coast = 0.
    for p in range(pmax):
        points_near_coast += _masking_loop_func(mask, lon2d, lat2d,
                                                lonlat[p, 0], lonlat[p, 1],
                                                dist, r_planet=r_planet)
    return points_near_coast / <double>pmax


cdef double _arr_around_point(double[:, ::1] mask,
                              double[:, ::1] lon2d,
                              double[:, ::1] lat2d,
                              double lon,
                              double lat,
                              double dist,
                              double r_planet=EARTH_RADIUS):
    cdef int i, j
    cdef int counter
    cdef int jmax = lon2d.shape[0]
    cdef int imax = lon2d.shape[1]
    cdef double area_sum

    counter = 0
    area_sum = 0.
    for j in range(jmax):
        for i in range(imax):
            if _great_circle(lon, lon2d[j, i],
                             lat, lat2d[j, i], r_planet=r_planet) <= dist:
                counter += 1
                area_sum += mask[j, i]
    if counter == 0:
        return 0.
    else:
        return area_sum / <double>counter


cpdef double[:] mean_arr_along_track(double[:, ::1] arr,
                                     double[:, ::1] lon2d,
                                     double[:, ::1] lat2d,
                                     double[:, ::1] lonlat,
                                     double dist,
                                     double r_planet=EARTH_RADIUS):
    """
    Calculate the mean of an array along the cyclone track within distance `dist` of each point.

    Parameters
    ----------
    arr: double, shape(M, N)
        Two-dimensional array of values (e.g. land-sea mask)
    lon2d: double, shape(M, N)
        Array of longitudes corresponding to `arr`
    lat2d: double, shape(M, N)
        Array of latitudes corresponding to `arr`
    lonlat: double, shape(P, 2)
        Array of track's longitudes and latitudes
    dist: double
        Distance in metres defining the radius for averaging
    r_planet: double, optional
        Radius of the planet in metres
        Default: EARTH_RADIUS

    Returns
    -------
    Mean value of the array for each point along the track.
    """
    cdef int p
    cdef int pmax = lonlat.shape[0]
    z = np.zeros([pmax], dtype=np.double)
    cdef double[:] area_mean = z

    for p in range(pmax):
        area_mean[p] = _arr_around_point(arr, lon2d, lat2d,
                                         lonlat[p, 0], lonlat[p, 1],
                                         dist, r_planet=r_planet)
    return area_mean


# Distance metrics
cdef double _traj_variance(double[:] x1,
                           double[:] y1,
                           double[:] t1,
                           double[:] x2,
                           double[:] y2,
                           double[:] t2,
                           double alpha=1.,
                           double beta=100,
                           double r_planet=EARTH_RADIUS):
    """
    Calculate cyclone track variance (eq. (3) in Blender and Schubert (2000))

    Parameters
    ----------
    x1: double, shape(N, )
        Array of longitudes of track 1
    y1: double, shape(N, )
        Array of latitudes of track 1
    t1: double, shape(N, )
        Array of times (in seconds) of track 1
    x2: double, shape(M, )
        Array of longitudes of track 2
    y2: double, shape(M, )
        Array of latitudes of track 2
    t2: double, shape(M, )
        Array of times (in seconds) of track 2
    alpha: double, optional (default: 1)
        Parameter alpha in eq. (3)
    beta: double, optional (default: 100)
        Parameter beta in eq. (3)
    r_planet: double, optional
        Radius of the planet in metres
        Default: EARTH_RADIUS

    Returns
    -------
    variance_sum: double
        Accumulated variance (sigma) between the two tracks
    """
    cdef int imax1 = x1.shape[0]
    cdef int imax2 = x2.shape[0]
    cdef int i1, i2
    cdef double variance_sum
    cdef double f0
    cdef double f1
    cdef double g0
    cdef double g1
    cdef double da1
    cdef double da2
    cdef double A1
    cdef double A2

    A1 = t1[imax1-1] - t1[0]
    A2 = t2[imax2-1] - t2[0]

    variance_sum = 0
    for i1 in range(imax1-1):
        da1 = t1[i1+1] - t1[i1]
        for i2 in range(imax2-1):
            da2 = t2[i2+1] - t2[i2]
            f0 = ( alpha * (_great_circle(x1[i1], x2[i2],
                                          y1[i1], y2[i2], r_planet=r_planet) ** 2)
                  + beta * ((t1[i1] - t2[i2])) ** 2 )
            f1 = ( alpha * (_great_circle(x1[i1+1], x2[i2],
                                          y1[i1+1], y2[i2], r_planet=r_planet) ** 2)
                  + beta * ((t1[i1+1] - t2[i2])) ** 2 )
            g0 = ( alpha * (_great_circle(x1[i1], x2[i2+1],
                                          y1[i1], y2[i2+1], r_planet=r_planet) ** 2)
                  + beta * ((t1[i1] - t2[i2+1])) ** 2 )
            g1 = ( alpha * (_great_circle(x1[i1+1], x2[i2+1],
                                          y1[i1+1], y2[i2+1], r_planet=r_planet) ** 2)
                  + beta * ((t1[i1+1] - t2[i2+1])) ** 2 )
            variance_sum += 0.25 * (f0 + f1 + g0 + g1) * da1 * da2
    return variance_sum / (A1 * A2)


# @cython.boundscheck(False)  # Deactivate bounds checking
# @cython.wraparound(False)  # Deactivate negative indexing
@cython.cdivision(True)  # Do not check for ZeroDivision errors 
cpdef double distance_metric(double[:] x1,
                             double[:] y1,
                             long[:] t1,
                             double[:] x2,
                             double[:] y2,
                             long[:] t2,
                             double alpha=1.,
                             double beta=100.,
                             double r_planet=EARTH_RADIUS):
    """
    Calculate the distance metric (eq. (4) in Blender and Schubert (2000))

    Parameters
    ----------
    x1: double, shape(N, )
        Array of longitudes of track 1
    y1: double, shape(N, )
        Array of latitudes of track 1
    t1: long, shape(N, )
        Array of times (in nanoseconds) of track 1
    x2: double, shape(M, )
        Array of longitudes of track 2
    y2: double, shape(M, )
        Array of latitudes of track 2
    t2: long, shape(M, )
        Array of times (in nanoseconds) of track 2
    alpha: double, optional (default: 1)
        Parameter alpha in eq. (3)
    beta: double, optional (default: 100)
        Parameter beta in eq. (3)
    r_planet: double, optional
        Radius of the planet in metres
        Default: EARTH_RADIUS

    Returns
    -------
    dm: double
        The distance metric


    Note: time arrays are taken in nanoseconds because this is the
    default precision of numpy.datetime64 arrays within the pandas.DataFrame
    representing a cyclone track
    """

    cdef double dm
    cdef double sigma11
    cdef double sigma12
    cdef double sigma22
    cdef double A1
    cdef double A2
    cdef int imax1 = x1.shape[0]
    cdef int imax2 = x2.shape[0]
    cdef double nano_s = 1e-9
    h_np1 = np.zeros([imax1], dtype=np.double)
    h_np2 = np.zeros([imax2], dtype=np.double)
    cdef double[:] t1_s = h_np1
    cdef double[:] t2_s = h_np2

    for i1 in range(imax1):
        t1_s[i1] = <double>t1[i1] * nano_s
    for i2 in range(imax2):
        t2_s[i2] = <double>t2[i2] * nano_s

    A1 = t1_s[imax1-1] - t1_s[0]
    A2 = t2_s[imax2-1] - t2_s[0]

    sigma12 = _traj_variance(x1, y1, t1_s, x2, y2, t2_s, alpha=alpha, beta=beta, r_planet=r_planet)
    sigma11 = _traj_variance(x1, y1, t1_s, x1, y1, t1_s, alpha=alpha, beta=beta, r_planet=r_planet)
    sigma22 = _traj_variance(x2, y2, t2_s, x2, y2, t2_s, alpha=alpha, beta=beta, r_planet=r_planet)

    dm = ((sigma12 - 0.5 * (sigma11 + sigma22)) / (A1 * A2)) ** 0.5

    return dm
