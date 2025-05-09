#!/bin/bash
# Build NGINX and modules on Heroku.
# This program is designed to run in a web dyno provided by Heroku.
# We would like to build an NGINX binary for the builpack on the
# exact machine in which the binary will run.
# Our motivation for running in a web dyno is that we need a way to
# download the binary once it is built so we can vendor it in the buildpack.
#
# Once the dyno has is 'up' you can open your browser and navigate
# this dyno's directory structure to download the nginx binary.

NGINX_VERSION=${NGINX_VERSION-1.26.2}
PCRE_VERSION=${PCRE_VERSION-8.45}
HEADERS_MORE_VERSION=${HEADERS_MORE_VERSION-0.38}

nginx_tarball_url=http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
pcre_tarball_url=http://nchc.dl.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2
headers_more_nginx_module_url=https://github.com/agentzh/headers-more-nginx-module/archive/v${HEADERS_MORE_VERSION}.tar.gz

temp_dir=$(mktemp -d /tmp/nginx.XXXXXXXXXX)

echo "Serving files from /tmp on $PORT"
cd /tmp
python -m http.server $PORT &

cd $temp_dir
echo "Temp dir: $temp_dir"

echo "Downloading $nginx_tarball_url"
curl -L $nginx_tarball_url | tar xzv

echo "Downloading $pcre_tarball_url"
(cd nginx-${NGINX_VERSION} && curl -L $pcre_tarball_url | tar xvj )

echo "Downloading $headers_more_nginx_module_url"
(cd nginx-${NGINX_VERSION} && curl -L $headers_more_nginx_module_url | tar xvz )

echo '#!/bin/sh' > /tmp/gcc-with-flags.sh
echo "exec /usr/bin/gcc-11 --sysroot=/app/.apt \"\$@\"" >> /tmp/gcc-with-flags.sh
chmod +x /tmp/gcc-with-flags.sh

(
	cd nginx-${NGINX_VERSION}
  export LD_LIBRARY_PATH=/app/.apt/usr/lib:/app/.apt/usr/lib/x86_64-linux-gnu
	./configure --with-cc=/tmp/gcc-with-flags.sh --with-pcre=pcre-${PCRE_VERSION} --prefix=/tmp/nginx --add-module=/${temp_dir}/nginx-${NGINX_VERSION}/headers-more-nginx-module-${HEADERS_MORE_VERSION} --with-http_gzip_static_module  --with-cc-opt="-Wno-error"

  (
    cd pcre-${PCRE_VERSION}
    CC="/tmp/gcc-with-flags.sh" CFLAGS="-O2 -fomit-frame-pointer -pipe" ./configure --disable-shared --disable-cpp
  )

	make install
)

while true
do
	sleep 1
	echo "."
done
