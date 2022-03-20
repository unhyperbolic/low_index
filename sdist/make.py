import os, sys, glob, subprocess, shutil

py = sys.executable

os.chdir('..')
subprocess.check_call([py, 'setup.py', 'clean', 'build', 'sdist'])

os.chdir('dist')
sdist_tarball = glob.glob('low_index-*.tar.gz')[0]
sdist = sdist_tarball[:-7]
subprocess.check_call(['tar', 'xf', sdist_tarball])
subprocess.check_call(['cp', '../sdist/setup-sdist.py', sdist +'/setup.py'])
subprocess.check_call(['tar', 'cfz', sdist_tarball, sdist])
shutil.rmtree(sdist)
