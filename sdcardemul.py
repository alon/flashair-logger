#!/usr/bin/python
import os
import sys
from StringIO import StringIO
from SimpleHTTPServer import BaseHTTPServer, SimpleHTTPRequestHandler

class AirHTTPRequestHandler(SimpleHTTPRequestHandler):
    def list_directory(self, path):
        f = StringIO()
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
            f.write('wlansd[%(i)d]="%(path)s,%(filename)s,%(size)d,32,%(date)d,%(time)d";\n' % locals())
        length = f.tell()
        f.seek(0)
        self.send_response(200)
        encoding = sys.getfilesystemencoding()
        self.send_header('Content-type', 'text/html; charset=%s' % encoding)
        self.send_header('Content-Length', str(length))
        self.end_headers()
        return f

def test(HandlerClass = AirHTTPRequestHandler,
         ServerClass = BaseHTTPServer.HTTPServer):
    BaseHTTPServer.test(HandlerClass, ServerClass)

if __name__ == '__main__':
    os.chdir('test-dir')
    test()
