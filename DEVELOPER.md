# Developer Documentation

This document is intended to provide guidelines for software developers either maintaining or 
contributing to `svtools` development.

## Installing svtools

1. from a repo
1. from a conda thing
1. using pip package on pypi
1. downloading a github tarball

### From the git repo
prepare your python environment
  you might want to use pyenv virtual-env, you can learn about that here https://github.com/yyuu/pyenv-virtualenv 
  we require python 2.7.X 
  this process might look like this
  <pre><code>pyenv virtualenv 2.7.9 svtools_install_instructions-2.7.9
  pyenv activate</pre></code> 
check out svtools from the hall-lab github repository
 <pre><code>git clone https://github.com/hall-lab/svtools.git svtools_test</code></pre>
install dependencies as suggested in the requiremnts files
<pre><code>pip install nose
pip install coverage
pip install statsmodels</pre></code>
installing statsmodel can take a while, but in our testing it satisfies the requirement for numpy,pandas, and scipy
in our local environment we need to specify pysam versions less than 0.9.0, YMMV
<pre><code>pip install 'pysam>=0.8.1,<0.9.0'</pre></code>

use pip to install svtools from within the repo
<pre><code>cd svtools
pip install .</pre></code>
test your svtools installation
<pre><code>svtools --version</pre></code>

### From a conda package TODO
### Using pip package on pypi TODO
### Downloading a github tarball TODO

## Releasing a new version

### Tagging a release on github
`svtools` manages its versions using [python-versioneer](https://github.com/warner/python-versioneer). 
New versions are derived and generated from the names of tags in git. To release a new version, all 
that is needed is to tag the correct commit with an annotated tag. Always prepend versions with a 
'v' character.

For example, to release version 0.0.1 from the current commit:
```
git tag -a v0.0.1 -m 'v0.0.1'
git push --tags
```

Next navigate to the github [Releases page](https://github.com/hall-lab/svtools/releases), draft a new 
release using the tag you just generated and add release information (a description of changes made since the last release). This will create an entry on the Github Releases page and upload the release to Zenodo.

### Build a pip package and upload to PyPI
Now that you have a new release, upload the package to [PyPI](https://pypi.python.org/pypi). To do so, you'll need a PyPI account, configuration for both the standard and test PyPI servers and necessary permissions on the `svtools` package. 

These instructions assume you have committed no additional changes after tagging the new release.

1. Build the new release and test by uploading to the PyPI test server.
  
  ```
  python setup.py sdist bdist_wheel upload -r pypitest
  ```
2. Verify that the package appears and information looks correct at https://testpypi.python.org/pypi
3. Build and upload the package to PyPI itself.
  
  ```
  python setup.py sdist bdist_wheel upload
  ```
4. In a fresh virtual environment, verify that the new package installs.
  
  ```
  pyenv virtualenv 2.7.9 test_new_package
  pyenv activate test_new_package
  pip install svtools
  ```

### Build a conda package
1. Obtain and install a [Miniconda](http://conda.pydata.org/miniconda.html) version appropriate for your platform.
2. Install conda-build:
  
  ```
  conda install conda-build
  ```
3. Create the conda recipe skeleton
  1. Run conda skeleton
  
    ```
    conda skeleton pypi svtools
    ```
  2. Edit the tests section of the resulting `svtools/meta.yml` file to look like the following section:
    ```YAML
    test:
      # Python imports
      imports:
      - svtools
      - svtools.vcf
      
    commands:
      # You can put test commands to be run here.  Use this to test that the
      # entry points work.
    
      - svtools --help
      - create_coordinates --help
    ```


4. Build the conda recipe
  
  ```
  conda build -c bioconda svtools
  ```
5. Test your recipe by installing it into a new conda environment. The bioconda channel is needed to pull in pysam.
  
  ```
  conda install -c bioconda -n svtools_install_test --use-local svtools
  ```
6. Verify the install was successful.
  
  ```
  source activate svtools_install_test
  svtools --version
  create_coordinates --version
  ```
7. Upload to location TBD
