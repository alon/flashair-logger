#!/usr/bin/python3

from argparse import ArgumentParser
import os
import sys
from io import BytesIO
from http.server import HTTPServer, SimpleHTTPRequestHandler, test
from http import HTTPStatus

"""

Acronyms used:
FAv3 - FlashAir v3 by Toshiba. The only supported hardware (used to support v2,
need to check if v2 supports the command.cgi API.

Downloading files is the same, i.e.

http://192.168.0.1/<full_path>

Command API documentation:
https://www.flashair-developers.com/en/documents/api/commandcgi/

"""


def try_parse_int(x, default):
    try:
        return int(x)
    except:
        return default


encoding = sys.getfilesystemencoding()


class AirHTTPRequestHandler(SimpleHTTPRequestHandler):
    """
    Implement v3 Command API op for directory listing

    There are two ways to go:
     - parse the HTML page (specifically the script part) returned
     - use the command.cgi response - it is clearer

    command.cgi?op=100&DIR=<dir> (optional TIME=(new Date()).getTime())
    """

    flashair_version = 3

    def do_GET(self):
        """ implement command.cgi, fallback to default implementation (which
        will either list a directory or send a file back)
        """
        if self.path.startswith('/command.cgi'):
            return self.handle_command_cgi()
        return super().do_GET()

    def handle_command_cgi(self):
        # TODO - use the standard library for this
        qsplit = self.path.split('?')
        if len(qsplit) == 1:
            return self.send_error(
                HTTPStatus.BAD_REQUEST,
                'Bad command.cgi invocation (not FAv3 compat)')
        params = [x.split('=') for x in qsplit[1].split('&')]
        if not all(len(p) == 2 for p in params):
            return self.send_error(
                HTTPStatus.BAD_REQUEST,
                'Bad command.cgi parameters (not FAv3 compat)')
        d = dict(params)
        if 'op' not in d:
            return self.send_error(
                HTTPStatus.BAD_REQUEST,
                'Bad command.cgi call: missing op (not FAv3 compat)')
        op_str = d['op']
        op = try_parse_int(d['op'], op_str)
        if not isinstance(op, int):
            return self.send_error(
                HTTPStatus.BAD_REQUEST,
                'Bad command.cgi call: op is not an integer (not FAv3 compat)')
        if op != 100:
            return self.send_error(
                HTTPStatus.BAD_REQUEST,
                'Unsupported command.cgi op: {op} (not FAv3 compat)'
                .format(**locals()))
        if 'DIR' not in d:
            return self.send_error(
                HTTPStatus.BAD_REQUEST,
                'Bad 100 command: missing DIR (not FAv3 compat)'
                .format(**locals()))
        DIR = d['DIR']
        while DIR[:1] == '/':
            DIR = DIR[1:]
        items, http_code, error_message = self._read_dir_as_fav3(DIR)
        if items is None:
            return self.send_error(http_code, error_message)
        f = BytesIO()
        f.write(b'WLANSD_FILELIST\n')
        for item in items:
            filename, size, date, time = (
                item['filename'], item['size'], item['date'], item['time']
            )
            f.write('{DIR},{filename},{size},32,{date},{time}\n'
                    .format(**locals())
                    .encode())
        f.seek(0)
        self.send_response(HTTPStatus.OK)
        self.send_header('Connection', 'close')
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.copyfile(f, self.wfile)


    def _read_dir_as_fav3(self, path):
        try:
            lst = os.listdir(path)
        except os.error:
            return (None, HTTPStatus.BAD_REQUEST,
                    "No permission to list directory")
        lst.sort(key=lambda a: a.lower())
        ret = []
        for filename in lst:
            stat = os.stat(os.path.join(path, filename))
            size = stat.st_size
            mtime = int(stat.st_mtime)
            date, time = mtime >> 16, mtime & 0xffff
            ret.append(dict(
                filename=filename, size=size, date=date, time=time))
        return ret, None, ''


    def list_directory(self, path):
        """
        Simulates enough of the returned page by FAv3 to

        overrides SimpleHTTPRequestHandler.list_directory
        """
        f = BytesIO()
        items, http_code, error_message = self._read_dir_as_fav3(path)
        if items is None:
            return self.send_error(http_code, error_message)
        path = os.path.join('/', os.path.relpath(path, BASE_DIR))
        for i, item in enumerate(items):
            filename, size, date, time = (
                item['filename'], item['size'], item['date'], item['time']
            )
            if self.flashair_version == 2:
                s = 'wlansd[{i}]="{path},{filename},{size},32,{date},{time}";\n'.format(**locals())
            else:
                s = 'wlansd.push({{"r_uri":"{path}", "fname":"{filename}", "fsize":{size},"attr":32,"fdate":{date},"ftime":{time}}}'.format(**locals())
            f.write(s.encode())
        return self.bytesio_response(HTTPStatus.OK, f)


    def bytesio_response(self, http_code, f):
        length = f.tell()
        f.seek(0)
        self.send_response(http_code)
        self.send_header('Content-type', 'text/html; charset=%s' % encoding)
        self.send_header('Content-Length', str(length))
        self.end_headers()
        return f


def main(HandlerClass=AirHTTPRequestHandler,
         ServerClass=HTTPServer):
    test(HandlerClass=HandlerClass, ServerClass=ServerClass)


if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument('--version', default=3, type=int, choices=[2, 3])
    parser.add_argument('--dir', default='test-dir')
    args = parser.parse_args()
    BASE_DIR = os.path.join(os.getcwd(), args.dir)
    AirHTTPRequestHandler.flashair_version = args.version
    print("FlashAir card Emulator - Serving from {args.dir}"
          .format(**locals()))
    print("Emulating version {args.version}".format(**locals()))
    os.chdir(BASE_DIR)
    main()
