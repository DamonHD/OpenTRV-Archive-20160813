import os
import os.path

ROOT_PATH = os.path.expanduser('~/.local/share/opentrv')

def path(partial_path):
    """
    Return the full path for the given partial path.
    """
    return os.path.abspath(os.path.join(ROOT_PATH, partial_path))

def mkdir(partial_path):
    """
    Recursively create a folder for the given partial path.
    """
    fpath = path(partial_path)
    if os.path.exists(fpath):
        if not os.path.isdir(fpath):
            raise ValueError("Path {0} already exists and is not a directory".format(fpath))
    else:
        os.makedirs(fpath)
