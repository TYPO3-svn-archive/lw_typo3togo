#!/bin/bash

# TYPO3togo (2011/02/18)
#
# (c) 2011 Lightwerk GmbH, written by Rene J. Pollesch
#
# This script automagically creates a portable version of TYPO3 using
# Server2Go which includes Apache, MySQL and so on. Please make sure the
# following settings are correct:

# absolute path to HTTP document root
TYPO3_DOCROOT="/var/www"

# those files or directories will be copied into Server2Go document root
TYPO3_DEPENDENCIES="typo3 typo3conf uploads t3lib typo3temp fileadmin index.php .htaccess"

# replace this domain or IP address in SQL dump by 127.0.0.1
TYPO3_ORIGINAL_DOMAIN="192.168.1.253"

# MySQL connection
MYSQL_HOSTNAME="localhost"
MYSQL_DATABASE="typo3togo"
MYSQL_USERNAME="root"
MYSQL_PASSWORD="ubuntu"
MYSQL_DIRECTORY="/var/lib/mysql"

# we need those files. make sure the links are still valid!
HTTP_RESOURCE_SERVER2GO="http://www.server2go-download.de/download/server2go_a22_psm.zip"
HTTP_RESOURCE_IMAGEMAGICK="http://www.imagemagick.org/download/binaries/ImageMagick-6.6.7-Q16-windows.zip"
HTTP_RESOURCE_SPLASHSCREEN="http://forge.typo3.org/attachments/download/5543/typo3togo_750px.png"

# target archive (without file suffix!) and archiver to use ("zip" or "tar.gz")
TYPO3TOGO_ARCHIVER="zip"
TYPO3TOGO_STORAGE="/var/tmp"

# -----------------------------------------------------------------------------

_tmp_dir=`mktemp -d`
_tmp_files="${_tmp_dir}/files"
_tmp_build="${_tmp_dir}/server2go"
_tmp_zip="${_tmp_dir}/server2go.zip"
_tmp_dump="${_tmp_dir}/database.sql"
_tmp_httpd_conf="${_tmp_dir}/httpd.conf"
_tmp_db="`mktemp -u "${MYSQL_DATABASE}_XXXXX"`"

_mkfilelist(){
	cd "$1" && find "$2" -not \( -name '*.svn' -prune \) >>"$3"
}

_log() {
	echo "`date '+%x %X'` $1"
}

_log "Will start to create a TYPO3togo package! Please be patient..."

if [ ! -d "${TYPO3TOGO_STORAGE}" ]; then
	mkdir "${TYPO3TOGO_STORAGE}" >/dev/null 2>&1

	if [ "$0" -ne "0" ]; then
		_log "ERROR: Could not create storage folder: ${TYPO3TOGO_STORAGE}"
		exit
	fi
fi

if [ ! -f "${TYPO3TOGO_STORAGE}/server2go.zip" ]; then
	_log "Downloading Server2Go"
	wget "${HTTP_RESOURCE_SERVER2GO}" -O "${TYPO3TOGO_STORAGE}/server2go.zip" >/dev/null 2>&1
fi

if [ ! -f "${TYPO3TOGO_STORAGE}/imagemagick.zip" ]; then
	_log "Downloading ImageMagick"
	wget "${HTTP_RESOURCE_IMAGEMAGICK}" -O "${TYPO3TOGO_STORAGE}/imagemagick.zip" >/dev/null 2>&1
fi

_log "Decompressing Server2Go"
unzip "${TYPO3TOGO_STORAGE}/server2go.zip" -d "${_tmp_dir}" -x "server2go/htdocs/*" >/dev/null 2>&1
if [ "$?" -ne "0" ]; then
	_log "ERROR: Could not decompress Server2Go archive! (unzip available?)"
	exit
fi
mv "${_tmp_dir}/server2go/Server2Go.exe" "${_tmp_dir}/server2go/TYPO3togo.exe"

_log "Decompressing ImageMagick"
unzip "${TYPO3TOGO_STORAGE}/imagemagick.zip" -d "${_tmp_dir}/server2go/server" >/dev/null 2>&1
if [ "$?" -ne "0" ]; then
	_log "ERROR: Could not decompress ImageMagick?"
	exit
else
	mv "`find ${_tmp_dir}/server2go/server -maxdepth 1 -iname imagemagick*`" "${_tmp_dir}/server2go/server/imagemagick"
fi

_log "Generating file list"
for _dep in ${TYPO3_DEPENDENCIES}; do
	if [ -f "${TYPO3_DOCROOT}/${_dep}" ]; then
		echo "${_dep}" >>${_tmp_files}
	else
		_mkfilelist "${TYPO3_DOCROOT}" "${_dep}" "${_tmp_files}"
	fi
done
_log "`cat ${_tmp_files}|wc|awk '{printf("%d",$1);}'` files found"

_log "Copying files from HTTP document root"
while read _fname; do
	_dname="`dirname "${_fname}"`"
        [ ! -d "${_tmp_build}/htdocs/${_dname}" ] && mkdir -p "${_tmp_build}/htdocs/${_dname}"
	cp "${TYPO3_DOCROOT}/${_fname}" "${_tmp_build}/htdocs/${_dname}" >/dev/null 2>&1
done < "${_tmp_files}"

