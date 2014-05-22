#!/usr/bin/env python

import sys
import os
from os import path
from argparse import ArgumentParser
import subprocess
import json
import platform
import urllib
import tempfile

ME = path.basename(path.realpath(__file__))
MYDIR = path.dirname(path.realpath(__file__))

parser = ArgumentParser()
parser.add_argument('-v', '--verbose', help='Be verbose', action='store_true')
parser.add_argument('--key', required=True, help='Ipernity API key')
parser.add_argument('--secret', required=True, help='Ipernity API secret')
parser.add_argument('-o', '--output', required=True,
                    help='Download output directory')
args = parser.parse_args()


def log(msg):
    msg = u"%s: %s" % (ME, msg)
    print >> sys.stderr, msg.encode(encoding='UTF-8',
                                    errors='backslashreplace')

def log_json(json_object):
    log(json.dumps(json_object, indent=2, sort_keys=True))


class IpernityError(Exception):
    def __init__(self, method, code, message):
        Exception.__init__(
            self, "Ipernity error while invoking '%s', code: %s: %s" % (
                method, code, message))


class IpernityAPI:
    def __init__(self, key, secret, open_browser=True):
        self.key = key
        self.secret = secret
        self.frob = ""
        self.token = ""

        self.frob = self._get_frob()
        self._get_user_auth(open_browser)
        self.token = self._get_token()

    def get_album(self, album_id):
        return self('album.get', album_id=album_id)['album']

    def get_album_list(self):
        page = 1
        total_pages = -1
        albums = []
        while True:
            resp = self('album.getList', page=page)
            albums += resp['albums']['album']
            page = int(resp['albums']['page'])
            total_pages = int(resp['albums']['pages'])
            if page >= total_pages:
                break
            page += 1
        return albums

    def get_album_documents(self, album_id):
        page = 1
        total_pages = -1
        total_docs = -1
        docs = []
        log('Downloading document list for album %s' % album_id)
        while True:
            resp = self('album.docs.getList', album_id=album_id,
                        per_page=100, page=page)
            total_docs = int(resp['album']['docs']['total'])

            for doc in resp['album']['docs']['doc']:
                doc_id = doc['doc_id']
                docs.append(self.get_document(doc_id=doc_id))

            page = int(resp['album']['docs']['page'])
            total_pages = int(resp['album']['docs']['pages'])
            if page >= total_pages:
                break
            page += 1
        assert len(docs) == total_docs
        return IpernityAPI._make_unique_documents(documents=docs)

    def get_document(self, doc_id):
        return self('doc.get', doc_id=doc_id)

    @staticmethod
    def _make_unique_documents(documents):
        names = set()
        for doc in documents:
            filename = doc['doc']['original']['filename']
            counter = 1
            while filename in names:
                (root, ext) = path.splitext(filename)
                filename = "%s-%d%s" % (root, counter, ext)
                log("Changing %s => %s" % (doc['doc']['original']['filename'],
                                           filename))
                doc['doc']['original']['filename'] = filename
            names.add(filename)
        return documents

    def _get_frob(self):
        resp = self('get-frob')
        return resp['auth']['frob']

    def _get_user_auth(self, open_browser):
        url = IpernityAPI._call('get-user-auth',
                              key=self.key,
                              secret=self.secret,
                              frob=self.frob)
        url = url.strip()
        fallback=False
        if open_browser:
            system = platform.system()
            if system == 'Darwin':
                subprocess.check_call("open \"%s\"" % url, shell=True)
            elif system == 'Linux':
                subprocess.check_call(['xdg-open', url], shell=True)
            else:
                fallback = True
        else:
            fallback = True
        if fallback:
            print "Please, visit\n%s\n and authorize this script" % url
        raw_input("Press any key to continue.")

    def _get_token(self):
        resp = self('get-token')
        return resp['auth']['token']

    def __call__(self, method, **kwargs):
        output = IpernityAPI._call(method, key=self.key, secret=self.secret,
                                   token=self.token, frob=self.frob,
                                   **kwargs)
        js = json.loads(output)
        #log_json(js)
        if js['api']['status'] == 'error':
            raise IpernityError(method=method, code=js['api']['code'],
                                message=js['api']['message'])
        return js

    @staticmethod
    def _call(method, key, secret, token="", frob="", **kwargs):
        call = [ path.join(MYDIR, 'iper-api-call.sh'),
                 '-k', key,
                 '-s', secret,
                 '-t', token,
                 '-f', frob,
                 method,
                 ' '.join(
                     ['%s=%s' % (k, v) for k, v in kwargs.iteritems()])
                 ]
        #log(call)
        output = subprocess.check_output(call, shell=False)
        output = output.strip()
        return output

def download_album(api, album_id, album_title, output_dir):
    log('Downloading Album "%s" (%s)' % (album_title, album_id))
    album_dir = path.join(output_dir, album_title)
    if not path.isdir(album_dir):
        log("Creating album directory %s" % album_dir)
        os.makedirs(album_dir)
    docs = api.get_album_documents(album_id=album_id)
    log("Downloading %s documents from album %s" % (len(docs), album_title))
    total_docs = 0
    for doc in docs:
        url = doc['doc']['original']['url']
        filename = path.join(album_dir, doc['doc']['original']['filename'])
        if path.isfile(filename) and path.getsize(filename) > 0:
            log("File %s already downloaded" % filename)
        else:
            tempname = ''
            with tempfile.NamedTemporaryFile() as f:
                tempname = f.name
            log("Downloading %s: %s" % (url, tempname))
            urllib.urlretrieve(url, tempname)
            # log("Renaming %s => %s" % (tempname, filename))
            os.rename(tempname, filename)
        total_docs += 1
    assert total_docs == len(docs)


if not path.isdir(args.output):
    log("Creating output directory %s" % args.output)
    os.makedirs(args.output)

api = IpernityAPI(key=args.key, secret=args.secret)

albums = api.get_album_list()
for album in albums:
    album_title = album['title']
    album_id = album['album_id']
    download_album(api=api, album_id=album_id, album_title=album_title,
                   output_dir=args.output)

