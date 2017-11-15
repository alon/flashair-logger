#!/usr/bin/python3

from os import path
from argparse import ArgumentParser
from io import BytesIO


def read_config(filename):
    ret = []
    section = None
    with open(filename, 'rb') as fd:
        for l in fd.readlines():
            if l[-2:] == b'\r\n':
                l = l[:-2]
            if len(l.strip()) > 0 and l.strip()[0] == ord(b'['):
                if section is not None:
                    ret.append((section, section_lines))
                section = l.strip().split(b'[', 1)[1].split(b']')[0].strip()
                section_lines = []
            elif b'=' in l:
                section_lines.append(l.split(b'='))
            else:
                section_lines.append(l)
        ret.append((section, section_lines))
    return ret


def config_to_bytes(config, section, keyvals):
    """
    Update existing values in config.section, then append the ones left.
    """
    out = BytesIO()
    def write_keyvals():
        for key, val in keyvals.items():
            out.write(b'%s=%s\r\n' % (key, val))
        keyvals.clear()
    for existing_section, section_lines in config:
        out.write(b'[%s]\r\n' % existing_section)
        if existing_section == section:
            for line in section_lines:
                if isinstance(line, list):
                    key, val = line
                    if key in keyvals:
                        val = keyvals[key]
                        del keyvals[key]
                    out.write(b'%s=%s\r\n' % (key, val))
                else:
                    out.write(b'%s\r\n' % line)
            if len(keyvals) > 0:
                write_keyvals()
    if len(keyvals) > 0:
        # section didn't exist before, write it from scratch
        out.write(b'[%s]\r\n'% section)
        write_keyvals()
    out.seek(0)
    return out.read()


def update_config_file(root, ssid, key, dryrun):
    """
    Full documentation: https://flashair-developers.com/en/documents/api/config/

    """
    config_path = path.join(root, 'SD_WLAN', 'CONFIG')
    if not path.isfile(config_path):
        raise Exception(f"cannot access or find Flash Air Config file under {root}")
    config = read_config(config_path)
    keyvals = dict(
        APPAUTOTIME='0', # never turn off wifi AP, even if no one connects
        APPSSID=ssid,
        APPNETWORKKEY=key,
        APPMODE='4') # set to access mode
    keyvals = {k.encode(): v.encode() for k, v in keyvals.items()}
    output = config_to_bytes(config, b'Vendor', keyvals)
    if not dryrun:
        with open(config_path, 'wb+') as fd:
            fd.write(output)
    else:
        print(output.decode(), end="")


def main():
    parser = ArgumentParser()
    parser.add_argument('--root', help='root path to FlashAir SD card', required=True)
    parser.add_argument('--ssid', help='ESSID to use', required=True)
    parser.add_argument('--key', help='Shared key (password) for wireless network', required=True)
    parser.add_argument('--write', help='write to file (otherwise does a dryrun)', action='store_true')
    args = parser.parse_args()
    update_config_file(root=args.root, ssid=args.ssid, key=args.key, dryrun=not args.write)


if __name__ == '__main__':
    main()