_log "Dumping database"
mysqldump -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOSTNAME} ${MYSQL_DATABASE} | sed -e "s/${TYPO3_ORIGINAL_DOMAIN}/127.0.0.1:4001/g" >"${_tmp_dump}"
if [ ! "$?" -eq "0" ]; then
	_log "ERROR: Could not dump database! (permission?)"
	exit
fi

_log "Creating temporary database: ${_tmp_db}"
mysql -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOSTNAME} -e"CREATE DATABASE ${_tmp_db}"
mysql -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOSTNAME} ${_tmp_db} < ${_tmp_dump}

_log "Preparing TYPO3 database and configuration"
mysql -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOSTNAME} ${_tmp_db} -e "ALTER TABLE cache_hash ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE cache_imagesizes ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE cache_md5params ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE cache_pages ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE cache_pagesection ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE cache_typo3temp_log ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE fe_sessions ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE fe_session_data ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE index_grlist ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE index_phash ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE index_rel ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE index_section ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE index_stat_search ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE index_stat_word ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE sys_log ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE tx_realurl_chashcache ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE tx_realurl_pathcache ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE tx_realurl_urldecodecache ENGINE = MYISAM ROW_FORMAT = COMPACT; ALTER TABLE tx_realurl_urlencodecache ENGINE = MYISAM ROW_FORMAT = COMPACT;"
mysql -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOSTNAME} ${_tmp_db} -e "TRUNCATE cache_extensions; TRUNCATE cache_hash; TRUNCATE cache_md5params; TRUNCATE cache_pages; TRUNCATE cache_pagesection; TRUNCATE cache_typo3temp_log; TRUNCATE fe_users; TRUNCATE sys_log; TRUNCATE sys_history; TRUNCATE tx_realurl_chashcache; TRUNCATE tx_realurl_errorlog; TRUNCATE tx_realurl_pathcache; TRUNCATE tx_realurl_redirects; TRUNCATE tx_realurl_uniqalias; TRUNCATE tx_realurl_urldecodecache; TRUNCATE tx_realurl_urlencodecache; TRUNCATE index_fulltext;"
rm -f ${_tmp_build}/htdocs/typo3conf/deprecation_*.log ${_tmp_build}/htdocs/typo3conf/temp_*.php ${_tmp_build}/Thumbs.db >/dev/null 2>&1
cat ${TYPO3_DOCROOT}/typo3conf/localconf.php \
	| sed -e 's/$typo_db_username.*/$typo_db_username = '\''root'\'';/g' \
	| sed -e 's/$typo_db_password.*/$typo_db_password = '\'''\'';/g' \
	| sed -e 's/$TYPO3_CONF_VARS\['\''GFX'\''\]\['\''im_path'\''\].*/$TYPO3_CONF_VARS\['\''GFX'\''\]\['\''im_path'\''\] = $_ENV\["S2G_SERVER_APPROOT"\].'\''server'\\\\\\\\'imagemagick'\\\\\\\\''\'';/g' \
	| sed -e 's/$TYPO3_CONF_VARS\['\''GFX'\''\]\['\''im_path_lzw'\''\].*/$TYPO3_CONF_VARS\['\''GFX'\''\]\['\''im_path_lzw'\''\] = $_ENV\["S2G_SERVER_APPROOT"\].'\''server'\\\\\\\\'imagemagick'\\\\\\\\''\'';/g' \
	| sed -e 's/$TYPO3_CONF_VARS\['\''GFX'\''\]\['\''im_version_5'\''\].*/$TYPO3_CONF_VARS\['\''GFX'\''\]\['\''im_version_5'\''\] = '\''0'\'';/g' \
	> ${_tmp_build}/htdocs/typo3conf/localconf.php
wget "${HTTP_RESOURCE_SPLASHSCREEN}" -O "${_tmp_build}/splash.png" >/dev/null 2>&1
mv "${_tmp_build}/server/config_tpl/httpd.conf" "${_tmp_httpd_conf}"
cat "${_tmp_httpd_conf}" \
	| sed -e 's/AllowOverride None/AllowOverride FileInfo/g' \
	| sed -e 's/'\#'LoadModule rewrite_module/LoadModule rewrite_module/g' \
	> ${_tmp_build}/server/config_tpl/httpd.conf

_log "Copying database to TYPO3togo"
mkdir "${_tmp_build}/dbdir/${MYSQL_DATABASE}"
cp -R ${MYSQL_DIRECTORY}/${_tmp_db}/* "${_tmp_build}/dbdir/${MYSQL_DATABASE}"

_log "Compressing target package using ${TYPO3TOGO_ARCHIVER}"
cd "${_tmp_build}"
if [ "${TYPO3TOGO_ARCHIVER}" == "zip" ]; then
	zip -rq9 "${TYPO3TOGO_STORAGE}/typo3togo.${TYPO3TOGO_ARCHIVER}" *
else
	tar -cf - * | gzip -9 - >"${TYPO3TOGO_STORAGE}/typo3togo.${TYPO3TOGO_ARCHIVER}" 2>/dev/null
fi

_log "Cleaning up"
mysql -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} -h${MYSQL_HOSTNAME} -e"DROP DATABASE ${_tmp_db}"
rm -rf "${_tmp_dir}"

_log "Finished creating TYPO3togo package: ${TYPO3TOGO_STORAGE}/typo3togo.${TYPO3TOGO_ARCHIVER}"
