.. _install:

############
Installation
############

Supported platforms
===================

- Operating system: Linux
- Python: 3.6 and 3.7

.. note::

   We highly recommend installing and using the free `Anaconda
   <https://www.anaconda.com/download/>`_ distribution of Python (or
   `Miniconda <https://conda.io/miniconda.html>`_, if you don't want
   all of the extra packages that come built-in with Anaconda), which
   works on Mac, Linux, and Windows, both on normal computers and
   institutional clusters and doesn't require root permissions.

Recommended installation method: conda
======================================

The recommended installation method is via `conda
<https://conda.io/docs/>`_ ::

  conda install -c dennissergeev octant

Latest nightly build::

  conda install -c dennissergeev/label/nightly octant


Alternative method: clone from Github
========================================

You can also directly clone the `Github repo
<https://github.com/dennissergeev/octant>`_ ::

  git clone https://www.github.com/dennissergeev/octant.git
  cd octant
  python setup.py install

Verifying proper installation
=============================

Once installed via any of these methods, you can run octant's suite of
tests using `py.test <http://doc.pytest.org/>`_.  From the top-level
directory of the octant installation ::

  conda install pytest  # if you don't have it already; or 'pip install pytest'
  py.test octant

If you don't know the directory where octant was installed, you can find it via ::

  python -c "import octant; print(octant.__path__[0])"

If the pytest command results in any error messages or test failures,
something has gone wrong, and please refer to the Troubleshooting
information below.

Troubleshooting
===============

Please search through the `Issues page`_ on Github if anybody else has had the same problem you're facing.
If none do, then please send open a new Issue.

.. _Issues page: https://github.com/dennissergeev/octant/issues
