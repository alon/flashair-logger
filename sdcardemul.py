#!/usr/bin/python3

import os
import sys
from io import BytesIO
from http.server import HTTPServer, SimpleHTTPRequestHandler, test

"""

Acronyms used:
FAv3 - FlashAir v3 by Toshiba. The only supported hardware (used to support v2,
need to check if v2 supports the command.cgi API. Downloading files is the same,
i.e.
http://192.168.0.1/<full_path>

"""


class AirHTTPRequestHandler(SimpleHTTPRequestHandler):
    """
    Implement v3 observed API (TBD: is this documented anywhere?)

    There are two ways to go:
     - parse the HTML page (specifically the script part) returned
     - use the command.cgi response - it is clearer

    command.cgi?op=100&DIR=<dir> (optional TIME=(new Date()).getTime())
    """


    def list_directory(self, path):
        """
        Simulates enough of the returned page by FAv3 to
        """
        f = BytesIO()
        try:
            lst = os.listdir(path)
        except os.error:
            self.send_error(404, "No permission to list directory")
            return None
        lst.sort(key=lambda a: a.lower())
        for i, filename in enumerate(lst):
            stat = os.stat(os.path.join(path, filename))
            size = stat.st_size
            mtime = int(stat.st_mtime)
            date, time = mtime >> 16, mtime & 0xffff
            f.write(f'wlansd[{i}]="{path},{filename},{size},32,{date},{time}";\n'.encode())
        length = f.tell()
        f.seek(0)
        self.send_response(200)
        encoding = sys.getfilesystemencoding()
        self.send_header('Content-type', 'text/html; charset=%s' % encoding)
        self.send_header('Content-Length', str(length))
        self.end_headers()
        return f

def main(HandlerClass = AirHTTPRequestHandler,
         ServerClass = HTTPServer):
    test(HandlerClass=HandlerClass, ServerClass=ServerClass)

if __name__ == '__main__':
    os.chdir('test-dir')
    main()
