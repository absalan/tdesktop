#!/bin/bash

set -e

REPO="$PWD"
[[ ! $MAKE_ARGS ]] && MAKE_ARGS="--quiet -j4"
QT_VERSION=5.6.0
QT_PATH="$REPO/build/qt"
UPSTREAM="$REPO/upstream"
EXTERNAL="$REPO/external"

run() {    
    g++ --version
    
    # Move files to subdir
    cd ..
    mv tdesktop tdesktop2
    mkdir tdesktop
    mv tdesktop2 "$UPSTREAM"

    downloadLibs
    build
    check
}

# install
downloadLibs() {
    cd "$REPO"
    mkdir external && cd external
    
	echo -e "Clone Qt ${QT_VERSION}\n"
	git clone git://code.qt.io/qt/qt5.git qt${QT_VERSION}
	cd qt${QT_VERSION}
	git checkout $(echo ${QT_VERSION} | sed -e "s/\..$//")
	perl init-repository --module-subset=qtbase,qtimageformats
	git checkout v${QT_VERSION}
	cd qtbase && git checkout v${QT_VERSION} && cd ..
	cd qtimageformats && git checkout v${QT_VERSION} && cd ..
	cd ..

    git clone          https://chromium.googlesource.com/breakpad/breakpad
    git clone          https://git.mel.vin/mirror/dee.git
    git clone          https://git.ffmpeg.org/ffmpeg.git
    git clone          https://git.mel.vin/mirror/libunity.git
    git clone          https://github.com/xkbcommon/libxkbcommon.git
    git clone          https://chromium.googlesource.com/linux-syscall-support
    git clone          https://github.com/kcat/openal-soft.git
}

build() {
# libxkbcommon
cd "$EXTERNAL/libxkbcommon"
./autogen.sh \
	--prefix='/usr/local'
make $MAKE_ARGS
sudo make install
sudo ldconfig

# ffmpeg
cd "$EXTERNAL/ffmpeg"
./configure \
	--prefix='/usr/local' \
	--disable-debug \
	--disable-programs \
	--disable-doc \
	--disable-everything \
	--enable-gpl \
	--enable-version3 \
	--enable-libopus \
	--enable-decoder=aac \
	--enable-decoder=aac_latm \
	--enable-decoder=aasc \
	--enable-decoder=flac \
	--enable-decoder=gif \
	--enable-decoder=h264 \
	--enable-decoder=h264_vdpau \
	--enable-decoder=mp1 \
	--enable-decoder=mp1float \
	--enable-decoder=mp2 \
	--enable-decoder=mp2float \
	--enable-decoder=mp3 \
	--enable-decoder=mp3adu \
	--enable-decoder=mp3adufloat \
	--enable-decoder=mp3float \
	--enable-decoder=mp3on4 \
	--enable-decoder=mp3on4float \
	--enable-decoder=mpeg4 \
	--enable-decoder=mpeg4_vdpau \
	--enable-decoder=msmpeg4v2 \
	--enable-decoder=msmpeg4v3 \
	--enable-decoder=opus \
	--enable-decoder=vorbis \
	--enable-decoder=wavpack \
	--enable-decoder=wmalossless \
	--enable-decoder=wmapro \
	--enable-decoder=wmav1 \
	--enable-decoder=wmav2 \
	--enable-decoder=wmavoice \
	--enable-encoder=libopus \
	--enable-hwaccel=h264_vaapi \
	--enable-hwaccel=h264_vdpau \
	--enable-hwaccel=mpeg4_vaapi \
	--enable-hwaccel=mpeg4_vdpau \
	--enable-parser=aac \
	--enable-parser=aac_latm \
	--enable-parser=flac \
	--enable-parser=h264 \
	--enable-parser=mpeg4video \
	--enable-parser=mpegaudio \
	--enable-parser=opus \
	--enable-parser=vorbis \
	--enable-demuxer=aac \
	--enable-demuxer=flac \
	--enable-demuxer=gif \
	--enable-demuxer=h264 \
	--enable-demuxer=mov \
	--enable-demuxer=mp3 \
	--enable-demuxer=ogg \
	--enable-demuxer=wav \
	--enable-muxer=ogg \
	--enable-muxer=opus
make $MAKE_ARGS
sudo make install
sudo ldconfig

# openal_soft
cd "$EXTERNAL/openal-soft/build"
cmake \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_BUILD_TYPE=Release \
    -D LIBTYPE=STATIC \
    ..
make $MAKE_ARGS
sudo make install
sudo ldconfig

# qtbase
cd "$EXTERNAL/qt${QT_VERSION}/qtbase"
git apply "$UPSTREAM/Telegram/Patches/qtbase_$(echo ${QT_VERSION} | sed -e "s/\./_/g").diff"
cd ..
./configure -prefix "$QT_PATH" -release -opensource -confirm-license -qt-zlib \
                -qt-libpng -qt-libjpeg -qt-freetype -qt-harfbuzz -qt-pcre -qt-xcb \
                -qt-xkbcommon-x11 -no-opengl -static -nomake examples -nomake tests \
                -dbus-runtime -openssl-linked -no-gstreamer -no-mtdev -no-xinput2 -no-gtkstyle -no-glib # <- Not sure about these
make $MAKE_ARGS
sudo make install

export PATH="$QT_PATH/bin:$PATH"

# breakpad
ln -s -f "$EXTERNAL/linux-syscall-support" "$EXTERNAL/breakpad/src/third_party/lss"
cd "$EXTERNAL/breakpad"
./configure
make $MAKE_ARGS

# patch telegram
    sed -i 's/CUSTOM_API_ID//g' "$UPSTREAM/Telegram/Telegram.pro"
	sed -i 's,LIBS += /usr/local/lib/libxkbcommon.a,,g' "$UPSTREAM/Telegram/Telegram.pro"
	sed -i 's,LIBS += /usr/local/lib/libz.a,LIBS += -lz,g' "$UPSTREAM/Telegram/Telegram.pro"
    sed -i "s,\..*/Libraries/breakpad/,$EXTERNAL/breakpad/,g" "$UPSTREAM/Telegram/Telegram.pro"

	local options=""

	if [[ $BUILD_VERSION == *"disable_autoupdate"* ]]; then
		options+="\nDEFINES += TDESKTOP_DISABLE_AUTOUPDATE"
	fi

	if [[ $BUILD_VERSION == *"disable_register_custom_scheme"* ]]; then
		options+="\nDEFINES += TDESKTOP_DISABLE_REGISTER_CUSTOM_SCHEME"
	fi

	if [[ $BUILD_VERSION == *"disable_crash_reports"* ]]; then
		options+="\nDEFINES += TDESKTOP_DISABLE_CRASH_REPORTS"
	fi

	if [[ $BUILD_VERSION == *"disable_network_proxy"* ]]; then
		options+="\nDEFINES += TDESKTOP_DISABLE_NETWORK_PROXY"
	fi

	if [[ $BUILD_VERSION == *"disable_desktop_file_generation"* ]]; then
		options+="\nDEFINES += TDESKTOP_DISABLE_DESKTOP_FILE_GENERATION"
	fi

	if [[ $BUILD_VERSION == *"disable_unity_integration"* ]]; then
		options+="\nDEFINES += TDESKTOP_DISABLE_UNITY_INTEGRATION"
	fi

	options+='\nINCLUDEPATH += "/usr/lib/glib-2.0/include"'
	options+='\nINCLUDEPATH += "/usr/lib/gtk-2.0/include"'
	options+='\nINCLUDEPATH += "/usr/include/opus"'
	options+='\nLIBS += -lcrypto -lssl'

	info_msg "Build options: ${options}"

	echo -e "${options}" >> "$UPSTREAM/Telegram/Telegram.pro"
    
    cat "$UPSTREAM/Telegram/Telegram.pro"

    buildTelegram
}

