# docker-websvn
Docker container for SVN and WebSVN

### SVN and WebSVN on docker
Runs apache server with PHP5 installed to run the WebSVN application. Apache is configured to use SVN_DAV to checkout and commit to the SVN repositories. Permissions are handled through a htaccess file. The permissions are common to SVN as well as WebSVN.

### Building the docker image
Use docker to build the image as you normaly would.
`docker build --rm=true --tag="image_websvn" ./`

### Running the docker container
Three data volumes are needed for this docker image.
* SVN data volume
* password data volume
* ssl certificate data volume

Untill these volumes are populate this image will not run.

Use this command to run the container and map the https port to a local IP address:
```bash
docker run -d --name websvn -P -p ${WEBSVN_IP}:443:443 \
  --volumes-from data_volume_websvn_ssl \
  --volumes-from data_volume_websvn_passwd \
  --volumes-from data_volume_websvn_svn \
  image_websvn
```

#### Populating the SVN data volume
Passing the argument `svn_import` to the image will run a script to setup the SVN repositories in the SVN data volume. Any arguments passed after `svn_import` will be the names of the repositories to be created. In adition full repositories can be imported by mapping a volume to the `/tmp/import_export` directory. Files in that directory matching `*.svndump.gz` will be passed through `gunzip` to `svnadmin load`. This will load the archived repository into the SVN data volume.

##### Examples:
```bash
docker run -ti --rm --volumes-from data_volume_websvn_svn    image_websvn svn_import repos_name_1 repos_name_2 repos_name_3 repos_name_4
docker run -ti --rm --volumes-from data_volume_websvn_svn    -v ${HOST_BACKUP_DIR}:/tmp/import_export image_websvn svn_import
```

#### Populating the password data volume
To get up and running quickly, pass the argument `passwd_generate` to the image. This will create an initial htpasswd file with one user. The username will be `novatech` with a password of `novatech`.

The recomended method for populating this file is to import the htpassword file. The file needs to be nammed `dav_svn.passwd`.

##### Example:
This example will generate the password file, export that password file and then finaly reimport that password file.
```bash
docker run -ti --rm --volumes-from data_volume_websvn_passwd image_websvn passwd_generate
docker run -ti --rm --volumes-from data_volume_websvn_passwd -v ${HOST_BACKUP_DIR}:/tmp/import_export image_websvn passwd_backup
docker run -ti --rm --volumes-from data_volume_websvn_passwd -v ${HOST_BACKUP_DIR}:/tmp/import_export image_websvn passwd_import
```

#### Populate the ssl certificate data volume
* This section probably needs more work in setting up better ssl certificates

Passing the argument `ssl_generate` to the image will run a script to setup a self signed ssl certificate in the SVN data volume. An optional argument can also be passed in for the subject line to the openssl program.

##### Example:
This example will generate the password file, export that password file and then finaly reimport that password file.

```bash
docker run -ti --rm --volumes-from data_volume_websvn_ssl    image_websvn ssl_generate
docker run -ti --rm --volumes-from data_volume_websvn_ssl    image_websvn ssl_generate "/C=US/ST=Kansas/L=Lenexa/O=Novatech/CN=websvn.example.com"
```

Alternativly the ssl certificate can be imported by passing `ssl_import` to the image. This will copy two files into the ssl certificate data volume. The two files are named `apache.key` and `apache.pem`.

### Backup the data volumes
The three following commands will run a script to export the data allowing the containers to be backed up.

```bash
docker run -ti --rm --volumes-from data_volume_websvn_svn    -v ${HOST_BACKUP_DIR}:/tmp/import_export image_websvn svn_backup
docker run -ti --rm --volumes-from data_volume_websvn_ssl    -v ${HOST_BACKUP_DIR}:/tmp/import_export image_websvn ssl_backup
docker run -ti --rm --volumes-from data_volume_websvn_passwd -v ${HOST_BACKUP_DIR}:/tmp/import_export image_websvn passwd_backup
```
