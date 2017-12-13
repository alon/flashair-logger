#!/usr/bin/env python3

import os
from subprocess import check_output
import atexit
import shutil
from tempfile import TemporaryDirectory
import time


def cleanup():
    os.system('killall sdcardemul.py')


atexit.register(cleanup)


def as_flashair(cmd):
    ret = check_output(['ssh', 'flashair@localhost', cmd])
    return ret


config_template = """
SDCARD_HOST='{SDCARD_HOST}'
SDCARD_PORT={SDCARD_PORT}
SSH_USER='{SSH_USER}'
TARGET_PATH='{TARGET_PATH}'
SYNC_DIR='{SYNC_DIR}'
DEBUG=true
"""


def create_config(root_dir):
    filename = os.path.join(root_dir, 'config.lua')
    SDCARD_HOST = 'localhost'
    SDCARD_PORT = 8000
    SSH_USER = 'flashair'
    SSH_HOST = '127.0.0.1'
    TARGET_PATH = '/home/flashair/test'
    SYNC_DIR = os.path.join(root_dir, 'sync_dir')
    as_flashair(f'rm -Rf {TARGET_PATH}')
    as_flashair(f'mkdir -p {TARGET_PATH}')
    with open(filename, 'w+') as fd:
        fd.write(config_template.format(**locals()))
    return filename, TARGET_PATH


def is_same(base1, base2):
    for (root1, dirs1, files1), (root2, dirs2, files2) in zip(os.walk(base1), os.walk(base2)):
        if len(files1) != len(files2):
            return False
        if set(files1) != set(files2):
            return False
        if set(dirs1) != set(dirs2):
            return False
        for f1, f2 in zip(files1, files2):
            if f1 != f2:
                return False
            if os.stat(os.path.join(root1, f1)).st_size != os.stat(os.path.join(root2, f2)).st_size:
                return False
    return True


def run_sdcardemul_syncroot(syncroot):
    # assemble
    config_filename, target_path = create_config(syncroot)
    source_dir = os.path.join(syncroot, 'sd')
    csv_dir = os.path.join(source_dir, 'CSVFILES', 'LOG')
    os.makedirs(csv_dir)
    os.system(f'./sdcardemul.py --dir {source_dir} &')
    filenames = ['a.csv', 'b.csv', 'c.csv']
    for fname in filenames:
        with open(os.path.join(csv_dir, fname), 'w+') as fd:
            fd.write('1,2,3\n')
    time.sleep(0.5)

    # action
    os.system(f'./sync_sd_to_remote {config_filename}')

    # assert directories contain same files
    local_path = os.path.join(syncroot, 'result')
    os.makedirs(local_path)
    os.system(f'rsync -rva flashair@localhost:{target_path}/ {local_path}/')
    if not is_same(csv_dir, local_path):
        import pdb; pdb.set_trace()
        assert False, 'test failed'

    #import pdb; pdb.set_trace()

    # second assemble

    # make sure none of the files is updated the second time around -
    #  i.e. that syncing works
    mtimes = [os.stat(os.path.join(local_path, fname)).st_mtime for fname in filenames]

    # second action
    os.system(f'./sync_sd_to_remote {config_filename}')

    # second assert
    os.system(f'rsync -rva flashair@localhost:{target_path}/ {local_path}/')
    assert is_same(csv_dir, local_path)
    new_mtimes = [os.stat(os.path.join(local_path, fname)).st_mtime for fname in filenames]
    assert new_mtimes == mtimes


def run_sdcardemul():
    os.system('killall sdcardemul.py')

    with TemporaryDirectory() as syncroot:
        run_sdcardemul_syncroot(syncroot)

def main():
    run_sdcardemul()


if __name__ == '__main__':
    main()