buildTelegram() {
	info_msg "Build codegen_style"
	# Build codegen_style
	mkdir -p "$UPSTREAM/Linux/obj/codegen_style/Debug"
	cd "$UPSTREAM/Linux/obj/codegen_style/Debug"
	qmake QT_TDESKTOP_PATH=${QT_PATH} QT_TDESKTOP_VERSION=${QT_VERSION} CONFIG+=debug "../../../../Telegram/build/qmake/codegen_style/codegen_style.pro"
	make $MAKE_ARGS

	info_msg "Build codegen_numbers"
	# Build codegen_numbers
	mkdir -p "$UPSTREAM/Linux/obj/codegen_numbers/Debug"
	cd "$UPSTREAM/Linux/obj/codegen_numbers/Debug"
	qmake QT_TDESKTOP_PATH=${QT_PATH} QT_TDESKTOP_VERSION=${QT_VERSION} CONFIG+=debug "../../../../Telegram/build/qmake/codegen_numbers/codegen_numbers.pro"
	make $MAKE_ARGS

	info_msg "Build MetaLang"
	# Build MetaLang
	mkdir -p "$UPSTREAM/Linux/DebugIntermediateLang"
	cd "$UPSTREAM/Linux/DebugIntermediateLang"
	qmake QT_TDESKTOP_PATH=${QT_PATH} QT_TDESKTOP_VERSION=${QT_VERSION} CONFIG+=debug "../../Telegram/MetaLang.pro"
	make $MAKE_ARGS

	info_msg "Build Telegram Desktop"
	# Build Telegram Desktop
	mkdir -p "$UPSTREAM/Linux/DebugIntermediate"
	cd "$UPSTREAM/Linux/DebugIntermediate"

	./../codegen/Debug/codegen_style "-I./../../Telegram/Resources" "-I./../../Telegram/SourceFiles" "-o./GeneratedFiles/styles" all_files.style --rebuild
	./../codegen/Debug/codegen_numbers "-o./GeneratedFiles" "./../../Telegram/Resources/numbers.txt"
	./../DebugLang/MetaLang -lang_in ./../../Telegram/Resources/langs/lang.strings -lang_out ./GeneratedFiles/lang_auto
	qmake QT_TDESKTOP_PATH=${QT_PATH} QT_TDESKTOP_VERSION=${QT_VERSION} CONFIG+=debug "../../Telegram/Telegram.pro"
	make $MAKE_ARGS
}

check() {
	local filePath="$UPSTREAM/Linux/Debug/Telegram"
	if test -f "$filePath"; then
		success_msg "Build successful done! :)"

		local size;
		size=$(stat -c %s "$filePath")
		success_msg "File size of ${filePath}: ${size} Bytes"
	else
		error_msg "Build error, output file does not exist"
		exit 1
	fi
}

source ./.travis/common.sh

run