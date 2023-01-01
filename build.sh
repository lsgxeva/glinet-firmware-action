#!/bin/bash
#filename: build.sh
#usage: ./build.sh $HOME

CRTDIR=$(pwd)

base=$1
profile=$2
ui=$3
dlg=$4
dlo=$5

echo "base => $base"
if [ ! -e "$base" ]; then
	echo "Please enter base folder"
	exit 1
else
	if [ ! -d $base ]; then 
		echo "Openwrt base folder not exist"
		exit 1
	fi
fi

if [ ! -n "$profile" ]; then
	profile=target_wlan_ap-gl-axt1800
fi
echo "profile => $profile"

if [ ! -n "$ui" ]; then
	ui=true
fi
echo "ui => $ui"

if [ ! -n "$dlg" ]; then
	dlg=false
fi
echo "dlg => $dlg"

if [ ! -n "$dlo" ]; then
	dlo=false
fi
echo "dlo => $dlo"


echo "clone gl-infra-builder source ..."
git clone https://github.com/gl-inet/gl-infra-builder.git $base/gl-infra-builder
cp -r custom/  $base/gl-infra-builder/feeds/custom/
cp -r *.yml $base/gl-infra-builder/profiles
cd $base/gl-infra-builder

echo "setup config profile ..."
if [[ $profile == *5-4* ]]; then
	python3 setup.py -c configs/config-wlan-ap-5.4.yml
elif [[ $profile == *a1300* ]]; then
	python3 setup.py -c configs/config-21.02.2.yml
elif [[ $profile == *mt7981* ]]; then
	python3 setup.py -c configs/config-mt798x-7.6.6.1.yml
else
	python3 setup.py -c configs/config-wlan-ap.yml
fi

echo "preparation project director ..."
if [[ $profile == *wlan_ap*  ]]; then
	ln -s $base/gl-infra-builder/wlan-ap/openwrt ~/openwrt
elif [[ $profile == *mt7981* ]]; then
	ln -s $base/gl-infra-builder/mt7981 ~/openwrt
else
	ln -s $base/gl-infra-builder/openwrt-21.02/openwrt-21.02.2 ~/openwrt
fi
cd ~/openwrt

echo "generate config profile ..."
if [[ $ui == true  ]] && [[ $profile == *wlan_ap* ]]; then 
	./scripts/gen_config.py $profile glinet_depends custom
elif [[ $ui == true  ]] && [[ $profile == *mt7981* ]]; then
	./scripts/gen_config.py $profile glinet_depends custom
else
	./scripts/gen_config.py $profile openwrt_common luci custom
fi

echo "checkout golang package ..."
# fix helloword build error
rm -rf feeds/packages/lang/golang
svn co https://github.com/openwrt/packages/branches/openwrt-22.03/lang/golang feeds/packages/lang/golang

echo "clone glinet sdk ..."
git clone https://github.com/gl-inet/glinet4.x.git $base/glinet
if [[ $ui == true  ]] && [[ $profile == *wlan_ap* ]]; then 
	GL_PKGDIR=$base/glinet/ipq60xx/
elif [[ $ui == true  ]] && [[ $profile == *mt7981* ]]; then
	GL_PKGDIR=$base/glinet/mt7981/
else
	GL_PKGDIR=''
fi

echo "feeds update install ..."
./scripts/feeds update -a 
./scripts/feeds install -a

echo "make defconfig ..."
make defconfig

echo "make download ..."
make download -j$(expr $(nproc) + 1) 

mkdir -p ~/openwrt/artifact
if [[ $dlg == true ]] || [[ $dlo == true ]] ; then
	cd ~/openwrt/artifact
	if [[ $dlg == true ]]; then 
		tar -zcpf glinet_dl.tar.gz ~/gl-infra-builder --exclude="~/gl-infra-builder/wlan-ap" --exclude="~/gl-infra-builder/mt7981" 
		du -sh glinet_dl.tar.gz
	fi
	if [[ $dlo == true ]]; then 
		tar -zcpf openwrt_dl.tar.gz ~/gl-infra-builder/wlan-ap --exclude="~/gl-infra-builder/wlan-ap/openwrt/artifact" --exclude="~/gl-infra-builder/wlan-ap/openwrt/bin" --exclude="~/gl-infra-builder/wlan-ap/openwrt/build_dir" --exclude="~/gl-infra-builder/wlan-ap/openwrt/staging_dir" --exclude="~/gl-infra-builder/wlan-ap/openwrt/tmp" --exclude="~/gl-infra-builder/wlan-ap/openwrt/logs" 
		du -sh openwrt_dl.tar.gz
	fi
	echo "will be exit"
	exit 0
fi

echo "compile firmware ..."
if [ ! -n "$GL_PKGDIR" ]; then 
	make -j$(expr $(nproc) + 1) GL_PKGDIR=$GL_PKGDIR V=s
else
	make -j$(expr $(nproc) + 1) V=s
fi

echo "prepare artifact ..."
rm -rf $(find ~/openwrt/bin/targets/ -type d -name "packages")
cp -rf $(find ~/openwrt/bin/targets/ -type f) ~/openwrt/artifact/
#cp -rf $(find ~/openwrt/bin/packages/ -type f -name "*.ipk") ~/openwrt/artifact/
#cp -rf $(find ~/openwrt/bin/targets/ -type f -name "*.buildinfo" -o -name "*.manifest") ~/openwrt/artifact/
du -sh ~/openwrt/artifact/*

echo "build done."
exit 0
